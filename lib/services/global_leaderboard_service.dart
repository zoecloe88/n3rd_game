import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:n3rd_game/services/leaderboard/leaderboard_repository.dart';
import 'package:n3rd_game/services/leaderboard/firestore_leaderboard_repository.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/models/game_mode_config.dart';

/// Service for managing global leaderboards for all game modes
///
/// Handles score submission, leaderboard queries, and friend comparisons with:
/// - Repository pattern for storage abstraction
/// - Firestore integration for cloud storage
/// - Caching for leaderboard data
/// - Pagination support
/// - Multiple timeframes (daily, weekly, monthly, all-time)
class GlobalLeaderboardService {
  static const Duration _cacheExpiry = Duration(minutes: 5);

  GlobalLeaderboardRepository? _repository;
  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _disposed = false;

  // Cache for leaderboard data
  final Map<String, PaginatedGlobalLeaderboardResult> _leaderboardCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  /// Get current user ID
  String? get _userId {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (e) {
      return null;
    }
  }

  /// Get current user display name
  String? get _displayName {
    try {
      return FirebaseAuth.instance.currentUser?.displayName;
    } catch (e) {
      return null;
    }
  }

  /// Initialize the service
  Future<void> init() async {
    if (_isInitialized || _isInitializing || _disposed) return;

    _isInitializing = true;

    try {
      // Try to initialize Firebase
      try {
        Firebase.app();
        _repository =
            FirestoreGlobalLeaderboardRepository(FirebaseFirestore.instance);
      } catch (e) {
        LoggerService.warning('Firebase not available for global leaderboard',
            error: e,);
      }

      _isInitialized = true;
    } catch (e, stack) {
      LoggerService.error('Failed to initialize GlobalLeaderboardService',
          error: e, stack: stack,);
    } finally {
      _isInitializing = false;
    }
  }

  /// Get cache key for a leaderboard query
  String _getCacheKey(String gameMode, LeaderboardTimeframe timeframe,
      {DocumentSnapshot? startAfter,}) {
    final startAfterId = startAfter?.id ?? 'first';
    return '${gameMode}_${timeframe.name}_$startAfterId';
  }

  /// Get cached leaderboard
  PaginatedGlobalLeaderboardResult? _getCachedLeaderboard(
    String gameMode,
    LeaderboardTimeframe timeframe, {
    DocumentSnapshot? startAfter,
  }) {
    final key = _getCacheKey(gameMode, timeframe, startAfter: startAfter);
    final timestamp = _cacheTimestamps[key];

    if (timestamp == null) return null;

    if (DateTime.now().difference(timestamp) > _cacheExpiry) {
      _leaderboardCache.remove(key);
      _cacheTimestamps.remove(key);
      return null;
    }

    return _leaderboardCache[key];
  }

  /// Cache leaderboard result
  void _cacheLeaderboard(
    String gameMode,
    LeaderboardTimeframe timeframe,
    PaginatedGlobalLeaderboardResult result, {
    DocumentSnapshot? startAfter,
  }) {
    final key = _getCacheKey(gameMode, timeframe, startAfter: startAfter);
    _leaderboardCache[key] = result;
    _cacheTimestamps[key] = DateTime.now();
  }

  /// Submit a score for a game mode
  Future<void> submitScore({
    required int score,
    required GameMode gameMode,
    LeaderboardTimeframe timeframe = LeaderboardTimeframe.allTime,
  }) async {
    if (_disposed) return;

    final userId = _userId;
    if (userId == null) {
      LoggerService.warning('Cannot submit score: user not logged in');
      return;
    }

    if (_repository == null || !_repository!.isAvailable) {
      LoggerService.warning('Cannot submit score: Firebase not available');
      return;
    }

    if (score < 0) {
      LoggerService.warning('Cannot submit negative score');
      return;
    }

    try {
      await _repository!.submitScore(
        userId: userId,
        displayName: _displayName,
        score: score,
        gameMode: gameMode.name,
        timeframe: timeframe,
      );

      // Invalidate cache for this game mode and timeframe
      _invalidateCache(gameMode.name, timeframe);
    } catch (e, stack) {
      LoggerService.error('Error submitting score to global leaderboard',
          error: e, stack: stack,);
    }
  }

