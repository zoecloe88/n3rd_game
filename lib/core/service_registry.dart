import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:n3rd_game/services/revenue_cat_service.dart';
import 'package:n3rd_game/services/auth_service.dart';
import 'package:n3rd_game/services/game_service.dart';
import 'package:n3rd_game/services/stats_service.dart';
import 'package:n3rd_game/services/free_tier_service.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/services/ai_mode_service.dart';
import 'package:n3rd_game/services/ai_edition_service.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/services/trivia_personalization_service.dart';
import 'package:n3rd_game/services/trivia_gamification_service.dart';
import 'package:n3rd_game/services/trivia_generator_service.dart';
import 'package:n3rd_game/services/challenge_service.dart';
import 'package:n3rd_game/services/daily_challenge_leaderboard_service.dart';
import 'package:n3rd_game/services/text_to_speech_service.dart';
import 'package:n3rd_game/services/voice_recognition_service.dart';
import 'package:n3rd_game/services/pronunciation_dictionary_service.dart';
import 'package:n3rd_game/services/voice_calibration_service.dart';
import 'package:n3rd_game/services/theme_service.dart';
import 'package:n3rd_game/services/language_service.dart';
import 'package:n3rd_game/services/settings_service.dart';
import 'package:n3rd_game/services/learning_service.dart';
import 'package:n3rd_game/services/offline_service.dart';
import 'package:n3rd_game/services/accessibility_service.dart';
import 'package:n3rd_game/services/sound_service.dart';
import 'package:n3rd_game/services/notification_service.dart';
import 'package:n3rd_game/services/animation_randomizer_service.dart';
import 'package:n3rd_game/services/network_service.dart';
import 'package:n3rd_game/services/multiplayer_service.dart';
import 'package:n3rd_game/services/edition_access_service.dart';
import 'package:n3rd_game/services/family_group_service.dart';
import 'package:n3rd_game/services/friends_service.dart';
import 'package:n3rd_game/services/friend_score_service.dart';
import 'package:n3rd_game/services/direct_message_service.dart';
import 'package:n3rd_game/services/game_history_service.dart';
import 'package:n3rd_game/services/performance_monitoring_service.dart';
import 'package:n3rd_game/services/newsfeed_service.dart';
import 'package:n3rd_game/services/social_discovery_service.dart';
import 'package:n3rd_game/services/word_service.dart';
import 'package:n3rd_game/services/haptic_service.dart';
import 'package:n3rd_game/services/resource_manager.dart';
import 'package:n3rd_game/services/data_export_service.dart';
import 'package:n3rd_game/screens/friends_more_view_model.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/data/trivia_templates_consolidated.dart'
    deferred as templates;

/// Service registry for dependency injection
///
/// Centralizes all service provider configuration and manages
/// service dependencies and initialization order.
class ServiceRegistry {
  /// Initialize SubscriptionService asynchronously
  static Future<void> initializeSubscriptionService(
    SubscriptionService service,
    RevenueCatService revenueCat,
    AuthService auth,
  ) async {
    try {
      await service.init();
      if (revenueCat.isInitialized) {
        service.syncWithRevenueCat(revenueCat, auth);
      } else {
        LoggerService.debug('⚠️ SubscriptionService: RevenueCat not initialized, skipping sync.');
      }
    } catch (e) {
      LoggerService.error('SubscriptionService init error', error: e);
    }
  }

