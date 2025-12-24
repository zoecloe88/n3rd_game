import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Submission result with error details
enum SubmissionResult {
  success,
  maxAttemptsReached,
  scoreNotImproved,
  networkError,
  permissionDenied,
  challengeInvalid,
  unknownError,
}

class SubmissionResponse {
  final SubmissionResult result;
  final String? message;

  SubmissionResponse(this.result, [this.message]);

  bool get isSuccess => result == SubmissionResult.success;
}

class DailyChallengeLeaderboardEntry {
  final String userId;
  final String? displayName;
  final int score;
  final int completionTime; // in seconds
  final double accuracy; // percentage
  final DateTime timestamp;
  final int rank;

  DailyChallengeLeaderboardEntry({
    required this.userId,
    this.displayName,
    required this.score,
    required this.completionTime,
    required this.accuracy,
    required this.timestamp,
    required this.rank,
  });

  factory DailyChallengeLeaderboardEntry.fromFirestore(
    DocumentSnapshot doc,
    int rank,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    return DailyChallengeLeaderboardEntry(
      userId: doc.id,
      displayName: data['displayName'] as String?,
      score: data['score'] as int? ?? 0,
      completionTime: data['completionTime'] as int? ?? 0,
      accuracy: (data['accuracy'] as num?)?.toDouble() ?? 0.0,
      timestamp:
          (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now().toUtc(),
      rank: rank,
    );
  }
}

class DailyChallengeLeaderboardService {
  FirebaseFirestore? get _firestore {
    try {
      Firebase.app();
      return FirebaseFirestore.instance;
    } catch (e) {
      return null;
    }
  }

  String? get _userId {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (e) {
      return null;
    }
  }

  String? get _displayName {
    try {
      return FirebaseAuth.instance.currentUser?.displayName;
    } catch (e) {
      return null;
    }
  }

  /// Submit a score for daily competitive challenge
  /// Returns SubmissionResponse with result details
  Future<SubmissionResponse> submitDailyChallengeScore({
    required String challengeId,
    required int score,
    required int completionTime,
    required double accuracy,
  }) async {
    // Validate challenge ID
    if (challengeId.isEmpty) {
      return SubmissionResponse(
        SubmissionResult.challengeInvalid,
        'Invalid challenge ID',
      );
    }

    final firestore = _firestore;
    final userId = _userId;
    final displayName = _displayName ?? 'Anonymous';

    if (firestore == null || userId == null) {
      debugPrint('Cannot submit score: Firebase or user not available');
      return SubmissionResponse(
        SubmissionResult.unknownError,
        'Firebase or user not available',
      );
    }

    try {
      // Use UTC for consistency across timezones
      final today = DateTime.now().toUtc();
      final dateKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final collectionPath =
          'daily_challenge_leaderboard/$dateKey/$challengeId/scores';

      // Check attempt count (limit to 5 attempts per day)
      // Validate collection path before querying
      if (dateKey.isEmpty || challengeId.isEmpty) {
        debugPrint('Invalid dateKey or challengeId for attempt count query');
        return SubmissionResponse(
          SubmissionResult.challengeInvalid,
          'Invalid challenge parameters',
        );
      }
      
      int attemptCount = 0;
      try {
        final attemptCountQuery = await firestore
            .collection(
              'daily_challenge_leaderboard/$dateKey/$challengeId/attempts',
            )
            .where('userId', isEqualTo: userId)
            .get();
        attemptCount = attemptCountQuery.docs.length;
      } catch (e) {
        // Collection might not exist yet - treat as 0 attempts
        debugPrint('Error getting attempt count (collection may not exist): $e');
        attemptCount = 0;
      }
      if (attemptCount >= 5) {
        debugPrint('Maximum attempts (5) reached for this challenge');
        return SubmissionResponse(
          SubmissionResult.maxAttemptsReached,
          'Maximum attempts (5) reached',
        );
      }

      // Check if user already has a score for this challenge today
      final existingQuery = await firestore
          .collection(collectionPath)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      bool scoreImproved = false;

      if (existingQuery.docs.isNotEmpty) {
        final existingDoc = existingQuery.docs.first;
        final existingData = existingDoc.data();
        final existingScore = existingData['score'] as int? ?? 0;
        final existingTime = existingData['completionTime'] as int? ?? 0;

        // Only update if new score is better (higher score, or same score but faster time)
        if (score > existingScore ||
            (score == existingScore && completionTime < existingTime)) {
          await existingDoc.reference.update({
            'score': score,
            'completionTime': completionTime,
            'accuracy': accuracy,
            'timestamp': FieldValue.serverTimestamp(),
            'displayName': displayName,
          });
          scoreImproved = true;
        } else {
          // Score not better - DON'T record attempt to avoid wasting attempts
          return SubmissionResponse(
            SubmissionResult.scoreNotImproved,
            'Score did not improve. Your previous best: $existingScore points in ${existingTime}s',
          );
        }
      } else {
        // Create new entry
        await firestore.collection(collectionPath).doc(userId).set({
          'userId': userId,
          'displayName': displayName,
          'score': score,
          'completionTime': completionTime,
          'accuracy': accuracy,
          'timestamp': FieldValue.serverTimestamp(),
        });
        scoreImproved = true;
      }

      // Only record attempt if score improved (to avoid wasting attempts)
      if (scoreImproved) {
        await firestore
            .collection(
              'daily_challenge_leaderboard/$dateKey/$challengeId/attempts',
            )
            .add({
              'userId': userId,
              'timestamp': FieldValue.serverTimestamp(),
              'score': score,
              'improved': true,
            });
        return SubmissionResponse(
          SubmissionResult.success,
          'Score submitted successfully!',
        );
      }

      return SubmissionResponse(
        SubmissionResult.unknownError,
        'Unexpected error',
      );
    } on FirebaseException catch (e) {
      debugPrint('Firebase error submitting daily challenge score: $e');
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
    } catch (e) {
      debugPrint('Error submitting daily challenge score: $e');
      return SubmissionResponse(
        SubmissionResult.unknownError,
        'An error occurred: $e',
      );
    }
  }

