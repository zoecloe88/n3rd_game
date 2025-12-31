import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:n3rd_game/services/challenge/leaderboard_repository.dart';
import 'package:n3rd_game/services/daily_challenge_leaderboard_service.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Firestore implementation of LeaderboardRepository
class FirestoreLeaderboardRepository implements LeaderboardRepository {

  FirestoreLeaderboardRepository(this._firestore);
  final FirebaseFirestore _firestore;
  static const Duration _timeout = Duration(seconds: 10);
  static const int _maxAttempts = 5;

  @override
  bool get isAvailable {
    try {
      Firebase.app();
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<SubmissionResponse> submitScore({
    required String dateKey,
    required String challengeId,
    required String userId,
    required String displayName,
    required int score,
    required int completionTime,
    required double accuracy,
  }) async {
    if (!isAvailable) {
      return SubmissionResponse(
        SubmissionResult.networkError,
        'Firebase is not available',
      );
    }

    // Validate inputs
    if (dateKey.isEmpty || challengeId.isEmpty || userId.isEmpty) {
      return SubmissionResponse(
        SubmissionResult.challengeInvalid,
        'Invalid challenge parameters',
      );
    }

    try {
      final collectionPath =
          'daily_challenge_leaderboard/$dateKey/$challengeId/scores';
      final attemptsPath =
          'daily_challenge_leaderboard/$dateKey/$challengeId/attempts';

      // Check attempt count
      int attemptCount = 0;
      try {
        final attemptCountQuery = await _firestore
            .collection(attemptsPath)
            .where('userId', isEqualTo: userId)
            .get()
            .timeout(_timeout);
        attemptCount = attemptCountQuery.docs.length;
      } catch (e) {
        // Collection might not exist yet - treat as 0 attempts
        LoggerService.debug(
            'Error getting attempt count (collection may not exist);: $e',);
        attemptCount = 0;
      }

      if (attemptCount >= _maxAttempts) {
        return SubmissionResponse(
          SubmissionResult.maxAttemptsReached,
          'Maximum attempts ($_maxAttempts) reached',
        );
      }

      // Check if user already has a score
      final existingQuery = await _firestore
          .collection(collectionPath)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get()
          .timeout(_timeout);

      bool scoreImproved = false;

      if (existingQuery.docs.isNotEmpty) {
        final existingDoc = existingQuery.docs.first;
        final existingData = existingDoc.data();
        final existingScore = existingData['score'] as int? ?? 0;
        final existingTime = existingData['completionTime'] as int? ?? 0;

        // Only update if new score is better
        if (score > existingScore ||
            (score == existingScore && completionTime < existingTime)) {
          await existingDoc.reference.update({
            'score': score,
            'completionTime': completionTime,
            'accuracy': accuracy,
            'timestamp': FieldValue.serverTimestamp(),
            'displayName': displayName,
          }).timeout(_timeout);
          scoreImproved = true;
        } else {
          return SubmissionResponse(
            SubmissionResult.scoreNotImproved,
            'Score did not improve. Your previous best: $existingScore points in ${existingTime}s',
          );
        }
      } else {
        // Create new entry
        await _firestore.collection(collectionPath).doc(userId).set({
          'userId': userId,
          'displayName': displayName,
          'score': score,
          'completionTime': completionTime,
          'accuracy': accuracy,
          'timestamp': FieldValue.serverTimestamp(),
        }).timeout(_timeout);
        scoreImproved = true;
      }

      // Only record attempt if score improved
      if (scoreImproved) {
        await _firestore.collection(attemptsPath).add({
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
          'score': score,
          'improved': true,
        }).timeout(_timeout);
        return SubmissionResponse(
          SubmissionResult.success,
          'Score submitted successfully!',
        );
      }

      return SubmissionResponse(
        SubmissionResult.unknownError,
        'Unexpected error',
      );
    } on TimeoutException {
      LoggerService.error('Firestore submit timeout for leaderboard');
      return SubmissionResponse(
        SubmissionResult.networkError,
        'Request timed out. Please check your connection and try again.',
      );
    } on FirebaseException catch (e) {
      LoggerService.error('Firebase error submitting score', error: e);
      if (e.code == 'permission-denied') {
        return SubmissionResponse(
          SubmissionResult.permissionDenied,
          'Permission denied. Please check your account.',
        );
      } else if (e.code == 'unavailable') {
        return SubmissionResponse(
          SubmissionResult.networkError,
          'Network error. Please check your connection and try again.',
        );
      }
      return SubmissionResponse(
        SubmissionResult.networkError,
        'Network error: ${e.message}',
      );
    } catch (e, stack) {
      LoggerService.error('Unexpected error submitting score',
          error: e, stack: stack,);
      return SubmissionResponse(
        SubmissionResult.unknownError,
        'An error occurred: $e',
      );
    }
  }

  @override
  Future<int> getAttemptCount({
    required String dateKey,
    required String challengeId,
    required String userId,
  }) async {
    if (!isAvailable) {
      return 0;
    }

    if (dateKey.isEmpty || challengeId.isEmpty || userId.isEmpty) {
      LoggerService.warning(
          'Invalid dateKey or challengeId for attempt count query',);
      return 0;
    }

    try {
      final attemptsPath =
          'daily_challenge_leaderboard/$dateKey/$challengeId/attempts';
      final attemptCountQuery = await _firestore
          .collection(attemptsPath)
          .where('userId', isEqualTo: userId)
          .get()
          .timeout(_timeout);
      return attemptCountQuery.docs.length;
    } on TimeoutException {
      LoggerService.warning('Timeout getting attempt count');
      return 0;
    } catch (e) {
      // Collection might not exist yet - treat as 0 attempts
      LoggerService.debug(
          'Error getting attempt count (collection may not exist);: $e',);
      return 0;
    }
  }

  @override
  Future<List<DailyChallengeLeaderboardEntry>> getTopLeaderboard({
    required String dateKey,
    required String challengeId,
    int limit = 5,
  }) async {
    if (!isAvailable) {
      return [];
    }

    if (dateKey.isEmpty || challengeId.isEmpty) {
      LoggerService.warning(
          'Invalid dateKey or challengeId for leaderboard query',);
      return [];
    }

    try {
      final collectionPath =
          'daily_challenge_leaderboard/$dateKey/$challengeId/scores';

      // Query with ranking: Score DESC
      final querySnapshot = await _firestore
          .collection(collectionPath)
          .orderBy('score', descending: true)
          .limit(limit * 2) // Get more than needed to handle ties
          .get()
          .timeout(_timeout);

      if (querySnapshot.docs.isEmpty) {
        return [];
      }

      // Convert to entries
      final entries = querySnapshot.docs
          .map((doc) => DailyChallengeLeaderboardEntry.fromFirestore(doc, 0))
          .toList();

      // Sort: Score DESC → Time ASC → Timestamp ASC
      entries.sort((a, b) {
        if (a.score != b.score) {
          return b.score.compareTo(a.score); // Higher score first
        }
        if (a.completionTime != b.completionTime) {
          return a.completionTime
              .compareTo(b.completionTime); // Faster time first
        }
        return a.timestamp.compareTo(b.timestamp); // Earlier timestamp first
      });

      // Assign ranks and return top N
      final topEntries = entries.take(limit).toList();
      for (int i = 0; i < topEntries.length; i++) {
        topEntries[i] = DailyChallengeLeaderboardEntry(
          userId: topEntries[i].userId,
          displayName: topEntries[i].displayName,
          score: topEntries[i].score,
          completionTime: topEntries[i].completionTime,
          accuracy: topEntries[i].accuracy,
          timestamp: topEntries[i].timestamp,
          rank: i + 1,
        );
      }

      return topEntries;
    } on TimeoutException {
      LoggerService.warning('Timeout getting leaderboard');
      return [];
    } catch (e, stack) {
      LoggerService.error('Error fetching leaderboard', error: e, stack: stack);
      return [];
    }
  }

  @override
  Future<int?> getUserRank({
    required String dateKey,
    required String challengeId,
    required String userId,
    int maxRank = 50,
  }) async {
    if (!isAvailable) {
      return null;
    }

    if (dateKey.isEmpty || challengeId.isEmpty || userId.isEmpty) {
      LoggerService.warning('Invalid dateKey or challengeId for rank query');
      return null;
    }

    try {
      final collectionPath =
          'daily_challenge_leaderboard/$dateKey/$challengeId/scores';

      final querySnapshot = await _firestore
          .collection(collectionPath)
          .orderBy('score', descending: true)
          .limit(maxRank)
          .get()
          .timeout(_timeout);

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      final entries = querySnapshot.docs
          .map((doc) => DailyChallengeLeaderboardEntry.fromFirestore(doc, 0))
          .toList();

      entries.sort((a, b) {
        if (a.score != b.score) {
          return b.score.compareTo(a.score);
        }
        if (a.completionTime != b.completionTime) {
          return a.completionTime.compareTo(b.completionTime);
        }
        return a.timestamp.compareTo(b.timestamp);
      });

      for (int i = 0; i < entries.length; i++) {
        if (entries[i].userId == userId) {
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
  Future<PaginatedLeaderboardResult> getPaginatedLeaderboard({
    required String dateKey,
    required String challengeId,
    int pageSize = 20,
    DocumentSnapshot? startAfter,
  }) async {
    if (!isAvailable) {
      return PaginatedLeaderboardResult(
        entries: [],
        hasMore: false,
      );
    }

    if (dateKey.isEmpty || challengeId.isEmpty) {
      LoggerService.warning(
          'Invalid dateKey or challengeId for paginated leaderboard query',);
      return PaginatedLeaderboardResult(
        entries: [],
        hasMore: false,
      );
    }

    try {
      final collectionPath =
          'daily_challenge_leaderboard/$dateKey/$challengeId/scores';

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
        return PaginatedLeaderboardResult(
          entries: [],
          hasMore: false,
        );
      }

      // Check if there are more results
      final hasMore = querySnapshot.docs.length > pageSize;
      final docs = hasMore
          ? querySnapshot.docs.take(pageSize).toList()
          : querySnapshot.docs;

      // Convert to entries
      final entries = docs.asMap().entries.map((entry) {
        final index = entry.key;
        final doc = entry.value;
        // Calculate rank based on startAfter position if provided
        // For simplicity, we'll use the index in this page
        // Full rank calculation would require knowing the total count
        return DailyChallengeLeaderboardEntry.fromFirestore(doc, index + 1);
      }).toList();

      // Get the last document for pagination
      final lastDocument = docs.isNotEmpty ? docs.last : null;

      return PaginatedLeaderboardResult(
        entries: entries,
        hasMore: hasMore,
        lastDocument: lastDocument,
      );
    } on TimeoutException {
      LoggerService.warning('Timeout getting paginated leaderboard');
      return PaginatedLeaderboardResult(
        entries: [],
        hasMore: false,
      );
    } catch (e, stack) {
      LoggerService.error('Error fetching paginated leaderboard',
          error: e, stack: stack,);
      return PaginatedLeaderboardResult(
        entries: [],
        hasMore: false,
      );
    }
  }

  @override
  Future<String?> validateChallenge({
    required String dateKey,
    required String challengeId,
  }) async {
    if (!isAvailable) {
      return 'Firebase not available';
    }

    try {
      final scoresRef = _firestore.collection(
        'daily_challenge_leaderboard/$dateKey/$challengeId/scores',
      );
      await scoresRef.limit(1).get().timeout(_timeout);
      return null; // Valid
    } on TimeoutException {
      return 'Validation timeout';
    } on FirebaseException catch (e) {
      LoggerService.error('Error validating challenge', error: e);
      if (e.code == 'permission-denied') {
        return 'Permission denied';
      } else if (e.code == 'not-found') {
        return 'Challenge not found or expired';
      }
      return 'Validation error: ${e.message}';
    } catch (e) {
      LoggerService.error('Error validating challenge', error: e);
      return 'Challenge validation failed: $e';
    }
  }
}
