import 'package:n3rd_game/models/game_history_entry.dart';
import 'package:n3rd_game/utils/game_mode_extensions.dart';

/// Statistics service for game history
///
/// Calculates and caches statistics from game history.
/// Supports incremental updates for performance.
class GameHistoryStatistics {
  static const Duration _cacheTTL = Duration(minutes: 5);

  Map<String, dynamic>? _cachedStatistics;
  DateTime? _cacheTimestamp;
  List<GameHistoryEntry>? _cachedGames;

  /// Calculate statistics from game history
  ///
  /// [games] - List of game history entries to analyze
  /// [useCache] - Whether to use cached statistics if available
  Map<String, dynamic> calculateStatistics(
    List<GameHistoryEntry> games, {
    bool useCache = true,
  }) {
    // Check cache
    if (useCache &&
        _cachedStatistics != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheTTL &&
        _cachedGames != null &&
        _listEquals(_cachedGames!, games)) {
      return Map<String, dynamic>.from(_cachedStatistics!);
    }

    if (games.isEmpty) {
      return _emptyStatistics();
    }

    final totalGames = games.length;
    final totalScore = games.fold<int>(0, (acc, g) => acc + g.score);
    final averageScore = totalScore / totalGames;
    final highestScore =
        games.map((g) => g.score).reduce((a, b) => a > b ? a : b);
    final totalRounds = games.fold<int>(0, (acc, g) => acc + g.rounds);
    final totalAccuracy = games.fold<double>(0.0, (acc, g) => acc + g.accuracy);
    final averageAccuracy = totalAccuracy / totalGames;

    final modeBreakdown = <String, int>{};
    for (final game in games) {
      final modeName = game.mode.displayName;
      modeBreakdown[modeName] = (modeBreakdown[modeName] ?? 0) + 1;
    }

    final statistics = {
      'totalGames': totalGames,
      'totalScore': totalScore,
      'averageScore': averageScore,
      'highestScore': highestScore,
      'totalRounds': totalRounds,
      'averageAccuracy': averageAccuracy,
      'modeBreakdown': modeBreakdown,
    };

    // Cache results
    _cachedStatistics = Map<String, dynamic>.from(statistics);
    _cacheTimestamp = DateTime.now();
    _cachedGames = List.from(games);

    return statistics;
  }

  /// Calculate incremental statistics update
  ///
  /// Updates cached statistics with a new game entry.
  Map<String, dynamic>? updateWithNewGame(GameHistoryEntry newGame) {
    if (_cachedStatistics == null || _cachedGames == null) {
      return null; // No cache to update
    }

    // Add new game to cached list
    _cachedGames!.insert(0, newGame);

    // Recalculate statistics
    return calculateStatistics(_cachedGames!, useCache: false);
  }

  /// Invalidate cache
  void invalidateCache() {
    _cachedStatistics = null;
    _cacheTimestamp = null;
    _cachedGames = null;
  }

  /// Get empty statistics
  Map<String, dynamic> _emptyStatistics() {
    return {
      'totalGames': 0,
      'totalScore': 0,
      'averageScore': 0.0,
      'highestScore': 0,
      'totalRounds': 0,
      'averageAccuracy': 0.0,
      'modeBreakdown': <String, int>{},
    };
  }

  /// Check if two lists are equal (by gameId)
  bool _listEquals(List<GameHistoryEntry> a, List<GameHistoryEntry> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].gameId != b[i].gameId) return false;
    }
    return true;
  }
}
