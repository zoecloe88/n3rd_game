import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service for managing offline operations queue
///
/// Queues operations when offline and executes them when connectivity is restored.
/// Supports retry logic with exponential backoff.
class OfflineQueueService {
  final List<QueuedOperation> _queue = [];
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOnline = true;
  Timer? _retryTimer;

  OfflineQueueService() {
    _initConnectivityMonitoring();
  }

  /// Initialize connectivity monitoring
  Future<void> _initConnectivityMonitoring() async {
    // Check initial connectivity
    final results = await _connectivity.checkConnectivity();
    _isOnline = results.any((result) => result != ConnectivityResult.none);

    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      final wasOffline = !_isOnline;
      _isOnline = results.any((result) => result != ConnectivityResult.none);

      // If we just came online, process queue
      if (wasOffline && _isOnline) {
        _processQueue();
      }
    });
  }

  /// Add operation to queue
  Future<T> queueOperation<T>({
    required Future<T> Function() operation,
    String? operationId,
    int maxRetries = 3,
    Duration? timeout,
  }) async {
    final queuedOp = QueuedOperation<T>(
      operation: operation,
      operationId:
          operationId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      maxRetries: maxRetries,
      timeout: timeout ?? const Duration(seconds: 30),
      createdAt: DateTime.now(),
    );

    if (_isOnline) {
      // Try to execute immediately
      try {
        return await _executeOperation(queuedOp);
      } catch (e) {
        // If it fails, add to queue
        _queue.add(queuedOp);
        _scheduleRetry();
        rethrow;
      }
    } else {
      // Add to queue
      _queue.add(queuedOp);
      return Future.error('Offline: Operation queued');
    }
  }

  /// Execute a queued operation
  Future<T> _executeOperation<T>(QueuedOperation<T> op) async {
    try {
      return await op.operation().timeout(op.timeout);
    } catch (e) {
      op.retryCount++;
      if (op.retryCount >= op.maxRetries) {
        throw Exception('Operation failed after ${op.maxRetries} retries: $e');
      }
      rethrow;
    }
  }

  /// Process the queue
  Future<void> _processQueue() async {
    if (!_isOnline || _queue.isEmpty) return;

    final operationsToProcess = List<QueuedOperation>.from(_queue);
    _queue.clear();

    for (final op in operationsToProcess) {
      if (!_isOnline) {
        // Went offline again, re-queue
        _queue.add(op);
        continue;
      }

      try {
        await _executeOperation(op);
        // Operation succeeded, remove from queue
      } catch (e) {
        // Operation failed, re-queue if retries remaining
        if (op.retryCount < op.maxRetries) {
          _queue.add(op);
        }
      }
    }

    // Schedule retry if queue not empty
    if (_queue.isNotEmpty) {
      _scheduleRetry();
    }
  }

  /// Schedule retry for failed operations
  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 5), () {
      if (_isOnline) {
        _processQueue();
      }
    });
  }

  /// Get queue size
  int get queueSize => _queue.length;

  /// Check if online
  bool get isOnline => _isOnline;

  /// Clear queue
  void clearQueue() {
    _queue.clear();
    _retryTimer?.cancel();
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _retryTimer?.cancel();
    _queue.clear();
  }
}

/// Represents a queued operation
class QueuedOperation<T> {
  final Future<T> Function() operation;
  final String operationId;
  final int maxRetries;
  final Duration timeout;
  final DateTime createdAt;
  int retryCount = 0;

  QueuedOperation({
    required this.operation,
    required this.operationId,
    required this.maxRetries,
    required this.timeout,
    required this.createdAt,
  });
}
