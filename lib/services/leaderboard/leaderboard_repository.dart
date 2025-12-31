import 'package:cloud_firestore/cloud_firestore.dart';

/// Leaderboard entry for any game mode
class GlobalLeaderboardEntry {

  GlobalLeaderboardEntry({
    required this.userId,
    this.displayName,
    required this.score,
    required this.gameMode,
    required this.timestamp,
    required this.rank,
  });

  factory GlobalLeaderboardEntry.fromFirestore(
    DocumentSnapshot doc,
    int rank,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    return GlobalLeaderboardEntry(
      userId: doc.id,
      displayName: data['displayName'] as String?,
      score: data['score'] as int? ?? 0,
      gameMode: data['gameMode'] as String? ?? 'classic',
      timestamp:
          (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now().toUtc(),
      rank: rank,
    );
  }
  final String userId;
  final String? displayName;
  final int score;
  final String gameMode;
  final DateTime timestamp;
  final int rank;
}

/// Result of a paginated leaderboard query
class PaginatedGlobalLeaderboardResult {

  PaginatedGlobalLeaderboardResult({
    required this.entries,
    required this.hasMore,
    this.lastDocument,
  });
  final List<GlobalLeaderboardEntry> entries;
  final bool hasMore;
  final DocumentSnapshot? lastDocument;
}

/// Timeframe for leaderboard queries
enum LeaderboardTimeframe {
  daily,
  weekly,
  monthly,
  allTime,
}

/// Abstract repository interface for global leaderboard operations
///
/// Allows for easier testing and potential future storage backends.
abstract class GlobalLeaderboardRepository {
  /// Submit a score for a game mode
  Future<void> submitScore({
    required String userId,
    required String? displayName,
    required int score,
    required String gameMode,
    required LeaderboardTimeframe timeframe,
  });

  /// Get paginated leaderboard entries for a game mode and timeframe
  Future<PaginatedGlobalLeaderboardResult> getLeaderboard({
    required String gameMode,
    required LeaderboardTimeframe timeframe,
    int pageSize = 20,
    DocumentSnapshot? startAfter,
  });

  /// Get user's rank for a game mode and timeframe
  Future<int?> getUserRank({
    required String userId,
    required String gameMode,
    required LeaderboardTimeframe timeframe,
  });

  /// Get friends leaderboard for a game mode and timeframe
  Future<List<GlobalLeaderboardEntry>> getFriendsLeaderboard({
    required String userId,
    required List<String> friendUserIds,
    required String gameMode,
    required LeaderboardTimeframe timeframe,
    int limit = 20,
  });

  /// Check if repository is available (e.g., Firebase initialized)
  bool get isAvailable;
}
















