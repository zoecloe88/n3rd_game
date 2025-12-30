import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Centralized logging service for consistent error handling and debugging
///
/// This service provides a unified interface for logging throughout the app,
/// reducing code duplication and ensuring consistent error reporting.
class LoggerService {
  /// Log debug messages (only in debug mode)
  static void debug(String message, {Object? error, StackTrace? stack}) {
    if (kDebugMode) {
      LoggerService.debug('[DEBUG] $message');
      if (error != null) {
        LoggerService.error('Error: $error');
        if (stack != null) {
          LoggerService.debug('Stack: $stack');
        }
      }
    }
  }

  /// Log informational messages (only in debug mode)
  static void info(String message) {
    LoggerService.debug('[INFO] $message');
  }

  /// Log warning messages (only in debug mode)
  static void warning(String message, {Object? error}) {
    if (kDebugMode) {
      LoggerService.debug('[WARN] $message');
      if (error != null) {
        LoggerService.error('Error: $error');
      }
    }
  }

  /// Log error messages (always logged, also sent to Crashlytics in production)
  static void error(
    String message, {
    Object? error,
    StackTrace? stack,
    bool fatal = false,
    String? reason,
  }) {
    // Always print errors
    LoggerService.error('[ERROR] $message');
    if (error != null) {
      LoggerService.error('Error: $error');
      if (stack != null) {
        LoggerService.debug('Stack: $stack');
      }
    }

    // Log to Crashlytics in production
    if (!kDebugMode && error != null) {
      try {
        FirebaseCrashlytics.instance.recordError(
          error,
          stack ?? StackTrace.current,
          reason: reason ?? message,
          fatal: fatal,
        );
      } catch (e) {
        // Ignore Crashlytics errors (e.g., if Firebase not initialized)
        LoggerService.error('Failed to log to Crashlytics: $e');
      }
    }
  }

  /// Log performance metrics
  static void performance(
    String operation,
    Duration duration, {
    Map<String, Object>? metadata,
  }) {
    if (kDebugMode) {
      final ms = duration.inMilliseconds;
      LoggerService.debug('[PERF] $operation: ${ms}ms');
      if (metadata != null) {
        for (final entry in metadata.entries) {
          LoggerService.debug('  ${entry.key}: ${entry.value}');
        }
      }
    }
  }
}
