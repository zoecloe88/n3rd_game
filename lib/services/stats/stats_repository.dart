/// Abstract repository interface for user statistics/score data access
///
/// Allows for easier testing and potential future storage backends.
abstract class StatsRepository {
  /// Get highest score for a user
  Future<int?> getHighestScore(String userId);

  /// Get friend scores (highest scores for multiple users)
  Future<Map<String, int>> getFriendScores(List<String> userIds);

  /// Check if repository is available (e.g., Firebase initialized)
  bool get isAvailable;
}













