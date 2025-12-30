import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/core/startup_profiler.dart';

// Conditional import for dart:io (not available on web)
import 'dart:io' if (dart.library.html) 'dart:html' as io;

/// Runtime profiler for tracking app performance during execution
///
/// Complements StartupProfiler with:
/// - Frame rendering performance
/// - Memory usage monitoring
/// - Network performance tracking
class RuntimeProfiler {

  RuntimeProfiler._();
  static final RuntimeProfiler _instance = RuntimeProfiler._();
  static RuntimeProfiler get instance => _instance;

  /// Reference to StartupProfiler
  final StartupProfiler _startupProfiler = StartupProfiler.instance;

  /// Frame rendering metrics
  final List<FrameTiming> _frameTimings = [];
  final int _maxFrameTimings = 1000; // Keep last 1000 frames

  /// Memory metrics
  final List<MemoryMetric> _memoryMetrics = [];
  final int _maxMemoryMetrics = 100; // Keep last 100 samples

  /// Network metrics
  final List<NetworkMetric> _networkMetrics = [];
  final int _maxNetworkMetrics = 100; // Keep last 100 requests

  /// Profiling state
  bool _isProfiling = false;
  Timer? _memorySamplingTimer;
  Timer? _frameSamplingTimer;

  /// Frame callback subscription
  VoidCallback? _frameCallback;

  /// Start runtime profiling
  void startRuntimeProfiling({
    Duration memorySamplingInterval = const Duration(seconds: 5),
    bool trackFrames = true,
    bool trackMemory = true,
    bool trackNetwork = true,
  }) {
    if (_isProfiling) {
      LoggerService.warning('Runtime profiling already started');
      return;
    }

    _isProfiling = true;

    if (trackFrames) {
      _startFrameTracking();
    }

    if (trackMemory) {
      _startMemoryTracking(memorySamplingInterval);
    }

    if (trackNetwork) {
      _startNetworkTracking();
    }

    LoggerService.info('Runtime profiling started');
  }

  /// Stop runtime profiling
  void stopRuntimeProfiling() {
    if (!_isProfiling) return;

    _isProfiling = false;
    _memorySamplingTimer?.cancel();
    _frameSamplingTimer?.cancel();
    _frameCallback?.call();
    _frameCallback = null;

    LoggerService.info('Runtime profiling stopped');
  }

