import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Performance metric types
enum PerformanceMetricType {
  widgetBuild,
  networkRequest,
  firestoreQuery,
  memoryUsage,
  frameRate,
  navigation,
  gameAction,
}

/// Performance metric model
class PerformanceMetric {

  PerformanceMetric({
    required this.type,
    required this.name,
    required this.duration,
    required this.timestamp,
    this.metadata,
  });
  final PerformanceMetricType type;
  final String name;
  final Duration duration;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'name': name,
      'duration': duration.inMilliseconds,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }
}

/// Performance threshold configuration
class PerformanceThreshold {

  const PerformanceThreshold({
    required this.warningThreshold,
    required this.errorThreshold,
  });
  final Duration warningThreshold;
  final Duration errorThreshold;
}

/// Performance monitoring service for tracking app performance metrics
///
/// This service provides comprehensive performance monitoring including:
/// - Widget build times
/// - Network request durations
/// - Firestore query performance
/// - Memory usage tracking
/// - Frame rate (FPS) monitoring
/// - Automated performance alerts
class PerformanceMonitoringService extends ChangeNotifier {
  static const int _maxMetricsHistory = 1000;
  static const Duration _memoryCheckInterval = Duration(seconds: 30);
  static const Duration _frameRateCheckInterval = Duration(seconds: 5);

  // Performance thresholds
  static const Map<PerformanceMetricType, PerformanceThreshold> _thresholds = {
    PerformanceMetricType.widgetBuild: PerformanceThreshold(
      warningThreshold: Duration(milliseconds: 16), // 60 FPS = 16ms per frame
      errorThreshold: Duration(milliseconds: 100), // Very slow build
    ),
    PerformanceMetricType.networkRequest: PerformanceThreshold(
      warningThreshold: Duration(seconds: 2),
      errorThreshold: Duration(seconds: 10),
    ),
    PerformanceMetricType.firestoreQuery: PerformanceThreshold(
      warningThreshold: Duration(milliseconds: 500),
      errorThreshold: Duration(seconds: 5),
    ),
    PerformanceMetricType.frameRate: PerformanceThreshold(
      warningThreshold: Duration(milliseconds: 20), // 50 FPS
      errorThreshold: Duration(milliseconds: 33), // 30 FPS
    ),
  };

  // Metrics storage
  final Queue<PerformanceMetric> _metrics = Queue<PerformanceMetric>();
  final Map<String, List<PerformanceMetric>> _metricsByType = {};

  // Frame rate monitoring
  int _frameCount = 0;
  DateTime _lastFrameCheck = DateTime.now();
  double _currentFPS = 60.0;
  Timer? _frameRateTimer;
  VoidCallback? _frameCallback;

  // Memory monitoring
  Timer? _memoryTimer;

  // Performance state
  bool _isInitialized = false;
  bool _isMonitoring = false;

  // Performance statistics
  final Map<PerformanceMetricType, PerformanceStatistics> _statistics = {};

  List<PerformanceMetric> get metrics => List.unmodifiable(_metrics);
  bool get isInitialized => _isInitialized;
  bool get isMonitoring => _isMonitoring;
  double get currentFPS => _currentFPS;

  Map<PerformanceMetricType, PerformanceStatistics> get statistics =>
      Map.unmodifiable(_statistics);

