import 'dart:async' hide unawaited;
import 'package:n3rd_game/utils/unawaited_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:n3rd_game/services/challenge/leaderboard_repository.dart';
import 'package:n3rd_game/services/challenge/firestore_leaderboard_repository.dart';
import 'package:n3rd_game/services/challenge/leaderboard_retry_queue.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/utils/input_sanitizer.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

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

  SubmissionResponse(this.result, [this.message]);
  final SubmissionResult result;
  final String? message;

  bool get isSuccess => result == SubmissionResult.success;
}

class DailyChallengeLeaderboardEntry {

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
  final String userId;
  final String? displayName;
  final int score;
  final int completionTime; // in seconds
  final double accuracy; // percentage
  final DateTime timestamp;
  final int rank;
}

/// Service for managing daily challenge leaderboards
///
/// Handles score submission, attempt tracking, and leaderboard queries with:
/// - Repository pattern for storage abstraction
/// - Firestore integration for cloud storage
/// - Error handling and retry logic
/// - Rate limiting
/// - Caching for leaderboard data
/// - Proper disposal of resources
class DailyChallengeLeaderboardService {
  static const int _maxSubmissionsPerMinute = 10;
  static const int _maxQueriesPerMinute = 20;
  static const Duration _rateLimitWindow = Duration(minutes: 1);

  LeaderboardRepository? _repository;
  final LeaderboardRetryQueue _retryQueue = LeaderboardRetryQueue();
  bool _isInitialized = false;
  bool _isInitializing = false; // Mutex to prevent concurrent initialization
  bool _disposed = false;

  // Rate limiting
  final List<DateTime> _submissionTimestamps = [];
  final List<DateTime> _queryTimestamps = [];

