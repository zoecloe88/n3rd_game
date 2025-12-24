import 'dart:async' show unawaited, StreamSubscription, TimeoutException;
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:n3rd_game/models/game_room.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/services/rate_limiter_service.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/utils/input_sanitizer.dart';

class MultiplayerService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Connectivity _connectivity = Connectivity();
  final RateLimiterService _rateLimiter = RateLimiterService();
  AnalyticsService? _analyticsService;

  void setAnalyticsService(AnalyticsService? service) {
    _analyticsService = service;
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
  String? get currentUserId => _auth.currentUser?.uid;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _isInitialized = true;
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
      List<ConnectivityResult> results,
    ) {
      final isOnline =
          !results.contains(ConnectivityResult.none) && results.isNotEmpty;

      if (isOnline && _lastRoomId != null && _currentRoom == null) {
        // Network restored and we were in a room - attempt reconnection
        _attemptReconnection();
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
      final docRef = _firestore.collection('game_rooms').doc(_lastRoomId!);
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
      final userId = _auth.currentUser?.uid;

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
  Future<GameRoom> createRoom({
    required MultiplayerMode mode,
    required int maxPlayers,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw AuthenticationException('User must be logged in to create a room');
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

    final room = GameRoom(
      id: '', // Will be set by Firestore
      hostId: user.uid,
      mode: mode,
      maxPlayers: maxPlayers,
      createdAt: DateTime.now(),
    );

    // Track performance for room creation
    final startTime = DateTime.now();
    int retryCount = 0;

    // Use retry logic for room creation
    final createdRoom = await _executeWithRetry<GameRoom>(
      () async {
        retryCount++;
        final docRef =
            await _firestore.collection('game_rooms').add(room.toJson());

        // Atomically set room ID and add host as first player
        await docRef.update({
          'id': docRef.id,
          'players': [hostPlayer.toJson()],
        });

        return room.copyWith(id: docRef.id, players: [hostPlayer]);
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
  Future<GameRoom> joinRoom(String roomId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw AuthenticationException('User must be logged in to join a room');
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
        return await _firestore.runTransaction<GameRoom>((transaction) async {
          final docRef =
              _firestore.collection('game_rooms').doc(sanitizedRoomId);
          final doc = await transaction.get(docRef);

          if (!doc.exists) {
            throw ValidationException('Room not found');
          }

          final room = GameRoom.fromFirestore(doc);

          // Check if already in room
          if (room.players.any((p) => p.userId == user.uid)) {
            return room; // Already in room
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

      final doc =
          await _firestore.collection('game_rooms').doc(sanitizedRoomId).get();

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

    final user = _auth.currentUser;
    if (user == null) return;

    _roomSubscription?.cancel();
    _roomSubscription = null;

    final roomId = _currentRoom!.id;
    final wasHost = _currentRoom!.hostId == user.uid;

    try {
      await _executeWithRetry(
        () async {
          final docRef = _firestore.collection('game_rooms').doc(roomId);

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
            if (updatedDoc.exists) {
              final updatedRoom = GameRoom.fromFirestore(updatedDoc);
              if (updatedRoom.players.isEmpty) {
                await docRef.delete();
              } else if (updatedRoom.players.isNotEmpty) {
                // CRITICAL: Double-check players list is not empty to prevent race condition
                // List might become empty between isEmpty check and first access
                // Transfer host to first remaining player
                await docRef
                    .update({'hostId': updatedRoom.players.first.userId});
              }
            }
          }
        },
        operationName: 'Leave room',
      );
    } catch (e) {
      LoggerService.warning('Error leaving room', error: e);
      // Continue with cleanup even if Firestore operation fails
    }

    _currentRoom = null;
    notifyListeners();
  }

  // Set player ready status
  Future<void> setPlayerReady(bool ready) async {
    if (_currentRoom == null) return;

    final user = _auth.currentUser;
    if (user == null) return;

    // Check connectivity before updating ready status
    await _checkConnectivity();

    await _executeWithRetry(
      () async {
        final docRef =
            _firestore.collection('game_rooms').doc(_currentRoom!.id);
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
  }

  // Start the game
  Future<void> startGame({String? gameMode, String? difficulty}) async {
    if (_currentRoom == null) return;

    final user = _auth.currentUser;
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
      if (_currentRoom!.players.isNotEmpty) {
        currentPlayerId = _currentRoom!.players.first.userId;
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
        final docRef =
            _firestore.collection('game_rooms').doc(_currentRoom!.id);
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

    final user = _auth.currentUser;
    if (user == null) return;

    await _executeWithRetry(
      () async {
        final docRef =
            _firestore.collection('game_rooms').doc(_currentRoom!.id);
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
  }

  // Assign role to player (for squad showdown)
  Future<void> assignRole(String userId, String role) async {
    if (_currentRoom == null) return;

    final user = _auth.currentUser;
    if (user == null) return;

    // Only host can assign roles
    if (_currentRoom!.hostId != user.uid) {
      throw ValidationException('Only the host can assign roles');
    }

    final docRef = _firestore.collection('game_rooms').doc(_currentRoom!.id);
    final players = _currentRoom!.players.map((p) {
      if (p.userId == userId) {
        return p.copyWith(role: role).toJson();
      }
      return p.toJson();
    }).toList();

    await _executeWithRetry(
      () async => await docRef.update({'players': players}),
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

    final user = _auth.currentUser;
    if (user == null) return;

    // Check connectivity before submitting answer
    await _checkConnectivity();

    await _executeWithRetry(
      () async {
        return await _firestore.runTransaction<void>((transaction) async {
          final docRef =
              _firestore.collection('game_rooms').doc(_currentRoom!.id);
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
  }

  // Advance to next round (for battle royale, move to next player)
  Future<void> nextRound() async {
    if (_currentRoom == null) return;

    final user = _auth.currentUser;
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
        final docRef =
            _firestore.collection('game_rooms').doc(_currentRoom!.id);
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
        final docRef =
            _firestore.collection('game_rooms').doc(_currentRoom!.id);
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
    _roomSubscription = _firestore
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
      final now = DateTime.now();
      final expiredRooms = await _firestore
          .collection('game_rooms')
          .where('expiresAt', isLessThan: now.toIso8601String())
          .get();

      final batch = _firestore.batch();
      for (final doc in expiredRooms.docs) {
        batch.delete(doc.reference);
      }

      if (expiredRooms.docs.isNotEmpty) {
        await batch.commit();
        debugPrint('Cleaned up ${expiredRooms.docs.length} expired rooms');
      }
    } catch (e) {
      debugPrint('Error cleaning up expired rooms: $e');
    }
  }

  // Find available rooms
  // NOTE: Callers are responsible for cancelling the returned stream subscription
  // to prevent memory leaks. Use StreamSubscription.cancel() when done listening.
  Stream<List<GameRoom>> findAvailableRooms(MultiplayerMode mode) {
    return _firestore
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
              debugPrint('Error parsing room ${doc.id}: $e');
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

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _connectivitySubscription?.cancel();
    leaveRoom();
    super.dispose();
  }
}
