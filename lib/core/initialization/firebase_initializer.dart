import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:n3rd_game/core/app_initializer.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Firebase initialization result
class FirebaseInitResult {
  final bool initialized;
  final String? error;

  FirebaseInitResult({required this.initialized, this.error});
}

/// Firebase initializer
class FirebaseInitializer {
  /// Initialize Firebase
  static Future<FirebaseInitResult> initialize() async {
    try {
      await Firebase.initializeApp();

      // Register background message handler
      try {
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      } catch (e) {
        LoggerService.warning(
          'Failed to register Firebase background message handler',
          error: e,
        );
      }

      LoggerService.info('Firebase initialized successfully');
      LoggerService.info('AI Edition configured to use Firebase Cloud Functions');

      return FirebaseInitResult(initialized: true);
    } catch (e, stackTrace) {
      LoggerService.error(
        'CRITICAL: Firebase initialization failed',
        error: e,
        stack: stackTrace,
        fatal: false,
      );
      return FirebaseInitResult(initialized: false, error: e.toString());
    }
  }

  /// Check if Firebase is initialized
  static bool isInitialized() {
    try {
      Firebase.app();
      return true;
    } catch (e) {
      return false;
    }
  }
}








