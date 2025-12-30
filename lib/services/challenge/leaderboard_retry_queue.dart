import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/services/daily_challenge_leaderboard_service.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Persistent retry queue for failed leaderboard submissions
///
/// Queues failed Firestore submissions and retries them in the background.
/// Persists queue to SharedPreferences for reliability across app restarts.
class LeaderboardRetryQueue {
  static const String _storageKey = 'leaderboard_retry_queue';
  static const int _maxRetries = 3;
  static const Duration _baseRetryDelay = Duration(seconds: 5);
  static const Duration _maxRetryAge = Duration(days: 7);

  final List<_QueuedSubmission> _queue = [];
  Timer? _retryTimer;
  bool _isProcessing = false;

  /// Add a submission to the retry queue
  Future<void> enqueue({
    required String dateKey,
    required String challengeId,
    required String userId,
    required String displayName,
    required int score,
    required int completionTime,
    required double accuracy,
  }) async {
    final queuedSubmission = _QueuedSubmission(
      dateKey: dateKey,
      challengeId: challengeId,
      userId: userId,
      displayName: displayName,
      score: score,
      completionTime: completionTime,
      accuracy: accuracy,
      attempts: 0,
      firstAttempt: DateTime.now(),
    );

    _queue.add(queuedSubmission);
    await _persistQueue();
    _scheduleRetry();
  }

  /// Process the retry queue
  ///
  /// [submitFunction] - Function to call for each submission
  Future<void> processQueue(
    Future<SubmissionResponse> Function({
      required String dateKey,
      required String challengeId,
      required String userId,
      required String displayName,
      required int score,
      required int completionTime,
      required double accuracy,
    }) submitFunction,
  ) async {
    if (_isProcessing || _queue.isEmpty) return;

    _isProcessing = true;

    try {
      final now = DateTime.now();
      final submissionsToRetry = <_QueuedSubmission>[];

      // Collect submissions that need retrying
      for (final queuedSubmission in _queue) {
        // Remove old entries
        if (now.difference(queuedSubmission.firstAttempt) > _maxRetryAge) {
          LoggerService.warning(
            'Removing old queued submission from retry queue: ${queuedSubmission.challengeId}',
          );
          continue;
        }

        // Skip if max retries reached
        if (queuedSubmission.attempts >= _maxRetries) {
          LoggerService.warning(
            'Max retries reached for submission: ${queuedSubmission.challengeId}',
          );
          continue;
        }

        submissionsToRetry.add(queuedSubmission);
      }

      // Remove processed/expired submissions
      _queue.removeWhere((q) => !submissionsToRetry.contains(q));

      // Retry each submission
      for (final queuedSubmission in submissionsToRetry) {
        try {
          final response = await submitFunction(
            dateKey: queuedSubmission.dateKey,
            challengeId: queuedSubmission.challengeId,
            userId: queuedSubmission.userId,
            displayName: queuedSubmission.displayName,
            score: queuedSubmission.score,
            completionTime: queuedSubmission.completionTime,
            accuracy: queuedSubmission.accuracy,
          );

          // Success - remove from queue
          if (response.isSuccess) {
            _queue.remove(queuedSubmission);
            LoggerService.info(
              'Successfully submitted queued score for challenge: ${queuedSubmission.challengeId}',
            );
          } else {
            // Failed - increment attempts
            queuedSubmission.attempts++;
            LoggerService.warning(
              'Retry failed for submission ${queuedSubmission.challengeId} (attempt ${queuedSubmission.attempts}/$_maxRetries);: ${response.message}',
            );
          }
        } catch (e) {
          // Failed - increment attempts
          queuedSubmission.attempts++;
          LoggerService.warning(
            'Retry failed for submission ${queuedSubmission.challengeId} (attempt ${queuedSubmission.attempts}/$_maxRetries);',
            error: e,
          );
        }
      }

      await _persistQueue();
    } finally {
      _isProcessing = false;
    }
  }

  /// Schedule next retry with exponential backoff
  void _scheduleRetry() {
    _retryTimer?.cancel();
    final delay = _calculateRetryDelay();
    _retryTimer = Timer(delay, () {
      // Retry will be triggered by service when it calls processQueue
    });
  }

  /// Calculate retry delay with exponential backoff
  Duration _calculateRetryDelay() {
    if (_queue.isEmpty) return _baseRetryDelay;

    final maxAttempts =
        _queue.map((q) => q.attempts).reduce((a, b) => a > b ? a : b);
    final multiplier = 1 << maxAttempts; // 2^attempts
    final delay = _baseRetryDelay * multiplier;

    // Cap at 5 minutes
    return delay > const Duration(minutes: 5)
        ? const Duration(minutes: 5)
        : delay;
  }

  /// Load queue from SharedPreferences
  Future<void> loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        final queueList = json['queue'] as List<dynamic>?;
        if (queueList != null) {
          _queue.clear();
          for (final item in queueList) {
            final map = item as Map<String, dynamic>;
            _queue.add(_QueuedSubmission.fromJson(map));
          }
        }
      }
    } catch (e) {
      LoggerService.error('Failed to load retry queue', error: e);
      _queue.clear();
    }
  }

  /// Persist queue to SharedPreferences
  Future<void> _persistQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = {
        'queue': _queue.map((q) => q.toJson()).toList(),
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_storageKey, jsonEncode(json));
    } catch (e) {
      LoggerService.error('Failed to persist retry queue', error: e);
    }
  }

  /// Get queue size
  int get queueSize => _queue.length;

  /// Clear the queue
  Future<void> clear() async {
    _queue.clear();
    await _persistQueue();
  }

  /// Dispose resources
  void dispose() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }
}

/// Internal class for queued submissions
class _QueuedSubmission {

  _QueuedSubmission({
    required this.dateKey,
    required this.challengeId,
    required this.userId,
    required this.displayName,
    required this.score,
    required this.completionTime,
    required this.accuracy,
    required this.attempts,
    required this.firstAttempt,
  });

  factory _QueuedSubmission.fromJson(Map<String, dynamic> json) {
    return _QueuedSubmission(
      dateKey: json['dateKey'] as String,
      challengeId: json['challengeId'] as String,
      userId: json['userId'] as String,
      displayName: json['displayName'] as String,
      score: json['score'] as int,
      completionTime: json['completionTime'] as int,
      accuracy: (json['accuracy'] as num).toDouble(),
      attempts: json['attempts'] as int,
      firstAttempt: DateTime.parse(json['firstAttempt'] as String),
    );
  }
  final String dateKey;
  final String challengeId;
  final String userId;
  final String displayName;
  final int score;
  final int completionTime;
  final double accuracy;
  int attempts;
  final DateTime firstAttempt;

  Map<String, dynamic> toJson() {
    return {
      'dateKey': dateKey,
      'challengeId': challengeId,
      'userId': userId,
      'displayName': displayName,
      'score': score,
      'completionTime': completionTime,
      'accuracy': accuracy,
      'attempts': attempts,
      'firstAttempt': firstAttempt.toIso8601String(),
    };
  }
}
















