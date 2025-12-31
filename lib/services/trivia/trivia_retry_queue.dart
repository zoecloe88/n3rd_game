import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Persistent retry queue for failed trivia saves
///
/// Queues failed Firestore saves and retries them in the background.
/// Persists queue to SharedPreferences for reliability across app restarts.
class TriviaRetryQueue {
  static const String _storageKey = 'trivia_retry_queue';
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 5);
  static const Duration _maxRetryAge = Duration(days: 7);

  final List<_QueuedTrivia> _queue = [];
  Timer? _retryTimer;
  bool _isProcessing = false;

  /// Add trivia to the retry queue
  Future<void> enqueue({
    required String category,
    required String question,
    required List<String> words,
    required List<String> correctAnswers,
    String? userId,
    String? toUserId,
    String operation = 'save', // 'save', 'share'
  }) async {
    final queuedTrivia = _QueuedTrivia(
      category: category,
      question: question,
      words: words,
      correctAnswers: correctAnswers,
      userId: userId,
      toUserId: toUserId,
      operation: operation,
      attempts: 0,
      firstAttempt: DateTime.now(),
    );

    _queue.add(queuedTrivia);
    await _persistQueue();
    _scheduleRetry();
  }

  /// Process the retry queue
  ///
  /// [saveFunction] - Function to call for save operations
  /// [shareFunction] - Function to call for share operations
  Future<void> processQueue({
    required Future<void> Function(String userId, String category,
            String question, List<String> words, List<String> correctAnswers,)
        saveFunction,
    required Future<void> Function(
            String fromUserId,
            String toUserId,
            String category,
            String question,
            List<String> words,
            List<String> correctAnswers,)
        shareFunction,
    String? userId,
  }) async {
    if (_isProcessing || _queue.isEmpty || userId == null) return;

    _isProcessing = true;

    try {
      final now = DateTime.now();
      final itemsToRetry = <_QueuedTrivia>[];

      // Collect items that need retrying
      for (final queuedTrivia in _queue) {
        // Remove old entries
        if (now.difference(queuedTrivia.firstAttempt) > _maxRetryAge) {
          LoggerService.warning(
            'Removing old queued trivia from retry queue',
          );
          continue;
        }

        // Skip if max retries reached
        if (queuedTrivia.attempts >= _maxRetries) {
          LoggerService.warning(
            'Max retries reached for trivia: ${queuedTrivia.category}',
          );
          continue;
        }

        itemsToRetry.add(queuedTrivia);
      }

      // Remove processed/expired items
      _queue.removeWhere((q) => !itemsToRetry.contains(q));

      // Retry each item
      for (final queuedTrivia in itemsToRetry) {
        try {
          if (queuedTrivia.operation == 'save') {
            await saveFunction(
              queuedTrivia.userId ?? userId,
              queuedTrivia.category,
              queuedTrivia.question,
              queuedTrivia.words,
              queuedTrivia.correctAnswers,
            );
          } else if (queuedTrivia.operation == 'share' &&
              queuedTrivia.toUserId != null) {
            await shareFunction(
              queuedTrivia.userId ?? userId,
              queuedTrivia.toUserId!,
              queuedTrivia.category,
              queuedTrivia.question,
              queuedTrivia.words,
              queuedTrivia.correctAnswers,
            );
          }

          // Success - remove from queue
          _queue.remove(queuedTrivia);
          LoggerService.info(
            'Successfully saved queued trivia: ${queuedTrivia.category}',
          );
        } catch (e) {
          // Failed - increment attempts
          queuedTrivia.attempts++;
          LoggerService.warning(
            'Retry failed for trivia ${queuedTrivia.category} (attempt ${queuedTrivia.attempts}/$_maxRetries);',
            error: e,
          );
        }
      }

      await _persistQueue();
    } finally {
      _isProcessing = false;
    }
  }

  /// Schedule next retry
  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(_retryDelay, () {
      // Retry will be triggered by service when it calls processQueue
    });
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
            _queue.add(_QueuedTrivia.fromJson(map));
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

/// Internal class for queued trivia
class _QueuedTrivia {

  _QueuedTrivia({
    required this.category,
    required this.question,
    required this.words,
    required this.correctAnswers,
    this.userId,
    this.toUserId,
    required this.operation,
    required this.attempts,
    required this.firstAttempt,
  });

  factory _QueuedTrivia.fromJson(Map<String, dynamic> json) {
    return _QueuedTrivia(
      category: json['category'] as String,
      question: json['question'] as String,
      words: List<String>.from(json['words'] as List),
      correctAnswers: List<String>.from(json['correctAnswers'] as List),
      userId: json['userId'] as String?,
      toUserId: json['toUserId'] as String?,
      operation: json['operation'] as String? ?? 'save',
      attempts: json['attempts'] as int,
      firstAttempt: DateTime.parse(json['firstAttempt'] as String),
    );
  }
  final String category;
  final String question;
  final List<String> words;
  final List<String> correctAnswers;
  final String? userId;
  final String? toUserId;
  final String operation;
  int attempts;
  final DateTime firstAttempt;

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'question': question,
      'words': words,
      'correctAnswers': correctAnswers,
      'userId': userId,
      'toUserId': toUserId,
      'operation': operation,
      'attempts': attempts,
      'firstAttempt': firstAttempt.toIso8601String(),
    };
  }
}
















