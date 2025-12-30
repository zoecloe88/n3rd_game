import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:n3rd_game/services/daily_challenge_leaderboard_service.dart';

/// Result of a paginated leaderboard query
class PaginatedLeaderboardResult {

  PaginatedLeaderboardResult({
    required this.entries,
    required this.hasMore,
    this.lastDocument,
  });
  final List<DailyChallengeLeaderboardEntry> entries;
  final bool hasMore;
  final DocumentSnapshot? lastDocument;
}

/// Abstract repository interface for leaderboard operations
///
/// Allows for easier testing and potential future storage backends.
abstract class LeaderboardRepository {
  /// Submit a score for daily competitive challenge
  Future<SubmissionResponse> submitScore({
    required String dateKey,
    required String challengeId,
    required String userId,
    required String displayName,
    required int score,
    required int completionTime,
    required double accuracy,
  });

  /// Get attempt count for a user on a specific challenge
  Future<int> getAttemptCount({
    required String dateKey,
    required String challengeId,
    required String userId,
  });

  /// Get top N leaderboard entries for a specific challenge
  Future<List<DailyChallengeLeaderboardEntry>> getTopLeaderboard({
    required String dateKey,
    required String challengeId,
    int limit = 5,
  });

  /// Get paginated leaderboard entries for a specific challenge
  /// Returns entries and a flag indicating if there are more results
  Future<PaginatedLeaderboardResult> getPaginatedLeaderboard({
    required String dateKey,
    required String challengeId,
    int pageSize = 20,
    DocumentSnapshot? startAfter,
  });

  /// Get user's rank for a specific challenge
  Future<int?> getUserRank({
    required String dateKey,
    required String challengeId,
    required String userId,
    int maxRank = 50,
  });

  /// Validate that a challenge exists and is for the given date
  Future<String?> validateChallenge({
    required String dateKey,
    required String challengeId,
  });

  /// Check if repository is available (e.g., Firebase initialized)
  bool get isAvailable;
}
