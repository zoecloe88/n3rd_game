import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:n3rd_game/utils/unawaited_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:n3rd_game/models/game_room.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/services/rate_limiter_service.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/exceptions/error_codes.dart';

/// Service for watching ongoing games as a spectator
///
/// Provides read-only access to room state for users who want to
/// watch games without participating. Supports multiple spectators
/// and rate limiting to prevent abuse.
class SpectatorService extends ChangeNotifier {
  FirebaseFirestore? _firestore;
  FirebaseAuth? _auth;
  final RateLimiterService _rateLimiter = RateLimiterService();

  /// Get Firestore instance if Firebase is available
  FirebaseFirestore? get _firestoreInstance {
    if (_firestore != null) return _firestore;
    try {
      Firebase.app(); // Check if Firebase is initialized
      _firestore = FirebaseFirestore.instance;
      return _firestore;
    } catch (e) {
      LoggerService.debug('Firebase not available for SpectatorService', error: e);
      return null;
    }
  }

  /// Get Auth instance if Firebase is available
  FirebaseAuth? get _authInstance {
    if (_auth != null) return _auth;
    try {
      Firebase.app(); // Check if Firebase is initialized
      _auth = FirebaseAuth.instance;
      return _auth;
    } catch (e) {
      LoggerService.debug('Firebase not available for SpectatorService', error: e);
      return null;
    }
  }

  GameRoom? _currentSpectatingRoom;
  StreamSubscription<DocumentSnapshot>? _roomSubscription;
  bool _isInitialized = false;

  GameRoom? get currentSpectatingRoom => _currentSpectatingRoom;
  bool get isInitialized => _isInitialized;
  bool get isSpectating => _currentSpectatingRoom != null;

  /// Initialize the service
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _isInitialized = true;
      LoggerService.info('SpectatorService initialized');
    } catch (e) {
      LoggerService.error('Error initializing SpectatorService', error: e);
      _isInitialized = false;
    }
  }

  /// Join a room as a spectator
  Future<void> joinAsSpectator(String roomId) async {
    final auth = _authInstance;
    if (auth == null) {
      throw AuthenticationException(
        'Firebase not available',
        errorCode: ErrorCode.authUserNotFound,
      );
    }
    final user = auth.currentUser;
    if (user == null) {
      throw AuthenticationException(
        'User must be logged in to spectate',
        errorCode: ErrorCode.authUserNotFound,
      );
    }

    // CRITICAL: Rate limit spectator connections to prevent abuse
    final isAllowed = await _rateLimiter.isAllowed(
      'spectator_join_${user.uid}',
      maxAttempts: 10,
      window: const Duration(minutes: 5),
    );
    if (!isAllowed) {
      throw ValidationException(
        'Too many spectator connections. Please wait before joining another room.',
        errorCode: ErrorCode.multiplayerRateLimitExceeded,
      );
    }

    try {
      // Get room document
      final firestore = _firestoreInstance;
      if (firestore == null) {
        throw NetworkException(
          'Firebase not available',
          errorCode: ErrorCode.networkServerError,
        );
      }
      final docRef = firestore.collection('game_rooms').doc(roomId);
      final doc = await docRef.get().timeout(const Duration(seconds: 10));

      if (!doc.exists) {
        throw ValidationException(
          'Room not found',
          errorCode: ErrorCode.multiplayerRoomNotFound,
        );
      }

      final room = GameRoom.fromFirestore(doc);

      // Check if room allows spectating
      if (!room.isSpectatorMode) {
        throw ValidationException(
          'This room does not allow spectators',
          errorCode: ErrorCode.multiplayerSpectatorLimitReached,
        );
      }

      // Check if user is already a player
      if (room.players.any((p) => p.userId == user.uid)) {
        throw ValidationException(
          'You are already a player in this room',
          errorCode: ErrorCode.multiplayerNotInRoom,
        );
      }

      // Check if spectator limit is reached
      if (!room.canSpectate) {
        throw ValidationException(
          'Maximum number of spectators reached',
          errorCode: ErrorCode.multiplayerSpectatorLimitReached,
        );
      }

      // Check if user is already a spectator
      if (room.spectators.contains(user.uid)) {
        // Already spectating, just start listening
        _currentSpectatingRoom = room;
        _listenToRoom(roomId);
        notifyListeners();
        return;
      }

      // Add user as spectator (firestore already checked above)
      await docRef.update({
        'spectators': FieldValue.arrayUnion([user.uid]),
      });

      // Start listening to room updates
      _currentSpectatingRoom = room;
      _listenToRoom(roomId);
      notifyListeners();

      LoggerService.info('User ${user.uid} joined room $roomId as spectator');
    } on TimeoutException {
      throw NetworkException(
        'Request timed out. Please check your connection and try again.',
        errorCode: ErrorCode.networkTimeout,
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw PermissionException(
          'Permission denied. You may not have access to this room.',
          errorCode: ErrorCode.systemPermissionDenied,
        );
      }
      throw NetworkException(
        'Failed to join as spectator: ${e.message}',
        errorCode: ErrorCode.networkServerError,
      );
    }
  }

  /// Leave the current spectating room
  Future<void> leaveSpectating() async {
    if (_currentSpectatingRoom == null) return;

    final auth = _authInstance;
    final user = auth?.currentUser;
    if (user == null) return;

    final roomId = _currentSpectatingRoom!.id;

    unawaited((_roomSubscription?.cancel() ?? Future<void>.value()) as Future<dynamic>,);
    _roomSubscription = null;

    try {
      // Remove user from spectators list
      final firestore = _firestoreInstance;
      if (firestore == null) {
        LoggerService.warning('Firebase not available, skipping Firestore update');
        _currentSpectatingRoom = null;
        notifyListeners();
        return;
      }
      await firestore.collection('game_rooms').doc(roomId).update({
        'spectators': FieldValue.arrayRemove([user.uid]),
      });

      LoggerService.info('User ${user.uid} left spectating room $roomId');
    } catch (e) {
      LoggerService.warning('Error leaving spectating room', error: e);
      // Continue with cleanup even if Firestore operation fails
    }

    _currentSpectatingRoom = null;
    notifyListeners();
  }

  /// Listen to room changes for real-time updates
  void _listenToRoom(String roomId) {
    _roomSubscription?.cancel();
    final firestore = _firestoreInstance;
    if (firestore == null) {
      LoggerService.warning('Firebase not available, cannot listen to room');
      return;
    }
    _roomSubscription =
        firestore.collection('game_rooms').doc(roomId).snapshots().listen(
      (snapshot) {
        if (snapshot.exists) {
          try {
            final room = GameRoom.fromFirestore(snapshot);

            // Check if user is still a spectator
            final auth = _authInstance;
            final user = auth?.currentUser;
            if (user != null && !room.spectators.contains(user.uid)) {
              // User was removed from spectators, stop spectating
              _currentSpectatingRoom = null;
              _roomSubscription?.cancel();
              _roomSubscription = null;
              notifyListeners();
              return;
            }

            _currentSpectatingRoom = room;
            notifyListeners();
          } catch (e) {
            LoggerService.warning('Error parsing room update', error: e);
          }
        } else {
          // Room was deleted
          _currentSpectatingRoom = null;
          _roomSubscription?.cancel();
          _roomSubscription = null;
          notifyListeners();
        }
      },
      onError: (error) {
        LoggerService.error('Error in room subscription', error: error);
        _currentSpectatingRoom = null;
        _roomSubscription?.cancel();
        _roomSubscription = null;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _roomSubscription = null;
    leaveSpectating();
    super.dispose();
  }
}