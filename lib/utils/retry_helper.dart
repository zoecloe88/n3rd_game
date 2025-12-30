import 'dart:async';
import 'package:n3rd_game/services/logger_service.dart';

/// Retry helper utility for network operations with exponential backoff
/// Provides automatic retry logic with configurable attempts and delays
class RetryHelper {
  /// Execute an operation with retry logic and exponential backoff
  ///
  /// [operation] - The async operation to execute
  /// [maxAttempts] - Maximum number of retry attempts (default: 3)
  /// [initialDelay] - Initial delay before first retry in milliseconds (default: 1000)
  /// [maxDelay] - Maximum delay between retries in milliseconds (default: 10000)
  /// [backoffMultiplier] - Multiplier for exponential backoff (default: 2.0)
  /// [retryableErrors] - List of error types to retry on (null = retry on all errors)
  ///
  /// Returns the result of the operation
  /// Throws the last error if all retries are exhausted
  static Future<T> retryWithBackoff<T>({
    required Future<T> Function() operation,
    int maxAttempts = 3,
    int initialDelay = 1000,
    int maxDelay = 10000,
    double backoffMultiplier = 2.0,
    List<Type>? retryableErrors,
  }) async {
    int attempt = 0;
    int delay = initialDelay;

    while (attempt < maxAttempts) {
      try {
        return await operation();
      } catch (e) {
        attempt++;

        // Check if error is retryable
        if (retryableErrors != null &&
            !retryableErrors.contains(e.runtimeType)) {
          LoggerService.debug('Error is not retryable: ${e.runtimeType}');
          rethrow;
        }

        // If this was the last attempt, rethrow the error
        if (attempt >= maxAttempts) {
          LoggerService.warning(
            'Operation failed after $maxAttempts attempts',
            error: e,
          );
          rethrow;
        }

        // Calculate exponential backoff delay
        final backoffDelay =
            (delay * backoffMultiplier).round().clamp(0, maxDelay);

        LoggerService.debug(
          'Operation failed (attempt $attempt/$maxAttempts), retrying in ${backoffDelay}ms...',
        );

        // Wait before retrying
        await Future.delayed(Duration(milliseconds: backoffDelay));

        // Update delay for next iteration
        delay = backoffDelay;
      }
    }

    // Should never reach here, but throw a generic error as fallback
    throw Exception('Retry logic exhausted without completing operation');
  }

  /// Execute an operation with retry logic and exponential backoff
  /// Includes error recovery suggestions
  ///
  /// [operation] - The async operation to execute
  /// [maxAttempts] - Maximum number of retry attempts (default: 3)
  /// [initialDelay] - Initial delay before first retry in milliseconds (default: 1000)
  /// [maxDelay] - Maximum delay between retries in milliseconds (default: 10000)
  /// [backoffMultiplier] - Multiplier for exponential backoff (default: 2.0)
  /// [onRetry] - Callback called before each retry attempt
  ///
  /// Returns a tuple of (result, errorMessage) where errorMessage is null on success
  static Future<(T?, String?)> retryWithRecovery<T>({
    required Future<T> Function() operation,
    int maxAttempts = 3,
    int initialDelay = 1000,
    int maxDelay = 10000,
    double backoffMultiplier = 2.0,
    void Function(int attempt, int totalAttempts, Duration delay)? onRetry,
  }) async {
    int attempt = 0;
    int delay = initialDelay;

    while (attempt < maxAttempts) {
      try {
        final result = await operation();
        return (result, null); // Success
      } catch (e) {
        attempt++;

        // If this was the last attempt, return error with recovery suggestion
        if (attempt >= maxAttempts) {
          final errorMessage = _getRecoverySuggestion(e);
          LoggerService.warning(
            'Operation failed after $maxAttempts attempts: $errorMessage',
            error: e,
          );
          return (null, errorMessage);
        }

        // Calculate exponential backoff delay
        final backoffDelay =
            (delay * backoffMultiplier).round().clamp(0, maxDelay);

        // Call onRetry callback if provided
        if (onRetry != null) {
          onRetry(attempt, maxAttempts, Duration(milliseconds: backoffDelay));
        }

        LoggerService.debug(
          'Operation failed (attempt $attempt/$maxAttempts), retrying in ${backoffDelay}ms...',
        );

        // Wait before retrying
        await Future.delayed(Duration(milliseconds: backoffDelay));

        // Update delay for next iteration
        delay = backoffDelay;
      }
    }

    // Should never reach here, but return error as fallback
    return (
      null,
      'Operation failed after multiple attempts. Please try again later.'
    );
  }

  /// Get user-friendly recovery suggestion based on error type
  static String _getRecoverySuggestion(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Network connection issue. Please check your internet connection and try again.';
    } else if (errorString.contains('timeout')) {
      return 'Request timed out. Please check your connection and try again.';
    } else if (errorString.contains('permission') ||
        errorString.contains('unauthorized')) {
      return 'Permission denied. Please check your account settings and try again.';
    } else if (errorString.contains('not found') ||
        errorString.contains('404')) {
      return 'Resource not found. The requested content may have been removed.';
    } else if (errorString.contains('server') || errorString.contains('500')) {
      return 'Server error. Please try again in a few moments.';
    } else {
      return 'An error occurred. Please try again. If the problem persists, contact support.';
    }
  }

  /// Execute multiple operations with retry logic
  /// Continues even if some operations fail
  ///
  /// [operations] - List of operations to execute
  /// [maxAttempts] - Maximum retry attempts per operation (default: 3)
  ///
  /// Returns list of results (null for failed operations)
  static Future<List<T?>> retryMultiple<T>({
    required List<Future<T> Function()> operations,
    int maxAttempts = 3,
  }) async {
    final results = <T?>[];

    for (final operation in operations) {
      try {
        final result = await retryWithBackoff<T>(
          operation: operation,
          maxAttempts: maxAttempts,
        );
        results.add(result);
      } catch (e) {
        LoggerService.warning(
          'Operation in batch failed after retries',
          error: e,
        );
        results.add(null); // Mark as failed but continue
      }
    }

    return results;
  }
}