  /// Create all service providers
  ///
  /// Note: Services are created without calling init() here. They will be
  /// initialized asynchronously via AppInitializer.initializeServices()
  /// after providers are created.
  ///
  /// [revenueCatService] - Pre-initialized RevenueCat service
  ///
  /// Returns list of providers for MultiProvider
  static List<dynamic> createProviders({
    required RevenueCatService revenueCatService,
  }) {
    return [
      ChangeNotifierProvider<AuthService>(create: (_) => AuthService()),
      ChangeNotifierProvider<StatsService>(create: (_) => StatsService()),
      ChangeNotifierProvider<AnalyticsService>(create: (_) => AnalyticsService()),
      ChangeNotifierProvider<ChallengeService>(create: (_) => ChallengeService()),
      Provider(create: (_) => DailyChallengeLeaderboardService()),
      ChangeNotifierProvider<TextToSpeechService>(create: (_) => TextToSpeechService()),
      ChangeNotifierProvider<PronunciationDictionaryService>(create: (_) => PronunciationDictionaryService()),
      ChangeNotifierProvider<VoiceCalibrationService>(create: (_) => VoiceCalibrationService()),
      ChangeNotifierProvider<ThemeService>(create: (_) => ThemeService()),
      ChangeNotifierProvider<LanguageService>(create: (_) => LanguageService()),
      ChangeNotifierProvider<SettingsService>(create: (_) => SettingsService()),
      ChangeNotifierProvider<LearningService>(create: (_) => LearningService()),
      ChangeNotifierProvider<AccessibilityService>(create: (_) => AccessibilityService()),
      ChangeNotifierProvider<FreeTierService>(create: (_) => FreeTierService()),
      ChangeNotifierProvider<SoundService>(create: (_) => SoundService()),
      ChangeNotifierProvider<NotificationService>(create: (_) => NotificationService()),
      ChangeNotifierProvider<AnimationRandomizerService>(create: (_) => AnimationRandomizerService()),
      ChangeNotifierProvider<NetworkService>(create: (_) => NetworkService()),
      ChangeNotifierProvider<MultiplayerService>(create: (_) => MultiplayerService()),
      ChangeNotifierProvider<FamilyGroupService>(create: (_) => FamilyGroupService()),
      ChangeNotifierProvider<FriendsService>(create: (_) => FriendsService()),
      ChangeNotifierProvider<FriendScoreService>(create: (_) => FriendScoreService()),
      ChangeNotifierProvider<NewsfeedService>(create: (_) => NewsfeedService()),
      ChangeNotifierProvider<SocialDiscoveryService>(create: (_) => SocialDiscoveryService()),
      ChangeNotifierProvider<DirectMessageService>(create: (_) => DirectMessageService()),
      ChangeNotifierProvider<GameHistoryService>(create: (_) => GameHistoryService()),
      ChangeNotifierProvider<FriendsMoreViewModel>(create: (_) => FriendsMoreViewModel()),
      ChangeNotifierProvider<PerformanceMonitoringService>(create: (_) => PerformanceMonitoringService()),
      ChangeNotifierProvider<RevenueCatService>.value(value: revenueCatService),
      ChangeNotifierProvider<AIModeService>(create: (_) => AIModeService()),
      ChangeNotifierProvider<TriviaPersonalizationService>(create: (_) => TriviaPersonalizationService()),
      ChangeNotifierProvider<TriviaGamificationService>(create: (_) => TriviaGamificationService()),
      ChangeNotifierProvider<GameService>(
        create: (_) => GameService(),
      ),
      ChangeNotifierProvider<EditionAccessService>(create: (_) => EditionAccessService()),
      ChangeNotifierProvider<WordService>(create: (_) => WordService()),
      Provider(create: (_) => HapticService()),
      Provider(create: (_) => ResourceManager()),
      Provider(create: (_) => DataExportService()),
    ];
  }

