import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Utility class for handling Firestore errors, especially permission-denied errors
class FirestoreErrorHandler {
  /// Check if error is a permission-denied error
  static bool isPermissionDenied(dynamic error) {
    if (error is FirebaseException) {
      return error.code == 'permission-denied';
    }
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('permission-denied') ||
        errorStr.contains('permission denied');
  }

  /// Check if user is authenticated before Firestore operations
  static bool isUserAuthenticated() {
    try {
      return FirebaseAuth.instance.currentUser != null;
    } catch (e) {
      LoggerService.warning('Error checking authentication state', error: e);
      return false;
    }
  }

  /// Wrap a Firestore operation with permission error handling
  /// Returns the result or throws a PermissionException if permission is denied
  static Future<T> handleFirestoreOperation<T>(
    Future<T> Function() operation, {
    String? operationName,
  }) async {
    // Check authentication first
    if (!isUserAuthenticated()) {
      throw AuthenticationException(
        'User must be authenticated to perform this operation.',
      );
    }

    try {
      return await operation();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        LoggerService.warning(
          'Firestore permission denied${operationName != null ? ' for $operationName' : ''}',
          error: e,
        );
        throw PermissionException(
          'Permission denied. Please check your access rights or contact support.',
        );
      }
      // Re-throw other Firebase exceptions
      rethrow;
    } catch (e) {
      // Check if it's a permission error in the message
      if (isPermissionDenied(e)) {
        LoggerService.warning(
          'Firestore permission denied${operationName != null ? ' for $operationName' : ''}',
          error: e,
        );
        throw PermissionException(
          'Permission denied. Please check your access rights or contact support.',
        );
      }
      // Re-throw other errors
      rethrow;
    }
  }

  /// Handle Firestore query with retry logic for permission errors
  static Future<QuerySnapshot> handleFirestoreQuery(
    Future<QuerySnapshot> Function() query, {
    String? operationName,
    int maxRetries = 2,
  }) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        return await handleFirestoreOperation(
          query,
          operationName: operationName,
        );
      } on PermissionException {
        // Don't retry permission errors - they won't resolve
        rethrow;
      } on FirebaseException catch (e) {
        attempts++;
        if (attempts >= maxRetries) {
          LoggerService.error(
            'Firestore query failed after $maxRetries attempts${operationName != null ? ' for $operationName' : ''}',
            error: e,
          );
          rethrow;
        }
        // Wait before retry (exponential backoff)
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      }
    }
    throw Exception('Unexpected error in Firestore query retry logic');
  }

  /// Handle Firestore document operations with retry logic
  static Future<T> handleFirestoreDocumentOperation<T>(
    Future<T> Function() operation, {
    String? operationName,
    int maxRetries = 2,
  }) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        return await handleFirestoreOperation(
          operation,
          operationName: operationName,
        );
      } on PermissionException {
        // Don't retry permission errors - they won't resolve
        rethrow;
      } on FirebaseException catch (e) {
        attempts++;
        if (attempts >= maxRetries) {
          LoggerService.error(
            'Firestore document operation failed after $maxRetries attempts${operationName != null ? ' for $operationName' : ''}',
            error: e,
          );
          rethrow;
        }
        // Wait before retry (exponential backoff)
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      }
    }
    throw Exception(
        'Unexpected error in Firestore document operation retry logic',);
  }
}
