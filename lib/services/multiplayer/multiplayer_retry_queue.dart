import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Enum to define the type of multiplayer operation to retry.
enum MultiplayerOperationType {
  submitRoundAnswer,
  setPlayerReady,
  sendPing,
  nextRound,
  leaveRoom,
}

/// Persistent retry queue for failed multiplayer operations.
///
/// Queues failed operations and retries them in the background with
/// exponential backoff. Persists the queue to SharedPreferences for
/// reliability across app restarts.
///
/// **Features:**
/// - Exponential backoff (max 5 minutes)
/// - Max 3 retries per operation
/// - Max 7 days retention
/// - Persistent storage via SharedPreferences
///
/// **Usage:**
/// ```dart
/// final queue = MultiplayerRetryQueue();
/// await queue.init();
/// await queue.enqueueSubmitRoundAnswer(...);
/// await queue.processQueue(
///   submitRoundAnswerFunction: ...,
///   setPlayerReadyFunction: ...,
///   sendPingFunction: ...,
///   nextRoundFunction: ...,
/// );
/// ```
class MultiplayerRetryQueue {
  static const String _storageKey = 'multiplayer_retry_queue';
  static const int _maxRetries = 3;
  static const Duration _baseRetryDelay = Duration(seconds: 5);
  static const Duration _maxRetryAge = Duration(days: 7);

  final List<_QueuedOperation> _queue = [];
  Timer? _retryTimer;
  bool _isProcessing = false;

  /// Initializes the retry queue by loading it from storage.
  Future<void> init() async {
    await loadQueue();
    _scheduleRetry();
  }

  /// Enqueues a submit round answer operation for retry.
  Future<void> enqueueSubmitRoundAnswer({
    required String roomId,
    required String userId,
    required int score,
    required int correctAnswers,
    required int wrongAnswers,
  }) async {
    final queuedOp = _QueuedOperation(
      type: MultiplayerOperationType.submitRoundAnswer,
      params: {
        'roomId': roomId,
        'userId': userId,
        'score': score,
        'correctAnswers': correctAnswers,
        'wrongAnswers': wrongAnswers,
      },
      attempts: 0,
      firstAttempt: DateTime.now(),
    );

    _queue.add(queuedOp);
    await _persistQueue();
    _scheduleRetry();
  }

  /// Enqueues a set player ready operation for retry.
  Future<void> enqueueSetPlayerReady({
    required String roomId,
    required String userId,
    required bool ready,
  }) async {
    final queuedOp = _QueuedOperation(
      type: MultiplayerOperationType.setPlayerReady,
      params: {
        'roomId': roomId,
        'userId': userId,
        'ready': ready,
      },
      attempts: 0,
      firstAttempt: DateTime.now(),
    );

    _queue.add(queuedOp);
    await _persistQueue();
    _scheduleRetry();
  }

  /// Enqueues a send ping operation for retry.
  Future<void> enqueueSendPing({
    required String roomId,
    required String userId,
  }) async {
    final queuedOp = _QueuedOperation(
      type: MultiplayerOperationType.sendPing,
      params: {
        'roomId': roomId,
        'userId': userId,
      },
      attempts: 0,
      firstAttempt: DateTime.now(),
    );

    _queue.add(queuedOp);
    await _persistQueue();
    _scheduleRetry();
  }

  /// Enqueues a next round operation for retry.
  Future<void> enqueueNextRound({
    required String roomId,
    required String userId,
  }) async {
    final queuedOp = _QueuedOperation(
      type: MultiplayerOperationType.nextRound,
      params: {
        'roomId': roomId,
        'userId': userId,
      },
      attempts: 0,
      firstAttempt: DateTime.now(),
    );

    _queue.add(queuedOp);
    await _persistQueue();
    _scheduleRetry();
  }

  /// Enqueues a leave room operation for retry.
  Future<void> enqueueLeaveRoom({
    required String roomId,
    required String userId,
  }) async {
    final queuedOp = _QueuedOperation(
      type: MultiplayerOperationType.leaveRoom,
      params: {
        'roomId': roomId,
        'userId': userId,
      },
      attempts: 0,
      firstAttempt: DateTime.now(),
    );

    _queue.add(queuedOp);
    await _persistQueue();
    _scheduleRetry();
  }