  /// Create all proxy providers for service dependencies
  ///
  /// Returns list of proxy providers (mixed types)
  static List<dynamic> createProxyProviders() {
    return [
      // Wire AnalyticsService to MultiplayerService
      ProxyProvider<AnalyticsService, MultiplayerService>(
        update: (_, analytics, previous) {
          previous?.setAnalyticsService(analytics);
          return previous ?? MultiplayerService();
          // Note: init() will be called via AppInitializer.initializeServices()
        },
      ),
      // Connect RevenueCat and AuthService to SubscriptionService
      ChangeNotifierProxyProvider2<RevenueCatService, AuthService,
          SubscriptionService>(
        create: (_) => SubscriptionService(),
        update: (_, revenueCat, auth, previous) {
          final service = previous ?? SubscriptionService();
          initializeSubscriptionService(service, revenueCat, auth);
          return service;
        },
      ),
      // Wire AIEditionService to use personalization, generator, and analytics
      ProxyProvider3<TriviaPersonalizationService, TriviaGeneratorService,
          AnalyticsService, AIEditionService>(
        update: (_, personalization, generator, analytics, previous) {
          previous ??= AIEditionService();
          previous.setPersonalizationService(personalization);
          previous.setGeneratorService(generator);
          previous.setAnalyticsService(analytics);
          return previous;
        },
      ),
      // Wire TriviaGeneratorService to use personalization and analytics
      ProxyProvider2<TriviaPersonalizationService, AnalyticsService,
          TriviaGeneratorService>(
        update: (_, personalization, analytics, previous) {
          return _createTriviaGeneratorService(
            personalization: personalization,
            analytics: analytics,
            previous: previous,
          );
        },
      ),
      // Wire GameService to personalization and gamification
      ProxyProvider2<TriviaPersonalizationService, TriviaGamificationService,
          GameService>(
        update: (_, personalization, gamification, gameService) {
          final service = gameService ?? GameService();
          service.setPersonalizationService(personalization);
          service.setGamificationService(gamification);
          return service;
        },
      ),
      // Wire AnalyticsService to GameService
      ProxyProvider<AnalyticsService, GameService>(
        update: (_, analytics, gameService) {
          final service = gameService ?? GameService();
          service.setAnalyticsService(analytics);
          return service;
        },
      ),
      // Wire SubscriptionService to GameService
      ProxyProvider<SubscriptionService, GameService>(
        update: (_, subscription, gameService) {
          final service = gameService ?? GameService();
          service.setSubscriptionService(subscription);
          return service;
        },
      ),
      // Wire GameHistoryService to GameService
      ProxyProvider<GameHistoryService, GameService>(
        update: (_, gameHistory, gameService) {
          final service = gameService ?? GameService();
          service.setGameHistoryService(gameHistory);
          return service;
        },
      ),
      // Wire AnalyticsService to NetworkService
      ProxyProvider<AnalyticsService, NetworkService>(
        update: (_, analytics, previous) {
          previous?.setAnalyticsService(analytics);
          return previous ?? NetworkService();
          // Note: init() will be called via AppInitializer.initializeServices()
        },
      ),
      // Wire RevenueCatService and SubscriptionService to EditionAccessService
      ProxyProvider2<RevenueCatService, SubscriptionService,
          EditionAccessService>(
        update: (_, revenueCat, subscription, previous) {
          previous ??= EditionAccessService();
          // Note: init() will be called via AppInitializer.initializeServices()
          previous.setRevenueCatService(revenueCat);
          previous.setSubscriptionService(subscription);
          return previous;
        },
      ),
      // Wire NetworkService to OfflineService
      ChangeNotifierProxyProvider<NetworkService, OfflineService>(
        create: (_) => OfflineService(),
        update: (_, network, previous) {
          previous?.setNetworkService(network);
          return previous ?? OfflineService();
          // Note: init() will be called via AppInitializer.initializeServices()
        },
      ),
      // Wire VoiceCalibrationService to VoiceRecognitionService
      ChangeNotifierProxyProvider<VoiceCalibrationService, VoiceRecognitionService>(
        create: (_) => VoiceRecognitionService(),
        update: (_, calibration, voiceService) {
          voiceService?.setVoiceCalibrationService(calibration);
          return voiceService ?? VoiceRecognitionService();
          // Note: init() will be called via AppInitializer.initializeServices()
        },
      ),
    ];
  }

