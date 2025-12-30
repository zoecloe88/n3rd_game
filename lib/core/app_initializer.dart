import 'dart:async' show Future, TimeoutException, unawaited;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/config/app_config.dart';
import 'package:n3rd_game/services/revenue_cat_service.dart';
import 'package:n3rd_game/services/video_cache_service.dart';
import 'package:n3rd_game/services/auth_service.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/services/challenge_service.dart';
import 'package:n3rd_game/services/daily_challenge_leaderboard_service.dart';
import 'package:n3rd_game/services/text_to_speech_service.dart';
import 'package:n3rd_game/services/voice_recognition_service.dart';
import 'package:n3rd_game/services/pronunciation_dictionary_service.dart';
import 'package:n3rd_game/services/voice_calibration_service.dart';
import 'package:n3rd_game/services/theme_service.dart';
import 'package:n3rd_game/services/settings_service.dart';
import 'package:n3rd_game/services/learning_service.dart';
import 'package:n3rd_game/services/offline_service.dart';
import 'package:n3rd_game/services/accessibility_service.dart';
import 'package:n3rd_game/services/free_tier_service.dart';
import 'package:n3rd_game/services/sound_service.dart';
import 'package:n3rd_game/services/notification_service.dart';
import 'package:n3rd_game/services/animation_randomizer_service.dart';
import 'package:n3rd_game/services/network_service.dart';
import 'package:n3rd_game/services/multiplayer_service.dart';
import 'package:n3rd_game/services/family_group_service.dart';
import 'package:n3rd_game/services/friends_service.dart';
import 'package:n3rd_game/services/newsfeed_service.dart';
import 'package:n3rd_game/services/social_discovery_service.dart';
import 'package:n3rd_game/services/game_history_service.dart';
import 'package:n3rd_game/services/trivia_creator_service.dart';
import 'package:n3rd_game/services/performance_monitoring_service.dart';
import 'package:n3rd_game/services/ai_mode_service.dart';
import 'package:n3rd_game/services/edition_access_service.dart';
import 'package:n3rd_game/data/trivia_templates_consolidated.dart'
    deferred as templates;
import 'package:n3rd_game/utils/image_cache_helper.dart';
import 'package:n3rd_game/core/error_handlers.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Service initialization result
class ServiceInitializationResult {
  ServiceInitializationResult({
    required this.initialized,
    this.errors = const {},
  });

  /// Whether all services initialized successfully
  final bool initialized;

  /// Map of service name to error message for failed initializations
  final Map<String, String> errors;
}

/// Application initialization result
class AppInitializationResult {
  AppInitializationResult({
    required this.firebaseInitialized,
    this.firebaseInitError,
    required this.triviaInitialized,
    this.triviaInitError,
    required this.revenueCatService,
    required this.appStartTime,
    required this.servicesInitialized,
    this.serviceInitErrors = const {},
  });

  /// Whether Firebase was initialized successfully
  final bool firebaseInitialized;

  /// Firebase initialization error (if any)
  final String? firebaseInitError;

  /// Whether trivia templates were initialized successfully
  final bool triviaInitialized;

  /// Trivia initialization error (if any)
  final String? triviaInitError;

  /// RevenueCat service instance
  final RevenueCatService revenueCatService;

  /// App startup time
  final DateTime appStartTime;

  /// Whether services were initialized successfully
  final bool servicesInitialized;

  /// Map of service name to error message for failed service initializations
  final Map<String, String> serviceInitErrors;
}

