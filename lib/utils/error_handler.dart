import 'package:flutter/material.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';

/// Centralized error handler for consistent error display across the app
/// Provides user-friendly error messages with actionable guidance
class ErrorHandler {
  /// Get localized error message from an error object
  /// Maps error types to user-friendly localized strings
  static String getLocalizedErrorMessage(
    dynamic error,
    BuildContext context,
  ) {
    final localizations = AppLocalizations.of(context);

    if (localizations == null) {
      // Fallback if localization not available
      return _getDefaultErrorMessage(error);
    }

    // Check if error is an AppException with a message that can be localized
    if (error is AuthenticationException ||
        error is ValidationException ||
        error is GameException ||
        error is NetworkException ||
        error is StorageException ||
        error is PermissionException) {
      final message = error.toString();
      final localizedMessage = _localizeExceptionMessage(
        localizations,
        message,
      );
      if (localizedMessage != null) {
        return localizedMessage;
      }
    }

    // Use the localization method if available
    try {
      return localizations.getLocalizedErrorMessage(error);
    } catch (e) {
      // Fallback if localization method fails
      return _getDefaultErrorMessage(error);
    }
  }

  /// Localize exception messages by matching them to localization keys
  static String? _localizeExceptionMessage(
    AppLocalizations localizations,
    String message,
  ) {
    // Map exception messages to localization getters
    final messageMap = {
      'User must be logged in': localizations.userMustBeLoggedIn,
      'User must be logged in to create a room':
          localizations.userMustBeLoggedInToCreateRoom,
      'User must be logged in to join a room':
          localizations.userMustBeLoggedInToJoinRoom,
      'Invalid room ID format': localizations.invalidRoomIdFormat,
      'Room not found': localizations.roomNotFound,
      'Room is full': localizations.roomIsFull,
      'Only the host can start the game': localizations.onlyHostCanStartGame,
      'Not all players are ready': localizations.notAllPlayersReady,
      'Only the host can assign roles': localizations.onlyHostCanAssignRoles,
      'Player not in room': localizations.playerNotInRoom,
      'Only the host can advance rounds':
          localizations.onlyHostCanAdvanceRounds,
      'Only the host can send invitations':
          localizations.onlyHostCanSendInvitations,
      'Friend already invited': localizations.friendAlreadyInvited,
      'Invitation not found': localizations.invitationNotFound,
      'Only the inviter can cancel the invitation':
          localizations.onlyInviterCanCancelInvitation,
      'Direct messaging requires premium access':
          localizations.directMessagingRequiresPremium,
      'User not authenticated': localizations.userNotAuthenticated,
      'Message cannot be empty': localizations.messageCannotBeEmpty,
      'No active conversation': localizations.noActiveConversation,
      'Message not found': localizations.messageNotFound,
      'You can only delete your own messages':
          localizations.canOnlyDeleteOwnMessages,
    };

    // Try exact match first
    if (messageMap.containsKey(message)) {
      return messageMap[message];
    }

    // Try case-insensitive match
    for (final entry in messageMap.entries) {
      if (entry.key.toLowerCase() == message.toLowerCase()) {
        return entry.value;
      }
    }

    return null;
  }

  /// Get default error message when localization is not available
  static String _getDefaultErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('network') || errorStr.contains('connection')) {
      return 'Network error. Please check your connection.';
    }
    if (errorStr.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }
    if (errorStr.contains('authentication')) {
      return 'Authentication failed. Please sign in again.';
    }
    if (errorStr.contains('permission')) {
      return 'Permission denied. Please check your access rights.';
    }

    return 'An error occurred. Please try again.';
  }

  /// Show an error dialog with optional retry action
  /// Automatically detects network/offline errors and provides helpful messages
  /// If message is null, will attempt to get localized error message from context
  static Future<void> showError(
    BuildContext context,
    String? message, {
    String? title,
    dynamic error,
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
    bool isOffline = false,
  }) async {
    // Get localized message if message not provided but error is
    final finalMessage = message ??
        (error != null
            ? getLocalizedErrorMessage(error, context)
            : 'An error occurred');

    final localizations = AppLocalizations.of(context);
    if (!context.mounted) return;

    // Enhance error message based on error type
    String enhancedMessage = finalMessage;
    if (isOffline ||
        finalMessage.toLowerCase().contains('network') ||
        finalMessage.toLowerCase().contains('offline') ||
        finalMessage.toLowerCase().contains('connection')) {
      enhancedMessage =
          '$finalMessage\n\nYou appear to be offline. Some features may not be available. '
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
                title ??
                    (isOffline
                        ? (localizations?.connectionLost ?? 'Offline Mode')
                        : (localizations?.error ?? 'Error')),
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
              child: Text(localizations?.retry ?? 'Retry'),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onDismiss?.call();
            },
            child: Text(localizations?.ok ?? 'OK'),
          ),
        ],
      ),
    );
  }

  /// Show a snackbar error message with enhanced offline detection
  /// If message is null, will attempt to get localized error message from error
  static void showSnackBar(
    BuildContext context,
    String? message, {
    dynamic error,
    Duration duration = const Duration(seconds: 3),
    Color? backgroundColor,
    bool isOffline = false,
  }) {
    if (!context.mounted) return;

    // Get localized message if message not provided but error is
    final finalMessage = message ??
        (error != null
            ? getLocalizedErrorMessage(error, context)
            : 'An error occurred');

    // Detect network errors automatically
    final detectedOffline = !isOffline &&
        (finalMessage.toLowerCase().contains('network') ||
            finalMessage.toLowerCase().contains('offline') ||
            finalMessage.toLowerCase().contains('connection') ||
            finalMessage.toLowerCase().contains('timeout') ||
            finalMessage.toLowerCase().contains('failed to fetch'));

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
                finalIsOffline &&
                        !finalMessage.toLowerCase().contains('offline')
                    ? '$finalMessage (${AppLocalizations.of(context)?.connectionLost ?? 'Offline mode active'})'
                    : finalMessage,
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

    final String message = getLocalizedErrorMessage(error, context);
    String? guidance;
    bool isOffline = false;

    // Detect error type and provide specific guidance
    final errorStr = error.toString().toLowerCase();

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
