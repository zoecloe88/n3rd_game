import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:flutter/foundation.dart';

/// Utility class for handling Firestore errors consistently
/// Provides standardized error handling and retry logic
class FirestoreErrorHandler {
  /// Handle Firestore exceptions and convert to app exceptions
  /// Returns appropriate exception type based on error
  static Exception handleFirestoreError(
    dynamic error,
    String operationName,
  ) {
    if (error is FirebaseException) {
      // Handle specific Firestore error codes
      switch (error.code) {
        case 'permission-denied':
          LoggerService.warning(
            'Firestore permission denied: $operationName',
            error: error,
          );
          return AuthenticationException(
            'You do not have permission to perform this operation.',
          );
        case 'unavailable':
          LoggerService.warning(
            'Firestore unavailable: $operationName',
            error: error,
          );
          return NetworkException(
            'Service is temporarily unavailable. Please check your connection and try again.',
          );
        case 'deadline-exceeded':
          LoggerService.warning(
            'Firestore deadline exceeded: $operationName',
            error: error,
          );
          return NetworkException(
            'Operation timed out. Please try again.',
          );
        case 'not-found':
          LoggerService.warning(
            'Firestore resource not found: $operationName',
            error: error,
          );
          return ValidationException(
            'Requested resource was not found.',
          );
        case 'already-exists':
          LoggerService.warning(
            'Firestore resource already exists: $operationName',
            error: error,
          );
          return ValidationException(
            'Resource already exists.',
          );
        case 'failed-precondition':
          LoggerService.warning(
            'Firestore precondition failed: $operationName',
            error: error,
          );
          return ValidationException(
            'Operation failed due to invalid state.',
          );
        case 'aborted':
          LoggerService.warning(
            'Firestore operation aborted: $operationName',
            error: error,
          );
          return NetworkException(
            'Operation was aborted. Please try again.',
          );
        case 'resource-exhausted':
          LoggerService.warning(
            'Firestore resource exhausted: $operationName',
            error: error,
          );
          return NetworkException(
            'Service is temporarily overloaded. Please try again later.',
          );
        case 'cancelled':
          LoggerService.warning(
            'Firestore operation cancelled: $operationName',
            error: error,
          );
          return NetworkException(
            'Operation was cancelled.',
          );
        case 'data-loss':
          LoggerService.error(
            'Firestore data loss: $operationName',
            error: error,
          );
          return StorageException(
            'Data integrity error. Please contact support.',
          );
        case 'unauthenticated':
          LoggerService.warning(
            'Firestore unauthenticated: $operationName',
            error: error,
          );
          return AuthenticationException(
            'You must be logged in to perform this operation.',
          );
        case 'unimplemented':
          LoggerService.error(
            'Firestore operation not implemented: $operationName',
            error: error,
          );
          return ValidationException(
            'This operation is not supported.',
          );
        default:
          LoggerService.error(
            'Firestore error (${error.code}): $operationName',
            error: error,
          );
          return NetworkException(
            'An error occurred: ${error.message ?? error.code}',
          );
      }
    }

    // Handle other exception types
    if (error is Exception) {
      LoggerService.error(
        'Firestore operation failed: $operationName',
        error: error,
      );
      return error;
    }

    // Handle unknown errors
    LoggerService.error(
      'Unknown Firestore error: $operationName',
      error: error,
    );
    return NetworkException(
      'An unexpected error occurred. Please try again.',
    );
  }

  /// Execute Firestore operation with comprehensive error handling
  /// Automatically converts Firestore errors to app exceptions
  static Future<T> executeWithErrorHandling<T>({
    required Future<T> Function() operation,
    required String operationName,
    T? fallbackValue,
  }) async {
    try {
      return await operation();
    } catch (e) {
      final appException = handleFirestoreError(e, operationName);

      // If fallback value provided, return it instead of throwing
      if (fallbackValue != null) {
        if (kDebugMode) {
          debugPrint(
            'Firestore operation failed, using fallback: $operationName',
          );
        }
        return fallbackValue;
      }

      throw appException;
    }
  }

  /// Check if error is retryable
  static bool isRetryable(dynamic error) {
    if (error is FirebaseException) {
      // Retryable error codes
      const retryableCodes = [
        'unavailable',
        'deadline-exceeded',
        'aborted',
        'resource-exhausted',
        'cancelled',
      ];
      return retryableCodes.contains(error.code);
    }
    // Network errors are generally retryable
    if (error is NetworkException) {
      return true;
    }
    return false;
  }
}

