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
  /// Get RevenueCat API key from environment variable
  /// Returns empty string if not set (graceful failure instead of throwing)
  /// This allows the app to continue functioning without subscriptions
  static String get revenueCatApiKey {
    const envKey = String.fromEnvironment('REVENUECAT_API_KEY');
    return envKey;
  }

  /// Check if RevenueCat API key is configured
  /// Returns true if key is set and non-empty
  static bool get isRevenueCatConfigured {
    return revenueCatApiKey.isNotEmpty;
  }

  /// Get RevenueCat API key with validation
  /// Throws ValidationException only if explicitly required (for critical operations)
  /// Use revenueCatApiKey getter for graceful failure scenarios
  static String getRevenueCatApiKeyOrThrow() {
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

  // Navigation configuration
  /// Maximum number of navigation history entries to retain (50 entries)
  static const int maxNavigationHistorySize = 50;

  // Authentication configuration
  /// Maximum failed login attempts before account lockout (5 attempts)
  static const int maxFailedLoginAttempts = 5;

  /// Account lockout duration after max failed attempts (30 minutes)
  static const Duration accountLockoutDuration = Duration(minutes: 30);

  /// Session timeout duration (24 hours)
  static const Duration sessionTimeoutDuration = Duration(hours: 24);

  /// Session activity check interval (5 minutes)
  static const Duration sessionActivityCheckInterval = Duration(minutes: 5);

  /// Biometric authentication enabled by default
  static const bool biometricAuthEnabled = true;

  // Routes that require onboarding completion
  /// List of routes that require the user to complete onboarding before access
  static const List<String> protectedRoutes = [
    '/title',
    '/modes',
    '/game',
    '/stats',
    '/leaderboard',
    '/friends',
    '/more',
    '/settings',
    '/word-of-day',
    '/editions',
    '/subscription-management',
  ];

  // Video configuration
  /// Video initialization timeout (8 seconds for slower devices)
  static const Duration videoInitializationTimeout = Duration(seconds: 8);

  /// Video fallback timer duration (3 seconds after failure)
  static const Duration videoFallbackTimerDuration = Duration(seconds: 3);

  /// Maximum wait time for video completion (10 seconds)
  /// Prevents indefinite waiting if video never completes
  static const Duration videoMaxWaitDuration = Duration(seconds: 10);

  /// Video retry delay multiplier (500ms per retry attempt)
  static const Duration videoRetryDelayBase = Duration(milliseconds: 500);

  /// Maximum video retry attempts
  static const int maxVideoRetries = 2;

  // Trivia generation retry configuration
  /// Maximum number of trivia generation retry attempts (5 attempts)
  static const int maxTriviaGenerationRetries = 5;

  /// Initial retry delay for trivia generation (200ms)
  static const Duration initialRetryDelay = Duration(milliseconds: 200);

  /// Retry backoff multiplier for exponential backoff (2.0)
  static const double retryBackoffMultiplier = 2.0;

  /// Maximum retry delay cap (5 seconds)
  static const Duration maxRetryDelay = Duration(seconds: 5);

  /// Maximum total timeout for all retry attempts (30 seconds)
  static const Duration maxTotalRetryTimeout = Duration(seconds: 30);

  // Mode transition configuration
  /// Minimum mode transition delay (3 seconds)
  static const Duration minModeTransitionDelay = Duration(seconds: 3);

  /// Maximum mode transition delay (10 seconds)
  static const Duration maxModeTransitionDelay = Duration(seconds: 10);

  /// Allow early navigation if video completes before minimum delay
  static const bool allowEarlyTransition = true;

  /// Allow skip button after minimum delay
  static const bool allowSkipTransition = true;

  // Certificate pinning configuration
  /// Enable certificate pinning in debug mode (default: false)
  /// Set to true only for testing certificate pinning in debug builds
  static bool? get enableCertificatePinningInDebug {
    const envValue = String.fromEnvironment('ENABLE_CERT_PINNING_DEBUG');
    if (envValue.isEmpty) return false;
    return envValue.toLowerCase() == 'true';
  }

  /// Get certificate pinning configuration for a specific host
  ///
  /// Returns certificate hashes (SHA-256, base64 encoded) for the host.
  /// These hashes are used to validate server certificates and prevent
  /// man-in-the-middle (MITM) attacks.
  ///
  /// **How to get certificate hashes:**
  /// 1. Extract certificate from server: `openssl s_client -connect host:443 -showcerts`
  /// 2. Calculate SHA-256 hash: `openssl x509 -in cert.pem -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64`
  ///
  /// **Example:**
  /// ```dart
  /// final config = AppConfig.getCertificatePinningConfig('api.example.com');
  /// // Returns CertificatePinningConfig with certificate hashes
  /// ```
  static CertificatePinningConfig? getCertificatePinningConfig(String host) {
    // Certificate pinning configurations by host
    // Add your certificate hashes here for production
    // Format: SHA-256 hash (base64 encoded) of the certificate's public key

    switch (host) {
      case 'us-central1-wordn3rd-7bd5d.cloudfunctions.net':
      case 'wordn3rd-7bd5d.cloudfunctions.net':
        // Firebase Cloud Functions certificate hashes
        //
        // NOTE: PRODUCTION SETUP REQUIRED - Certificate Pinning Configuration
        //
        // Certificate pinning requires actual certificate hashes from the server.
        // These cannot be generated programmatically and must be obtained from
        // the server administrator. This is a production deployment task.
        // the actual server certificates during production deployment.
        //
        // To obtain certificate hashes:
        // 1. Run: openssl s_client -connect us-central1-wordn3rd-7bd5d.cloudfunctions.net:443 -showcerts
        // 2. Copy the certificate chain output
        // 3. For each certificate in the chain:
        //    - Save the certificate to a file (e.g., cert.pem)
        //    - Run: openssl x509 -in cert.pem -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64
        //    - Or use: openssl x509 -in cert.pem -fingerprint -sha256 -noout
        // 4. Add the base64-encoded SHA-256 hash to the certificateHashes array below
        //
        // Example format: 'base64-encoded-sha256-hash'
        // Multiple hashes can be added for certificate chain pinning
        //
        // NOTE: Certificate pinning infrastructure is implemented in secure_http_client.dart
        // This configuration is required for production deployment to enable certificate validation
        return const CertificatePinningConfig(
          certificateHashes: [
            // NOTE: Add Firebase Cloud Functions certificate hashes here for production
            // These must be obtained from the server administrator
            // Example: 'ABC123...XYZ789=',
            // Example: 'DEF456...UVW012=',
          ],
          description: 'Firebase Cloud Functions',
        );

      case 'api.dictionaryapi.dev':
        // Dictionary API certificate hashes
        //
        // NOTE: PRODUCTION SETUP REQUIRED - Certificate Pinning Configuration
        //
        // Certificate pinning requires actual certificate hashes from the server.
        // These cannot be generated programmatically and must be obtained from
        // the server administrator. This is a production deployment task.
        // the actual server certificates during production deployment.
        //
        // To obtain certificate hashes:
        // 1. Run: openssl s_client -connect api.dictionaryapi.dev:443 -showcerts
        // 2. Copy the certificate chain output
        // 3. For each certificate in the chain:
        //    - Save the certificate to a file (e.g., cert.pem)
        //    - Run: openssl x509 -in cert.pem -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64
        //    - Or use: openssl x509 -in cert.pem -fingerprint -sha256 -noout
        // 4. Add the base64-encoded SHA-256 hash to the certificateHashes array below
        //
        // Example format: 'base64-encoded-sha256-hash'
        // Multiple hashes can be added for certificate chain pinning
        //
        // NOTE: Certificate pinning infrastructure is implemented in secure_http_client.dart
        // This configuration is required for production deployment to enable certificate validation
        return const CertificatePinningConfig(
          certificateHashes: [
            // NOTE: Add Dictionary API certificate hashes here for production
            // These must be obtained from the server administrator
            // Example: 'ABC123...XYZ789=',
            // Example: 'DEF456...UVW012=',
          ],
          description: 'Dictionary API',
        );

      default:
        // No pinning configured for this host
        // This allows gradual rollout of certificate pinning
        return null;
    }
  }
}

/// Certificate pinning configuration
///
/// Contains certificate hashes (SHA-256, base64 encoded) for a specific host.
/// These hashes are used to validate server certificates.
class CertificatePinningConfig {
  const CertificatePinningConfig({
    required this.certificateHashes,
    this.description,
  });

  /// List of certificate hashes (SHA-256, base64 encoded)
  final List<String> certificateHashes;

  /// Optional description of the host/service
  final String? description;
}