  /// Create TriviaGeneratorService with proper error handling
  static TriviaGeneratorService _createTriviaGeneratorService({
    required TriviaPersonalizationService personalization,
    required AnalyticsService analytics,
    TriviaGeneratorService? previous,
  }) {
    if (previous != null) {
      try {
        previous.setPersonalizationService(personalization);
        previous.setAnalyticsService(analytics);
      } catch (e) {
        LoggerService.debug('⚠️ Warning: Failed to set services on TriviaGeneratorService: $e',);
      }
      return previous;
    }

    // Check if templates are initialized - wrap in try-catch to handle deferred library not loaded yet
    bool templatesNotInitialized = false;
    String? templateError;
    try {
      templatesNotInitialized = !templates.EditionTriviaTemplates.isInitialized;
      if (templatesNotInitialized) {
        templateError = templates.EditionTriviaTemplates.lastValidationError ?? 'Unknown error';
      }
    } catch (e) {
      // Deferred library not loaded yet - this is expected during provider creation
      // Proceed directly to creating service, which will handle uninitialized state gracefully
      templatesNotInitialized = false; // Treat as initialized to skip the error path
    }

    if (templatesNotInitialized) {
      final errorMessage = 'TriviaGeneratorService initialization failed: '
          'Trivia templates were not initialized successfully. '
          'Error details: $templateError.';

      LoggerService.error('CRITICAL: $errorMessage');

      // Log to analytics
      try {
        analytics.logServiceInitializationFailure(
            'TriviaGeneratorService', templateError ?? 'Unknown error',);
      } catch (e) {
        // Ignore analytics errors
      }

      // Log to Crashlytics
      try {
        FirebaseCrashlytics.instance.recordError(
          Exception(errorMessage),
          StackTrace.current,
          reason: 'TriviaGeneratorService initialization failure',
          fatal: false,
        );
      } catch (e) {
        // Ignore Crashlytics errors
      }

      // Create service anyway to prevent null errors
      try {
        final service = TriviaGeneratorService();
        service.setPersonalizationService(personalization);
        service.setAnalyticsService(analytics);
        return service;
      } catch (e) {
        LoggerService.error('Failed to create TriviaGeneratorService', error: e);
        // Create fallback service instead of throwing
        try {
          final fallbackService = TriviaGeneratorService.fallback();
          fallbackService.setPersonalizationService(personalization);
          fallbackService.setAnalyticsService(analytics);
          return fallbackService;
        } catch (e2) {
          // Even fallback failed - return empty service
          LoggerService.error('Fallback service creation also failed', error: e2);
          final emptyService = TriviaGeneratorService.empty();
          // Try to set services even on empty service (may fail, but won't crash)
          try {
            emptyService.setPersonalizationService(personalization);
            emptyService.setAnalyticsService(analytics);
          } catch (_) {
            // Ignore - service is in empty mode
          }
          return emptyService;
        }
      }
    }

    // Templates initialized - create service normally
    try {
      final service = TriviaGeneratorService();
      service.setPersonalizationService(personalization);
      service.setAnalyticsService(analytics);
      return service;
    } catch (e, stackTrace) {
      final errorMessage = 'Failed to create TriviaGeneratorService: $e. '
          'This prevents the app from generating trivia questions.';

      if (kDebugMode) {
        LoggerService.error('CRITICAL: $errorMessage');
        LoggerService.debug('Stack trace: $stackTrace');
      }

      // Log to analytics
      try {
        analytics.logServiceInitializationFailure(
          'TriviaGeneratorService',
          '$e\nStack trace: $stackTrace',
        );
      } catch (analyticsError) {
        LoggerService.debug('⚠️ Warning: Failed to log initialization error to analytics: $analyticsError',);
      }

      // Log to Crashlytics
      try {
        FirebaseCrashlytics.instance.recordError(
          Exception(errorMessage),
          stackTrace,
          reason: 'TriviaGeneratorService initialization failure',
          fatal: false, // Changed from true to false
        );
      } catch (_) {
        // Ignore Crashlytics errors
      }

      // Final fallback - create fallback service instead of throwing
      try {
        final fallbackService = TriviaGeneratorService.fallback();
        fallbackService.setPersonalizationService(personalization);
        fallbackService.setAnalyticsService(analytics);
        return fallbackService;
      } catch (e2) {
        // Even fallback failed - return empty service
        LoggerService.error('Fallback service creation also failed', error: e2);
        final emptyService = TriviaGeneratorService.empty();
        // Try to set services even on empty service (may fail, but won't crash)
        try {
          emptyService.setPersonalizationService(personalization);
          emptyService.setAnalyticsService(analytics);
        } catch (_) {
          // Ignore - service is in empty mode
        }
        return emptyService;
      }
    }
  }
}