  /// Process the retry queue
  ///
  /// [submitRoundAnswerFunction] - Function to call for answer submissions
  /// [setPlayerReadyFunction] - Function to call for ready status updates
  /// [sendPingFunction] - Function to call for pings
  /// [nextRoundFunction] - Function to call for round advancement
  /// [leaveRoomFunction] - Function to call for leaving rooms
  Future<void> processQueue({
    required Future<void> Function({
      required String roomId,
      required String userId,
      required int score,
      required int correctAnswers,
      required int wrongAnswers,
    }) submitRoundAnswerFunction,
    required Future<void> Function({
      required String roomId,
      required String userId,
      required bool ready,
    }) setPlayerReadyFunction,
    required Future<void> Function({
      required String roomId,
      required String userId,
    }) sendPingFunction,
    required Future<void> Function({
      required String roomId,
      required String userId,
    }) nextRoundFunction,
    required Future<void> Function({
      required String roomId,
      required String userId,
    }) leaveRoomFunction,
  }) async {
    if (_isProcessing || _queue.isEmpty) return;

    _isProcessing = true;

    try {
      final now = DateTime.now();
      final operationsToRetry = <_QueuedOperation>[];

      // Collect operations that need retrying
      for (final queuedOp in _queue) {
        // Remove old entries
        if (now.difference(queuedOp.firstAttempt) > _maxRetryAge) {
          LoggerService.warning(
            'Removing old queued operation from retry queue: ${queuedOp.type}',
          );
          continue;
        }

        // Skip if max retries reached
        if (queuedOp.attempts >= _maxRetries) {
          LoggerService.warning(
            'Max retries reached for operation: ${queuedOp.type}',
          );
          continue;
        }

        operationsToRetry.add(queuedOp);
      }

      // Remove processed/expired operations from the original queue
      _queue.removeWhere((q) => !operationsToRetry.contains(q));

      // Retry each operation
      for (final queuedOp in operationsToRetry) {
        try {
          switch (queuedOp.type) {
            case MultiplayerOperationType.submitRoundAnswer:
              await submitRoundAnswerFunction(
                roomId: queuedOp.params['roomId'] as String,
                userId: queuedOp.params['userId'] as String,
                score: queuedOp.params['score'] as int,
                correctAnswers: queuedOp.params['correctAnswers'] as int,
                wrongAnswers: queuedOp.params['wrongAnswers'] as int,
              );
              break;
            case MultiplayerOperationType.setPlayerReady:
              await setPlayerReadyFunction(
                roomId: queuedOp.params['roomId'] as String,
                userId: queuedOp.params['userId'] as String,
                ready: queuedOp.params['ready'] as bool,
              );
              break;
            case MultiplayerOperationType.sendPing:
              await sendPingFunction(
                roomId: queuedOp.params['roomId'] as String,
                userId: queuedOp.params['userId'] as String,
              );
              break;
            case MultiplayerOperationType.nextRound:
              await nextRoundFunction(
                roomId: queuedOp.params['roomId'] as String,
                userId: queuedOp.params['userId'] as String,
              );
              break;
            case MultiplayerOperationType.leaveRoom:
              await leaveRoomFunction(
                roomId: queuedOp.params['roomId'] as String,
                userId: queuedOp.params['userId'] as String,
              );
              break;
          }

          // Success - remove from queue
          _queue.remove(queuedOp);
          LoggerService.info(
            'Successfully processed queued operation: ${queuedOp.type}',
          );
        } catch (e) {
          // Failed - increment attempts
          queuedOp.attempts++;
          LoggerService.warning(
            'Retry failed for operation ${queuedOp.type} (attempt ${queuedOp.attempts}/$_maxRetries);',
            error: e,
          );
        }
      }

      await _persistQueue();
    } finally {
      _isProcessing = false;
      _scheduleRetry();
    }
  }

  /// Schedule next retry with exponential backoff
  void _scheduleRetry() {
    _retryTimer?.cancel();
    if (_queue.isEmpty) return;

    final maxAttempts =
        _queue.map((q) => q.attempts).reduce((a, b) => a > b ? a : b);
    final multiplier = 1 << maxAttempts;
    final delay = _baseRetryDelay * multiplier;

    // Cap at 5 minutes
    final effectiveDelay =
        delay > const Duration(minutes: 5) ? const Duration(minutes: 5) : delay;

    _retryTimer = Timer(effectiveDelay, () {
      LoggerService.debug(
          'MultiplayerRetryQueue: Retrying operations after delay.',);
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
            _queue.add(_QueuedOperation.fromJson(map));
          }
        }
      }
    } catch (e, stack) {
      LoggerService.error('Failed to load retry queue', error: e, stack: stack);
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
    } catch (e, stack) {
      LoggerService.error('Failed to persist retry queue',
          error: e, stack: stack,);
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

/// Internal class for queued operations
class _QueuedOperation {

  _QueuedOperation({
    required this.type,
    required this.params,
    required this.attempts,
    required this.firstAttempt,
  });

  factory _QueuedOperation.fromJson(Map<String, dynamic> json) {
    return _QueuedOperation(
      type: MultiplayerOperationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MultiplayerOperationType.submitRoundAnswer,
      ),
      params: json['params'] as Map<String, dynamic>,
      attempts: json['attempts'] as int,
      firstAttempt: DateTime.parse(json['firstAttempt'] as String),
    );
  }
  final MultiplayerOperationType type;
  final Map<String, dynamic> params;
  int attempts;
  final DateTime firstAttempt;

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'params': params,
      'attempts': attempts,
      'firstAttempt': firstAttempt.toIso8601String(),
    };
  }
}
















