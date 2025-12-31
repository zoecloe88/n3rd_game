import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Centralized error handling setup
///
/// Configures Flutter and platform error handlers for the application.
class ErrorHandlers {
  /// Initialize all error handlers
  ///
  /// [isFirebaseInitialized] - Whether Firebase is initialized
  static void initialize({required bool isFirebaseInitialized}) {
    // Global error handler for all Flutter framework errors
    // This complements ErrorWidget.builder (which handles widget build errors)
    // by catching async errors, render errors, and other runtime exceptions
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      // Log to console in debug mode
      if (kDebugMode) {
        LoggerService.error('Flutter Error: ${details.exception}');
        LoggerService.debug('Stack trace: ${details.stack}');
      }
      // Log to Firebase Crashlytics only if Firebase is initialized
      if (isFirebaseInitialized) {
        try {
          FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        } catch (e) {
          LoggerService.error('Failed to log to Crashlytics', error: e);
        }
      }
    };

    // Platform error handler
    PlatformDispatcher.instance.onError = (error, stack) {
      if (kDebugMode) {
        LoggerService.error('Platform Error: $error');
        LoggerService.debug('Stack trace: $stack');
      }
      // Log to Crashlytics only if Firebase is initialized
      if (isFirebaseInitialized) {
        try {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        } catch (e) {
          LoggerService.error('Failed to log to Crashlytics', error: e);
        }
      }
      return true; // Handled
    };
  }
}
