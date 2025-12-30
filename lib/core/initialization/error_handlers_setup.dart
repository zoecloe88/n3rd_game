import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:flutter/foundation.dart';

/// Error handlers setup
class ErrorHandlersSetup {
  /// Setup global error handlers
  static void setup({required bool isFirebaseInitialized}) {
    // Flutter error handler
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      LoggerService.error(
        'Flutter Error: ${details.exception}',
        error: details.exception,
        stack: details.stack,
        fatal: false,
      );
      if (isFirebaseInitialized) {
        try {
          FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        } catch (e) {
          LoggerService.debug('Failed to log to Crashlytics', error: e);
        }
      }
    };

    // Platform error handler
    PlatformDispatcher.instance.onError = (error, stack) {
      LoggerService.error(
        'Platform Error: $error',
        error: error,
        stack: stack,
        fatal: true,
      );
      if (isFirebaseInitialized) {
        try {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        } catch (e) {
          LoggerService.debug('Failed to log to Crashlytics', error: e);
        }
      }
      return true; // Handled
    };
  }
}