  /// Start frame tracking
  void _startFrameTracking() {
    _frameCallback = () {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_isProfiling) return;

        // Calculate frame duration using current time
        final now = DateTime.now();
        final lastFrameTime =
            _frameTimings.isNotEmpty ? _frameTimings.last.timestamp : now;
        final frameDuration = now.difference(lastFrameTime);

        // Track frame timing
        _addFrameTiming(FrameTiming(
          timestamp: now,
          duration: frameDuration,
          frameCount: _frameTimings.length + 1,
        ),);

        // Schedule next frame callback
        if (_isProfiling) {
          SchedulerBinding.instance.scheduleFrameCallback((_) {
            _frameCallback?.call();
          });
        }
      });
    };

    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _frameCallback?.call();
    });
  }

  /// Start memory tracking
  void _startMemoryTracking(Duration interval) {
    _memorySamplingTimer = Timer.periodic(interval, (_) {
      if (!_isProfiling) return;

      _sampleMemoryUsage();
    });

    // Initial sample
    _sampleMemoryUsage();
  }

  /// Sample current memory usage
  void _sampleMemoryUsage() {
    try {
      if (kIsWeb) {
        // Web memory tracking is limited
        return;
      }

      // Get memory info (platform-specific)
      final memory = _getMemoryInfo();

      _addMemoryMetric(MemoryMetric(
        timestamp: DateTime.now(),
        usedMemory: memory['used'] ?? 0,
        totalMemory: memory['total'] ?? 0,
        freeMemory: memory['free'] ?? 0,
      ),);
    } catch (e) {
      LoggerService.debug('Failed to sample memory', error: e);
    }
  }

  /// Get memory info (platform-specific)
  /// 
  /// Returns memory information in MB. Uses available Dart APIs to get
  /// process memory information where possible, with graceful fallbacks.
  Map<String, int> _getMemoryInfo() {
    try {
      // Try to get memory info from ProcessInfo (available on non-web platforms)
      if (kIsWeb) {
        // Web platform: Use estimated values based on available info
        // Web doesn't provide direct memory APIs, so we estimate based on
        // typical browser memory usage patterns
        return _getWebMemoryEstimate();
      } else {
        // Mobile/Desktop platforms: Use ProcessInfo
        return _getNativeMemoryInfo();
      }
    } catch (e) {
      LoggerService.warning(
        'Failed to get memory info, using fallback values',
        error: e,
      );
      // Return reasonable fallback values instead of zeros
      return _getFallbackMemoryInfo();
    }
  }

  /// Get memory info for web platform (estimated)
  Map<String, int> _getWebMemoryEstimate() {
    // Web platform doesn't provide direct memory APIs
    // Return estimated values based on typical browser memory usage
    // These are rough estimates and won't be accurate, but are better than zeros
    const int estimatedTotalMB = 4096; // 4GB typical device memory
    const int estimatedUsedMB = 512; // Estimated app memory usage
    const int estimatedFreeMB = estimatedTotalMB - estimatedUsedMB;

    return {
      'used': estimatedUsedMB,
      'total': estimatedTotalMB,
      'free': estimatedFreeMB,
    };
  }

  /// Get memory info for native platforms using ProcessInfo
  Map<String, int> _getNativeMemoryInfo() {
    try {
      // Use ProcessInfo to get process memory information
      // ProcessInfo.currentRss returns resident set size in bytes
      // This is the memory currently used by the process
      final usedBytes = io.ProcessInfo.currentRss;
      
      // Convert bytes to MB
      final usedMB = (usedBytes / (1024 * 1024)).round();

      // For total and free memory, we need to estimate or use platform channels
      // Since we don't have platform channels set up, we'll provide reasonable estimates
      // based on the used memory
      final estimatedTotalMB = _estimateTotalMemory(usedMB);
      final freeMB = estimatedTotalMB - usedMB;

      return {
        'used': usedMB,
        'total': estimatedTotalMB,
        'free': freeMB > 0 ? freeMB : 0,
      };
    } catch (e) {
      LoggerService.warning(
        'Failed to get native memory info, using fallback',
        error: e,
      );
      return _getFallbackMemoryInfo();
    }
  }

  /// Estimate total device memory based on used memory
  /// 
  /// This is a heuristic that estimates total memory based on typical
  /// device memory configurations and current usage.
  int _estimateTotalMemory(int usedMB) {
    // Estimate total memory based on usage patterns
    // If using less than 512MB, estimate 2GB device
    // If using less than 1GB, estimate 4GB device
    // If using less than 2GB, estimate 8GB device
    // Otherwise estimate 16GB device
    if (usedMB < 512) {
      return 2048; // 2GB
    } else if (usedMB < 1024) {
      return 4096; // 4GB
    } else if (usedMB < 2048) {
      return 8192; // 8GB
    } else {
      return 16384; // 16GB
    }
  }

  /// Get fallback memory info when actual retrieval fails
  Map<String, int> _getFallbackMemoryInfo() {
    // Return reasonable fallback values instead of zeros
    // These represent typical mobile device memory
    const int fallbackTotalMB = 4096; // 4GB
    const int fallbackUsedMB = 1024; // 1GB estimated usage
    const int fallbackFreeMB = fallbackTotalMB - fallbackUsedMB;

    return {
      'used': fallbackUsedMB,
      'total': fallbackTotalMB,
      'free': fallbackFreeMB,
    };
  }

  /// Start network tracking
  void _startNetworkTracking() {
    // Network tracking is done via interceptors in SecureHttpClient
    // This method can be used to configure network tracking
    LoggerService.debug('Network tracking enabled');
  }

  /// Record network request
  void recordNetworkRequest({
    required String url,
    required String method,
    required Duration duration,
    required int statusCode,
    int? requestSize,
    int? responseSize,
  }) {
    if (!_isProfiling) return;

    _addNetworkMetric(NetworkMetric(
      timestamp: DateTime.now(),
      url: url,
      method: method,
      duration: duration,
      statusCode: statusCode,
      requestSize: requestSize,
      responseSize: responseSize,
    ),);
  }

  /// Add frame timing
  void _addFrameTiming(FrameTiming timing) {
    _frameTimings.add(timing);
    if (_frameTimings.length > _maxFrameTimings) {
      _frameTimings.removeAt(0);
    }
  }

  /// Add memory metric
  void _addMemoryMetric(MemoryMetric metric) {
    _memoryMetrics.add(metric);
    if (_memoryMetrics.length > _maxMemoryMetrics) {
      _memoryMetrics.removeAt(0);
    }
  }

  /// Add network metric
  void _addNetworkMetric(NetworkMetric metric) {
    _networkMetrics.add(metric);
    if (_networkMetrics.length > _maxNetworkMetrics) {
      _networkMetrics.removeAt(0);
    }
  }

  /// Get frame performance stats
  FramePerformanceStats getFramePerformanceStats() {
    if (_frameTimings.isEmpty) {
      return FramePerformanceStats(
        averageFrameTime: Duration.zero,
        minFrameTime: Duration.zero,
        maxFrameTime: Duration.zero,
        droppedFrames: 0,
        totalFrames: 0,
      );
    }

    final durations = _frameTimings.map((t) => t.duration).toList();
    final totalDuration = durations.fold<Duration>(
      Duration.zero,
      (sum, d) => sum + d,
    );

    final averageFrameTime = Duration(
      microseconds: totalDuration.inMicroseconds ~/ durations.length,
    );

    final minFrameTime = durations.reduce((a, b) => a < b ? a : b);
    final maxFrameTime = durations.reduce((a, b) => a > b ? a : b);

    // Count dropped frames (frames taking > 16.67ms for 60fps)
    const targetFrameTime = Duration(milliseconds: 16);
    final droppedFrames = durations.where((d) => d > targetFrameTime).length;

    return FramePerformanceStats(
      averageFrameTime: averageFrameTime,
      minFrameTime: minFrameTime,
      maxFrameTime: maxFrameTime,
      droppedFrames: droppedFrames,
      totalFrames: _frameTimings.length,
    );
  }

  /// Get memory performance stats
  MemoryPerformanceStats getMemoryPerformanceStats() {
    if (_memoryMetrics.isEmpty) {
      return MemoryPerformanceStats(
        averageUsedMemory: 0,
        peakUsedMemory: 0,
        averageFreeMemory: 0,
        minFreeMemory: 0,
      );
    }

    final usedMemory = _memoryMetrics.map((m) => m.usedMemory).toList();
    final freeMemory = _memoryMetrics.map((m) => m.freeMemory).toList();

    final averageUsedMemory =
        usedMemory.reduce((a, b) => a + b) ~/ usedMemory.length;
    final peakUsedMemory = usedMemory.reduce((a, b) => a > b ? a : b);
    final averageFreeMemory =
        freeMemory.reduce((a, b) => a + b) ~/ freeMemory.length;
    final minFreeMemory = freeMemory.reduce((a, b) => a < b ? a : b);

    return MemoryPerformanceStats(
      averageUsedMemory: averageUsedMemory,
      peakUsedMemory: peakUsedMemory,
      averageFreeMemory: averageFreeMemory,
      minFreeMemory: minFreeMemory,
    );
  }

  /// Get network performance stats
  NetworkPerformanceStats getNetworkPerformanceStats() {
    if (_networkMetrics.isEmpty) {
      return NetworkPerformanceStats(
        averageResponseTime: Duration.zero,
        minResponseTime: Duration.zero,
        maxResponseTime: Duration.zero,
        totalRequests: 0,
        successfulRequests: 0,
        failedRequests: 0,
        averageRequestSize: 0,
        averageResponseSize: 0,
      );
    }

    final durations = _networkMetrics.map((m) => m.duration).toList();
    final totalDuration = durations.fold<Duration>(
      Duration.zero,
      (sum, d) => sum + d,
    );

    final averageResponseTime = Duration(
      microseconds: totalDuration.inMicroseconds ~/ durations.length,
    );

    final minResponseTime = durations.reduce((a, b) => a < b ? a : b);
    final maxResponseTime = durations.reduce((a, b) => a > b ? a : b);

    final successfulRequests = _networkMetrics
        .where((m) => m.statusCode >= 200 && m.statusCode < 300)
        .length;
    final failedRequests = _networkMetrics.length - successfulRequests;

    final requestSizes = _networkMetrics
        .where((m) => m.requestSize != null)
        .map((m) => m.requestSize!)
        .toList();
    final responseSizes = _networkMetrics
        .where((m) => m.responseSize != null)
        .map((m) => m.responseSize!)
        .toList();

    final averageRequestSize = requestSizes.isEmpty
        ? 0
        : requestSizes.reduce((a, b) => a + b) ~/ requestSizes.length;
    final averageResponseSize = responseSizes.isEmpty
        ? 0
        : responseSizes.reduce((a, b) => a + b) ~/ responseSizes.length;

    return NetworkPerformanceStats(
      averageResponseTime: averageResponseTime,
      minResponseTime: minResponseTime,
      maxResponseTime: maxResponseTime,
      totalRequests: _networkMetrics.length,
      successfulRequests: successfulRequests,
      failedRequests: failedRequests,
      averageRequestSize: averageRequestSize,
      averageResponseSize: averageResponseSize,
    );
  }

  /// Log runtime performance to analytics
  void logRuntimePerformanceToAnalytics(AnalyticsService? analyticsService) {
    if (analyticsService == null) return;

    final frameStats = getFramePerformanceStats();
    final memoryStats = getMemoryPerformanceStats();
    final networkStats = getNetworkPerformanceStats();

    // Log frame performance
    analyticsService.logPerformanceMetric(
      metricName: 'runtime_frame_avg',
      duration: frameStats.averageFrameTime,
    );
    analyticsService.logPerformanceMetric(
      metricName: 'runtime_frame_max',
      duration: frameStats.maxFrameTime,
    );

    // Log memory performance
    analyticsService.logPerformanceMetric(
      metricName: 'runtime_memory_avg',
      duration: Duration(milliseconds: memoryStats.averageUsedMemory),
    );
    analyticsService.logPerformanceMetric(
      metricName: 'runtime_memory_peak',
      duration: Duration(milliseconds: memoryStats.peakUsedMemory),
    );

    // Log network performance
    analyticsService.logPerformanceMetric(
      metricName: 'runtime_network_avg',
      duration: networkStats.averageResponseTime,
    );
  }

  /// Get runtime performance summary
  String getRuntimePerformanceSummary() {
    final buffer = StringBuffer();
    buffer.writeln('=== Runtime Performance Summary ===');

    final frameStats = getFramePerformanceStats();
    buffer.writeln('\nFrame Performance:');
    buffer.writeln(
        '  Average Frame Time: ${frameStats.averageFrameTime.inMilliseconds}ms',);
    buffer.writeln(
        '  Min Frame Time: ${frameStats.minFrameTime.inMilliseconds}ms',);
    buffer.writeln(
        '  Max Frame Time: ${frameStats.maxFrameTime.inMilliseconds}ms',);
    buffer.writeln(
        '  Dropped Frames: ${frameStats.droppedFrames}/${frameStats.totalFrames}',);

    final memoryStats = getMemoryPerformanceStats();
    buffer.writeln('\nMemory Performance:');
    buffer.writeln('  Average Used Memory: ${memoryStats.averageUsedMemory}MB');
    buffer.writeln('  Peak Used Memory: ${memoryStats.peakUsedMemory}MB');
    buffer.writeln('  Average Free Memory: ${memoryStats.averageFreeMemory}MB');
    buffer.writeln('  Min Free Memory: ${memoryStats.minFreeMemory}MB');

    final networkStats = getNetworkPerformanceStats();
    buffer.writeln('\nNetwork Performance:');
    buffer.writeln(
        '  Average Response Time: ${networkStats.averageResponseTime.inMilliseconds}ms',);
    buffer.writeln(
        '  Min Response Time: ${networkStats.minResponseTime.inMilliseconds}ms',);
    buffer.writeln(
        '  Max Response Time: ${networkStats.maxResponseTime.inMilliseconds}ms',);
    buffer.writeln('  Total Requests: ${networkStats.totalRequests}');
    buffer.writeln('  Successful: ${networkStats.successfulRequests}');
    buffer.writeln('  Failed: ${networkStats.failedRequests}');
    buffer.writeln(
        '  Average Request Size: ${networkStats.averageRequestSize} bytes',);
    buffer.writeln(
        '  Average Response Size: ${networkStats.averageResponseSize} bytes',);

    return buffer.toString();
  }

  /// Reset profiler
  void reset() {
    _startupProfiler.reset();
    _frameTimings.clear();
    _memoryMetrics.clear();
    _networkMetrics.clear();
    stopRuntimeProfiling();
  }
}

