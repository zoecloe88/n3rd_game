import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:n3rd_game/models/game_history_entry.dart';
import 'package:n3rd_game/models/game_mode_config.dart';
import 'package:n3rd_game/utils/game_mode_extensions.dart';

/// Abstract storage interface for game history
///
/// Allows for easier testing and potential future storage backends.
abstract class GameHistoryStorage {
  /// Save a game entry
  Future<void> saveGame(String userId, GameHistoryEntry game);

  /// Get game history with filters
  Future<List<GameHistoryEntry>> getGameHistory({
    required String userId,
    int limit = 20,
    DocumentSnapshot? startAfter,
    GameMode? mode,
    DateTime? startDate,
    DateTime? endDate,
    int? minScore,
    int? maxScore,
  });

  /// Get a specific game by ID
  Future<GameHistoryEntry?> getGameById(String userId, String gameId);

  /// Delete a game record
  Future<bool> deleteGame(String userId, String gameId);

  /// Set up real-time listener
  Stream<QuerySnapshot> listenToHistory({
    required String userId,
    int limit = 100,
  });
}

/// Firestore implementation of GameHistoryStorage
class FirestoreGameHistoryStorage implements GameHistoryStorage {

  FirestoreGameHistoryStorage(this._firestore);
  final FirebaseFirestore _firestore;

  @override
  Future<void> saveGame(String userId, GameHistoryEntry game) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('game_history')
        .doc(game.gameId)
        .set(game.toFirestore(), SetOptions(merge: true));
  }

  @override
  Future<List<GameHistoryEntry>> getGameHistory({
    required String userId,
    int limit = 20,
    DocumentSnapshot? startAfter,
    GameMode? mode,
    DateTime? startDate,
    DateTime? endDate,
    int? minScore,
    int? maxScore,
  }) async {
    Query query =
        _firestore.collection('users').doc(userId).collection('game_history');

    // Apply filters
    if (mode != null) {
      query = query.where('mode', isEqualTo: mode.toFirestoreString());
    }
    if (startDate != null) {
      query = query.where('completedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),);
    }
    if (endDate != null) {
      query = query.where('completedAt',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),);
    }
    if (minScore != null) {
      query = query.where('score', isGreaterThanOrEqualTo: minScore);
    }
    if (maxScore != null) {
      query = query.where('score', isLessThanOrEqualTo: maxScore);
    }

    // Order and paginate
    query = query.orderBy('completedAt', descending: true);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final clampedLimit = limit.clamp(1, 100);
    final snapshot = await query.limit(clampedLimit).get();

    return snapshot.docs
        .map((doc) => GameHistoryEntry.fromFirestore(doc))
        .toList();
  }

  @override
  Future<GameHistoryEntry?> getGameById(String userId, String gameId) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('game_history')
        .doc(gameId)
        .get();

    if (doc.exists) {
      return GameHistoryEntry.fromFirestore(doc);
    }
    return null;
  }

  @override
  Future<bool> deleteGame(String userId, String gameId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('game_history')
        .doc(gameId)
        .delete();
    return true;
  }

  @override
  Stream<QuerySnapshot> listenToHistory({
    required String userId,
    int limit = 100,
  }) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('game_history')
        .orderBy('completedAt', descending: true)
        .limit(limit)
        .snapshots();
  }
}
