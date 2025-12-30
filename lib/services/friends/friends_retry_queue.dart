import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Persistent retry queue for failed friend operations
///
/// Queues failed operations (friend requests, invitations, reports) and
/// retries them in the background with exponential backoff. Persists queue
/// to SharedPreferences for reliability across app restarts.
///
/// **Features:**
/// - Exponential backoff (max 5 minutes)
/// - Max 3 retries per operation
/// - Max 7 days retention
/// - Persistent storage via SharedPreferences
///
/// **Usage:**
/// ```dart
/// final queue = FriendsRetryQueue();
/// await queue.loadQueue();
/// await queue.enqueueFriendRequest(...);
/// await queue.processQueue(
///   friendRequestFunction: ...,
///   invitationFunction: ...,
///   reportFunction: ...,
/// );
/// ```
class FriendsRetryQueue {
  static const String _storageKey = 'friends_retry_queue';
  static const int _maxRetries = 3;
  static const Duration _baseRetryDelay = Duration(seconds: 5);
  static const Duration _maxRetryAge = Duration(days: 7);

  final List<_QueuedOperation> _queue = [];
  Timer? _retryTimer;
  bool _isProcessing = false;

  /// Add a friend request to the retry queue
  Future<void> enqueueFriendRequest({
    required String fromUserId,
    required String toUserId,
    String? fromDisplayName,
    String? fromEmail,
    String? toDisplayName,
    String? toEmail,
  }) async {
    final queuedOp = _QueuedOperation(
      type: _OperationType.friendRequest,
      data: {
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'fromDisplayName': fromDisplayName,
        'fromEmail': fromEmail,
        'toDisplayName': toDisplayName,
        'toEmail': toEmail,
      },
      attempts: 0,
      firstAttempt: DateTime.now(),
    );

    _queue.add(queuedOp);
    await _persistQueue();
    _scheduleRetry();
  }

  /// Add an invitation to the retry queue
  Future<void> enqueueInvitation({
    required String fromUserId,
    required String toEmail,
  }) async {
    final queuedOp = _QueuedOperation(
      type: _OperationType.invitation,
      data: {
        'fromUserId': fromUserId,
        'toEmail': toEmail,
      },
      attempts: 0,
      firstAttempt: DateTime.now(),
    );

    _queue.add(queuedOp);
    await _persistQueue();
    _scheduleRetry();
  }

  /// Add a report to the retry queue
  Future<void> enqueueReport({
    required String reporterUserId,
    required String reportedUserId,
    required String reason,
  }) async {
    final queuedOp = _QueuedOperation(
      type: _OperationType.report,
      data: {
        'reporterUserId': reporterUserId,
        'reportedUserId': reportedUserId,
        'reason': reason,
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
  /// [friendRequestFunction] - Function to call for friend requests
  /// [invitationFunction] - Function to call for invitations
  /// [reportFunction] - Function to call for reports
  Future<void> processQueue({
    required Future<void> Function({
      required String fromUserId,
      required String toUserId,
      String? fromDisplayName,
      String? fromEmail,
      String? toDisplayName,
      String? toEmail,
    }) friendRequestFunction,
    required Future<void> Function({
      required String fromUserId,
      required String toEmail,
    }) invitationFunction,
    required Future<void> Function({
      required String reporterUserId,
      required String reportedUserId,
      required String reason,
    }) reportFunction,
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

      // Remove processed/expired operations
      _queue.removeWhere((q) => !operationsToRetry.contains(q));

      // Retry each operation
      for (final queuedOp in operationsToRetry) {
        try {
          switch (queuedOp.type) {
            case _OperationType.friendRequest:
              await friendRequestFunction(
                fromUserId: queuedOp.data['fromUserId'] as String,
                toUserId: queuedOp.data['toUserId'] as String,
                fromDisplayName: queuedOp.data['fromDisplayName'] as String?,
                fromEmail: queuedOp.data['fromEmail'] as String?,
                toDisplayName: queuedOp.data['toDisplayName'] as String?,
                toEmail: queuedOp.data['toEmail'] as String?,
              );
              break;
            case _OperationType.invitation:
              await invitationFunction(
                fromUserId: queuedOp.data['fromUserId'] as String,
                toEmail: queuedOp.data['toEmail'] as String,
              );
              break;
            case _OperationType.report:
              await reportFunction(
                reporterUserId: queuedOp.data['reporterUserId'] as String,
                reportedUserId: queuedOp.data['reportedUserId'] as String,
                reason: queuedOp.data['reason'] as String,
              );
              break;
          }

          // Success - remove from queue
          _queue.remove(queuedOp);
          LoggerService.info(
            'Successfully retried queued operation: ${queuedOp.type}',
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
            _queue.add(_QueuedOperation.fromJson(map));
          }
        }
      }
    } catch (e) {
      LoggerService.error('Failed to load friends retry queue', error: e);
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
      LoggerService.error('Failed to persist friends retry queue', error: e);
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

/// Internal enum for operation types
enum _OperationType {
  friendRequest,
  invitation,
  report;

  String get name {
    switch (this) {
      case _OperationType.friendRequest:
        return 'friendRequest';
      case _OperationType.invitation:
        return 'invitation';
      case _OperationType.report:
        return 'report';
    }
  }

  static _OperationType fromString(String name) {
    switch (name) {
      case 'friendRequest':
        return _OperationType.friendRequest;
      case 'invitation':
        return _OperationType.invitation;
      case 'report':
        return _OperationType.report;
      default:
        throw ArgumentError('Unknown operation type: $name');
    }
  }
}

/// Internal class for queued operations
class _QueuedOperation {

  _QueuedOperation({
    required this.type,
    required this.data,
    required this.attempts,
    required this.firstAttempt,
  });

  factory _QueuedOperation.fromJson(Map<String, dynamic> json) {
    return _QueuedOperation(
      type: _OperationType.fromString(json['type'] as String),
      data: Map<String, dynamic>.from(json['data'] as Map),
      attempts: json['attempts'] as int,
      firstAttempt: DateTime.parse(json['firstAttempt'] as String),
    );
  }
  final _OperationType type;
  final Map<String, dynamic> data;
  int attempts;
  final DateTime firstAttempt;

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'data': data,
      'attempts': attempts,
      'firstAttempt': firstAttempt.toIso8601String(),
    };
  }
}
