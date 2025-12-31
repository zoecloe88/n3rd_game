import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Firebase test configuration and initialization helpers
class FirebaseTestHelper {
  static bool _isInitializing = false;
  
  /// Track all created Firebase app names for cleanup
  static final Set<String> _createdAppNames = <String>{};
  
  /// Track the default app name separately
  static String? _defaultAppName;

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
  /// Returns true if a new app was created, false if it already existed
  static Future<bool> initializeFirebaseForTests() async {
    // Prevent concurrent initialization
    if (_isInitializing) {
      return false;
    }

    // Check if Firebase apps already exist using Firebase.apps list
    if (Firebase.apps.isNotEmpty) {
      // Firebase is already initialized, nothing to do
      // Track existing default app if not already tracked
      try {
        final defaultApp = Firebase.app();
        if (_defaultAppName == null) {
          _defaultAppName = defaultApp.name;
          _createdAppNames.add(defaultApp.name);
        }
      } catch (e) {
        // No default app, but other apps exist - that's fine
      }
      return false;
    }

    _isInitializing = true;
    try {
      // Set up mocks first
      setupFirebaseMocks();

      // Initialize Firebase with test options (default app)
      try {
        final app = await Firebase.initializeApp(
          options: testOptions,
        );
        _defaultAppName = app.name;
        _createdAppNames.add(app.name);
        
        // Give Firebase a moment to fully initialize
        await Future.delayed(const Duration(milliseconds: 100));
        return true;
      } catch (e) {
        // If initialization fails, check if Firebase is now available
        // (may have been initialized by another thread)
        try {
          final defaultApp = Firebase.app();
          if (_defaultAppName == null) {
            _defaultAppName = defaultApp.name;
            _createdAppNames.add(defaultApp.name);
          }
          return false;
        } catch (_) {
          // Firebase initialization failed and no app is available
          // Don't create named apps as fallback - let tests handle the error
          // This prevents accumulation of named apps
          rethrow;
        }
      }
    } finally {
      _isInitializing = false;
    }
  }

  /// Check if Firebase is initialized
  static bool isFirebaseInitialized() {
    return Firebase.apps.isNotEmpty;
  }

  /// Get the count of Firebase apps currently initialized
  /// Useful for debugging and verification
  static int getFirebaseAppCount() {
    return Firebase.apps.length;
  }

  /// Clean up all tracked Firebase apps
  /// Deletes all named apps (non-default) to prevent memory accumulation
  /// Keeps the default app if it exists (for test isolation)
  static Future<void> cleanupFirebaseApps() async {
    try {
      final appsToDelete = <String>[];
      
      // Collect all named apps (non-default) for deletion
      for (final appName in _createdAppNames) {
        if (appName != _defaultAppName && appName != '[DEFAULT]') {
          appsToDelete.add(appName);
        }
      }
      
      // Delete each named app
      for (final appName in appsToDelete) {
        try {
          final app = Firebase.app(appName);
          await app.delete();
          _createdAppNames.remove(appName);
        } catch (e) {
          // App may have already been deleted or doesn't exist
          // Remove from tracking anyway
          _createdAppNames.remove(appName);
        }
      }
      
      // Optionally delete default app if we want full cleanup
      // For now, we keep it for test isolation between test files
      // If default app needs cleanup, uncomment below:
      // if (_defaultAppName != null) {
      //   try {
      //     final defaultApp = Firebase.app(_defaultAppName!);
      //     await defaultApp.delete();
      //     _createdAppNames.remove(_defaultAppName!);
      //     _defaultAppName = null;
      //   } catch (e) {
      //     // Default app may have already been deleted
      //     _createdAppNames.remove(_defaultAppName!);
      //     _defaultAppName = null;
      //   }
      // }
    } catch (e) {
      // If cleanup fails completely, at least clear tracking
      // This prevents tracking from growing indefinitely
      _createdAppNames.clear();
      _defaultAppName = null;
    }
  }

  /// Reset tracking (for testing cleanup functionality)
  static void resetTracking() {
    _createdAppNames.clear();
    _defaultAppName = null;
  }
}