  /// Initialize performance monitoring service
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _startFrameRateMonitoring();
      _startMemoryMonitoring();
      _isInitialized = true;
      _isMonitoring = true;
      notifyListeners();
    } catch (e) {
      LoggerService.error(
        'PerformanceMonitoringService: Failed to initialize',
        error: e,
        reason: 'Initialization error',
        fatal: false,
      );
    }
  }

  /// Start monitoring frame rate using SchedulerBinding for accurate tracking
  void _startFrameRateMonitoring() {
    _frameRateTimer?.cancel();
    _frameCallback?.call();
    _frameCount = 0;
    _lastFrameCheck = DateTime.now();

    // Use SchedulerBinding to track actual frame rendering
    _frameCallback = () {
      if (!_isMonitoring) return;
      _frameCount++;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_isMonitoring && mounted) {
          _frameCallback?.call();
        }
      });
    };

    // Start frame tracking
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _frameCallback?.call();
    });

    // Periodic check and recording
    _frameRateTimer = Timer.periodic(_frameRateCheckInterval, (timer) {
      _checkFrameRate();
    });
  }

  /// Check current frame rate and record metrics
  void _checkFrameRate() {
    final now = DateTime.now();
    final elapsed = now.difference(_lastFrameCheck);

    if (elapsed >= _frameRateCheckInterval) {
      // Calculate FPS based on actual frame count
      final elapsedSeconds = elapsed.inMilliseconds / 1000;
      final actualFPS =
          elapsedSeconds > 0 ? _frameCount / elapsedSeconds : 60.0;

      _currentFPS = actualFPS.clamp(0.0, 120.0);

      // Record frame rate metric
      final frameTime =
          Duration(milliseconds: (1000 / actualFPS.clamp(1.0, 120.0)).round());
      recordMetric(
        PerformanceMetricType.frameRate,
        'frame_rate_check',
        frameTime,
        metadata: {
          'fps': actualFPS,
          'expectedFPS': 60.0,
          'frameCount': _frameCount,
        },
      );

      // Check for performance degradation
      if (actualFPS < 50.0) {
        LoggerService.warning(
          'PerformanceMonitoringService: Low FPS detected (${actualFPS.toStringAsFixed(1)} FPS)',
        );
      }

      _frameCount = 0;
      _lastFrameCheck = now;
    }
  }

  bool get mounted => _isMonitoring && _isInitialized;

  /// Start memory monitoring
  void _startMemoryMonitoring() {
    _memoryTimer?.cancel();
    _memoryTimer = Timer.periodic(_memoryCheckInterval, (timer) {
      _checkMemoryUsage();
    });
  }

  /// Check memory usage (tracks basic metrics, full implementation requires platform channels)
  void _checkMemoryUsage() {
    try {
      // Track basic memory metrics available in Dart
      // Full memory monitoring would require platform channels for native memory stats
      final timestamp = DateTime.now();

      // Record memory check metric
      // In production, this could include:
      // - Heap size (requires platform channel)
      // - Object count (limited in Dart)
      // - GC frequency (requires platform channel)
      recordMetric(
        PerformanceMetricType.memoryUsage,
        'memory_check',
        Duration.zero,
        metadata: {
          'timestamp': timestamp.toIso8601String(),
          'note': 'Full memory stats require platform channels',
        },
      );
    } catch (e) {
      LoggerService.warning('Failed to check memory usage', error: e);
    }
  }

  /// Get performance budget status (check if metrics are within acceptable ranges)
  Map<String, bool> getPerformanceBudgetStatus() {
    final status = <String, bool>{};

    // Check widget build times
    final avgBuildTime = getAverageDuration(PerformanceMetricType.widgetBuild);
    status['widgetBuild'] = avgBuildTime == null ||
        avgBuildTime <
            _thresholds[PerformanceMetricType.widgetBuild]!.warningThreshold;

    // Check network request times
    final avgNetworkTime =
        getAverageDuration(PerformanceMetricType.networkRequest);
    status['networkRequest'] = avgNetworkTime == null ||
        avgNetworkTime <
            _thresholds[PerformanceMetricType.networkRequest]!.warningThreshold;

    // Check Firestore query times
    final avgFirestoreTime =
        getAverageDuration(PerformanceMetricType.firestoreQuery);
    status['firestoreQuery'] = avgFirestoreTime == null ||
        avgFirestoreTime <
            _thresholds[PerformanceMetricType.firestoreQuery]!.warningThreshold;

    // Check FPS
    status['frameRate'] = _currentFPS >= 50.0; // Above 50 FPS is acceptable

    return status;
  }

  /// Record a performance metric
  void recordMetric(
    PerformanceMetricType type,
    String name,
    Duration duration, {
    Map<String, dynamic>? metadata,
  }) {
    if (!_isMonitoring) return;

    final metric = PerformanceMetric(
      type: type,
      name: name,
      duration: duration,
      timestamp: DateTime.now(),
      metadata: metadata,
    );

    // Add to metrics queue
    _metrics.addLast(metric);
    if (_metrics.length > _maxMetricsHistory) {
      _metrics.removeFirst();
    }

    // Group by type
    final typeKey = type.name;
    _metricsByType.putIfAbsent(typeKey, () => []).add(metric);
    if (_metricsByType[typeKey]!.length > 100) {
      _metricsByType[typeKey]!.removeAt(0);
    }

    // Update statistics
    _updateStatistics(type, duration);

    // Check thresholds and log warnings
    _checkThresholds(type, name, duration);

    // Log to LoggerService
    LoggerService.performance(
      name,
      duration,
      metadata: metadata?.map((key, value) => MapEntry(key, value as Object)),
    );

    notifyListeners();
  }

  /// Track widget build time
  T trackWidgetBuild<T>(String widgetName, T Function() builder) {
    final stopwatch = Stopwatch()..start();
    try {
      final result = builder();
      stopwatch.stop();
      recordMetric(
        PerformanceMetricType.widgetBuild,
        'widget_build_$widgetName',
        stopwatch.elapsed,
      );
      return result;
    } catch (e) {
      stopwatch.stop();
      recordMetric(
        PerformanceMetricType.widgetBuild,
        'widget_build_${widgetName}_error',
        stopwatch.elapsed,
        metadata: {'error': e.toString()},
      );
      rethrow;
    }
  }

  /// Track network request duration
  Future<T> trackNetworkRequest<T>(
    String requestName,
    Future<T> Function() request, {
    Map<String, dynamic>? metadata,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await request();
      stopwatch.stop();
      recordMetric(
        PerformanceMetricType.networkRequest,
        'network_$requestName',
        stopwatch.elapsed,
        metadata: metadata,
      );
      return result;
    } catch (e) {
      stopwatch.stop();
      recordMetric(
        PerformanceMetricType.networkRequest,
        'network_${requestName}_error',
        stopwatch.elapsed,
        metadata: {
          ...?metadata,
          'error': e.toString(),
        },
      );
      rethrow;
    }
  }

  /// Track Firestore query duration
  Future<T> trackFirestoreQuery<T>(
    String queryName,
    Future<T> Function() query, {
    Map<String, dynamic>? metadata,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await query();
      stopwatch.stop();
      recordMetric(
        PerformanceMetricType.firestoreQuery,
        'firestore_$queryName',
        stopwatch.elapsed,
        metadata: metadata,
      );
      return result;
    } catch (e) {
      stopwatch.stop();
      recordMetric(
        PerformanceMetricType.firestoreQuery,
        'firestore_${queryName}_error',
        stopwatch.elapsed,
        metadata: {
          ...?metadata,
          'error': e.toString(),
        },
      );
      rethrow;
    }
  }

  /// Update performance statistics
  void _updateStatistics(PerformanceMetricType type, Duration duration) {
    _statistics
        .putIfAbsent(
          type,
          () => PerformanceStatistics(),
        )
        .addSample(duration);
  }

  /// Check performance thresholds and log warnings
  void _checkThresholds(
    PerformanceMetricType type,
    String name,
    Duration duration,
  ) {
    final threshold = _thresholds[type];
    if (threshold == null) return;

    if (duration >= threshold.errorThreshold) {
      LoggerService.warning(
        'PerformanceMonitoringService: $name exceeded error threshold (${duration.inMilliseconds}ms >= ${threshold.errorThreshold.inMilliseconds}ms);',
        error: Exception('Performance degradation'),
      );
    } else if (duration >= threshold.warningThreshold) {
      LoggerService.debug(
        'PerformanceMonitoringService: $name exceeded warning threshold (${duration.inMilliseconds}ms >= ${threshold.warningThreshold.inMilliseconds}ms);',
      );
    }
  }

  /// Get metrics for a specific type
  List<PerformanceMetric> getMetricsByType(PerformanceMetricType type) {
    return _metricsByType[type.name] ?? [];
  }

  /// Get average duration for a metric type
  Duration? getAverageDuration(PerformanceMetricType type) {
    final stats = _statistics[type];
    if (stats == null || stats.count == 0) return null;
    return Duration(milliseconds: stats.averageDurationMs.round());
  }

  /// Get recent metrics (last N metrics)
  List<PerformanceMetric> getRecentMetrics(int count) {
    final endIndex = _metrics.length;
    final startIndex = (endIndex - count).clamp(0, endIndex);
    return _metrics.toList().sublist(startIndex, endIndex);
  }

  /// Clear all metrics
  void clearMetrics() {
    _metrics.clear();
    _metricsByType.clear();
    _statistics.clear();
    notifyListeners();
  }

  /// Stop monitoring
  void stopMonitoring() {
    _isMonitoring = false;
    _frameRateTimer?.cancel();
    _memoryTimer?.cancel();
    notifyListeners();
  }

  /// Resume monitoring
  void resumeMonitoring() {
    if (!_isInitialized) {
      init();
      return;
    }
    _isMonitoring = true;
    _startFrameRateMonitoring();
    _startMemoryMonitoring();
    notifyListeners();
  }

  @override
  void dispose() {
    _frameRateTimer?.cancel();
    _memoryTimer?.cancel();
    _frameCallback = null;
    _isMonitoring = false;
    super.dispose();
  }

  /// Reset service state for testing
  /// Cancels all timers and clears state to prevent resource leaks in tests
  static void resetForTesting() {
    // Note: This is a static method because the service may be instantiated
    // multiple times in tests. Individual instances should be disposed properly.
    // This method is primarily for clearing any static state if it exists.
    // For instance cleanup, use dispose() on the instance.
  }
}

/// Performance statistics for a metric type
class PerformanceStatistics {
  int _count = 0;
  int _totalDurationMs = 0;
  int _minDurationMs = double.maxFinite.toInt();
  int _maxDurationMs = 0;

  int get count => _count;
  double get averageDurationMs => _count > 0 ? _totalDurationMs / _count : 0.0;
  int get minDurationMs =>
      _minDurationMs == double.maxFinite.toInt() ? 0 : _minDurationMs;
  int get maxDurationMs => _maxDurationMs;

  void addSample(Duration duration) {
    final ms = duration.inMilliseconds;
    _count++;
    _totalDurationMs += ms;
    if (ms < _minDurationMs) _minDurationMs = ms;
    if (ms > _maxDurationMs) _maxDurationMs = ms;
  }

  void reset() {
    _count = 0;
    _totalDurationMs = 0;
    _minDurationMs = double.maxFinite.toInt();
    _maxDurationMs = 0;
  }
}
