import 'package:flutter/foundation.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Startup profiler for tracking initialization performance
///
/// Tracks initialization time for each service and logs performance
/// metrics to identify bottlenecks.
class StartupProfiler {

  StartupProfiler._();
  static final StartupProfiler _instance = StartupProfiler._();
  static StartupProfiler get instance => _instance;

  /// App startup time
  DateTime? _appStartTime;

  /// Service initialization times
  final Map<String, Duration> _serviceTimes = {};

  /// Service start times
  final Map<String, DateTime> _serviceStartTimes = {};

  /// Start profiling app startup
  void startAppStartup() {
    _appStartTime = DateTime.now();
    if (kDebugMode) {
      LoggerService.debug('App startup profiling started');
    }
  }

  /// Start profiling a service
  void startService(String serviceName) {
    _serviceStartTimes[serviceName] = DateTime.now();
  }

  /// End profiling a service
  void endService(String serviceName) {
    final startTime = _serviceStartTimes[serviceName];
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      _serviceTimes[serviceName] = duration;
      _serviceStartTimes.remove(serviceName);

      if (kDebugMode) {
        LoggerService.debug(
          'Service "$serviceName" initialized in ${duration.inMilliseconds}ms',
        );
      }
    }
  }

  /// Get total startup time
  Duration? getTotalStartupTime() {
    if (_appStartTime == null) return null;
    return DateTime.now().difference(_appStartTime!);
  }

  /// Get service initialization time
  Duration? getServiceTime(String serviceName) {
    return _serviceTimes[serviceName];
  }

  /// Get all service times
  Map<String, Duration> getAllServiceTimes() {
    return Map.unmodifiable(_serviceTimes);
  }

  /// Log startup performance to analytics
  void logToAnalytics(AnalyticsService? analyticsService) {
    if (analyticsService == null) return;

    final totalTime = getTotalStartupTime();
    if (totalTime != null) {
      analyticsService.logAppStartup(
        totalTime,
        success: true,
        firebaseInitialized: true,
        templatesInitialized: true,
      );
    }

    // Log individual service times
    for (final entry in _serviceTimes.entries) {
      analyticsService.logPerformanceMetric(
        metricName: 'service_init_${entry.key}',
        duration: entry.value,
      );
    }
  }

  /// Get performance summary
  String getPerformanceSummary() {
    final buffer = StringBuffer();
    buffer.writeln('=== Startup Performance Summary ===');

    final totalTime = getTotalStartupTime();
    if (totalTime != null) {
      buffer.writeln('Total Startup Time: ${totalTime.inMilliseconds}ms');
    }

    buffer.writeln('\nService Initialization Times:');
    final sortedServices = _serviceTimes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sortedServices) {
      buffer.writeln(
        '  ${entry.key}: ${entry.value.inMilliseconds}ms',
      );
    }

    // Identify slow services
    final slowServices = _serviceTimes.entries
        .where((e) => e.value.inMilliseconds > 500)
        .toList();

    if (slowServices.isNotEmpty) {
      buffer.writeln('\n⚠️  Slow Services (>500ms):');
      for (final entry in slowServices) {
        buffer.writeln(
          '  ${entry.key}: ${entry.value.inMilliseconds}ms',
        );
      }
    }

    return buffer.toString();
  }

  /// Reset profiler
  void reset() {
    _appStartTime = null;
    _serviceTimes.clear();
    _serviceStartTimes.clear();
  }
}
