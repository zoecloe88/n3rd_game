import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:n3rd_game/services/leaderboard/leaderboard_repository.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Firestore implementation of GlobalLeaderboardRepository
class FirestoreGlobalLeaderboardRepository
    implements GlobalLeaderboardRepository {

  FirestoreGlobalLeaderboardRepository(this._firestore);
  final FirebaseFirestore _firestore;
  static const Duration _timeout = Duration(seconds: 10);

  @override
  bool get isAvailable {
    try {
      Firebase.app();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get collection path for a game mode and timeframe
  String _getCollectionPath(String gameMode, LeaderboardTimeframe timeframe) {
    final timeframeStr = timeframe.name;
    return 'global_leaderboards/$gameMode/$timeframeStr/scores';
  }

  @override
  Future<void> submitScore({
    required String userId,
    required String? displayName,
    required int score,
    required String gameMode,
    required LeaderboardTimeframe timeframe,
  }) async {
    if (!isAvailable) {
      throw Exception('Firebase is not available');
    }

    if (userId.isEmpty || gameMode.isEmpty || score < 0) {
      throw Exception('Invalid score submission parameters');
    }

    try {
      final collectionPath = _getCollectionPath(gameMode, timeframe);

      // Check if user already has a score
      final existingDoc = _firestore.collection(collectionPath).doc(userId);
      final existingSnapshot = await existingDoc.get().timeout(_timeout);

      if (existingSnapshot.exists) {
        final existingData = existingSnapshot.data();
        final existingScore = existingData?['score'] as int? ?? 0;

        // Only update if new score is better
        if (score > existingScore) {
          await existingDoc.update({
            'score': score,
            'displayName': displayName,
            'timestamp': FieldValue.serverTimestamp(),
            'gameMode': gameMode,
          }).timeout(_timeout);
        }
      } else {
        // Create new entry
        await existingDoc.set({
          'userId': userId,
          'displayName': displayName,
          'score': score,
          'gameMode': gameMode,
          'timestamp': FieldValue.serverTimestamp(),
        }).timeout(_timeout);
      }
    } on TimeoutException {
      LoggerService.error('Firestore submit timeout for global leaderboard');
      rethrow;
    } on FirebaseException catch (e) {
      LoggerService.error('Firebase error submitting score', error: e);
      rethrow;
    } catch (e, stack) {
      LoggerService.error('Unexpected error submitting score',
          error: e, stack: stack,);
      rethrow;
    }
  }

  @override
  Future<PaginatedGlobalLeaderboardResult> getLeaderboard({
    required String gameMode,
    required LeaderboardTimeframe timeframe,
    int pageSize = 20,
    DocumentSnapshot? startAfter,
  }) async {
    if (!isAvailable) {
      return PaginatedGlobalLeaderboardResult(
        entries: [],
        hasMore: false,
      );
    }

    if (gameMode.isEmpty) {
      LoggerService.warning('Invalid gameMode for leaderboard query');
      return PaginatedGlobalLeaderboardResult(
        entries: [],
        hasMore: false,
      );
    }

    try {
      final collectionPath = _getCollectionPath(gameMode, timeframe);

      // Build query with pagination
      Query query = _firestore
          .collection(collectionPath)
          .orderBy('score', descending: true)
          .limit(pageSize + 1); // Get one extra to check if there are more

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final querySnapshot = await query.get().timeout(_timeout);

      if (querySnapshot.docs.isEmpty) {
        return PaginatedGlobalLeaderboardResult(
          entries: [],
          hasMore: false,
        );
      }

      // Check if there are more results
      final hasMore = querySnapshot.docs.length > pageSize;
      final docs = hasMore
          ? querySnapshot.docs.take(pageSize).toList()
          : querySnapshot.docs;

      // Convert to entries with ranks
      final entries = docs.asMap().entries.map((entry) {
        final index = entry.key;
        final doc = entry.value;
        return GlobalLeaderboardEntry.fromFirestore(doc, index + 1);
      }).toList();

      // Get the last document for pagination
      final lastDocument = docs.isNotEmpty ? docs.last : null;

      return PaginatedGlobalLeaderboardResult(
        entries: entries,
        hasMore: hasMore,
        lastDocument: lastDocument,
      );
    } on TimeoutException {
      LoggerService.warning('Timeout getting paginated leaderboard');
      return PaginatedGlobalLeaderboardResult(
        entries: [],
        hasMore: false,
      );
    } catch (e, stack) {
      LoggerService.error('Error fetching paginated leaderboard',
          error: e, stack: stack,);
      return PaginatedGlobalLeaderboardResult(
        entries: [],
        hasMore: false,
      );
    }
  }

  @override
  Future<int?> getUserRank({
    required String userId,
    required String gameMode,
    required LeaderboardTimeframe timeframe,
  }) async {
    if (!isAvailable) {
      return null;
    }

    if (userId.isEmpty || gameMode.isEmpty) {
      LoggerService.warning('Invalid userId or gameMode for rank query');
      return null;
    }

    try {
      final collectionPath = _getCollectionPath(gameMode, timeframe);

      // Get all scores ordered by score descending
      final querySnapshot = await _firestore
          .collection(collectionPath)
          .orderBy('score', descending: true)
          .get()
          .timeout(_timeout);

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      // Find user's rank
      for (int i = 0; i < querySnapshot.docs.length; i++) {
        if (querySnapshot.docs[i].id == userId) {
          return i + 1;
        }
      }

      return null;
    } on TimeoutException {
      LoggerService.warning('Timeout getting user rank');
      return null;
    } catch (e, stack) {
      LoggerService.error('Error getting user rank', error: e, stack: stack);
      return null;
    }
  }

  @override
  Future<List<GlobalLeaderboardEntry>> getFriendsLeaderboard({
    required String userId,
    required List<String> friendUserIds,
    required String gameMode,
    required LeaderboardTimeframe timeframe,
    int limit = 20,
  }) async {
    if (!isAvailable) {
      return [];
    }

    if (userId.isEmpty || gameMode.isEmpty || friendUserIds.isEmpty) {
      LoggerService.warning('Invalid parameters for friends leaderboard query');
      return [];
    }

    try {
      final collectionPath = _getCollectionPath(gameMode, timeframe);

      // Include current user in the list
      final allUserIds = [userId, ...friendUserIds];

      // Query scores for all friends
      final entries = <GlobalLeaderboardEntry>[];

      // Firestore 'in' query limit is 10, so we need to batch
      for (int i = 0; i < allUserIds.length; i += 10) {
        final batch = allUserIds.skip(i).take(10).toList();
        final querySnapshot = await _firestore
            .collection(collectionPath)
            .where(FieldPath.documentId, whereIn: batch)
            .get()
            .timeout(_timeout);

        for (final doc in querySnapshot.docs) {
          entries.add(GlobalLeaderboardEntry.fromFirestore(doc, 0));
        }
      }

      // Sort by score descending
      entries.sort((a, b) => b.score.compareTo(a.score));

      // Assign ranks
      for (int i = 0; i < entries.length; i++) {
        entries[i] = GlobalLeaderboardEntry(
          userId: entries[i].userId,
          displayName: entries[i].displayName,
          score: entries[i].score,
          gameMode: entries[i].gameMode,
          timestamp: entries[i].timestamp,
          rank: i + 1,
        );
      }

      return entries.take(limit).toList();
    } on TimeoutException {
      LoggerService.warning('Timeout getting friends leaderboard');
      return [];
    } catch (e, stack) {
      LoggerService.error('Error getting friends leaderboard',
          error: e, stack: stack,);
      return [];
    }
  }
}
