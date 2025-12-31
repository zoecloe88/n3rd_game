import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/services/auth_service.dart';
import 'package:n3rd_game/services/feature_flag_service.dart';
import 'package:n3rd_game/services/edition_content_service.dart';
import 'package:n3rd_game/services/video_cache_service.dart';
import 'package:n3rd_game/data/trivia_templates_consolidated.dart'
    deferred as templates;
import 'firebase_test_helper.dart';
import 'video_player_test_helper.dart';

/// Test utilities for common test setup and mocking
class TestHelpers {
  /// Shared mock data storage (shared across all tests)
  /// This allows us to clear it between tests
  static final Map<String, dynamic> _mockPrefsData = {};

  /// Set up mock SharedPreferences for testing
  /// Uses both setMockInitialValues and a custom handler for complete coverage
  static void setupMockSharedPreferences() {
    // Clear any existing data
    _mockPrefsData.clear();
    // Use setMockInitialValues for basic functionality
    // This ensures SharedPreferences.getInstance() works correctly
    SharedPreferences.setMockInitialValues({});

    // Also set up custom handler for methods that might not be covered
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (methodCall) async {
        if (methodCall.method == 'getAll') {
          return Map<String, dynamic>.from(_mockPrefsData);
        }
        if (methodCall.method == 'getString') {
          final key = _extractKey(methodCall.arguments);
          return _mockPrefsData[key] as String?;
        }
        if (methodCall.method == 'getInt') {
          final key = _extractKey(methodCall.arguments);
          return _mockPrefsData[key] as int?;
        }
        if (methodCall.method == 'getBool') {
          final key = _extractKey(methodCall.arguments);
          return _mockPrefsData[key] as bool?;
        }
        if (methodCall.method == 'getDouble') {
          final key = _extractKey(methodCall.arguments);
          return _mockPrefsData[key] as double?;
        }
        if (methodCall.method == 'getStringList') {
          final key = _extractKey(methodCall.arguments);
          return _mockPrefsData[key] as List<String>?;
        }
        if (methodCall.method == 'setString') {
          final args = _extractArgs(methodCall.arguments);
          _mockPrefsData[args[0] as String] = args[1] as String;
          return true;
        }
        if (methodCall.method == 'setInt') {
          final args = _extractArgs(methodCall.arguments);
          _mockPrefsData[args[0] as String] = args[1] as int;
          return true;
        }
        if (methodCall.method == 'setBool') {
          final args = _extractArgs(methodCall.arguments);
          _mockPrefsData[args[0] as String] = args[1] as bool;
          return true;
        }
        if (methodCall.method == 'setDouble') {
          final args = _extractArgs(methodCall.arguments);
          _mockPrefsData[args[0] as String] = args[1] as double;
          return true;
        }
        if (methodCall.method == 'setStringList') {
          final args = _extractArgs(methodCall.arguments);
          _mockPrefsData[args[0] as String] = args[1] as List<String>;
          return true;
        }
        if (methodCall.method == 'remove') {
          final key = _extractKey(methodCall.arguments);
          _mockPrefsData.remove(key);
          return true;
        }
        if (methodCall.method == 'clear') {
          _mockPrefsData.clear();
          return true;
        }
        if (methodCall.method == 'containsKey') {
          final key = _extractKey(methodCall.arguments);
          return _mockPrefsData.containsKey(key);
        }
        return null;
      },
    );
  }

  /// Extract key from arguments (handles both String and List formats)
  static String _extractKey(dynamic arguments) {
    if (arguments is String) {
      return arguments;
    }
    if (arguments is List && arguments.isNotEmpty) {
      return arguments[0] as String;
    }
    if (arguments is Map && arguments.containsKey('key')) {
      return arguments['key'] as String;
    }
    return '';
  }

  /// Extract args from arguments (handles both List and Map formats)
  static List _extractArgs(dynamic arguments) {
    if (arguments is List) {
      return arguments;
    }
    if (arguments is Map) {
      // Convert map to list format [key, value]
      final key = arguments['key'] ?? arguments['0'];
      final value = arguments['value'] ?? arguments['1'];
      return [key, value];
    }
    return [];
  }

  /// Clear mock SharedPreferences handler and reset mock data
  static void clearMockSharedPreferences() {
    // Clear the mock data
    _mockPrefsData.clear();
    // Clear the handler
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      null,
    );
    // Also reset setMockInitialValues to clear state
    SharedPreferences.setMockInitialValues({});
  }

  /// Set up mock connectivity for testing
  static void setupMockConnectivity({bool isConnected = true}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (methodCall) async {
        if (methodCall.method == 'check') {
          return isConnected ? ['wifi'] : ['none'];
        }
        return null;
      },
    );
  }

  /// Clear mock connectivity handler
  static void clearMockConnectivity() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      null,
    );
  }

  /// Ensure test binding is initialized
  static void ensureInitialized() {
    TestWidgetsFlutterBinding.ensureInitialized();
  }

  /// Create a test SharedPreferences instance with data
  static Future<SharedPreferences> createTestPrefs(
    Map<String, dynamic> data,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in data.entries) {
      if (entry.value is String) {
        await prefs.setString(entry.key, entry.value as String);
      } else if (entry.value is int) {
        await prefs.setInt(entry.key, entry.value as int);
      } else if (entry.value is bool) {
        await prefs.setBool(entry.key, entry.value as bool);
      } else if (entry.value is double) {
        await prefs.setDouble(entry.key, entry.value as double);
      } else if (entry.value is List<String>) {
        await prefs.setStringList(entry.key, entry.value as List<String>);
      }
    }
    return prefs;
  }

  /// Set up Firebase for testing
  /// Initializes Firebase with test options if not already initialized
  static Future<void> setupFirebaseForTests() async {
    await FirebaseTestHelper.initializeFirebaseForTests();
  }

  /// Set up video player mocks for testing
  static void setupVideoPlayerMocks() {
    VideoPlayerTestHelper.setupVideoPlayerMocks();
  }

  /// Set up asset manifest mock for testing
  /// Note: Asset manifest is typically not available in test environment
  /// This method helps tests handle this gracefully
  static void setupAssetManifest() {
    // Mock asset manifest loading by providing a minimal response
    // This prevents errors when services try to load AssetManifest.json
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter/assets'),
      (methodCall) async {
        if (methodCall.method == 'loadString') {
          final key = methodCall.arguments as String;
          if (key == 'AssetManifest.json') {
            // Return minimal asset manifest with common assets
            return '''
{
  "packages": {},
  "assets": {
    "assets/background n3rd.png": [],
    "assets/loginscreen.mp4": []
  }
}
''';
          }
          // For font files and other string assets, return empty string
          // This prevents FormatException errors
          return '';
        }
        if (methodCall.method == 'load') {
          final key = methodCall.arguments as String;
          // Return a minimal valid PNG for image assets to prevent "Message corrupted" errors
          // Create a minimal 1x1 transparent PNG with correct CRC values
          if (key.contains('.png') ||
              key.contains('.jpg') ||
              key.contains('.jpeg')) {
            // Minimal valid 1x1 RGBA PNG
            // This is a real valid PNG file that Flutter can decode
            final pngBytes = Uint8List.fromList([
              // PNG signature
              0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
              // IHDR chunk (13 bytes of data)
              0x00, 0x00, 0x00, 0x0D, // Length: 13
              0x49, 0x48, 0x44, 0x52, // "IHDR"
              0x00, 0x00, 0x00, 0x01, // Width: 1
              0x00, 0x00, 0x00, 0x01, // Height: 1
              0x08, 0x06, 0x00, 0x00,
              0x00, // Bit depth: 8, Color type: 6 (RGBA), Compression: 0, Filter: 0, Interlace: 0
              0xF7, 0x64, 0xF8, 0x8A, // CRC for IHDR (corrected)
              // IDAT chunk (compressed 1x1 RGBA pixel: 0x00000000 = transparent black)
              0x00, 0x00, 0x00, 0x0C, // Length: 12
              0x49, 0x44, 0x41, 0x54, // "IDAT"
              0x78, 0x9C, 0x63, 0x00, 0x00, 0x00, 0x02, 0x00, 0x01, 0x00, 0x00,
              0x05, // Compressed data
              0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, // CRC for IDAT
              // IEND chunk
              0x00, 0x00, 0x00, 0x00, // Length: 0
              0x49, 0x45, 0x4E, 0x44, // "IEND"
              0xAE, 0x42, 0x60, 0x82, // CRC for IEND
            ]);
            return pngBytes;
          }
          // For font files, google_fonts will handle fallback to system fonts
          // Return empty list to prevent FormatException "Message corrupted" errors
          // google_fonts has built-in fallback handling
          if (key.contains('.ttf') ||
              key.contains('.otf') ||
              key.contains('google_fonts')) {
            return <int>[];
          }
          // For other binary assets, return empty list
          return <int>[];
        }
        return null;
      },
    );
  }

  /// Set up all test infrastructure at once
  /// This is a convenience method that sets up Firebase, video player mocks, and asset manifest
  static Future<void> setupAllTestInfrastructure() async {
    ensureInitialized();
    await setupFirebaseForTests();
    setupVideoPlayerMocks();
    setupAssetManifest();
    setupMockSharedPreferences();
    setupMockConnectivity();
  }

  /// Tear down all test infrastructure
  /// Cleans up all mocks and handlers
  static Future<void> tearDownAllTestInfrastructure() async {
    // Clean up Firebase apps first to prevent memory accumulation
    // This deletes all named apps (non-default) while keeping default app for test isolation
    try {
      await FirebaseTestHelper.cleanupFirebaseApps();
    } catch (e) {
      // Firebase cleanup errors should not prevent other cleanup
      // This is safe - Firebase apps will be cleaned up on next tearDownAll
    }
    
    clearMockSharedPreferences();
    clearMockConnectivity();
    VideoPlayerTestHelper.clearVideoPlayerMocks();
    // Reset trivia templates to prevent memory accumulation across test suites
    // Use deferred import to avoid loading huge file during test discovery
    try {
      templates.EditionTriviaTemplates.resetForTesting();
    } catch (e) {
      // Library not loaded yet, skip reset (deferred import not loaded)
      // This is safe - templates will be reset when library is actually loaded
    }
    // Reset singleton services to prevent state persistence across tests
    FeatureFlagService.resetForTesting();
    EditionContentService.resetForTesting();
    VideoCacheService.resetForTesting();
    // Note: PerformanceMonitoringService instances should be disposed individually
    // as they are not singletons - tests that create them should dispose them
  }

  /// Set up all common providers for widget tests
  /// Returns a list of providers that are commonly needed
  static List<Widget> setupAllProviders({
    AnalyticsService? analyticsService,
    SubscriptionService? subscriptionService,
    AuthService? authService,
  }) {
    final providers = <Widget>[];

    // Always include AnalyticsService (required by VideoBackgroundWidget and others)
    providers.add(
      ChangeNotifierProvider<AnalyticsService>.value(
        value: analyticsService ?? AnalyticsService(),
      ),
    );

    if (subscriptionService != null) {
      providers.add(
        ChangeNotifierProvider<SubscriptionService>.value(
          value: subscriptionService,
        ),
      );
    }

    if (authService != null) {
      providers.add(
        ChangeNotifierProvider<AuthService>.value(
          value: authService,
        ),
      );
    }

    return providers;
  }

  /// Create a test widget with all required providers
  /// Wraps the given child widget with MultiProvider and MaterialApp
  static Widget createTestWidget({
    required Widget child,
    AnalyticsService? analyticsService,
    SubscriptionService? subscriptionService,
    AuthService? authService,
    List<Widget>? additionalProviders,
  }) {
    final providers = setupAllProviders(
      analyticsService: analyticsService,
      subscriptionService: subscriptionService,
      authService: authService,
    );

    if (additionalProviders != null) {
      providers.addAll(additionalProviders);
    }

    return MultiProvider(
      providers: providers.cast(),
      child: MaterialApp(
        home: child,
      ),
    );
  }
}