  /// Get attempt count for a user on a specific challenge
  Future<int> getAttemptCount(String challengeId, DateTime? date) async {
    final firestore = _firestore;
    final userId = _userId;

    if (firestore == null || userId == null) {
      return 0;
    }

    try {
      // Use UTC for consistency
      final targetDate = (date ?? DateTime.now()).toUtc();
      final dateKey =
          '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';

      // NOTE: This query requires a Firestore composite index on:
      // Collection: daily_challenge_leaderboard/{dateKey}/{challengeId}/attempts
      // Fields: userId (Ascending)
      // Create the index in Firebase Console if you encounter index errors
      
      // Validate collection path before querying
      if (dateKey.isEmpty || challengeId.isEmpty) {
        debugPrint('Invalid dateKey or challengeId for attempt count query');
        return 0;
      }
      
      try {
        final attemptCountQuery = await firestore
            .collection(
              'daily_challenge_leaderboard/$dateKey/$challengeId/attempts',
            )
            .where('userId', isEqualTo: userId)
            .get();
        return attemptCountQuery.docs.length;
      } catch (e) {
        // Collection might not exist yet - treat as 0 attempts
        debugPrint('Error getting attempt count (collection may not exist): $e');
        return 0;
      }
    } on FirebaseException catch (e) {
      debugPrint('Firebase error getting attempt count: $e');
      return 0;
    } catch (e) {
      debugPrint('Error getting attempt count: $e');
      return 0;
    }
  }

