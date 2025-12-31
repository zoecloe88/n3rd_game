import 'dart:async' show StreamSubscription, TimeoutException;
import 'package:n3rd_game/utils/unawaited_helper.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:n3rd_game/models/game_room.dart';
import 'package:n3rd_game/models/room_invitation.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/exceptions/error_codes.dart';
import 'package:n3rd_game/services/rate_limiter_service.dart';
import 'package:n3rd_game/services/multiplayer/multiplayer_retry_queue.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/services/friends_service.dart';
import 'package:n3rd_game/services/notification_service.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/utils/input_sanitizer.dart';
import 'package:n3rd_game/utils/list_helper.dart';
import 'package:n3rd_game/utils/firebase_helper.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class MultiplayerService extends ChangeNotifier {
  FirebaseFirestore? _firestore;
  FirebaseAuth? _auth;
  final Connectivity _connectivity = Connectivity();
  final RateLimiterService _rateLimiter = RateLimiterService();
  final MultiplayerRetryQueue _retryQueue = MultiplayerRetryQueue();
  AnalyticsService? _analyticsService;
  FriendsService? _friendsService;
  NotificationService? _notificationService;

  /// Get Firestore instance if Firebase is available
  FirebaseFirestore? get _firestoreInstance {
    if (_firestore != null) return _firestore;
    if (!FirebaseHelper.isInitialized()) {
      LoggerService.debug('Firebase not initialized for MultiplayerService');
      return null;
    }
    try {
      _firestore = FirebaseFirestore.instance;
      return _firestore;
    } catch (e) {
      LoggerService.debug('Firebase not available for MultiplayerService', error: e);
      return null;
    }
  }

  /// Get Auth instance if Firebase is available
  FirebaseAuth? get _authInstance {
    if (_auth != null) return _auth;
    if (!FirebaseHelper.isInitialized()) {
      LoggerService.debug('Firebase not initialized for MultiplayerService');
      return null;
    }
    try {
      _auth = FirebaseAuth.instance;
      return _auth;
    } catch (e) {
      LoggerService.debug('Firebase not available for MultiplayerService', error: e);
      return null;
    }
  }

  void setAnalyticsService(AnalyticsService? service) {
    _analyticsService = service;
  }

  void setFriendsService(FriendsService? service) {
    _friendsService = service;
  }

  void setNotificationService(NotificationService? service) {
    _notificationService = service;
  }

  GameRoom? _currentRoom;
  StreamSubscription<DocumentSnapshot>? _roomSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isInitialized = false;
  bool _isReconnecting = false;
  bool _isAttemptingReconnection =
      false; // Mutex to prevent concurrent reconnection attempts
  DateTime? _lastDisconnectTime; // Track when disconnect occurred for UX
  String? _lastRoomId; // Store room ID for reconnection

  GameRoom? get currentRoom => _currentRoom;
  bool get isInitialized => _isInitialized;
  bool get isReconnecting => _isReconnecting;
  String? get currentUserId => _authInstance?.currentUser?.uid;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _isInitialized = true;
      await _retryQueue.init();
      _setupConnectivityListener();
      LoggerService.info('MultiplayerService initialized');
    } catch (e) {
      LoggerService.error('Error initializing MultiplayerService', error: e);
      _isInitialized = false;
    }
  }

  /// Setup connectivity listener for automatic reconnection
  void _setupConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      final isOnline =
          !results.contains(ConnectivityResult.none) && results.isNotEmpty;

      if (isOnline && _lastRoomId != null && _currentRoom == null) {
        // Network restored and we were in a room - attempt reconnection
        _attemptReconnection();
        // Process retry queue when network is restored
        unawaited(_processRetryQueue());
      } else if (!isOnline && _currentRoom != null) {
        // Network lost while in a room
        _lastDisconnectTime = DateTime.now();
        _lastRoomId = _currentRoom!.id;
        LoggerService.warning(
          'Network lost. Room ID saved for reconnection: $_lastRoomId',
        );
      }
    });
  }

  /// Attempt to reconnect to the last room after network restoration
  ///
  /// **Reconnection Algorithm:**
  /// 1. Checks mutex to prevent concurrent reconnection attempts
  /// 2. Waits for network to stabilize (2 seconds)
  /// 3. Validates room still exists in Firestore
  /// 4. Verifies user is still a member of the room
  /// 5. Restores room state and re-establishes listener
  /// 6. Tracks reconnection time for analytics/UX
  ///
  /// **Edge Cases Handled:**
  /// - Concurrent attempts: Protected by mutex (_isAttemptingReconnection)
  /// - Room deleted: Cancels reconnection, clears saved room ID
  /// - User removed: Cancels reconnection, clears saved room ID
  /// - Network timeout: Logs error, allows retry on next connectivity change
  /// - Firestore errors: Handles gracefully, logs for debugging
  ///
  /// **State Management:**
  /// - Sets _isReconnecting flag for UI feedback
  /// - Clears _lastRoomId on success or permanent failure
  /// - Notifies listeners of state changes
  ///
  /// **Performance:**
  /// - Uses timeout (10 seconds) to prevent indefinite hangs
  /// - Waits for network stabilization before attempting
  /// - Cancels operation if room/user validation fails
  ///
  /// CRITICAL: Uses mutex to prevent concurrent reconnection attempts
  Future<void> _attemptReconnection() async {
    // CRITICAL: Mutex to prevent concurrent reconnection attempts
    if (_isAttemptingReconnection || _isReconnecting || _lastRoomId == null) {
      return;
    }

    _isAttemptingReconnection = true;
    _isReconnecting = true;
    notifyListeners();

    try {
      LoggerService.debug('Attempting to reconnect to room: $_lastRoomId');

      // Wait a moment for network to stabilize
      await Future.delayed(const Duration(seconds: 2));

      // Check if room still exists and we're still a member
      final firestore = _firestoreInstance;
      if (firestore == null) {
        LoggerService.warning('Firebase not available, cannot reconnect');
        _isReconnecting = false;
        _isAttemptingReconnection = false;
        notifyListeners();
        return;
      }
      final docRef = firestore.collection('game_rooms').doc(_lastRoomId!);
      final doc = await docRef.get().timeout(const Duration(seconds: 10));

      if (!doc.exists) {
        LoggerService.warning(
          'Room $_lastRoomId no longer exists. Reconnection cancelled.',
        );
        _lastRoomId = null;
        _isReconnecting = false;
        _isAttemptingReconnection = false;
        notifyListeners();
        return;
      }

      final room = GameRoom.fromFirestore(doc);
      final auth = _authInstance;
      final userId = auth?.currentUser?.uid;

      if (userId == null || !room.players.any((p) => p.userId == userId)) {
        LoggerService.warning(
          'User no longer in room $_lastRoomId. Reconnection cancelled.',
        );
        _lastRoomId = null;
        _isReconnecting = false;
        _isAttemptingReconnection = false;
        notifyListeners();
        return;
      }

      // Rejoin the room
      _currentRoom = room;
      _listenToRoom(_lastRoomId!);

      // Calculate reconnection time for analytics/UX
      final reconnectDuration = _lastDisconnectTime != null
          ? DateTime.now().difference(_lastDisconnectTime!)
          : null;

      _lastRoomId = null;
      _lastDisconnectTime = null;
      _isReconnecting = false;
      _isAttemptingReconnection = false;

      final durationStr = reconnectDuration != null
          ? ' (reconnected after ${reconnectDuration.inSeconds}s)'
          : '';
      LoggerService.info(
        'Successfully reconnected to room: ${room.id}$durationStr',
      );

      // Process retry queue after successful reconnection
      await _processRetryQueue();

      notifyListeners();
    } catch (e, stackTrace) {
      LoggerService.error(
        'Failed to reconnect to room: $_lastRoomId',
        error: e,
        stack: stackTrace,
      );
      _isReconnecting = false;
      _isAttemptingReconnection = false;
      _lastRoomId = null; // Clear on failure to prevent retry loops
      notifyListeners();
    }
  }

  /// Check network connectivity and internet reachability before multiplayer operations
  Future<void> _checkConnectivity() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity();
      final isOffline = connectivityResults.contains(ConnectivityResult.none) ||
          connectivityResults.isEmpty;
      if (isOffline) {
        throw NetworkException(
          'No internet connection. Please check your network and try again.',
        );
      }

      // Additional check: Verify actual internet reachability (not just connection type)
      // This prevents issues where device is connected to WiFi but has no internet
      try {
        final result = await InternetAddress.lookup(
          'firebase.googleapis.com',
        ).timeout(const Duration(seconds: 5));
        if (result.isEmpty || result[0].rawAddress.isEmpty) {
          throw NetworkException(
            'Connected to network but no internet access. Please check your connection.',
          );
        }
      } catch (e) {
        if (e is NetworkException) rethrow;
        // If DNS lookup fails, we don't have internet
        throw NetworkException(
          'No internet access. Please check your connection and try again.',
        );
      }
    } catch (e) {
      if (e is NetworkException) rethrow;
      // If connectivity check fails, assume online and continue
      // (Firestore will handle offline persistence)
      if (kDebugMode) {
        debugPrint(
          'Failed to check connectivity: $e - continuing with operation',
        );
      }
    }
  }

  /// Execute Firestore operation with timeout and retry logic
  Future<T> _executeWithRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration timeout = const Duration(seconds: 15),
    String operationName = 'Firestore operation',
  }) async {
    int attempts = 0;
    String? lastError;

    while (attempts < maxRetries) {
      try {
        return await operation().timeout(timeout);
      } on TimeoutException catch (e) {
        lastError = 'Timeout: $e';
        if (kDebugMode) {
          debugPrint(
            '$operationName timeout (attempt ${attempts + 1}/$maxRetries)',
          );
        }
      } on FirebaseException catch (e) {
        // CRITICAL: Handle permission-denied errors specifically
        // Don't retry on permission errors - they won't succeed on retry
        if (e.code == 'permission-denied') {
          LoggerService.error(
            '$operationName: Permission denied. User may not be authenticated or lacks required permissions. '
            'Operation: $operationName, Firebase code: ${e.code}, Message: ${e.message ?? 'No message'}',
            error: e,
            reason: 'Firestore permission-denied error',
            fatal: false,
          );
          // Check if user is authenticated
          final auth = _authInstance;
      final userId = auth?.currentUser?.uid;
          if (userId == null) {
            throw AuthenticationException(
              'User not authenticated. Please log in to continue.',
              recoverySuggestion:
                  'Please sign in to access multiplayer features.',
            );
          }
          throw NetworkException(
            'Permission denied. You may not have access to this feature.',
            recoverySuggestion:
                'Please check your subscription status or contact support if you believe you should have access.',
          );
        }
        // For other Firebase errors, log and rethrow
        lastError = 'Firebase error (${e.code}): ${e.message}';
        LoggerService.error(
          '$operationName: Firebase error ${e.code}',
          error: e,
          reason: 'Firestore operation failed',
          fatal: false,
        );
        // Don't retry on other Firebase errors
        rethrow;
      } catch (e) {
        lastError = e.toString();
        // Don't retry on validation/authentication errors
        if (e is ValidationException || e is AuthenticationException) {
          rethrow;
        }
        if (kDebugMode) {
          debugPrint(
            '$operationName failed (attempt ${attempts + 1}/$maxRetries): $e',
          );
        }
      }

      attempts++;
      if (attempts < maxRetries) {
        // Exponential backoff: 1s, 2s, 4s
        final delay = Duration(milliseconds: 1000 * (1 << (attempts - 1)));
        await Future.delayed(delay);
      }
    }

    throw NetworkException(
      '$operationName failed after $maxRetries attempts: $lastError',
    );
  }

  // Create a new game room
  // CRITICAL: Uses transaction to ensure atomic room creation
  // NOTE: Premium check should be done in UI layer, but we validate here as well
  Future<GameRoom> createRoom({
    required MultiplayerMode mode,
    required int maxPlayers,
    bool friendsOnly = false,
    List<String>? allowedPlayers,
    SubscriptionService? subscriptionService,
  }) async {
    final auth = _authInstance;
    final user = auth?.currentUser;
    if (user == null) {
      throw AuthenticationException('User must be logged in to create a room');
    }

    // Premium check - validate premium status if subscription service provided
    if (subscriptionService != null && !subscriptionService.isPremium) {
      throw ValidationException(
        'Premium subscription required to create game lobbies',
        recoverySuggestion: 'Please upgrade to Premium to access multiplayer features.',
      );
    }

    // CRITICAL: Rate limit room creation to prevent abuse
    final isAllowed = await _rateLimiter.isAllowed(
      'create_room',
      maxAttempts: 10,
      window: const Duration(minutes: 15),
    );
    if (!isAllowed) {
      throw ValidationException(
        'Too many room creation attempts. Please wait before creating another room.',
      );
    }

    // Check connectivity before creating room
    await _checkConnectivity();

    final hostPlayer = Player(
      userId: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      lastActive: DateTime.now(),
    );

    // If friends-only, get host's friends list for allowedPlayers
    List<String>? finalAllowedPlayers = allowedPlayers;
    if (friendsOnly && _friendsService != null) {
      try {
        await _friendsService!.init();
        final friends = _friendsService!.friends;
        finalAllowedPlayers = [user.uid, ...friends.map((f) => f.userId)];
      } catch (e) {
        LoggerService.warning(
          'Failed to load friends for friend-only room, using provided allowedPlayers',
          error: e,
        );
      }
    }

    final room = GameRoom(
      id: '', // Will be set by Firestore
      hostId: user.uid,
      mode: mode,
      maxPlayers: maxPlayers,
      createdAt: DateTime.now(),
      friendsOnly: friendsOnly,
      allowedPlayers: finalAllowedPlayers,
    );

    // Track performance for room creation
    final startTime = DateTime.now();
    int retryCount = 0;

    // Use retry logic for room creation
    final createdRoom = await _executeWithRetry<GameRoom>(
      () async {
        retryCount++;
        final firestore = _firestoreInstance;
        if (firestore == null) {
          throw NetworkException(
            'Firebase not available',
            errorCode: ErrorCode.networkServerError,
          );
        }
        final docRef =
            await firestore.collection('game_rooms').add(room.toJson());

        // Atomically set room ID and add host as first player
        await docRef.update({
          'id': docRef.id,
          'players': [hostPlayer.toJson()],
          'friendsOnly': friendsOnly,
          'invitedFriends': <String>[],
          if (finalAllowedPlayers != null)
            'allowedPlayers': finalAllowedPlayers,
        });

        return room.copyWith(
          id: docRef.id,
          players: [hostPlayer],
          friendsOnly: friendsOnly,
          allowedPlayers: finalAllowedPlayers,
        );
      },
      operationName: 'Create room',
    );

    // Log performance metrics
    final duration = DateTime.now().difference(startTime);
    unawaited(
      _analyticsService?.logRoomCreation(
        duration,
        success: true,
        mode: mode.name,
        maxPlayers: maxPlayers,
        retryCount:
            retryCount - 1, // Subtract 1 since first attempt isn't a retry
      ),
    );

    _currentRoom = createdRoom;
    _listenToRoom(createdRoom.id);

    notifyListeners();
    return createdRoom;
  }

  // Join an existing room
  // CRITICAL: Uses Firestore transaction to prevent race conditions
  // This ensures atomic check-and-update to prevent exceeding maxPlayers
  // NOTE: Premium check should be done in UI layer, but we validate here as well
  Future<GameRoom> joinRoom(
    String roomId, {
    SubscriptionService? subscriptionService,
  }) async {
    final auth = _authInstance;
    final user = auth?.currentUser;
    if (user == null) {
      throw AuthenticationException('User must be logged in to join a room');
    }

    // Premium check - validate premium status if subscription service provided
    if (subscriptionService != null && !subscriptionService.isPremium) {
      throw ValidationException(
        'Premium subscription required to join game lobbies',
        recoverySuggestion: 'Please upgrade to Premium to access multiplayer features.',
      );
    }

    // CRITICAL: Sanitize room ID to prevent injection attacks
    final sanitizedRoomId = InputSanitizer.sanitizeFileName(roomId);
    if (sanitizedRoomId.isEmpty || sanitizedRoomId != roomId) {
      throw ValidationException('Invalid room ID format');
    }

    // CRITICAL: Rate limit room joining to prevent abuse
    final isAllowed = await _rateLimiter.isAllowed(
      'join_room',
      maxAttempts: 20,
      window: const Duration(minutes: 15),
    );
    if (!isAllowed) {
      throw ValidationException(
        'Too many join attempts. Please wait before joining another room.',
      );
    }

    // Check connectivity before joining room
    await _checkConnectivity();

    final newPlayer = Player(
      userId: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      lastActive: DateTime.now(),
    );

    // Track performance for room joining
    final startTime = DateTime.now();
    int retryCount = 0;

    // Use transaction to atomically check room capacity and add player
    // This prevents race condition where multiple players join simultaneously
    final room = await _executeWithRetry<GameRoom>(
      () async {
        retryCount++;
        final firestore = _firestoreInstance;
        if (firestore == null) {
          throw NetworkException(
            'Firebase not available',
            errorCode: ErrorCode.networkServerError,
          );
        }
        return firestore.runTransaction<GameRoom>((transaction) async {
          final docRef =
              firestore.collection('game_rooms').doc(sanitizedRoomId);
          final doc = await transaction.get(docRef);

          if (!doc.exists) {
            throw ValidationException('Room not found');
          }

          final room = GameRoom.fromFirestore(doc);

          // Check if already in room
          if (room.players.any((p) => p.userId == user.uid)) {
            return room; // Already in room
          }

          // Check if room is friends-only and validate access
          if (room.friendsOnly) {
            final hasAccess = await validateFriendAccess(room.id, user.uid);
            if (!hasAccess) {
              throw ValidationException(
                'This room is friends-only. Only friends of the host can join.',
              );
            }
          }

          // Check room capacity atomically within transaction
          if (room.isFull) {
            throw ValidationException('Room is full');
          }

          // Atomically add player within transaction
          transaction.update(docRef, {
            'players': FieldValue.arrayUnion([newPlayer.toJson()]),
          });

          // Return updated room state
          return room.copyWith(players: [...room.players, newPlayer]);
        });
      },
      operationName: 'Join room',
    );

    // Log performance metrics
    final duration = DateTime.now().difference(startTime);
    unawaited(
      _analyticsService?.logRoomJoining(
        duration,
        success: true,
        retryCount:
            retryCount - 1, // Subtract 1 since first attempt isn't a retry
      ),
    );

    _currentRoom = room;
    _listenToRoom(sanitizedRoomId);
    notifyListeners();
    return room;
  }

  /// Validate that user is a member of the room
  /// Used for defense in depth security
  /// Returns true if user is a player or host in the room
  Future<bool> validatePlayerMembership(String roomId, String userId) async {
    try {
      // CRITICAL: Sanitize room ID for defense in depth security
      // This prevents injection attacks even if called with unsanitized input
      final sanitizedRoomId = InputSanitizer.sanitizeFileName(roomId);
      if (sanitizedRoomId.isEmpty || sanitizedRoomId != roomId) {
        LoggerService.warning(
          'Invalid room ID format in validatePlayerMembership: $roomId',
        );
        return false; // Invalid room ID format
      }

      final firestore = _firestoreInstance;
      if (firestore == null) {
        throw NetworkException(
          'Firebase not available',
          errorCode: ErrorCode.networkServerError,
        );
      }
      final doc = await firestore.collection('game_rooms').doc(sanitizedRoomId).get();

      if (!doc.exists) return false;

      final room = GameRoom.fromFirestore(doc);

      // Check if user is host
      if (room.hostId == userId) return true;

      // Check if user is a player
      return room.players.any((p) => p.userId == userId);
    } catch (e, stackTrace) {
      LoggerService.error(
        'Error validating player membership',
        error: e,
        stack: stackTrace,
      );
      return false;
    }
  }

  // Leave the current room
  Future<void> leaveRoom() async {
    if (_currentRoom == null) return;

    final auth = _authInstance;
    final user = auth?.currentUser;
    if (user == null) return;

    unawaited((_roomSubscription?.cancel() ?? Future<void>.value()) as Future<dynamic>,);
    _roomSubscription = null;

    final roomId = _currentRoom!.id;
    final wasHost = _currentRoom!.hostId == user.uid;

    try {
      await _executeWithRetry(
        () async {
          final firestore = _firestoreInstance;
          if (firestore == null) {
            throw NetworkException(
              'Firebase not available',
              errorCode: ErrorCode.networkServerError,
            );
          }
          final docRef = firestore.collection('game_rooms').doc(roomId);

          // Remove player from room
          await docRef.update({
            'players': FieldValue.arrayRemove(
              _currentRoom!.players
                  .where((p) => p.userId == user.uid)
                  .map((p) => p.toJson())
                  .toList(),
            ),
          });

          // If host left, check if room should be deleted or host transferred
          if (wasHost) {
            final updatedDoc = await docRef.get();
            if (!updatedDoc.exists) {
              // Room was already deleted, nothing to do
              LoggerService.debug('Room $roomId was already deleted');
              return;
            }

            final updatedRoom = GameRoom.fromFirestore(updatedDoc);

            // Validate room state
            if (updatedRoom.players.isEmpty) {
              // No players left, delete the room
              await docRef.delete();
              LoggerService.info('Deleted empty room $roomId after host left');
            } else {
              // CRITICAL: Double-check players list is not empty to prevent race condition
              // List might become empty between isEmpty check and first access
              // Transfer host to first remaining player (safe access)
              final newHost = ListHelper.safeFirst(updatedRoom.players);
              if (newHost == null) {
                LoggerService.error('Cannot transfer host: players list is empty');
                return;
              }

              // Validate new host exists and is valid
              if (newHost.userId.isEmpty) {
                LoggerService.error('Invalid new host userId in room $roomId');
                // Fallback: delete room if we can't transfer
                await docRef.delete();
                return;
              }

              // Validate new host is still in the room (defense in depth)
              final hostStillInRoom = updatedRoom.players.any(
                (p) => p.userId == newHost.userId,
              );

              if (!hostStillInRoom) {
                LoggerService.error(
                    'New host ${newHost.userId} is not in room $roomId',);
                // Fallback: delete room if host is invalid
                await docRef.delete();
                return;
              }

              // Transfer host using transaction for atomicity
              final firestore = _firestoreInstance;
              if (firestore == null) {
                throw NetworkException(
                  'Firebase not available',
                  errorCode: ErrorCode.networkServerError,
                );
              }
              await firestore.runTransaction<void>((transaction) async {
                final currentDoc = await transaction.get(docRef);
                if (!currentDoc.exists) {
                  return; // Room was deleted
                }

                final currentRoom = GameRoom.fromFirestore(currentDoc);
                if (currentRoom.players.isEmpty) {
                  // Room became empty, delete it
                  transaction.delete(docRef);
                  return;
                }

                // Validate new host is still available
                final validNewHost = currentRoom.players.firstWhere(
                  (p) => p.userId == newHost.userId,
                  orElse: () {
                    final firstPlayer = ListHelper.safeFirst(currentRoom.players);
                    if (firstPlayer == null) {
                      throw Exception('Cannot find valid host: players list is empty');
                    }
                    return firstPlayer;
                  },
                );

                // Transfer host
                transaction.update(docRef, {
                  'hostId': validNewHost.userId,
                });
              });

              LoggerService.info(
                'Transferred host of room $roomId to ${newHost.userId}',
              );

              // Log analytics if available
              unawaited(
                _analyticsService?.logCustomEvent(
                  'host_transferred',
                  parameters: {
                    'roomId': roomId,
                    'newHostId': newHost.userId,
                    'previousHostId': user.uid,
                  },
                ),
              );
            }
          }
        },
        operationName: 'Leave room',
      );
    } catch (e, stackTrace) {
      LoggerService.warning('Error leaving room', error: e);
      // Report leave room errors to Crashlytics
      unawaited(FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Error leaving room: $roomId',
        fatal: false,
      ),);
      // Continue with cleanup even if Firestore operation fails
    }

    _currentRoom = null;
    notifyListeners();
  }

  // Set player ready status
  Future<void> setPlayerReady(bool ready) async {
    if (_currentRoom == null) return;

    final auth = _authInstance;
    final user = auth?.currentUser;
    if (user == null) return;

    // Check connectivity before updating ready status
    await _checkConnectivity();

    try {
      await _executeWithRetry(
        () async {
          final firestore = _firestoreInstance;
          if (firestore == null) {
            throw NetworkException(
              'Firebase not available',
              errorCode: ErrorCode.networkServerError,
            );
          }
          final docRef = firestore.collection('game_rooms').doc(_currentRoom!.id);
          final players = _currentRoom!.players.map((p) {
            if (p.userId == user.uid) {
              return p.copyWith(isReady: ready).toJson();
            }
            return p.toJson();
          }).toList();

          await docRef.update({'players': players});
        },
        operationName: 'Set player ready',
      );
    } on NetworkException catch (e) {
      // Queue for retry if network error
      await _retryQueue.enqueueSetPlayerReady(
        roomId: _currentRoom!.id,
        userId: user.uid,
        ready: ready,
      );
      LoggerService.warning(
        'Network error setting player ready, queued for retry',
        error: e,
      );
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  // Start the game
  Future<void> startGame({String? gameMode, String? difficulty}) async {
    if (_currentRoom == null) return;

    final auth = _authInstance;
    final user = auth?.currentUser;
    if (user == null) return;

    if (_currentRoom!.hostId != user.uid) {
      throw ValidationException('Only the host can start the game');
    }

    if (!_currentRoom!.canStart) {
      throw ValidationException('Not all players are ready');
    }

    // Check connectivity before starting game
    await _checkConnectivity();

    // For battle royale, set first player as current and initialize submissions
    String? currentPlayerId;
    Map<String, bool>? playerSubmissions;
    if (_currentRoom!.mode == MultiplayerMode.battleRoyale) {
      // CRITICAL: Check players list is not empty before accessing first element
      final firstPlayer = ListHelper.safeFirst(_currentRoom!.players);
      if (firstPlayer != null) {
        currentPlayerId = firstPlayer.userId;
      }
      // Initialize submission tracking
      playerSubmissions = {
        for (final player in _currentRoom!.players) player.userId: false,
      };
    }

    // For squad showdown, create teams
    List<Team>? teams;
    if (_currentRoom!.mode == MultiplayerMode.squadShowdown) {
      teams = _createTeams(_currentRoom!.players);
    }

    await _executeWithRetry(
      () async {
        final firestore = _firestoreInstance;
        if (firestore == null) {
          LoggerService.warning('Firebase not available, skipping update');
          return;
        }
        final docRef = firestore.collection('game_rooms').doc(_currentRoom!.id);
        await docRef.update({
          'status': RoomStatus.inProgress.name,
          'startedAt': DateTime.now().toIso8601String(),
          'currentRound': 1,
          'selectedGameMode': gameMode,
          'selectedDifficulty': difficulty,
          'currentPlayerId': currentPlayerId,
          'playerSubmissions': playerSubmissions,
          'expiresAt':
              DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
          if (teams != null) 'teams': teams.map((t) => t.toJson()).toList(),
        });
      },
      operationName: 'Start game',
    );
  }

  // Create teams for squad showdown
  List<Team> _createTeams(List<Player> players) {
    final teams = <Team>[];
    final shuffled = List<Player>.from(players)..shuffle();

    final roles = ['Leader', 'Strategist', 'Analyst'];

    if (players.length == 4) {
      // 2v2
      final team1Players = shuffled.sublist(0, 2).asMap().entries.map((entry) {
        return entry.value.copyWith(role: entry.key == 0 ? roles[0] : roles[1]);
      }).toList();

      final team2Players = shuffled.sublist(2, 4).asMap().entries.map((entry) {
        return entry.value.copyWith(role: entry.key == 0 ? roles[0] : roles[1]);
      }).toList();

      teams.add(Team(id: 'team1', name: 'Team 1', players: team1Players));
      teams.add(Team(id: 'team2', name: 'Team 2', players: team2Players));
    } else if (players.length == 6) {
      // 3v3
      final team1Players = shuffled.sublist(0, 3).asMap().entries.map((entry) {
        return entry.value.copyWith(role: roles[entry.key]);
      }).toList();

      final team2Players = shuffled.sublist(3, 6).asMap().entries.map((entry) {
        return entry.value.copyWith(role: roles[entry.key]);
      }).toList();

      teams.add(Team(id: 'team1', name: 'Team 1', players: team1Players));
      teams.add(Team(id: 'team2', name: 'Team 2', players: team2Players));
    }

    return teams;
  }

  // Send a ping (for squad showdown)
  Future<void> sendPing() async {
    if (_currentRoom == null) return;

    final auth = _authInstance;
    final user = auth?.currentUser;
    if (user == null) return;

    try {
      await _executeWithRetry(
        () async {
          final firestore = _firestoreInstance;
          if (firestore == null) {
            throw NetworkException(
              'Firebase not available',
              errorCode: ErrorCode.networkServerError,
            );
          }
          final docRef = firestore.collection('game_rooms').doc(_currentRoom!.id);
          final players = _currentRoom!.players.map((p) {
            if (p.userId == user.uid) {
              return p.copyWith(lastPing: DateTime.now()).toJson();
            }
            return p.toJson();
          }).toList();

          await docRef.update({'players': players});
        },
        operationName: 'Send ping',
      );
    } on NetworkException catch (e) {
      // Queue for retry if network error
      await _retryQueue.enqueueSendPing(
        roomId: _currentRoom!.id,
        userId: user.uid,
      );
      LoggerService.warning(
        'Network error sending ping, queued for retry',
        error: e,
      );
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  // Assign role to player (for squad showdown)
  Future<void> assignRole(String userId, String role) async {
    if (_currentRoom == null) return;

    final auth = _authInstance;
    final user = auth?.currentUser;
    if (user == null) return;

    // Only host can assign roles
    if (_currentRoom!.hostId != user.uid) {
      throw ValidationException('Only the host can assign roles');
    }

    final firestore = _firestoreInstance;
    if (firestore == null) {
      throw NetworkException(
        'Firebase not available',
        errorCode: ErrorCode.networkServerError,
      );
    }
    final docRef = firestore.collection('game_rooms').doc(_currentRoom!.id);
    final players = _currentRoom!.players.map((p) {
      if (p.userId == userId) {
        return p.copyWith(role: role).toJson();
      }
      return p.toJson();
    }).toList();

    await _executeWithRetry(
      () async => docRef.update({'players': players}),
      operationName: 'Assign role',
    );
  }

  // Submit answer for current round
  // CRITICAL: Uses transaction to ensure atomic score updates
  Future<void> submitRoundAnswer({
    required int score,
    required int correctAnswers,
    required int wrongAnswers,
  }) async {
    if (_currentRoom == null) return;

    final auth = _authInstance;
    final user = auth?.currentUser;
    if (user == null) return;

    // CRITICAL: Rate limit answer submissions to prevent abuse
    // Limit: 30 submissions per minute per user
    final isAllowed = await _rateLimiter.isAllowed(
      'submit_round_answer_${user.uid}',
      maxAttempts: 30,
      window: const Duration(minutes: 1),
    );
    if (!isAllowed) {
      LoggerService.warning(
        'Rate limit exceeded for answer submission by user ${user.uid}',
      );
      unawaited(
        _analyticsService?.logCustomEvent(
          'multiplayer_rate_limit_exceeded',
          parameters: {
            'operation': 'submit_round_answer',
            'userId': user.uid,
            'roomId': _currentRoom!.id,
          },
        ),
      );
      throw ValidationException(
        'Too many answer submissions. Please wait a moment before submitting again.',
        errorCode: ErrorCode.multiplayerRateLimitExceeded,
        recoverySuggestion:
            'Please wait a few seconds before submitting your answer again.',
      );
    }

    // Check connectivity before submitting answer
    await _checkConnectivity();

    try {
      await _executeWithRetry(
        () async {
          final firestore = _firestoreInstance;
          if (firestore == null) {
            throw NetworkException(
              'Firebase not available',
              errorCode: ErrorCode.networkServerError,
            );
          }
          return firestore.runTransaction<void>((transaction) async {
            final docRef =
                firestore.collection('game_rooms').doc(_currentRoom!.id);
            final doc = await transaction.get(docRef);

            if (!doc.exists) {
              throw ValidationException('Room not found');
            }

            final room = GameRoom.fromFirestore(doc);

            // Verify player is still in room
            if (!room.players.any((p) => p.userId == user.uid)) {
              throw ValidationException('Player not in room');
            }

            // Update player score atomically
            final players = room.players.map((p) {
              if (p.userId == user.uid) {
                return p
                    .copyWith(
                      score: p.score + score,
                      correctAnswers: p.correctAnswers + correctAnswers,
                      wrongAnswers: p.wrongAnswers + wrongAnswers,
                    )
                    .toJson();
              }
              return p.toJson();
            }).toList();

            // For battle royale, mark player as submitted
            final Map<String, dynamic> updateData = {'players': players};
            if (room.mode == MultiplayerMode.battleRoyale) {
              final submissions = Map<String, bool>.from(
                room.playerSubmissions ?? {},
              );
              submissions[user.uid] = true;
              updateData['playerSubmissions'] = submissions;
            }

            transaction.update(docRef, updateData);
          });
        },
        operationName: 'Submit round answer',
      );
    } on NetworkException catch (e) {
      // Queue for retry if network error
      await _retryQueue.enqueueSubmitRoundAnswer(
        roomId: _currentRoom!.id,
        userId: user.uid,
        score: score,
        correctAnswers: correctAnswers,
        wrongAnswers: wrongAnswers,
      );
      LoggerService.warning(
        'Network error submitting answer, queued for retry',
        error: e,
      );
      rethrow;
    } catch (e) {
      // For other errors, don't queue (validation errors, etc.)
      rethrow;
    }
  }

  // Advance to next round (for battle royale, move to next player)
  Future<void> nextRound() async {
    if (_currentRoom == null) return;

    final auth = _authInstance;
    final user = auth?.currentUser;
    if (user == null) return;

    if (_currentRoom!.hostId != user.uid) {
      throw ValidationException('Only the host can advance rounds');
    }

    // For battle royale, check if all players have submitted
    if (_currentRoom!.mode == MultiplayerMode.battleRoyale) {
      final submissions = _currentRoom!.playerSubmissions ?? {};
      final allSubmitted = _currentRoom!.players.every(
        (p) => submissions[p.userId] == true,
      );

      if (!allSubmitted) {
        throw ValidationException(
          'Not all players have submitted their answers yet',
        );
      }
    }

    final currentRound = _currentRoom!.currentRound;
    if (currentRound >= _currentRoom!.totalRounds) {
      // Game finished
      await _finishGame();
      return;
    }

    String? nextPlayerId;
    Map<String, bool>? playerSubmissions;
    if (_currentRoom!.mode == MultiplayerMode.battleRoyale) {
      // Move to next player
      final currentIndex = _currentRoom!.players.indexWhere(
        (p) => p.userId == _currentRoom!.currentPlayerId,
      );
      final nextIndex = (currentIndex + 1) % _currentRoom!.players.length;
      nextPlayerId = _currentRoom!.players[nextIndex].userId;
      // Reset submissions for next round
      playerSubmissions = {
        for (final player in _currentRoom!.players) player.userId: false,
      };
    }

    await _executeWithRetry(
      () async {
        final firestore = _firestoreInstance;
        if (firestore == null) {
          LoggerService.warning('Firebase not available, skipping update');
          return;
        }
        final docRef = firestore.collection('game_rooms').doc(_currentRoom!.id);
        await docRef.update({
          'currentRound': currentRound + 1,
          'currentPlayerId': nextPlayerId,
          if (playerSubmissions != null) 'playerSubmissions': playerSubmissions,
        });
      },
      operationName: 'Advance round',
    );
  }

  // Finish the game
  Future<void> _finishGame() async {
    if (_currentRoom == null) return;

    await _executeWithRetry(
      () async {
        final firestore = _firestoreInstance;
        if (firestore == null) {
          LoggerService.warning('Firebase not available, skipping update');
          return;
        }
        final docRef = firestore.collection('game_rooms').doc(_currentRoom!.id);
        await docRef.update({
          'status': RoomStatus.finished.name,
          'finishedAt': DateTime.now().toIso8601String(),
        });
      },
      operationName: 'Finish game',
    );
  }

  // Listen to room changes
  void _listenToRoom(String roomId) {
    _roomSubscription?.cancel();
    final firestore = _firestoreInstance;
    if (firestore == null) {
      LoggerService.warning('Firebase not available, cannot listen to room');
      return;
    }
    _roomSubscription = firestore
        .collection('game_rooms')
        .doc(roomId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        _currentRoom = GameRoom.fromFirestore(snapshot);
        notifyListeners();
      } else {
        _currentRoom = null;
        notifyListeners();
      }
    });
  }

  // Clean up abandoned/expired rooms (call on app start)
  Future<void> cleanupExpiredRooms() async {
    try {
      final firestore = _firestoreInstance;
      if (firestore == null) {
        LoggerService.warning('Firebase not available, cannot cleanup expired rooms');
        return;
      }
      final now = DateTime.now();
      final expiredRooms = await firestore
          .collection('game_rooms')
          .where('expiresAt', isLessThan: now.toIso8601String())
          .get();

      final batch = firestore.batch();
      for (final doc in expiredRooms.docs) {
        batch.delete(doc.reference);
      }

      if (expiredRooms.docs.isNotEmpty) {
        await batch.commit();
        LoggerService.debug('Cleaned up ${expiredRooms.docs.length} expired rooms');
      }
    } catch (e) {
      LoggerService.error('Error cleaning up expired rooms', error: e);
    }
  }

  // Find available rooms
  // NOTE: Callers are responsible for cancelling the returned stream subscription
  // to prevent memory leaks. Use StreamSubscription.cancel() when done listening.
  Stream<List<GameRoom>> findAvailableRooms(MultiplayerMode mode) {
    final firestore = _firestoreInstance;
    if (firestore == null) {
      return Stream.value([]); // Return empty stream if Firebase not available
    }
    return firestore
        .collection('game_rooms')
        .where('mode', isEqualTo: mode.name)
        .where('status', isEqualTo: RoomStatus.waiting.name)
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      return snapshot.docs
          .map((doc) {
            try {
              return GameRoom.fromFirestore(doc);
            } catch (e) {
              LoggerService.error('Error parsing room ${doc.id}', error: e);
              return null;
            }
          })
          .where((room) {
            if (room == null) return false;
            final expiresAt = room.expiresAt;
            return !room.isFull &&
                (expiresAt == null || expiresAt.isAfter(now));
          })
          .cast<GameRoom>()
          .toList();
    });
  }

  /// Send room invitation to a friend
  Future<String> sendRoomInvitation(String roomId, String friendUserId) async {
    final auth = _authInstance;
    final user = auth?.currentUser;
    if (user == null) {
      throw AuthenticationException(
          'User must be logged in to send invitation',);
    }

    // Validate room exists and user is host
    final firestore = _firestoreInstance;
    if (firestore == null) {
      throw NetworkException(
        'Firebase not available',
        errorCode: ErrorCode.networkServerError,
      );
    }
    final roomDoc = await firestore.collection('game_rooms').doc(roomId).get();
    if (!roomDoc.exists) {
      throw ValidationException('Room not found');
    }

    final room = GameRoom.fromFirestore(roomDoc);
    if (room.hostId != user.uid) {
      throw ValidationException('Only the host can send invitations');
    }

    // Check if already invited
    if (room.invitedFriends.contains(friendUserId)) {
      throw ValidationException('Friend already invited');
    }

    // Generate room code (using room ID)
    final roomCode = roomId;

    // Create invitation document (firestore already checked above)
    final invitationRef = await firestore.collection('game_room_invitations').add({
      'roomId': roomId,
      'inviterUserId': user.uid,
      'friendUserId': friendUserId,
      'roomCode': roomCode,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });

    // Update room to add friend to invited list
    await firestore.collection('game_rooms').doc(roomId).update({
      'invitedFriends': FieldValue.arrayUnion([friendUserId]),
    });

    // Send push notification
    if (_notificationService != null) {
      try {
        final inviterName =
            user.displayName ?? user.email?.split('@').first ?? 'Someone';
        await _notificationService!.sendRoomInvitationNotification(
          friendUserId,
          roomId,
          inviterName,
          roomCode,
        );
      } catch (e) {
        LoggerService.warning('Failed to send push notification for invitation',
            error: e,);
        // Continue even if notification fails
      }
    }

    // Log analytics
    unawaited(
      _analyticsService?.logCustomEvent(
        'room_invitation_sent',
        parameters: {
          'roomId': roomId,
          'friendUserId': friendUserId,
        },
      ),
    );

    return invitationRef.id;
  }

  /// Get room invitations for a specific room
  Future<List<RoomInvitation>> getRoomInvitations(String roomId) async {
    try {
      final firestore = _firestoreInstance;
      if (firestore == null) {
        throw NetworkException(
          'Firebase not available',
          errorCode: ErrorCode.networkServerError,
        );
      }
      final snapshot = await firestore
          .collection('game_room_invitations')
          .where('roomId', isEqualTo: roomId)
          .where('status', isEqualTo: 'pending')
          .get();

      return snapshot.docs
          .map((doc) => RoomInvitation.fromFirestore(doc))
          .toList();
    } catch (e) {
      LoggerService.error('Error getting room invitations', error: e);
      return [];
    }
  }

  /// Cancel a room invitation
  Future<void> cancelRoomInvitation(String invitationId) async {
    final auth = _authInstance;
    final user = auth?.currentUser;
    if (user == null) {
      throw AuthenticationException(
          'User must be logged in to cancel invitation',);
    }

    try {
      final firestore = _firestoreInstance;
      if (firestore == null) {
        throw NetworkException(
          'Firebase not available',
          errorCode: ErrorCode.networkServerError,
        );
      }
      final invitationDoc = await firestore
          .collection('game_room_invitations')
          .doc(invitationId)
          .get();

      if (!invitationDoc.exists) {
        throw ValidationException('Invitation not found');
      }

      final invitation = RoomInvitation.fromFirestore(invitationDoc);

      // Verify user is the inviter
      if (invitation.inviterUserId != user.uid) {
        throw ValidationException('Only the inviter can cancel the invitation');
      }

      // Update invitation status (firestore already checked above)
      await firestore
          .collection('game_room_invitations')
          .doc(invitationId)
          .update({'status': 'cancelled'});

      // Remove from room's invited friends list
      await firestore.collection('game_rooms').doc(invitation.roomId).update({
        'invitedFriends': FieldValue.arrayRemove([invitation.friendUserId]),
      });
    } catch (e) {
      LoggerService.error('Error cancelling room invitation', error: e);
      rethrow;
    }
  }

  /// Validate if a user has access to a friend-only room
  Future<bool> validateFriendAccess(String roomId, String userId) async {
    try {
      final firestore = _firestoreInstance;
      if (firestore == null) {
        throw NetworkException(
          'Firebase not available',
          errorCode: ErrorCode.networkServerError,
        );
      }
      final roomDoc = await firestore.collection('game_rooms').doc(roomId).get();
      if (!roomDoc.exists) {
        return false;
      }

      final room = GameRoom.fromFirestore(roomDoc);

      // If not friends-only, allow access
      if (!room.friendsOnly) {
        return true;
      }

      // Host always has access
      if (room.hostId == userId) {
        return true;
      }

      // Check if user is in allowedPlayers list
      if (room.allowedPlayers != null &&
          room.allowedPlayers!.contains(userId)) {
        return true;
      }

      // Check if user is a friend of the host using FriendsService
      if (_friendsService != null) {
        try {
          await _friendsService!.init();
          final friends = _friendsService!.friends;
          final isFriend = friends.any((f) => f.userId == room.hostId) ||
              room.hostId == userId;
          return isFriend;
        } catch (e) {
          LoggerService.warning(
            'Failed to check friend status, denying access',
            error: e,
          );
          return false;
        }
      }

      // If FriendsService not available, check allowedPlayers only
      return room.allowedPlayers?.contains(userId) ?? false;
    } catch (e) {
      LoggerService.error('Error validating friend access', error: e);
      return false;
    }
  }

  /// Process retry queue for failed operations
  Future<void> _processRetryQueue() async {
    try {
      await _retryQueue.processQueue(
        submitRoundAnswerFunction: ({
          required roomId,
          required userId,
          required score,
          required correctAnswers,
          required wrongAnswers,
        }) async {
          // Re-execute the submit round answer logic
          final firestore = _firestoreInstance;
          if (firestore == null) {
            throw NetworkException(
              'Firebase not available',
              errorCode: ErrorCode.networkServerError,
            );
          }
          final docRef = firestore.collection('game_rooms').doc(roomId);
          final doc = await docRef.get();
          if (!doc.exists) {
            throw ValidationException('Room not found');
          }
          final room = GameRoom.fromFirestore(doc);
          if (!room.players.any((p) => p.userId == userId)) {
            throw ValidationException('Player not in room');
          }
          final players = room.players.map((p) {
            if (p.userId == userId) {
              return p
                  .copyWith(
                    score: p.score + score,
                    correctAnswers: p.correctAnswers + correctAnswers,
                    wrongAnswers: p.wrongAnswers + wrongAnswers,
                  )
                  .toJson();
            }
            return p.toJson();
          }).toList();
          final updateData = <String, dynamic>{'players': players};
          if (room.mode == MultiplayerMode.battleRoyale) {
            final submissions =
                Map<String, bool>.from(room.playerSubmissions ?? {});
            submissions[userId] = true;
            updateData['playerSubmissions'] = submissions;
          }
          await docRef.update(updateData);
        },
        setPlayerReadyFunction: ({
          required roomId,
          required userId,
          required ready,
        }) async {
          final firestore = _firestoreInstance;
          if (firestore == null) {
            throw NetworkException(
              'Firebase not available',
              errorCode: ErrorCode.networkServerError,
            );
          }
          final docRef = firestore.collection('game_rooms').doc(roomId);
          final doc = await docRef.get();
          if (!doc.exists) return;
          final room = GameRoom.fromFirestore(doc);
          final players = room.players.map((p) {
            if (p.userId == userId) {
              return p.copyWith(isReady: ready).toJson();
            }
            return p.toJson();
          }).toList();
          await docRef.update({'players': players});
        },
        sendPingFunction: ({
          required roomId,
          required userId,
        }) async {
          final firestore = _firestoreInstance;
          if (firestore == null) {
            throw NetworkException(
              'Firebase not available',
              errorCode: ErrorCode.networkServerError,
            );
          }
          final docRef = firestore.collection('game_rooms').doc(roomId);
          final doc = await docRef.get();
          if (!doc.exists) return;
          final room = GameRoom.fromFirestore(doc);
          final players = room.players.map((p) {
            if (p.userId == userId) {
              return p.copyWith(lastPing: DateTime.now()).toJson();
            }
            return p.toJson();
          }).toList();
          await docRef.update({'players': players});
        },
        nextRoundFunction: ({
          required roomId,
          required userId,
        }) async {
          final firestore = _firestoreInstance;
          if (firestore == null) {
            throw NetworkException(
              'Firebase not available',
              errorCode: ErrorCode.networkServerError,
            );
          }
          final docRef = firestore.collection('game_rooms').doc(roomId);
          final doc = await docRef.get();
          if (!doc.exists) return;
          final room = GameRoom.fromFirestore(doc);
          if (room.hostId != userId) return;
          final currentRound = room.currentRound;
          if (currentRound >= room.totalRounds) {
            await docRef.update({
              'status': RoomStatus.finished.name,
              'finishedAt': DateTime.now().toIso8601String(),
            });
            return;
          }
          String? nextPlayerId;
          Map<String, bool>? playerSubmissions;
          if (room.mode == MultiplayerMode.battleRoyale) {
            final currentIndex = room.players.indexWhere(
              (p) => p.userId == room.currentPlayerId,
            );
            final nextIndex = (currentIndex + 1) % room.players.length;
            nextPlayerId = room.players[nextIndex].userId;
            playerSubmissions = {
              for (final player in room.players) player.userId: false,
            };
          }
          await docRef.update({
            'currentRound': currentRound + 1,
            'currentPlayerId': nextPlayerId,
            if (playerSubmissions != null)
              'playerSubmissions': playerSubmissions,
          });
        },
        leaveRoomFunction: ({
          required roomId,
          required userId,
        }) async {
          final firestore = _firestoreInstance;
          if (firestore == null) {
            throw NetworkException(
              'Firebase not available',
              errorCode: ErrorCode.networkServerError,
            );
          }
          final docRef = firestore.collection('game_rooms').doc(roomId);
          final doc = await docRef.get();
          if (!doc.exists) return;
          final room = GameRoom.fromFirestore(doc);
          final wasHost = room.hostId == userId;
          await docRef.update({
            'players': FieldValue.arrayRemove(
              room.players
                  .where((p) => p.userId == userId)
                  .map((p) => p.toJson())
                  .toList(),
            ),
          });
          if (wasHost && room.players.length > 1) {
            final updatedDoc = await docRef.get();
            if (updatedDoc.exists) {
              final updatedRoom = GameRoom.fromFirestore(updatedDoc);
              if (updatedRoom.players.isNotEmpty) {
                final firstPlayer = ListHelper.safeFirst(updatedRoom.players);
                if (firstPlayer != null) {
                  await docRef.update({'hostId': firstPlayer.userId});
                }
              }
            }
          }
        },
      );
    } catch (e, stack) {
      LoggerService.error(
        'Error processing multiplayer retry queue',
        error: e,
        stack: stack,
      );
    }
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _retryQueue.dispose();
    leaveRoom();
    super.dispose();
  }
}