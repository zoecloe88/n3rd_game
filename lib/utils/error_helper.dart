import 'package:flutter/material.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';

/// Helper class for user-friendly error messages
class ErrorHelper {
  /// Convert technical errors to user-friendly messages
  static String getUserFriendlyError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('internet')) {
      return 'Please check your internet connection and try again.';
    } else if (errorString.contains('timeout')) {
      return 'Request timed out. Please try again.';
    } else if (errorString.contains('permission') ||
        errorString.contains('denied')) {
      return 'Permission denied. Please enable in settings.';
    } else if (errorString.contains('authentication') ||
        errorString.contains('unauthorized')) {
      return 'Authentication failed. Please sign in again.';
    } else if (errorString.contains('not found') ||
        errorString.contains('404')) {
      return 'Content not found. Please try again later.';
    } else if (errorString.contains('server') || errorString.contains('500')) {
      return 'Server error. Please try again later.';
    } else if (errorString.contains('firebase')) {
      return 'Service temporarily unavailable. Please try again.';
    }

    return 'An error occurred. Please try again.';
  }

  /// Show error snackbar with user-friendly message
  static void showErrorSnackBar(BuildContext context, dynamic error) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(getUserFriendlyError(error)),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Retry an operation with exponential backoff
  static Future<T> retryOperation<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;

    while (attempt < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) {
          rethrow;
        }
        // Exponential backoff
        await Future.delayed(delay);
        delay = Duration(milliseconds: delay.inMilliseconds * 2);
      }
    }

    throw GameException('Max retries exceeded');
  }
}
