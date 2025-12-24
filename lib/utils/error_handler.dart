import 'package:flutter/material.dart';

/// Centralized error handler for consistent error display across the app
/// Provides user-friendly error messages with actionable guidance
class ErrorHandler {
  /// Show an error dialog with optional retry action
  /// Automatically detects network/offline errors and provides helpful messages
  static Future<void> showError(
    BuildContext context,
    String message, {
    String? title,
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
    bool isOffline = false,
  }) async {
    if (!context.mounted) return;

    // Enhance error message based on error type
    String enhancedMessage = message;
    if (isOffline ||
        message.toLowerCase().contains('network') ||
        message.toLowerCase().contains('offline') ||
        message.toLowerCase().contains('connection')) {
      enhancedMessage =
          '$message\n\nYou appear to be offline. Some features may not be available. '
          'The app will continue to work with cached content.';
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isOffline ? Icons.wifi_off : Icons.error_outline,
              color: isOffline ? Colors.orange : Colors.red,
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title ?? (isOffline ? 'Offline Mode' : 'Error'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(enhancedMessage),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: const Text('Retry'),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onDismiss?.call();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show a snackbar error message with enhanced offline detection
  static void showSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    Color? backgroundColor,
    bool isOffline = false,
  }) {
    if (!context.mounted) return;

    // Detect network errors automatically
    final detectedOffline = !isOffline &&
        (message.toLowerCase().contains('network') ||
            message.toLowerCase().contains('offline') ||
            message.toLowerCase().contains('connection') ||
            message.toLowerCase().contains('timeout') ||
            message.toLowerCase().contains('failed to fetch'));

    final finalIsOffline = isOffline || detectedOffline;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (finalIsOffline)
              const Icon(Icons.wifi_off, color: Colors.white, size: 20),
            if (finalIsOffline) const SizedBox(width: 8),
            Expanded(
              child: Text(
                finalIsOffline && !message.toLowerCase().contains('offline')
                    ? '$message (Offline mode active)'
                    : message,
              ),
            ),
          ],
        ),
        duration: duration,
        backgroundColor:
            finalIsOffline ? Colors.orange : (backgroundColor ?? Colors.red),
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

  /// Show a success snackbar message
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        backgroundColor: Colors.green,
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

  /// Show a warning dialog with actionable guidance
  static Future<void> showWarning(
    BuildContext context,
    String message, {
    String? title,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    String? helpText,
  }) async {
    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title ?? 'Warning',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (helpText != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.blue,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        helpText,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (onCancel != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onCancel();
              },
              child: const Text('Cancel'),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm?.call();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show an error with actionable guidance based on error type
  static Future<void> showErrorWithGuidance(
    BuildContext context,
    dynamic error, {
    String? title,
    VoidCallback? onRetry,
  }) async {
    if (!context.mounted) return;

    final String message = error.toString();
    String? guidance;
    bool isOffline = false;

    // Detect error type and provide specific guidance
    final errorStr = message.toLowerCase();

    if (errorStr.contains('network') ||
        errorStr.contains('connection') ||
        errorStr.contains('timeout') ||
        errorStr.contains('offline')) {
      isOffline = true;
      guidance =
          'Check your internet connection and try again. The app will work offline with cached content.';
    } else if (errorStr.contains('authentication') ||
        errorStr.contains('sign in')) {
      guidance =
          'Please sign in again. If the problem persists, try signing out and back in.';
    } else if (errorStr.contains('subscription') ||
        errorStr.contains('purchase')) {
      guidance =
          'Subscription issues can usually be resolved by restoring purchases. Go to Settings > Subscriptions to restore.';
    } else if (errorStr.contains('trivia') || errorStr.contains('template')) {
      guidance =
          'Trivia content failed to load. Try restarting the app or selecting a different category.';
    } else if (errorStr.contains('permission') || errorStr.contains('access')) {
      guidance =
          'The app needs permission to access this feature. Go to Settings to enable permissions.';
    }

    await showError(
      context,
      message,
      title: title,
      onRetry: onRetry,
      isOffline: isOffline,
    );

    // Show additional guidance dialog if needed (with null check)
    if (guidance != null && context.mounted) {
      final guidanceText =
          guidance; // Store non-null value (already checked above)
      await Future.delayed(
        const Duration(milliseconds: 300),
      ); // Small delay to let error dialog show first
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.help_outline, color: Colors.blue, size: 24),
                SizedBox(width: 8),
                Text(
                  'Help',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Text(guidanceText),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Got it'),
              ),
            ],
          ),
        );
      }
    }
  }
}