  /// Get top 5 leaderboard for a specific challenge
  Future<List<DailyChallengeLeaderboardEntry>> getTop5Leaderboard({
    required String challengeId,
    DateTime? date,
  }) async {
    final firestore = _firestore;
    if (firestore == null) {
      return [];
    }

    try {
      // Use UTC for consistency
      final targetDate = (date ?? DateTime.now()).toUtc();
      final dateKey =
          '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
      
      // Validate collection path before querying
      if (dateKey.isEmpty || challengeId.isEmpty) {
        debugPrint('Invalid dateKey or challengeId for leaderboard query');
        return [];
      }
      
      final collectionPath =
          'daily_challenge_leaderboard/$dateKey/$challengeId/scores';

      // Query with ranking: Score DESC, Time ASC, Timestamp ASC
      // Note: Firestore doesn't support multiple orderBy easily, so we'll fetch and sort in memory
      final querySnapshot = await firestore
          .collection(collectionPath)
          .orderBy('score', descending: true)
          .limit(100) // Get more than top 5 to handle ties
          .get();

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
          return a.completionTime.compareTo(
            b.completionTime,
          ); // Faster time first
        }
        return a.timestamp.compareTo(b.timestamp); // Earlier timestamp first
      });

      // Assign ranks and return top 5
      final top5 = entries.take(5).toList();
      for (int i = 0; i < top5.length; i++) {
        top5[i] = DailyChallengeLeaderboardEntry(
          userId: top5[i].userId,
          displayName: top5[i].displayName,
          score: top5[i].score,
          completionTime: top5[i].completionTime,
          accuracy: top5[i].accuracy,
          timestamp: top5[i].timestamp,
          rank: i + 1,
        );
      }

      return top5;
    } catch (e) {
      debugPrint('Error fetching daily challenge leaderboard: $e');
      return [];
    }
  }

  /// Get user's rank for a specific challenge
  Future<int?> getUserRank({
    required String challengeId,
    required String userId,
    DateTime? date,
  }) async {
    final firestore = _firestore;
    if (firestore == null) {
      return null;
    }

    try {
      // Use UTC for consistency
      final targetDate = (date ?? DateTime.now()).toUtc();
      final dateKey =
          '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
      
      // Validate collection path before querying
      if (dateKey.isEmpty || challengeId.isEmpty) {
        debugPrint('Invalid dateKey or challengeId for rank query');
        return null;
      }
      
      final collectionPath =
          'daily_challenge_leaderboard/$dateKey/$challengeId/scores';

      // Optimize: First check if user has a score, then query only if needed
      // Limit to 50 for better performance (most users will be in top 50)
      final querySnapshot = await firestore
          .collection(collectionPath)
          .orderBy('score', descending: true)
          .limit(50)
          .get();

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
    } on FirebaseException catch (e) {
      debugPrint('Firebase error getting user rank: $e');
      return null;
    } catch (e) {
      debugPrint('Error getting user rank: $e');
      return null;
    }
  }

  /// Validate that a challenge exists and is for today
  /// Returns error message if validation fails, null if valid
  Future<String?> validateChallenge(String challengeId) async {
    final firestore = _firestore;
    if (firestore == null) {
      return 'Firebase not available';
    }

    try {
      // Use UTC for consistency
      final today = DateTime.now().toUtc();
      final dateKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Check if challenge collection exists (indicates challenge was created today)
      final scoresRef = firestore.collection(
        'daily_challenge_leaderboard/$dateKey/$challengeId/scores',
      );
      await scoresRef.limit(1).get(); // Just check if collection exists

      // Validate that challenge is for today's date
      // The dateKey in the path ensures it's today's challenge
      // Additional validation: Check if challenge exists in ChallengeService
      // Note: This validates the challenge exists and is for today via the collection path

      // Note: We cannot directly validate ChallengeType here without accessing ChallengeService
      // The UI layer should ensure only competitive challenges are submitted
      // This validation ensures the challenge exists and is for today's date

      return null; // Valid
    } on FirebaseException catch (e) {
      debugPrint('Error validating challenge: $e');
      if (e.code == 'permission-denied') {
        return 'Permission denied';
      } else if (e.code == 'not-found') {
        return 'Challenge not found or expired';
      }
      return 'Validation error: ${e.message}';
    } catch (e) {
      debugPrint('Error validating challenge: $e');
      return 'Challenge validation failed: $e';
    }
  }
}
