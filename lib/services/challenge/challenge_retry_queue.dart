import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/models/daily_challenge.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Persistent retry queue for failed challenge saves
///
/// Queues failed Firestore saves and retries them in the background.
/// Persists queue to SharedPreferences for reliability across app restarts.
class ChallengeRetryQueue {
  static const String _storageKey = 'challenge_retry_queue';
  static const int _maxRetries = 3;
  static const Duration _baseRetryDelay = Duration(seconds: 5);
  static const Duration _maxRetryAge = Duration(days: 7);

  final List<_QueuedChallenge> _queue = [];
  Timer? _retryTimer;
  bool _isProcessing = false;

  /// Add a challenge save to the retry queue
  Future<void> enqueue({
    required String userId,
    required List<DailyChallenge> challenges,
  }) async {
    final queuedChallenge = _QueuedChallenge(
      userId: userId,
      challenges: challenges,
      attempts: 0,
      firstAttempt: DateTime.now(),
    );

    _queue.add(queuedChallenge);
    await _persistQueue();
    _scheduleRetry();
  }

  /// Process the retry queue
  ///
  /// [saveFunction] - Function to call for each challenge save
  Future<void> processQueue(
    Future<void> Function(String userId, List<DailyChallenge> challenges)
        saveFunction,
  ) async {
    if (_isProcessing || _queue.isEmpty) return;

    _isProcessing = true;

    try {
      final now = DateTime.now();
      final challengesToRetry = <_QueuedChallenge>[];

      // Collect challenges that need retrying
      for (final queuedChallenge in _queue) {
        // Remove old entries
        if (now.difference(queuedChallenge.firstAttempt) > _maxRetryAge) {
          LoggerService.warning(
            'Removing old queued challenge from retry queue: ${queuedChallenge.userId}',
          );
          continue;
        }

        // Skip if max retries reached
        if (queuedChallenge.attempts >= _maxRetries) {
          LoggerService.warning(
            'Max retries reached for challenge: ${queuedChallenge.userId}',
          );
          continue;
        }

        challengesToRetry.add(queuedChallenge);
      }

      // Remove processed/expired challenges
      _queue.removeWhere((q) => !challengesToRetry.contains(q));

      // Retry each challenge save
      for (final queuedChallenge in challengesToRetry) {
        try {
          await saveFunction(
            queuedChallenge.userId,
            queuedChallenge.challenges,
          );

          // Success - remove from queue
          _queue.remove(queuedChallenge);
          LoggerService.info(
            'Successfully saved queued challenges for user: ${queuedChallenge.userId}',
          );
        } catch (e) {
          // Failed - increment attempts
          queuedChallenge.attempts++;
          LoggerService.warning(
            'Retry failed for challenge ${queuedChallenge.userId} (attempt ${queuedChallenge.attempts}/$_maxRetries);',
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
            _queue.add(_QueuedChallenge.fromJson(map));
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

/// Internal class for queued challenges
class _QueuedChallenge {

  _QueuedChallenge({
    required this.userId,
    required this.challenges,
    required this.attempts,
    required this.firstAttempt,
  });

  factory _QueuedChallenge.fromJson(Map<String, dynamic> json) {
    return _QueuedChallenge(
      userId: json['userId'] as String,
      challenges: (json['challenges'] as List)
          .map((c) => DailyChallenge.fromJson(c as Map<String, dynamic>))
          .toList(),
      attempts: json['attempts'] as int,
      firstAttempt: DateTime.parse(json['firstAttempt'] as String),
    );
  }
  final String userId;
  final List<DailyChallenge> challenges;
  int attempts;
  final DateTime firstAttempt;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'challenges': challenges.map((c) => c.toJson()).toList(),
      'attempts': attempts,
      'firstAttempt': firstAttempt.toIso8601String(),
    };
  }
}













