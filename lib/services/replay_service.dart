import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:n3rd_game/models/game_replay.dart';
import 'package:n3rd_game/models/game_mode_config.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/exceptions/error_codes.dart';

/// Service for recording and replaying game sessions
///
/// Records game state snapshots and player actions during gameplay,
/// stores them in Firestore, and provides functionality to replay
/// games for analysis and sharing.
class ReplayService extends ChangeNotifier {
  FirebaseFirestore? _firestore;
  FirebaseAuth? _auth;

  /// Get Firestore instance if Firebase is available
  FirebaseFirestore? get _firestoreInstance {
    if (_firestore != null) return _firestore;
    try {
      Firebase.app(); // Check if Firebase is initialized
      _firestore = FirebaseFirestore.instance;
      return _firestore;
    } catch (e) {
      LoggerService.debug('Firebase not available for ReplayService', error: e);
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
      LoggerService.debug('Firebase not available for ReplayService', error: e);
      return null;
    }
  }

  GameReplay? _currentRecording;
  bool _isRecording = false;
  bool _isInitialized = false;

  bool get isRecording => _isRecording;
  bool get isInitialized => _isInitialized;

  /// Initialize the service
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _isInitialized = true;
      LoggerService.info('ReplayService initialized');
    } catch (e) {
      LoggerService.error('Error initializing ReplayService', error: e);
      _isInitialized = false;
    }
  }

  /// Start recording a game session
  Future<void> startRecording({
    required GameMode gameMode,
    bool isMultiplayer = false,
    String? roomId,
  }) async {
    if (_isRecording) {
      LoggerService.warning('Already recording a game');
      return;
    }

    final auth = _authInstance;
    final user = auth?.currentUser;
    if (user == null) {
      throw AuthenticationException(
        'User must be logged in to record games',
        errorCode: ErrorCode.authUserNotFound,
      );
    }

    _isRecording = true;
    _currentRecording = GameReplay(
      id: '', // Will be set when saved
      userId: user.uid,
      displayName: user.displayName,
      gameMode: gameMode,
      isMultiplayer: isMultiplayer,
      roomId: roomId,
      createdAt: DateTime.now(),
      gameStartedAt: DateTime.now(),
      finalScore: 0,
      totalRounds: 0,
    );

    LoggerService.info('Started recording game replay');
    notifyListeners();
  }

  /// Record a game state snapshot
  void recordSnapshot({
    required int round,
    required int score,
    required int lives,
    Map<String, dynamic>? state,
  }) {
    if (!_isRecording || _currentRecording == null) return;

    final snapshot = ReplaySnapshot(
      round: round,
      score: score,
      lives: lives,
      timestamp: DateTime.now(),
      state: state,
    );

    _currentRecording = _currentRecording!.copyWith(
      snapshots: [..._currentRecording!.snapshots, snapshot],
    );
  }

  /// Record a player action
  void recordAction({
    required String actionType,
    required int round,
    Map<String, dynamic>? data,
  }) {
    if (!_isRecording || _currentRecording == null) return;

    final action = ReplayAction(
      actionType: actionType,
      round: round,
      timestamp: DateTime.now(),
      data: data,
    );

    _currentRecording = _currentRecording!.copyWith(
      actions: [..._currentRecording!.actions, action],
    );
  }

  /// Stop recording and save the replay
  Future<String?> stopRecording({
    required int finalScore,
    required int totalRounds,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_isRecording || _currentRecording == null) {
      LoggerService.warning('Not currently recording');
      return null;
    }

    try {
      _currentRecording = _currentRecording!.copyWith(
        gameFinishedAt: DateTime.now(),
        finalScore: finalScore,
        totalRounds: totalRounds,
        metadata: metadata ?? {},
      );

      // Save to Firestore
      final firestore = _firestoreInstance;
      if (firestore == null) {
        throw NetworkException('Firebase not available');
      }
      final docRef = await firestore.collection('game_replays').add(
            _currentRecording!.toJson(),
          );

      // Update replay with ID
      await docRef.update({'id': docRef.id});

      final replayId = docRef.id;
      LoggerService.info('Saved game replay: $replayId');

      _isRecording = false;
      _currentRecording = null;
      notifyListeners();

      return replayId;
    } catch (e, stack) {
      LoggerService.error('Error saving game replay', error: e, stack: stack);
      _isRecording = false;
      _currentRecording = null;
      notifyListeners();
      return null;
    }
  }

  /// Get a replay by ID
  Future<GameReplay?> getReplay(String replayId) async {
    try {
      final firestore = _firestoreInstance;
      if (firestore == null) {
        throw NetworkException('Firebase not available');
      }
      final doc = await firestore
          .collection('game_replays')
          .doc(replayId)
          .get()
          .timeout(const Duration(seconds: 10));

      if (!doc.exists) {
        return null;
      }

      return GameReplay.fromFirestore(doc);
    } catch (e, stack) {
      LoggerService.error('Error getting replay', error: e, stack: stack);
      return null;
    }
  }

  /// Get user's replays
  Future<List<GameReplay>> getUserReplays({
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    final auth = _authInstance;
    final user = auth?.currentUser;
    if (user == null) {
      return [];
    }

    try {
      final firestore = _firestoreInstance;
      if (firestore == null) {
        throw NetworkException('Firebase not available');
      }
      Query query = firestore
          .collection('game_replays')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get().timeout(const Duration(seconds: 10));

      return snapshot.docs.map((doc) => GameReplay.fromFirestore(doc)).toList();
    } catch (e, stack) {
      LoggerService.error('Error getting user replays', error: e, stack: stack);
      return [];
    }
  }

  /// Share a replay with a friend
  Future<bool> shareReplay(String replayId, String friendUserId) async {
    try {
      // Create a share document
      final firestore = _firestoreInstance;
      final auth = _authInstance;
      if (firestore == null) {
        throw NetworkException('Firebase not available');
      }
      await firestore.collection('game_replay_shares').add({
        'replayId': replayId,
        'fromUserId': auth?.currentUser?.uid,
        'toUserId': friendUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'viewed': false,
      });

      LoggerService.info('Shared replay $replayId with user $friendUserId');
      return true;
    } catch (e, stack) {
      LoggerService.error('Error sharing replay', error: e, stack: stack);
      return false;
    }
  }

  /// Delete a replay
  Future<bool> deleteReplay(String replayId) async {
    final auth = _authInstance;
    final user = auth?.currentUser;
    if (user == null) {
      return false;
    }

    try {
      final firestore = _firestoreInstance;
      if (firestore == null) {
        throw NetworkException('Firebase not available');
      }
      final doc = await firestore.collection('game_replays').doc(replayId).get();

      if (!doc.exists) {
        return false;
      }

      final replay = GameReplay.fromFirestore(doc);
      if (replay.userId != user.uid) {
        throw PermissionException(
          'You can only delete your own replays',
          errorCode: ErrorCode.systemPermissionDenied,
        );
      }

      // firestore already checked above
      await firestore.collection('game_replays').doc(replayId).delete();
      LoggerService.info('Deleted replay: $replayId');
      return true;
    } catch (e, stack) {
      LoggerService.error('Error deleting replay', error: e, stack: stack);
      return false;
    }
  }

  /// Cancel current recording without saving
  void cancelRecording() {
    _isRecording = false;
    _currentRecording = null;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_isRecording) {
      cancelRecording();
    }
    super.dispose();
  }
}