/// Application initializer
///
/// Handles all application initialization logic including:
/// - Firebase initialization
/// - RevenueCat initialization
/// - Trivia template loading
/// - Error handler setup
class AppInitializer {
  /// Initialize the application
  ///
  /// Returns initialization result with status of all components
  static Future<AppInitializationResult> initialize() async {
    final appStartTime = DateTime.now();

    // Configure image cache
    ImageCacheHelper.configureImageCache(
      maximumSize: 100,
      maximumSizeBytes: 100 * 1024 * 1024, // 100MB
    );

    // Initialize Firebase
    final firebaseResult = await _initializeFirebase();

    // Setup error handlers
    ErrorHandlers.initialize(isFirebaseInitialized: firebaseResult.initialized);

    // Initialize trivia templates
    final triviaResult = await _initializeTriviaTemplates(
      isFirebaseInitialized: firebaseResult.initialized,
    );

    // Initialize RevenueCat
    final revenueCatService = await _initializeRevenueCat();

    // Set device orientation
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    // Preload priority videos (non-blocking)
    unawaited(
      VideoCacheService().preloadPriorityVideos().catchError((e) {
        LoggerService.error('Video preloading error (non-critical);', error: e);
      }),
    );

    return AppInitializationResult(
      firebaseInitialized: firebaseResult.initialized,
      firebaseInitError: firebaseResult.error,
      triviaInitialized: triviaResult.initialized,
      triviaInitError: triviaResult.error,
      revenueCatService: revenueCatService,
      appStartTime: appStartTime,
      servicesInitialized: true, // Services will be initialized after providers are created
      serviceInitErrors: const {},
    );
  }

