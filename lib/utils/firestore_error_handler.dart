import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/services/daily_challenge_leaderboard_service.dart' show SubmissionResponse, SubmissionResult;
import 'package:n3rd_game/exceptions/app_exceptions.dart';

/// Centralized Firestore error handling utility
///
/// Provides consistent error handling patterns for Firestore operations
/// across all services, reducing code duplication.
class FirestoreErrorHandler {
  /// Handle Firestore permission-denied errors with consistent logging and cleanup
  ///
  /// [error] - The FirebaseException with permission-denied code
  /// [serviceName] - Name of the service for logging (e.g., 'FriendsService')
  /// [clearData] - Optional callback to clear service data (e.g., clear friends list)
  /// [notifyListeners] - Optional callback to notify listeners after cleanup
  /// [customMessage] - Optional custom error message, otherwise uses default
  ///
  /// Returns true if permission was denied, false otherwise
  static bool handlePermissionDenied(
    dynamic error,
    String serviceName, {
    VoidCallback? clearData,
    VoidCallback? notifyListeners,
    String? customMessage,
  }) {
    if (error is! FirebaseException || error.code != 'permission-denied') {
      return false;
    }

    final message = customMessage ??
        '$serviceName: Permission denied. User may not be authenticated or lacks required permissions.';

    LoggerService.error(
      message,
      error: error,
      reason: 'Firestore permission-denied error',
      fatal: false,
    );

    // Clear data if callback provided
    clearData?.call();

    // Notify listeners if callback provided
    notifyListeners?.call();

    return true;
  }

  /// Handle Firestore errors with consistent logging and exception handling
  ///
  /// [error] - The error (FirebaseException or other)
  /// [serviceName] - Name of the service for logging
  /// [operationName] - Description of the operation (e.g., 'loading friends')
  /// [clearData] - Optional callback to clear service data
  /// [notifyListeners] - Optional callback to notify listeners
  ///
  /// Throws appropriate AppException based on error type
  static void handleFirestoreError(
    dynamic error,
    String serviceName,
    String operationName, {
    VoidCallback? clearData,
    VoidCallback? notifyListeners,
  }) {
    if (error is FirebaseException) {
      // Handle permission-denied
      if (error.code == 'permission-denied') {
        final handled = handlePermissionDenied(
          error,
          serviceName,
          clearData: clearData,
          notifyListeners: notifyListeners,
          customMessage:
              '$serviceName: Permission denied $operationName. User may not be authenticated or lacks required permissions.',
        );
        if (handled) {
          // Check if user is authenticated for more specific error
          final auth = FirebaseAuth.instance;
          final userId = auth.currentUser?.uid;
          if (userId == null) {
            throw AuthenticationException(
              'User not authenticated. Please log in to continue.',
              recoverySuggestion: 'Please sign in to access this feature.',
            );
          }
          throw PermissionException(
            'Permission denied. You may not have access to this feature.',
            recoverySuggestion:
                'Please check your subscription status or contact support if you believe you should have access.',
          );
        }
      }

      // Handle unavailable errors
      if (error.code == 'unavailable') {
        LoggerService.error(
          '$serviceName: Firestore service unavailable for $operationName',
          error: error,
          reason: 'Firestore unavailable error',
          fatal: false,
        );
        throw NetworkException(
          'Service temporarily unavailable. Please try again later.',
          recoverySuggestion: 'Please check your internet connection and try again.',
        );
      }

      // Handle other Firebase errors
      LoggerService.error(
        '$serviceName: Firebase error during $operationName (${error.code})',
        error: error,
        reason: 'Firestore operation failed',
        fatal: false,
      );
      throw NetworkException(
        'Operation failed: ${error.message ?? error.code}',
        recoverySuggestion: 'Please check your connection and try again.',
      );
    }

    // Handle timeout errors
    if (error is TimeoutException) {
      LoggerService.error(
        '$serviceName: Timeout during $operationName',
        error: error,
        reason: 'Firestore operation timeout',
        fatal: false,
      );
      throw NetworkException(
        'Request timed out. Please check your connection and try again.',
        recoverySuggestion: 'Please check your internet connection and try again.',
      );
    }

    // Generic error handling
    LoggerService.error(
      '$serviceName: Unexpected error during $operationName',
      error: error,
      reason: 'Unknown Firestore error',
      fatal: false,
    );
    throw NetworkException(
      'An unexpected error occurred. Please try again.',
      recoverySuggestion: 'If the problem persists, please restart the app.',
    );
  }

  /// Handle Firestore stream errors (used in Stream.listen onError callbacks)
  ///
  /// [error] - The error from stream
  /// [serviceName] - Name of the service
  /// [operationName] - Description of the stream operation
  /// [clearData] - Optional callback to clear service data
  /// [notifyListeners] - Optional callback to notify listeners
  static void handleStreamError(
    dynamic error,
    String serviceName,
    String operationName, {
    VoidCallback? clearData,
    VoidCallback? notifyListeners,
  }) {
    // Try permission-denied first (most common)
    final wasPermissionDenied = handlePermissionDenied(
      error,
      serviceName,
      clearData: clearData,
      notifyListeners: notifyListeners,
      customMessage:
          '$serviceName: Permission denied $operationName. User may not be authenticated or lacks required permissions.',
    );

    if (!wasPermissionDenied) {
      // Handle other stream errors
      LoggerService.error(
        '$serviceName: Error $operationName',
        error: error,
        reason: 'Firestore stream error',
        fatal: false,
      );
      clearData?.call();
      notifyListeners?.call();
    }
  }

  /// Handle Firestore errors and return a SubmissionResponse for challenge/leaderboard operations
  ///
  /// [error] - The error
  /// [serviceName] - Name of the service
  /// [operationName] - Description of the operation
  ///
  /// Returns SubmissionResponse with appropriate result type
  static SubmissionResponse handleSubmissionError(
    dynamic error,
    String serviceName,
    String operationName,
  ) {
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        LoggerService.error(
          '$serviceName: Permission denied $operationName',
          error: error,
          reason: 'Firestore permission-denied error',
          fatal: false,
        );
        return SubmissionResponse(
          SubmissionResult.permissionDenied,
          'Permission denied. Please check your account.',
        );
      } else if (error.code == 'unavailable') {
        LoggerService.error(
          '$serviceName: Service unavailable for $operationName',
          error: error,
          reason: 'Firestore unavailable error',
          fatal: false,
        );
        return SubmissionResponse(
          SubmissionResult.networkError,
          'Network error. Please check your connection and try again.',
        );
      }
    }

    if (error is TimeoutException) {
      LoggerService.error(
        '$serviceName: Timeout during $operationName',
        error: error,
        reason: 'Firestore operation timeout',
        fatal: false,
      );
      return SubmissionResponse(
        SubmissionResult.networkError,
        'Request timed out. Please check your connection and try again.',
      );
    }

    LoggerService.error(
      '$serviceName: Unexpected error during $operationName',
      error: error,
      reason: 'Unknown submission error',
      fatal: false,
    );
    return SubmissionResponse(
      SubmissionResult.networkError,
      'Network error: ${error.toString()}',
    );
  }
}