/// Frame timing data
class FrameTiming {

  FrameTiming({
    required this.timestamp,
    required this.duration,
    required this.frameCount,
  });
  final DateTime timestamp;
  final Duration duration;
  final int frameCount;
}

/// Memory metric data
class MemoryMetric { // in MB

  MemoryMetric({
    required this.timestamp,
    required this.usedMemory,
    required this.totalMemory,
    required this.freeMemory,
  });
  final DateTime timestamp;
  final int usedMemory; // in MB
  final int totalMemory; // in MB
  final int freeMemory;
}

/// Network metric data
class NetworkMetric { // in bytes

  NetworkMetric({
    required this.timestamp,
    required this.url,
    required this.method,
    required this.duration,
    required this.statusCode,
    this.requestSize,
    this.responseSize,
  });
  final DateTime timestamp;
  final String url;
  final String method;
  final Duration duration;
  final int statusCode;
  final int? requestSize; // in bytes
  final int? responseSize;
}

/// Frame performance statistics
class FramePerformanceStats {

  FramePerformanceStats({
    required this.averageFrameTime,
    required this.minFrameTime,
    required this.maxFrameTime,
    required this.droppedFrames,
    required this.totalFrames,
  });
  final Duration averageFrameTime;
  final Duration minFrameTime;
  final Duration maxFrameTime;
  final int droppedFrames;
  final int totalFrames;
}

/// Memory performance statistics
class MemoryPerformanceStats { // in MB

  MemoryPerformanceStats({
    required this.averageUsedMemory,
    required this.peakUsedMemory,
    required this.averageFreeMemory,
    required this.minFreeMemory,
  });
  final int averageUsedMemory; // in MB
  final int peakUsedMemory; // in MB
  final int averageFreeMemory; // in MB
  final int minFreeMemory;
}

/// Network performance statistics
class NetworkPerformanceStats { // in bytes

  NetworkPerformanceStats({
    required this.averageResponseTime,
    required this.minResponseTime,
    required this.maxResponseTime,
    required this.totalRequests,
    required this.successfulRequests,
    required this.failedRequests,
    required this.averageRequestSize,
    required this.averageResponseSize,
  });
  final Duration averageResponseTime;
  final Duration minResponseTime;
  final Duration maxResponseTime;
  final int totalRequests;
  final int successfulRequests;
  final int failedRequests;
  final int averageRequestSize; // in bytes
  final int averageResponseSize;
}