  /// Initialize all services asynchronously
  ///
  /// This should be called after providers are created but before the app
  /// starts using services. Services are initialized in parallel with timeout
  /// protection to prevent blocking app startup.
  ///
  /// [context] - BuildContext with access to all providers
  /// [timeoutSeconds] - Maximum time to wait for service initialization (default: 10)
  static Future<ServiceInitializationResult> initializeServices(
    BuildContext context, {
    int timeoutSeconds = 10,
  }) async {
    final errors = <String, String>{};
    final timeout = Duration(seconds: timeoutSeconds);

    LoggerService.debug('🔧 Initializing services...');

    // Get all services that need initialization from providers
    final servicesToInit = <String, Future<void> Function()>{};

    try {
      // Core services
      final authService = Provider.of<AuthService>(context, listen: false);
      servicesToInit['AuthService'] = () => authService.init();

      final analyticsService =
          Provider.of<AnalyticsService>(context, listen: false);
      servicesToInit['AnalyticsService'] = () => analyticsService.init();

      final challengeService =
          Provider.of<ChallengeService>(context, listen: false);
      servicesToInit['ChallengeService'] = () => challengeService.init();

      final dailyChallengeLeaderboardService =
          Provider.of<DailyChallengeLeaderboardService>(context, listen: false);
      servicesToInit['DailyChallengeLeaderboardService'] =
          () => dailyChallengeLeaderboardService.init();

      final textToSpeechService =
          Provider.of<TextToSpeechService>(context, listen: false);
      servicesToInit['TextToSpeechService'] =
          () => textToSpeechService.init();

      final voiceRecognitionService =
          Provider.of<VoiceRecognitionService>(context, listen: false);
      servicesToInit['VoiceRecognitionService'] =
          () => voiceRecognitionService.init();

      final pronunciationDictionaryService =
          Provider.of<PronunciationDictionaryService>(context, listen: false);
      servicesToInit['PronunciationDictionaryService'] =
          () => pronunciationDictionaryService.init();

      final voiceCalibrationService =
          Provider.of<VoiceCalibrationService>(context, listen: false);
      servicesToInit['VoiceCalibrationService'] =
          () => voiceCalibrationService.init();

      final themeService = Provider.of<ThemeService>(context, listen: false);
      servicesToInit['ThemeService'] = () => themeService.init();

      final settingsService =
          Provider.of<SettingsService>(context, listen: false);
      servicesToInit['SettingsService'] = () => settingsService.init();

      final learningService =
          Provider.of<LearningService>(context, listen: false);
      servicesToInit['LearningService'] = () => learningService.init();

      final offlineService =
          Provider.of<OfflineService>(context, listen: false);
      servicesToInit['OfflineService'] = () => offlineService.init();

      final accessibilityService =
          Provider.of<AccessibilityService>(context, listen: false);
      servicesToInit['AccessibilityService'] =
          () => accessibilityService.init();

      final freeTierService =
          Provider.of<FreeTierService>(context, listen: false);
      servicesToInit['FreeTierService'] = () => freeTierService.init();

      final soundService = Provider.of<SoundService>(context, listen: false);
      servicesToInit['SoundService'] = () => soundService.init();

      final notificationService =
          Provider.of<NotificationService>(context, listen: false);
      servicesToInit['NotificationService'] =
          () => notificationService.init();

      final animationRandomizerService =
          Provider.of<AnimationRandomizerService>(context, listen: false);
      servicesToInit['AnimationRandomizerService'] =
          () => animationRandomizerService.init();

      final networkService =
          Provider.of<NetworkService>(context, listen: false);
      servicesToInit['NetworkService'] = () => networkService.init();

      final multiplayerService =
          Provider.of<MultiplayerService>(context, listen: false);
      servicesToInit['MultiplayerService'] = () => multiplayerService.init();

      final familyGroupService =
          Provider.of<FamilyGroupService>(context, listen: false);
      servicesToInit['FamilyGroupService'] =
          () => familyGroupService.init();

      final friendsService =
          Provider.of<FriendsService>(context, listen: false);
      servicesToInit['FriendsService'] = () => friendsService.init();

      final newsfeedService =
          Provider.of<NewsfeedService>(context, listen: false);
      servicesToInit['NewsfeedService'] = () => newsfeedService.init();

      final socialDiscoveryService =
          Provider.of<SocialDiscoveryService>(context, listen: false);
      servicesToInit['SocialDiscoveryService'] =
          () => socialDiscoveryService.init();

      final gameHistoryService =
          Provider.of<GameHistoryService>(context, listen: false);
      servicesToInit['GameHistoryService'] =
          () => gameHistoryService.init();

      final triviaCreatorService =
          Provider.of<TriviaCreatorService>(context, listen: false);
      servicesToInit['TriviaCreatorService'] =
          () => triviaCreatorService.init();

      final performanceMonitoringService =
          Provider.of<PerformanceMonitoringService>(context, listen: false);
      servicesToInit['PerformanceMonitoringService'] =
          () => performanceMonitoringService.init();

      final aiModeService =
          Provider.of<AIModeService>(context, listen: false);
      servicesToInit['AIModeService'] = () => aiModeService.init();

      final editionAccessService =
          Provider.of<EditionAccessService>(context, listen: false);
      servicesToInit['EditionAccessService'] =
          () => editionAccessService.init();
    } catch (e) {
      LoggerService.error('⚠️ Warning: Failed to access some services', error: e);
      // Continue with available services
    }

    // Initialize all services in parallel with timeout
    final initFutures = servicesToInit.entries.map((entry) async {
      final serviceName = entry.key;
      final initFunction = entry.value;

      try {
        await initFunction().timeout(
          timeout,
          onTimeout: () {
            throw TimeoutException(
              'Service initialization timeout: $serviceName',
              timeout,
            );
          },
        );
        LoggerService.info('$serviceName initialized');
      } catch (e, stackTrace) {
        final errorMessage = e.toString();
        errors[serviceName] = errorMessage;

        LoggerService.error('$serviceName initialization failed: $errorMessage');

        // Log to Crashlytics if available
        try {
          unawaited(
            FirebaseCrashlytics.instance.recordError(
              e,
              stackTrace,
              reason: 'Service initialization failure: $serviceName',
              fatal: false,
            ),
          );
        } catch (_) {
          // Ignore Crashlytics errors
        }
      }
    }).toList();

    // Wait for all initializations to complete
    await Future.wait(initFutures);

    final allInitialized = errors.isEmpty;

    if (kDebugMode) {
      if (allInitialized) {
        LoggerService.info('All services initialized successfully');
      } else {
        LoggerService.warning(
          '${errors.length} service(s); failed to initialize: ${errors.keys.join(", ")}',
        );
      }
    }

    return ServiceInitializationResult(
      initialized: allInitialized,
      errors: errors,
    );
  }

