import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Firebase test configuration and initialization helpers
class FirebaseTestHelper {
  static bool _isInitializing = false;

  /// Test Firebase options
  static const FirebaseOptions testOptions = FirebaseOptions(
    apiKey: 'test-api-key',
    appId: 'test-app-id',
    messagingSenderId: 'test-sender-id',
    projectId: 'test-project-id',
  );

  /// Set up Firebase platform channel mocks
  static void setupFirebaseMocks() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/firebase_core'),
      (methodCall) async {
        if (methodCall.method == 'Firebase#initializeCore') {
          return [
            {
              'name': '[DEFAULT]',
              'options': {
                'apiKey': testOptions.apiKey,
                'appId': testOptions.appId,
                'messagingSenderId': testOptions.messagingSenderId,
                'projectId': testOptions.projectId,
              },
              'pluginConstants': {},
            }
          ];
        }
        if (methodCall.method == 'Firebase#initializeApp') {
          return {
            'name': methodCall.arguments['appName'] ?? '[DEFAULT]',
            'options': methodCall.arguments['options'] ??
                {
                  'apiKey': testOptions.apiKey,
                  'appId': testOptions.appId,
                  'messagingSenderId': testOptions.messagingSenderId,
                  'projectId': testOptions.projectId,
                },
            'pluginConstants': {},
          };
        }
        return null;
      },
    );
  }

  /// Initialize Firebase for testing
  /// Handles cases where Firebase is already initialized
  static Future<void> initializeFirebaseForTests() async {
    // Prevent concurrent initialization
    if (_isInitializing || isFirebaseInitialized()) {
      return;
    }

    _isInitializing = true;
    try {
      // Set up mocks first
      setupFirebaseMocks();

      // Check if Firebase is already initialized
      try {
        Firebase.app();
        // Firebase is already initialized, nothing to do
        return;
      } catch (e) {
        // Firebase is not initialized, proceed with initialization
      }

      // Initialize Firebase with test options
      await Firebase.initializeApp(
        options: testOptions,
      );

      // Give Firebase a moment to fully initialize
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      // Firebase may already be initialized by another test or setup
      // Try to verify it's available now
      try {
        Firebase.app(); // Verify Firebase is available
      } catch (_) {
        // If initialization failed and app is not available, try once more
        try {
          await Firebase.initializeApp(
            options: testOptions,
            name: 'test-app-${DateTime.now().millisecondsSinceEpoch}',
          );
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e2) {
          // Final fallback - tests that need Firebase will handle gracefully
          // Log the error for debugging
          if (e2.toString().contains('already been initialized')) {
            // This is fine - Firebase is already initialized
            return;
          }
        }
      }
    } finally {
      _isInitializing = false;
    }
  }

  /// Check if Firebase is initialized
  static bool isFirebaseInitialized() {
    try {
      Firebase.app();
      return true;
    } catch (e) {
      return false;
    }
  }
}
