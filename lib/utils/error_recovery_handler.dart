import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/exceptions/error_codes.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Centralized error recovery handler
///
/// Provides standardized error recovery patterns and retry strategies
/// for different error types.
class ErrorRecoveryHandler {
  /// Maximum retry attempts
  static const int maxRetries = 3;

  /// Base retry delay
  static const Duration baseRetryDelay = Duration(seconds: 1);

  /// Retry with exponential backoff
  ///
  /// [operation] - The operation to retry
  /// [maxAttempts] - Maximum number of retry attempts (default: 3)
  /// [retryDelay] - Base delay between retries (default: 1 second)
  /// [shouldRetry] - Function to determine if error should be retried
  ///
  /// Returns the result of the operation
  /// Throws the last exception if all retries fail
  static Future<T> retryWithBackoff<T>({
    required Future<T> Function() operation,
    int maxAttempts = maxRetries,
    Duration retryDelay = baseRetryDelay,
    bool Function(dynamic error)? shouldRetry,
  }) async {
    int attempt = 0;
    Exception? lastException;

    while (attempt < maxAttempts) {
      try {
        return await operation();
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());

        // Check if we should retry this error
        if (shouldRetry != null && !shouldRetry(e)) {
          rethrow;
        }

        // Don't retry on certain error types
        if (e is ValidationException || e is PermissionException) {
          rethrow;
        }

        attempt++;

        if (attempt < maxAttempts) {
          // Exponential backoff: 1s, 2s, 4s...
          final delay = Duration(
            milliseconds: retryDelay.inMilliseconds * (1 << (attempt - 1)),
          );

          LoggerService.debug(
            'Retrying operation (attempt $attempt/$maxAttempts); after ${delay.inMilliseconds}ms',
          );

          await Future.delayed(delay);
        }
      }
    }

    // All retries failed
    if (lastException != null) {
      throw lastException;
    }
    throw Exception('Operation failed after $maxAttempts attempts');
  }

  /// Handle error and provide recovery action
  ///
  /// [error] - The error to handle
  /// [context] - Additional context about where the error occurred
  ///
  /// Returns a recovery action suggestion
  static ErrorRecoveryAction handleError(
    dynamic error, {
    String? context,
  }) {
    // Extract error code if available
    ErrorCode? errorCode;
    String? recoverySuggestion;

    if (error is AuthenticationException) {
      errorCode = error.errorCode ?? ErrorCode.authInvalidCredentials;
      recoverySuggestion = error.recovery;
    } else if (error is NetworkException) {
      errorCode = error.errorCode ?? ErrorCode.networkNoConnection;
      recoverySuggestion = error.recovery;
    } else if (error is GameException) {
      errorCode = error.errorCode ?? ErrorCode.gameInvalidTriviaPool;
      recoverySuggestion = error.recovery;
    } else if (error is ValidationException) {
      errorCode = error.errorCode ?? ErrorCode.validationInvalidFormat;
      recoverySuggestion = error.recovery;
    } else if (error is StorageException) {
      errorCode = error.errorCode ?? ErrorCode.storageReadFailed;
      recoverySuggestion = error.recovery;
    } else {
      errorCode = ErrorCode.unknownError;
      recoverySuggestion = 'An unexpected error occurred. Please try again.';
    }

    // Get recovery suggestion from error code if not provided
    recoverySuggestion ??= ErrorRecoverySuggestions.getSuggestion(errorCode);

    return ErrorRecoveryAction(
      errorCode: errorCode,
      message: error.toString(),
      recoverySuggestion: recoverySuggestion,
      context: context,
    );
  }

  /// Check if error is recoverable
  static bool isRecoverable(dynamic error) {
    // Validation and permission errors are not recoverable
    if (error is ValidationException || error is PermissionException) {
      return false;
    }

    // Network errors are usually recoverable
    if (error is NetworkException) {
      return error.errorCode != ErrorCode.networkUnauthorized &&
          error.errorCode != ErrorCode.networkForbidden;
    }

    // Storage errors may be recoverable
    if (error is StorageException) {
      return error.errorCode != ErrorCode.storagePermissionDenied;
    }

    // Default: assume recoverable
    return true;
  }
}

/// Error recovery action with suggestions
class ErrorRecoveryAction {

  const ErrorRecoveryAction({
    required this.errorCode,
    required this.message,
    this.recoverySuggestion,
    this.context,
    this.isRecoverable = true,
  });
  /// Error code
  final ErrorCode errorCode;

  /// Error message
  final String message;

  /// Recovery suggestion
  final String? recoverySuggestion;

  /// Additional context
  final String? context;

  /// Whether the error is recoverable
  final bool isRecoverable;

  /// Get user-friendly error message
  String get userMessage {
    return recoverySuggestion ?? message;
  }
}