  /// Initialize Firebase
  static Future<({bool initialized, String? error})>
      _initializeFirebase() async {
    try {
      await Firebase.initializeApp();

      // Register background message handler
      try {
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );
      } catch (e) {
        LoggerService.warning(
          'Failed to register Firebase background message handler',
          error: e,
        );
      }

      if (kDebugMode) {
        LoggerService.info('Firebase initialized successfully');
        LoggerService.info('AI Edition configured to use Firebase Cloud Functions');
      }

      return (initialized: true, error: null);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        LoggerService.error(
          'CRITICAL: Firebase initialization failed',
          error: e,
          stack: stackTrace,
        );
      }
      return (initialized: false, error: e.toString());
    }
  }

  /// Initialize trivia templates
  static Future<({bool initialized, String? error})>
      _initializeTriviaTemplates({
    required bool isFirebaseInitialized,
  }) async {
    try {
      await templates.loadLibrary();
      await Future.delayed(const Duration(milliseconds: 50));
      await templates.EditionTriviaTemplates.initialize();

      if (!templates.EditionTriviaTemplates.isInitialized) {
        final error = templates.EditionTriviaTemplates.lastValidationError ??
            'Unknown error';

        LoggerService.error(
          'CRITICAL ERROR: Template initialization failed: $error',
        );

        // Log to Crashlytics if available
        if (isFirebaseInitialized) {
          try {
            unawaited(
              FirebaseCrashlytics.instance.recordError(
                Exception('Trivia template initialization failed: $error'),
                StackTrace.current,
                reason:
                    'Critical app initialization failure - trivia templates not initialized',
                fatal: false,
              ),
            );
          } catch (e) {
            LoggerService.error('Failed to log trivia init error to Crashlytics', error: e);
          }
        }

        return (initialized: false, error: error);
      }

      LoggerService.info('Trivia templates initialized successfully');

      return (initialized: true, error: null);
    } catch (e) {
      LoggerService.error(
        'CRITICAL ERROR: Failed to initialize trivia templates',
        error: e,
      );

      // Log to Crashlytics if available
      if (isFirebaseInitialized) {
        try {
          unawaited(
            FirebaseCrashlytics.instance.recordError(
              e,
              StackTrace.current,
              reason:
                  'Critical app initialization failure - trivia template exception',
              fatal: false,
            ),
          );
        } catch (crashlyticsError) {
          LoggerService.error(
            'Failed to log trivia init exception to Crashlytics',
            error: crashlyticsError,
          );
        }
      }

      return (initialized: false, error: e.toString());
    }
  }

  /// Initialize RevenueCat
  static Future<RevenueCatService> _initializeRevenueCat() async {
    final revenueCatService = RevenueCatService();

    try {
      final revenueCatApiKey = AppConfig.revenueCatApiKey;

      if (!AppConfig.isRevenueCatConfigured) {
        LoggerService.warning(
          'RevenueCat API key not set. Subscriptions will not work. Set REVENUECAT_API_KEY environment variable to enable subscriptions.',
        );
      } else {
        await revenueCatService.initialize(revenueCatApiKey);

        // Sync Firebase user if already logged in
        final firebaseUser = FirebaseAuth.instance.currentUser;
        if (firebaseUser != null) {
          await revenueCatService.syncFirebaseUser();
        }

        // Listen to auth changes to sync RevenueCat
        FirebaseAuth.instance.authStateChanges().listen((user) {
          if (user != null && revenueCatService.isInitialized) {
            revenueCatService.syncFirebaseUser();
          } else if (user == null && revenueCatService.isInitialized) {
            revenueCatService.logOut();
          }
        });

        LoggerService.info('RevenueCat initialized successfully');
      }
    } catch (e) {
      LoggerService.error('RevenueCat initialization error', error: e);
      // App continues without RevenueCat
    }

    return revenueCatService;
  }
}

/// Background message handler for Firebase Messaging
/// Must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Handle background message here
}
