import 'package:n3rd_game/exceptions/app_exceptions.dart';

/// Application configuration constants
///
/// This class centralizes all application configuration including:
/// - Firebase Cloud Functions URLs and settings
/// - API timeouts and retry configurations
/// - Rate limiting constants
/// - Input validation limits
/// - Cache settings
/// - Network security settings
class AppConfig {
  // Firebase Cloud Functions configuration
  /// Cloud Function region (default: us-central1)
  static String get cloudFunctionRegion => const String.fromEnvironment(
        'CLOUD_FUNCTION_REGION',
        defaultValue: 'us-central1',
      );

  /// Firebase project ID (default: wordn3rd-7bd5d)
  static String get firebaseProjectId => const String.fromEnvironment(
        'FIREBASE_PROJECT_ID',
        defaultValue: 'wordn3rd-7bd5d',
      );

  /// Cloud Function name (default: generateTrivia)
  static String get cloudFunctionName => const String.fromEnvironment(
        'CLOUD_FUNCTION_NAME',
        defaultValue: 'generateTrivia',
      );

  /// Get the full Cloud Function URL
  ///
  /// Constructs the URL in the format:
  /// `https://{region}-{projectId}.cloudfunctions.net/{functionName}`
  static String get cloudFunctionUrl {
    return 'https://$cloudFunctionRegion-$firebaseProjectId.cloudfunctions.net/$cloudFunctionName';
  }

  // API timeouts
  /// Timeout for Cloud Function requests (60 seconds)
  static const Duration cloudFunctionTimeout = Duration(seconds: 60);

  /// Timeout for dictionary API requests (15 seconds)
  static const Duration dictionaryApiTimeout = Duration(seconds: 15);

  // Rate limiting
  /// Daily generation limit per user (20 requests/day)
  static const int dailyGenerationLimit = 20;

  /// Maximum number of retry attempts for network requests
  static const int maxRetries = 3;

  // Retry delays (exponential backoff)
  /// Calculate retry delay based on attempt number
  ///
  /// Returns exponential backoff: 1s, 2s, 4s, 8s...
  ///
  /// Example:
  /// ```dart
  /// final delay = AppConfig.getRetryDelay(1); // Returns Duration(seconds: 2)
  /// ```
  static Duration getRetryDelay(int attempt) {
    return Duration(seconds: 1 << attempt); // 1s, 2s, 4s, 8s...
  }

  // Input validation limits
  /// Minimum topic length for AI generation (2 characters)
  static const int minTopicLength = 2;

  /// Maximum topic length for AI generation (100 characters)
  static const int maxTopicLength = 100;

  /// Minimum trivia count per generation (1)
  static const int minTriviaCount = 1;

  /// Maximum trivia count per generation (100)
  static const int maxTriviaCount = 100;

  // Cache settings
  /// Maximum age for cached trivia (24 hours)
  static const Duration cacheMaxAge = Duration(hours: 24);

  // Network settings
  /// Whether to enforce HTTPS connections (true)
  static const bool enforceHttps = true;

  // External API URLs
  /// Dictionary API base URL for word definitions
  static const String dictionaryApiUrl =
      'https://api.dictionaryapi.dev/api/v2/entries/en';

  /// Google search URL (for word lookups)
  static const String googleSearchUrl = 'https://www.google.com/search?q=';

  /// Wikipedia URL (for word information)
  static const String wikipediaUrl = 'https://en.wikipedia.org/wiki/';

  // Game mode configuration constants
  /// Shuffle mode intervals (milliseconds)
  static const int shuffleIntervalEasy = 3000; // 3 seconds
  static const int shuffleIntervalMedium = 2000; // 2 seconds
  static const int shuffleIntervalHard = 1000; // 1 second
  static const int shuffleIntervalInsane = 500; // 0.5 seconds

  // RevenueCat configuration
  /// RevenueCat API key (Secret Key - do not expose in version control)
  /// Get from: https://app.revenuecat.com
  ///
  /// **REQUIRED**: Must be set via environment variable for all builds (debug and production).
  /// Set via: `--dart-define=REVENUECAT_API_KEY=your_key_here`
  ///
  /// **Security**: Never hardcode API keys in source code. Always use environment variables.
  /// For local development, set the environment variable in your IDE or build configuration.
  static String get revenueCatApiKey {
    const envKey = String.fromEnvironment('REVENUECAT_API_KEY');

    if (envKey.isEmpty) {
      throw ValidationException(
        'RevenueCat API key is required. Set REVENUECAT_API_KEY environment variable.\n'
        'For Flutter: Use --dart-define=REVENUECAT_API_KEY=your_key_here\n'
        'For VS Code: Add to launch.json "dartDefine": {"REVENUECAT_API_KEY": "your_key"}\n'
        'For Android Studio: Run configuration > Additional run args > --dart-define=REVENUECAT_API_KEY=your_key\n'
        'Get your key from: https://app.revenuecat.com',
      );
    }

    return envKey;
  }

  // Stats and analytics configuration
  /// Maximum number of daily stats to retain (90 days)
  static const int maxDailyStatsDays = 90;

  /// Default chart period in days (30 days)
  static const int defaultChartDays = 30;

  /// Available chart period options (7, 30, 90 days)
  static const List<int> chartPeriodOptions = [7, 30, 90];

  /// Maximum streak value to display (prevents UI overflow)
  static const int maxStreakDisplay = 999;

  /// Maximum edition name length for validation
  static const int maxEditionNameLength = 100;

  /// Minimum edition name length for validation
  static const int minEditionNameLength = 3;

  /// Maximum display name length
  static const int maxDisplayNameLength = 50;

  // Network configuration
  /// Default timeout for network operations (10 seconds)
  static const Duration defaultTimeout = Duration(seconds: 10);

  /// Timeout for long-running operations (30 seconds)
  static const Duration longOperationTimeout = Duration(seconds: 30);

  /// Default retry delay between attempts (500ms)
  static const Duration retryDelay = Duration(milliseconds: 500);
}
