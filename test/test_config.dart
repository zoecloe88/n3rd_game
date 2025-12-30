import 'package:firebase_core/firebase_core.dart';

// Export test helpers
export 'utils/test_helpers.dart';
export 'utils/firebase_test_helper.dart';
export 'utils/video_player_test_helper.dart';

/// Test configuration constants
class TestConfig {
  /// Test Firebase options
  static const FirebaseOptions firebaseOptions = FirebaseOptions(
    apiKey: 'test-api-key',
    appId: 'test-app-id',
    messagingSenderId: 'test-sender-id',
    projectId: 'test-project-id',
  );

  /// Default test timeout
  static const Duration defaultTimeout = Duration(seconds: 30);

  /// Long test timeout (for integration tests)
  static const Duration longTimeout = Duration(seconds: 60);

  /// Short test timeout (for unit tests)
  static const Duration shortTimeout = Duration(seconds: 10);
}