  /// Invalidate cache for a game mode and timeframe
  void _invalidateCache(String gameMode, LeaderboardTimeframe timeframe) {
    final prefix = '${gameMode}_${timeframe.name}_';
    final keysToRemove = <String>[];
    for (final key in _leaderboardCache.keys) {
      if (key.startsWith(prefix)) {
        keysToRemove.add(key);
      }
    }
    for (final key in keysToRemove) {
      _leaderboardCache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }

  /// Get paginated leaderboard for a game mode and timeframe
  Future<PaginatedGlobalLeaderboardResult> getLeaderboard({
    required GameMode gameMode,
    required LeaderboardTimeframe timeframe,
    int pageSize = 20,
    DocumentSnapshot? startAfter,
  }) async {
    if (_disposed) {
      return PaginatedGlobalLeaderboardResult(
        entries: [],
        hasMore: false,
      );
    }

    if (_repository == null || !_repository!.isAvailable) {
      LoggerService.warning('Cannot get leaderboard: Firebase not available');
      final cached = _getCachedLeaderboard(gameMode.name, timeframe,
          startAfter: startAfter,);
      return cached ??
          PaginatedGlobalLeaderboardResult(
            entries: [],
            hasMore: false,
          );
    }

    try {
      // Check cache first
      final cached = _getCachedLeaderboard(gameMode.name, timeframe,
          startAfter: startAfter,);
      if (cached != null && startAfter == null) {
        // Only use cache for first page
        return cached;
      }

      final result = await _repository!.getLeaderboard(
        gameMode: gameMode.name,
        timeframe: timeframe,
        pageSize: pageSize,
        startAfter: startAfter,
      );

      // Cache the first page only
      if (startAfter == null && result.entries.isNotEmpty) {
        _cacheLeaderboard(gameMode.name, timeframe, result);
      }

      return result;
    } catch (e, stack) {
      LoggerService.error('Error fetching global leaderboard',
          error: e, stack: stack,);
      final cached = _getCachedLeaderboard(gameMode.name, timeframe,
          startAfter: startAfter,);
      return cached ??
          PaginatedGlobalLeaderboardResult(
            entries: [],
            hasMore: false,
          );
    }
  }

  /// Get user's rank for a game mode and timeframe
  Future<int?> getUserRank({
    required GameMode gameMode,
    required LeaderboardTimeframe timeframe,
  }) async {
    if (_disposed) return null;

    final userId = _userId;
    if (userId == null) {
      LoggerService.warning('Cannot get rank: user not logged in');
      return null;
    }

    if (_repository == null || !_repository!.isAvailable) {
      LoggerService.warning('Cannot get rank: Firebase not available');
      return null;
    }

    try {
      return await _repository!.getUserRank(
        userId: userId,
        gameMode: gameMode.name,
        timeframe: timeframe,
      );
    } catch (e, stack) {
      LoggerService.error('Error getting user rank', error: e, stack: stack);
      return null;
    }
  }

  /// Get friends leaderboard for a game mode and timeframe
  Future<List<GlobalLeaderboardEntry>> getFriendsLeaderboard({
    required List<String> friendUserIds,
    required GameMode gameMode,
    required LeaderboardTimeframe timeframe,
    int limit = 20,
  }) async {
    if (_disposed) return [];

    final userId = _userId;
    if (userId == null) {
      LoggerService.warning(
          'Cannot get friends leaderboard: user not logged in',);
      return [];
    }

    if (_repository == null || !_repository!.isAvailable) {
      LoggerService.warning(
          'Cannot get friends leaderboard: Firebase not available',);
      return [];
    }

    if (friendUserIds.isEmpty) {
      return [];
    }

    try {
      return await _repository!.getFriendsLeaderboard(
        userId: userId,
        friendUserIds: friendUserIds,
        gameMode: gameMode.name,
        timeframe: timeframe,
        limit: limit,
      );
    } catch (e, stack) {
      LoggerService.error('Error getting friends leaderboard',
          error: e, stack: stack,);
      return [];
    }
  }

  /// Dispose resources
  void dispose() {
    _disposed = true;
    _leaderboardCache.clear();
    _cacheTimestamps.clear();
  }
}