  // Cache for leaderboard data
  final Map<String, List<DailyChallengeLeaderboardEntry>> _leaderboardCache =
      {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);

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
            FirestoreLeaderboardRepository(FirebaseFirestore.instance);
      } catch (e) {
        LoggerService.warning('Firebase not available for leaderboard',
            error: e,);
      }

      // Load retry queue
      await _retryQueue.loadQueue();

      // Process retry queue in background
      unawaited(_processRetryQueue());

      _isInitialized = true;
    } catch (e, stack) {
      LoggerService.error(
          'Failed to initialize DailyChallengeLeaderboardService',
          error: e,
          stack: stack,);
      unawaited(FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'LeaderboardService init failed',
        fatal: false,
      ) as Future<dynamic>,);
    } finally {
      _isInitializing = false;
    }
  }

  /// Get date key for a given date (or today if null)
  String _getDateKey(DateTime? date) {
    final targetDate = (date ?? DateTime.now()).toUtc();
    return '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
  }

  /// Check rate limit for submissions
  bool _checkSubmissionRateLimit() {
    final now = DateTime.now();
    _submissionTimestamps.removeWhere(
      (timestamp) => now.difference(timestamp) > _rateLimitWindow,
    );

    if (_submissionTimestamps.length >= _maxSubmissionsPerMinute) {
      LoggerService.warning('Submission rate limit exceeded');
      return false;
    }

    _submissionTimestamps.add(now);
    return true;
  }

  /// Check rate limit for queries
  bool _checkQueryRateLimit() {
    final now = DateTime.now();
    _queryTimestamps.removeWhere(
      (timestamp) => now.difference(timestamp) > _rateLimitWindow,
    );

    if (_queryTimestamps.length >= _maxQueriesPerMinute) {
      LoggerService.warning('Query rate limit exceeded');
      return false;
    }

    _queryTimestamps.add(now);
    return true;
  }

  /// Process retry queue
  Future<void> _processRetryQueue() async {
    if (_repository == null || !_repository!.isAvailable) {
      return;
    }

    try {
      await _retryQueue.processQueue(({
        required dateKey,
        required challengeId,
        required userId,
        required displayName,
        required score,
        required completionTime,
        required accuracy,
      }) async {
        return _repository!.submitScore(
          dateKey: dateKey,
          challengeId: challengeId,
          userId: userId,
          displayName: displayName,
          score: score,
          completionTime: completionTime,
          accuracy: accuracy,
        );
      });
    } catch (e, stack) {
      LoggerService.error('Error processing retry queue',
          error: e, stack: stack,);
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
    if (_disposed) {
      return SubmissionResponse(
        SubmissionResult.unknownError,
        'Service has been disposed',
      );
    }

    // Sanitize and validate inputs
    final sanitizedChallengeId = InputSanitizer.sanitizeText(challengeId);
    if (sanitizedChallengeId.isEmpty) {
      return SubmissionResponse(
        SubmissionResult.challengeInvalid,
        'Invalid challenge ID',
      );
    }

    if (score < 0) {
      return SubmissionResponse(
        SubmissionResult.challengeInvalid,
        'Score cannot be negative',
      );
    }

    if (completionTime < 0) {
      return SubmissionResponse(
        SubmissionResult.challengeInvalid,
        'Completion time cannot be negative',
      );
    }

    if (accuracy < 0 || accuracy > 100) {
      return SubmissionResponse(
        SubmissionResult.challengeInvalid,
        'Accuracy must be between 0 and 100',
      );
    }

    // Check rate limit
    if (!_checkSubmissionRateLimit()) {
      return SubmissionResponse(
        SubmissionResult.unknownError,
        'Too many submissions. Please wait a moment.',
      );
    }

    final userId = _userId;
    final displayName = _displayName ?? 'Anonymous';

    if (userId == null) {
      LoggerService.warning('Cannot submit score: user not logged in');
      return SubmissionResponse(
        SubmissionResult.unknownError,
        'Please log in to submit scores',
      );
    }

    if (_repository == null || !_repository!.isAvailable) {
      LoggerService.warning('Cannot submit score: Firebase not available');
      // Queue for retry
      final dateKey = _getDateKey(null);
      await _retryQueue.enqueue(
        dateKey: dateKey,
        challengeId: challengeId,
        userId: userId,
        displayName: displayName,
        score: score,
        completionTime: completionTime,
        accuracy: accuracy,
      );
      return SubmissionResponse(
        SubmissionResult.networkError,
        'Network error. Your score will be submitted when connection is restored.',
      );
    }

    try {
      final dateKey = _getDateKey(null);
      final sanitizedDisplayName =
          InputSanitizer.sanitizeDisplayName(displayName);
      final response = await _repository!.submitScore(
        dateKey: dateKey,
        challengeId: sanitizedChallengeId,
        userId: userId,
        displayName: sanitizedDisplayName,
        score: score,
        completionTime: completionTime,
        accuracy: accuracy,
      );

      // Invalidate cache on successful submission
      if (response.isSuccess) {
        _invalidateCache(challengeId, dateKey);
      } else if (response.result == SubmissionResult.networkError) {
        // Queue for retry on network error
        await _retryQueue.enqueue(
          dateKey: dateKey,
          challengeId: sanitizedChallengeId,
          userId: userId,
          displayName: sanitizedDisplayName,
          score: score,
          completionTime: completionTime,
          accuracy: accuracy,
        );
      }

      return response;
    } catch (e, stack) {
      LoggerService.error('Unexpected error submitting score',
          error: e, stack: stack,);
      unawaited(FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'Score submission failed',
        fatal: false,
      ) as Future<dynamic>,);

      // Queue for retry
      final dateKey = _getDateKey(null);
      final sanitizedDisplayName =
          InputSanitizer.sanitizeDisplayName(displayName);
      await _retryQueue.enqueue(
        dateKey: dateKey,
        challengeId: sanitizedChallengeId,
        userId: userId,
        displayName: sanitizedDisplayName,
        score: score,
        completionTime: completionTime,
        accuracy: accuracy,
      );

      return SubmissionResponse(
        SubmissionResult.unknownError,
        'An error occurred. Your score will be submitted when connection is restored.',
      );
    }
  }

  /// Get attempt count for a user on a specific challenge
  Future<int> getAttemptCount(String challengeId, DateTime? date) async {
    if (_disposed || _repository == null || !_repository!.isAvailable) {
      return 0;
    }

    try {
      final sanitizedChallengeId = InputSanitizer.sanitizeText(challengeId);
      final dateKey = _getDateKey(date);
      final userId = _userId;
      if (userId == null) {
        return 0;
      }

      return await _repository!.getAttemptCount(
        dateKey: dateKey,
        challengeId: sanitizedChallengeId,
        userId: userId,
      );
    } catch (e, stack) {
      LoggerService.error('Error getting attempt count',
          error: e, stack: stack,);
      return 0;
    }
  }

  /// Get paginated leaderboard for a specific challenge
  /// Returns entries and a flag indicating if there are more results
  Future<PaginatedLeaderboardResult> getPaginatedLeaderboard({
    required String challengeId,
    DateTime? date,
    int pageSize = 20,
    DocumentSnapshot? startAfter,
  }) async {
    if (_disposed) {
      return PaginatedLeaderboardResult(
        entries: [],
        hasMore: false,
      );
    }

    // Sanitize challenge ID
    final sanitizedChallengeId = InputSanitizer.sanitizeText(challengeId);

    // Check rate limit
    if (!_checkQueryRateLimit()) {
      LoggerService.warning('Query rate limit exceeded, returning cached data');
      final cached = _getCachedLeaderboard(sanitizedChallengeId, date);
      return PaginatedLeaderboardResult(
        entries: cached,
        hasMore: false, // Can't determine hasMore from cache
      );
    }

    if (_repository == null || !_repository!.isAvailable) {
      LoggerService.warning('Cannot get leaderboard: Firebase not available');
      final cached = _getCachedLeaderboard(sanitizedChallengeId, date);
      return PaginatedLeaderboardResult(
        entries: cached,
        hasMore: false,
      );
    }

    try {
      final dateKey = _getDateKey(date);

      final result = await _repository!.getPaginatedLeaderboard(
        dateKey: dateKey,
        challengeId: sanitizedChallengeId,
        pageSize: pageSize,
        startAfter: startAfter,
      );

      // Cache the first page only (for quick access)
      if (startAfter == null && result.entries.isNotEmpty) {
        _cacheLeaderboard(sanitizedChallengeId, dateKey, result.entries);
      }

      return result;
    } catch (e, stack) {
      LoggerService.error('Error fetching paginated leaderboard',
          error: e, stack: stack,);
      final cached = _getCachedLeaderboard(sanitizedChallengeId, date);
      return PaginatedLeaderboardResult(
        entries: cached,
        hasMore: false,
      );
    }
  }

  /// Get top 5 leaderboard for a specific challenge
  Future<List<DailyChallengeLeaderboardEntry>> getTop5Leaderboard({
    required String challengeId,
    DateTime? date,
  }) async {
    if (_disposed) {
      return [];
    }

    // Sanitize challenge ID
    final sanitizedChallengeId = InputSanitizer.sanitizeText(challengeId);

    // Check rate limit
    if (!_checkQueryRateLimit()) {
      LoggerService.warning('Query rate limit exceeded, returning cached data');
      return _getCachedLeaderboard(sanitizedChallengeId, date);
    }

    if (_repository == null || !_repository!.isAvailable) {
      LoggerService.warning('Cannot get leaderboard: Firebase not available');
      return _getCachedLeaderboard(sanitizedChallengeId, date);
    }

    try {
      final dateKey = _getDateKey(date);

      // Check cache first
      final cached = _getCachedLeaderboard(sanitizedChallengeId, date);
      if (cached.isNotEmpty) {
        return cached;
      }

      final entries = await _repository!.getTopLeaderboard(
        dateKey: dateKey,
        challengeId: sanitizedChallengeId,
        limit: 5,
      );

      // Cache the result
      _cacheLeaderboard(sanitizedChallengeId, dateKey, entries);

      return entries;
    } catch (e, stack) {
      LoggerService.error('Error fetching leaderboard', error: e, stack: stack);
      return _getCachedLeaderboard(sanitizedChallengeId, date);
    }
  }

  /// Get user's rank for a specific challenge
  Future<int?> getUserRank({
    required String challengeId,
    required String userId,
    DateTime? date,
  }) async {
    if (_disposed || _repository == null || !_repository!.isAvailable) {
      return null;
    }

    try {
      final sanitizedChallengeId = InputSanitizer.sanitizeText(challengeId);
      final sanitizedUserId = InputSanitizer.sanitizeText(userId);
      final dateKey = _getDateKey(date);
      return await _repository!.getUserRank(
        dateKey: dateKey,
        challengeId: sanitizedChallengeId,
        userId: sanitizedUserId,
        maxRank: 50,
      );
    } catch (e, stack) {
      LoggerService.error('Error getting user rank', error: e, stack: stack);
      return null;
    }
  }

  /// Validate that a challenge exists and is for today
  /// Returns error message if validation fails, null if valid
  Future<String?> validateChallenge(String challengeId) async {
    if (_disposed || _repository == null || !_repository!.isAvailable) {
      return 'Firebase not available';
    }

    try {
      final sanitizedChallengeId = InputSanitizer.sanitizeText(challengeId);
      final dateKey = _getDateKey(null);
      return await _repository!.validateChallenge(
        dateKey: dateKey,
        challengeId: sanitizedChallengeId,
      );
    } catch (e, stack) {
      LoggerService.error('Error validating challenge', error: e, stack: stack);
      return 'Challenge validation failed: $e';
    }
  }

  /// Get cached leaderboard
  List<DailyChallengeLeaderboardEntry> _getCachedLeaderboard(
    String challengeId,
    DateTime? date,
  ) {
    final dateKey = _getDateKey(date);
    final cacheKey = '$dateKey:$challengeId';

    final cached = _leaderboardCache[cacheKey];
    final timestamp = _cacheTimestamps[cacheKey];

    if (cached != null && timestamp != null) {
      if (DateTime.now().difference(timestamp) < _cacheExpiry) {
        return cached;
      } else {
        // Cache expired
        _leaderboardCache.remove(cacheKey);
        _cacheTimestamps.remove(cacheKey);
      }
    }

    return [];
  }

  /// Cache leaderboard data
  void _cacheLeaderboard(
    String challengeId,
    String dateKey,
    List<DailyChallengeLeaderboardEntry> entries,
  ) {
    final cacheKey = '$dateKey:$challengeId';
    _leaderboardCache[cacheKey] = entries;
    _cacheTimestamps[cacheKey] = DateTime.now();
  }

  /// Invalidate cache for a challenge
  void _invalidateCache(String challengeId, String dateKey) {
    final cacheKey = '$dateKey:$challengeId';
    _leaderboardCache.remove(cacheKey);
    _cacheTimestamps.remove(cacheKey);
  }

  /// Dispose resources
  void dispose() {
    _disposed = true;
    _retryQueue.dispose();
    _leaderboardCache.clear();
    _cacheTimestamps.clear();
  }
}