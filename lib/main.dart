import 'dart:async' show Future, StreamSubscription;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/utils/route_observer.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:n3rd_game/services/revenue_cat_service.dart';
import 'package:n3rd_game/config/app_config.dart';
import 'package:n3rd_game/data/trivia_templates_consolidated.dart' deferred as templates;
import 'package:n3rd_game/widgets/initial_loading_screen_wrapper.dart';
import 'package:n3rd_game/screens/instructions_screen.dart';
import 'package:n3rd_game/screens/word_of_day_screen.dart';
import 'package:n3rd_game/screens/login_screen.dart';
import 'package:n3rd_game/screens/mode_transition_screen.dart';
import 'package:n3rd_game/screens/general_transition_screen.dart';
import 'package:n3rd_game/screens/game_screen.dart';
import 'package:n3rd_game/screens/multiplayer_lobby_screen.dart';
import 'package:n3rd_game/screens/multiplayer_loading_screen.dart';
import 'package:n3rd_game/screens/multiplayer_game_screen.dart';
import 'package:n3rd_game/screens/direct_message_screen.dart';
import 'package:n3rd_game/screens/onboarding_screen.dart';
import 'package:n3rd_game/screens/editions_selection_screen.dart';
import 'package:n3rd_game/screens/editions_screen.dart';
import 'package:n3rd_game/screens/youth_editions_screen.dart';
import 'package:n3rd_game/screens/subscription_management_screen.dart';
import 'package:n3rd_game/screens/family_management_screen.dart';
import 'package:n3rd_game/screens/family_invitation_screen.dart';
import 'package:n3rd_game/screens/analytics_dashboard_screen.dart';
import 'package:n3rd_game/screens/daily_challenges_screen.dart';
import 'package:n3rd_game/screens/voice_calibration_screen.dart';
import 'package:n3rd_game/screens/themes_screen.dart';
import 'package:n3rd_game/screens/learning_mode_screen.dart';
import 'package:n3rd_game/screens/performance_insights_screen.dart';
import 'package:n3rd_game/screens/practice_mode_screen.dart';
import 'package:n3rd_game/screens/trivia_creator_screen.dart';
import 'package:n3rd_game/screens/help_center_screen.dart';
import 'package:n3rd_game/screens/support_dashboard_screen.dart';
import 'package:n3rd_game/screens/privacy_policy_screen.dart';
import 'package:n3rd_game/screens/terms_of_service_screen.dart';
import 'package:n3rd_game/screens/ai_edition_history_screen.dart';
import 'package:n3rd_game/screens/ai_edition_input_screen.dart';
import 'package:n3rd_game/screens/achievements_screen.dart';
import 'package:n3rd_game/screens/settings_screen.dart';
import 'package:n3rd_game/screens/initialization_error_screen.dart';
import 'package:n3rd_game/widgets/main_navigation_wrapper.dart';
import 'package:n3rd_game/widgets/error_boundary.dart';
import 'package:n3rd_game/widgets/route_guard.dart';
import 'package:n3rd_game/models/game_room.dart';
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
import 'package:n3rd_game/services/text_to_speech_service.dart';
import 'package:n3rd_game/services/voice_recognition_service.dart';
import 'package:n3rd_game/services/pronunciation_dictionary_service.dart';
import 'package:n3rd_game/services/voice_calibration_service.dart';
import 'package:n3rd_game/services/theme_service.dart';
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
import 'package:n3rd_game/exceptions/app_exceptions.dart';

/// Initialize SubscriptionService asynchronously
/// Standardized async pattern using async/await instead of .then()
Future<void> _initializeSubscriptionService(
  SubscriptionService service,
  RevenueCatService revenueCat,
  AuthService auth,
) async {
  try {
    await service.init();
    // Only sync if RevenueCat is initialized (prevents errors if RevenueCat failed)
    if (revenueCat.isInitialized) {
      service.syncWithRevenueCat(revenueCat, auth);
    } else if (kDebugMode) {
      debugPrint(
        '⚠️ SubscriptionService: RevenueCat not initialized, skipping sync. Will sync when RevenueCat initializes.',
      );
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('❌ SubscriptionService init error: $e');
    }
    // Continue without sync - local tier is loaded from SharedPreferences
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Track app startup time for performance monitoring
  final appStartTime = DateTime.now();

  // Store auth state subscription to prevent memory leak
  // Note: This subscription persists for app lifetime (intentional - no cancellation needed)
  // ignore: unused_local_variable
  StreamSubscription<User?>? authStateSubscription;

  // Initialize Firebase (must be done before Crashlytics and FCM background handler)
  bool firebaseInitialized = false;
  String? firebaseInitError;
  try {
    await Firebase.initializeApp();
    firebaseInitialized = true;

    // CRITICAL: Register background message handler BEFORE any other Firebase operations
    // This must be registered at the top level, before runApp()
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      // Background message handler registration failure is non-critical
      // The app can still function without push notifications
      if (kDebugMode) {
        debugPrint(
          '⚠️ Warning: Failed to register Firebase background message handler: $e',
        );
      }
    }

    // AI Edition now uses Firebase Cloud Functions
    // API keys are stored server-side and never exposed to clients
    if (kDebugMode) {
      debugPrint('✓ Firebase initialized successfully');
      debugPrint('✓ AI Edition configured to use Firebase Cloud Functions');
    }
  } catch (e, stackTrace) {
    firebaseInitError = e.toString();
    if (kDebugMode) {
      debugPrint('❌ CRITICAL: Firebase initialization failed: $e');
      debugPrint('Stack trace: $stackTrace');
    }
    // App will continue but Firebase features will be disabled
    // Services that depend on Firebase will check isFirebaseInitialized
    // before attempting Firebase operations
  }

  // Initialize Firebase Crashlytics error handlers
  // Use the firebaseInitialized flag from initialization above
  final isFirebaseInitialized = firebaseInitialized ||
      (() {
        // Fallback check in case flag wasn't set correctly
        try {
          Firebase.app();
          return true;
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              'Firebase not initialized - Crashlytics will be disabled: $e',
            );
            if (firebaseInitError != null) {
              debugPrint('Original Firebase init error: $firebaseInitError');
            }
          }
          return false;
        }
      }());

  // Global error handler for all Flutter framework errors
  // This complements ErrorWidget.builder (which handles widget build errors)
  // by catching async errors, render errors, and other runtime exceptions
  //
  // Architecture:
  // - ErrorWidget.builder (in ErrorBoundary): Handles synchronous widget BUILD errors
  // - FlutterError.onError (here): Handles ALL other Flutter errors (async, render, etc.)
  // Both work together: ErrorWidget.builder shows user-friendly UI, this logs to analytics
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    // Log to console in debug mode
    if (kDebugMode) {
      debugPrint('Flutter Error: ${details.exception}');
      debugPrint('Stack trace: ${details.stack}');
    }
    // Log to Firebase Crashlytics only if Firebase is initialized
    // This ensures all errors are tracked in production for debugging
    if (isFirebaseInitialized) {
      try {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Failed to log to Crashlytics: $e');
        }
      }
    }
  };

  // Platform error handler
  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      debugPrint('Platform Error: $error');
      debugPrint('Stack trace: $stack');
    }
    // Log to Crashlytics only if Firebase is initialized
    if (isFirebaseInitialized) {
      try {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Failed to log to Crashlytics: $e');
        }
      }
    }
    return true; // Handled
  };

  // Initialize trivia templates (before AnalyticsService is available)
  // Analytics tracking will be done after AnalyticsService is initialized
  // CRITICAL: If template initialization fails, show blocking error screen
  // This prevents the app from starting in a broken state
  // Load templates library (deferred import to reduce kernel size)
  bool triviaInitializationFailed = false;
  String? triviaInitError;
  try {
    // CRITICAL: Load library first, then initialize
    await templates.loadLibrary();
    // Small delay to ensure library is fully loaded
    await Future.delayed(const Duration(milliseconds: 100));
    await templates.EditionTriviaTemplates.initialize();
    if (!templates.EditionTriviaTemplates.isInitialized) {
      triviaInitializationFailed = true;
      triviaInitError =
          templates.EditionTriviaTemplates.lastValidationError ?? 'Unknown error';
      if (kDebugMode) {
        debugPrint(
          '❌ CRITICAL ERROR: Template initialization failed: $triviaInitError',
        );
      }
      // Log to Crashlytics for production monitoring
      if (isFirebaseInitialized) {
        try {
          FirebaseCrashlytics.instance.recordError(
            Exception(
              'Trivia template initialization failed: $triviaInitError',
            ),
            StackTrace.current,
            reason:
                'Critical app initialization failure - trivia templates not initialized',
            fatal: false,
          );
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Failed to log trivia init error to Crashlytics: $e');
          }
        }
      }
    } else {
      if (kDebugMode) {
        debugPrint('✓ Trivia templates initialized successfully');
      }
    }
  } catch (e) {
    triviaInitializationFailed = true;
    triviaInitError = e.toString();
    if (kDebugMode) {
      debugPrint('❌ CRITICAL ERROR: Failed to initialize trivia templates: $e');
    }
    // Log to Crashlytics for production monitoring
    if (isFirebaseInitialized) {
      try {
        FirebaseCrashlytics.instance.recordError(
          e,
          StackTrace.current,
          reason:
              'Critical app initialization failure - trivia template exception',
          fatal: false,
        );
      } catch (crashlyticsError) {
        if (kDebugMode) {
          debugPrint(
            'Failed to log trivia init exception to Crashlytics: $crashlyticsError',
          );
        }
      }
    }
  }

  // Store reference for later analytics tracking
  // AnalyticsService will track template initialization status during its init()

  // Initialize RevenueCat
  final revenueCatService = RevenueCatService();
  try {
    // Get RevenueCat API key (may throw in production if not set via environment variable)
    String revenueCatApiKey;
    try {
      revenueCatApiKey = AppConfig.revenueCatApiKey;
    } catch (e) {
      // AppConfig.revenueCatApiKey throws in production if key is not provided
      if (kDebugMode) {
        debugPrint(
          '⚠️ Warning: RevenueCat API key not set. Subscriptions will not work.',
        );
        debugPrint('   Error: $e');
      }
      // Continue without RevenueCat - app will function but purchases won't work
      revenueCatApiKey = '';
    }

    if (revenueCatApiKey.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ Warning: RevenueCat API key is empty. Subscriptions will not work.',
        );
      }
      // Continue without RevenueCat - app will function but purchases won't work
    } else {
      await revenueCatService.initialize(revenueCatApiKey);

      // Sync Firebase user if already logged in
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        await revenueCatService.syncFirebaseUser();
      }

      // Listen to auth changes to sync RevenueCat
      // Store subscription to prevent memory leak (subscription persists for app lifetime - no cancellation needed)
      authStateSubscription = FirebaseAuth.instance.authStateChanges().listen((
        user,
      ) {
        if (user != null && revenueCatService.isInitialized) {
          revenueCatService.syncFirebaseUser();
        } else if (user == null && revenueCatService.isInitialized) {
          revenueCatService.logOut();
        }
      });

      if (kDebugMode) {
        debugPrint('RevenueCat initialized successfully');
      }
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('RevenueCat initialization error: $e');
    }
    // App continues without RevenueCat - purchases won't work
  }

  // Note: authStateSubscription is intentionally not canceled
  // It should persist for the app lifetime to sync RevenueCat with Firebase auth changes

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Create NavigatorObserver for screen view tracking
  final routeObserver = AnalyticsRouteObserver();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()..init()),
        // GameService is now provided by ChangeNotifierProxyProvider below
        ChangeNotifierProvider(create: (_) => StatsService()),
        ChangeNotifierProvider(create: (_) => AnalyticsService()..init()),
        ChangeNotifierProvider(create: (_) => ChallengeService()..init()),
        ChangeNotifierProvider(create: (_) => TextToSpeechService()..init()),
        ChangeNotifierProvider(
          create: (_) => VoiceRecognitionService()..init(),
        ),
        ChangeNotifierProvider(
          create: (_) => PronunciationDictionaryService()..init(),
        ),
        ChangeNotifierProvider(
          create: (_) => VoiceCalibrationService()..init(),
        ),
        ChangeNotifierProvider(create: (_) => ThemeService()..init()),
        ChangeNotifierProvider(create: (_) => LearningService()..init()),
        ChangeNotifierProvider(create: (_) => OfflineService()..init()),
        ChangeNotifierProvider(create: (_) => AccessibilityService()..init()),
        ChangeNotifierProvider(create: (_) => FreeTierService()..init()),
        ChangeNotifierProvider(create: (_) => SoundService()..init()),
        ChangeNotifierProvider(create: (_) => NotificationService()..init()),
        ChangeNotifierProvider(
          create: (_) => AnimationRandomizerService()..init(),
        ),
        ChangeNotifierProvider(create: (_) => NetworkService()..init()),
        ChangeNotifierProvider(create: (_) => MultiplayerService()..init()),
        // Wire AnalyticsService to MultiplayerService for performance tracking
        ProxyProvider<AnalyticsService, MultiplayerService>(
          update: (_, analytics, previous) {
            previous?.setAnalyticsService(analytics);
            return previous ?? MultiplayerService()..init();
          },
        ),
        // EditionAccessService is provided below via ProxyProvider2
        ChangeNotifierProvider(create: (_) => FamilyGroupService()..init()),
        ChangeNotifierProvider(create: (_) => FriendsService()..init()),
        // Add RevenueCatService provider
        ChangeNotifierProvider.value(value: revenueCatService),
        // Connect RevenueCat and AuthService to SubscriptionService
        // CRITICAL: Ensure init() completes before syncWithRevenueCat to prevent race conditions
        // Use ChangeNotifierProxyProvider2 since SubscriptionService extends ChangeNotifier
        ChangeNotifierProxyProvider2<RevenueCatService, AuthService, SubscriptionService>(
          create: (_) => SubscriptionService(),
          update: (_, revenueCat, auth, previous) {
            final service = previous ?? SubscriptionService();
            // Ensure init() completes before syncWithRevenueCat
            // Using standardized async/await pattern via helper function
            _initializeSubscriptionService(service, revenueCat, auth);
            return service;
          },
        ),
        ChangeNotifierProvider(create: (_) => AIModeService()..init()),
        // Create shared personalization service instance
        ChangeNotifierProvider(create: (_) => TriviaPersonalizationService()),
        // Wire AIEditionService to use personalization, generator, and analytics services
        ProxyProvider3<
          TriviaPersonalizationService,
          TriviaGeneratorService,
          AnalyticsService,
          AIEditionService
        >(
          update: (_, personalization, generator, analytics, previous) {
            previous ??= AIEditionService();
            previous.setPersonalizationService(personalization);
            previous.setGeneratorService(generator);
            previous.setAnalyticsService(analytics);
            return previous;
          },
        ),
        ChangeNotifierProvider(create: (_) => TriviaGamificationService()),
        // Wire TriviaGeneratorService to use the same personalization instance and analytics
        // CRITICAL: Validate templates are initialized before creating service
        ProxyProvider2<
          TriviaPersonalizationService,
          AnalyticsService,
          TriviaGeneratorService
        >(
          update: (_, personalization, analytics, previous) {
            // Only create new instance if it doesn't exist
            if (previous == null) {
              // Validate templates are initialized before creating service
              if (!templates.EditionTriviaTemplates.isInitialized) {
                final error =
                    templates.EditionTriviaTemplates.lastValidationError ??
                    'Unknown error';
                final errorMessage =
                    'TriviaGeneratorService initialization failed: '
                    'Trivia templates were not initialized successfully. '
                    'This prevents the app from generating trivia questions. '
                    'Error details: $error. '
                    'Please check that EditionTriviaTemplates.initialize() completed successfully.';

                if (kDebugMode) {
                  debugPrint('❌ CRITICAL: $errorMessage');
                  debugPrint(
                    '   App will continue but trivia generation will fail.',
                  );
                  debugPrint(
                    '   Users will see an error message when attempting to play games.',
                  );
                }

                // Log to analytics if available
                try {
                  analytics.logServiceInitializationFailure(
                    'TriviaGeneratorService',
                    error,
                  );
                } catch (e) {
                  // Ignore analytics errors during initialization
                }

                // Throw exception - ProxyProvider will catch it and prevent service creation
                // The app will continue but trivia generation will show error to user
                throw ValidationException(errorMessage);
              }

              try {
                previous = TriviaGeneratorService();
              } catch (e, stackTrace) {
                final errorMessage =
                    'Failed to create TriviaGeneratorService: $e. '
                    'This prevents the app from generating trivia questions. '
                    'Users will see an error message when attempting to play games.';

                if (kDebugMode) {
                  debugPrint('❌ CRITICAL: $errorMessage');
                  debugPrint('Stack trace: $stackTrace');
                }

                // Log to analytics if available
                try {
                  analytics.logServiceInitializationFailure(
                    'TriviaGeneratorService',
                    '$e\nStack trace: $stackTrace',
                  );
                } catch (analyticsError) {
                  // Ignore analytics errors during initialization
                  if (kDebugMode) {
                    debugPrint(
                      '⚠️ Warning: Failed to log initialization error to analytics: $analyticsError',
                    );
                  }
                }

                // Re-throw to prevent invalid service creation
                rethrow;
              }
            }

            // Set optional services (safe to call even if service creation was delayed)
            try {
              previous.setPersonalizationService(personalization);
              previous.setAnalyticsService(analytics);
            } catch (e) {
              if (kDebugMode) {
                debugPrint(
                  '⚠️ Warning: Failed to set services on TriviaGeneratorService: $e',
                );
              }
              // Continue - service might still work for basic operations
            }

            return previous;
          },
        ),
        // Wire GameService to personalization, gamification, and analytics services
        ProxyProvider2<
          TriviaPersonalizationService,
          TriviaGamificationService,
          GameService
        >(
          update: (_, personalization, gamification, previous) {
            previous ??= GameService();
            previous.setPersonalizationService(personalization);
            previous.setGamificationService(gamification);
            return previous;
          },
        ),
        // Wire AnalyticsService to GameService
        ChangeNotifierProxyProvider<AnalyticsService, GameService>(
          create: (_) => GameService(),
          update: (_, analytics, previous) {
            previous ??= GameService();
            previous.setAnalyticsService(analytics);
            return previous;
          },
        ),
        // Wire SubscriptionService to GameService
        ChangeNotifierProxyProvider<SubscriptionService, GameService>(
          create: (_) => GameService(),
          update: (_, subscription, previous) {
            previous ??= GameService();
            previous.setSubscriptionService(subscription);
            return previous;
          },
        ),
        // Wire AnalyticsService to NetworkService for performance tracking
        ProxyProvider<AnalyticsService, NetworkService>(
          update: (_, analytics, previous) {
            // NetworkService is already created by ChangeNotifierProvider above
            // Just wire analytics service to it
            previous?.setAnalyticsService(analytics);
            return previous ?? NetworkService()
              ..init();
          },
        ),
        // Add EditionAccessService provider
        ChangeNotifierProvider(create: (_) => EditionAccessService()..init()),
        // Wire RevenueCatService and SubscriptionService to EditionAccessService
        ProxyProvider2<
          RevenueCatService,
          SubscriptionService,
          EditionAccessService
        >(
          update: (_, revenueCat, subscription, previous) {
            previous ??= EditionAccessService()..init();
            previous.setRevenueCatService(revenueCat);
            previous.setSubscriptionService(subscription);
            return previous;
          },
        ),
      ],
      child: ErrorBoundary(
        child: _AuthStateListener(
          child: Builder(
            builder: (context) {
              // Show blocking error screen if trivia initialization failed
              if (triviaInitializationFailed) {
                return MaterialApp(
                  // Localization support
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  supportedLocales: const [
                    Locale('en', ''), // English
                  ],
                  locale: const Locale('en', ''),
                  debugShowCheckedModeBanner: false,
                  home: InitializationErrorScreen(
                    errorMessage:
                        'Failed to initialize trivia content. The app cannot start without valid trivia templates.',
                    recoveryAction:
                        'Please restart the app. If the problem persists, contact support.',
                    errorDetails: triviaInitError,
                  ),
                );
              }

              return Consumer<ThemeService>(
                builder: (context, themeService, _) {
                  // Track app startup time after first frame
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final analyticsService = Provider.of<AnalyticsService>(
                      context,
                      listen: false,
                    );
                    final startupDuration = DateTime.now().difference(appStartTime);
                    analyticsService.logAppStartup(
                      startupDuration,
                      success: !triviaInitializationFailed,
                      firebaseInitialized: firebaseInitialized,
                      templatesInitialized: !triviaInitializationFailed,
                    );
                  });

                  return MaterialApp(
                    // Localization support
                    localizationsDelegates: const [
                      AppLocalizations.delegate,
                      GlobalMaterialLocalizations.delegate,
                      GlobalWidgetsLocalizations.delegate,
                      GlobalCupertinoLocalizations.delegate,
                    ],
                    supportedLocales: const [
                      Locale('en', ''), // English
                      // Add more locales as needed: Locale('es', ''), Locale('fr', ''), etc.
                    ],
                    locale: const Locale('en', ''),
                    // Theme configuration
                    theme: ThemeData(
                      brightness: themeService.brightness,
                      useMaterial3: true,
                      colorScheme: ColorScheme.fromSeed(
                        seedColor: AppColors.primaryButton,
                        brightness: themeService.brightness,
                      ),
                      scaffoldBackgroundColor: themeService.isDarkMode
                          ? AppColors.darkCardBackground
                          : AppColors.cardBackground,
                      cardColor: themeService.isDarkMode
                          ? AppColors.darkCardBackground
                          : AppColors.cardBackground,
                    ),
                    darkTheme: ThemeData(
                      brightness: Brightness.dark,
                      useMaterial3: true,
                      colorScheme: ColorScheme.fromSeed(
                        seedColor: AppColors.darkPrimaryButton,
                        brightness: Brightness.dark,
                      ),
                      scaffoldBackgroundColor: AppColors.darkCardBackground,
                      cardColor: AppColors.darkCardBackground,
                    ),
                    themeMode: themeService.isDarkMode
                        ? ThemeMode.dark
                        : ThemeMode.light,
                    home: const InitialLoadingScreenWrapper(),
                    debugShowCheckedModeBanner: false,
                    navigatorObservers: [routeObserver],
                    routes: {
                      '/instructions': (context) => const InstructionsScreen(),
                      '/login': (context) => const LoginScreen(),
                      '/title': (context) =>
                          const MainNavigationWrapper(initialIndex: 0),
                      '/modes': (context) =>
                          const MainNavigationWrapper(initialIndex: 1),
                      '/game': (context) => const GameScreen(),
                      '/multiplayer-lobby': (context) => const RouteGuard(
                          requiresOnlineAccess: true,
                          featureName: 'Multiplayer Lobby',
                          child: MultiplayerLobbyScreen(),
                        ),
                      '/multiplayer-game': (context) => const RouteGuard(
                          requiresOnlineAccess: true,
                          featureName: 'Multiplayer Game',
                          child: MultiplayerGameScreen(),
                        ),
                      '/direct-message': (context) => const RouteGuard(
                          requiresOnlineAccess: true,
                          featureName: 'Direct Messages',
                          child: DirectMessageScreen(),
                        ),
                      '/onboarding': (context) => const OnboardingScreen(),
                      '/stats': (context) =>
                          const MainNavigationWrapper(initialIndex: 2),
                      '/leaderboard': (context) => const RouteGuard(
                          requiresOnlineAccess: true,
                          featureName: 'Leaderboard',
                          child: MainNavigationWrapper(initialIndex: 2),
                        ),
                      '/friends': (context) => const RouteGuard(
                          requiresOnlineAccess: true,
                          featureName: 'Friends',
                          child: MainNavigationWrapper(initialIndex: 3),
                        ),
                      '/more': (context) =>
                          const MainNavigationWrapper(initialIndex: 4),
                      '/word-of-day': (context) => const WordOfDayScreen(),
                      '/editions-selection': (context) => const RouteGuard(
                          requiresEditionsAccess: true,
                          featureName: 'Editions Selection',
                          child: EditionsSelectionScreen(),
                        ),
                      '/editions': (context) => const RouteGuard(
                          requiresEditionsAccess: true,
                          featureName: 'Editions',
                          child: EditionsScreen(),
                        ),
                      '/youth-editions': (context) => const RouteGuard(
                          requiresEditionsAccess: true,
                          featureName: 'Youth Editions',
                          child: YouthEditionsScreen(),
                        ),
                      '/subscription-management': (context) =>
                          const SubscriptionManagementScreen(),
                      '/family-management': (context) => const RouteGuard(
                          requiresFamilyFriends: true,
                          featureName: 'Family Management',
                          child: FamilyManagementScreen(),
                        ),
                      '/family-invitation': (context) {
                        final args = ModalRoute.of(context)?.settings.arguments;
                        final groupId = args is String ? args : null;
                        return RouteGuard(
                          requiresOnlineAccess: true,
                          featureName: 'Family Invitation',
                          child: FamilyInvitationScreen(groupId: groupId),
                        );
                      },
                      '/privacy-policy': (context) =>
                          const PrivacyPolicyScreen(),
                      '/terms-of-service': (context) =>
                          const TermsOfServiceScreen(),
                      '/ai-edition-history': (context) => const RouteGuard(
                          requiresEditionsAccess: true,
                          featureName: 'AI Edition History',
                          child: AIEditionHistoryScreen(),
                        ),
                      '/analytics': (context) => const RouteGuard(
                          requiresPremium: true,
                          featureName: 'Analytics Dashboard',
                          child: AnalyticsDashboardScreen(),
                        ),
                      '/daily-challenges': (context) => const RouteGuard(
                          requiresOnlineAccess: true,
                          featureName: 'Daily Challenges',
                          child: DailyChallengesScreen(),
                        ),
                      '/voice-calibration': (context) => const RouteGuard(
                          requiresPremium: true,
                          featureName: 'Voice Calibration',
                          child: VoiceCalibrationScreen(),
                        ),
                      '/themes': (context) => const ThemesScreen(),
                      '/learning': (context) => const RouteGuard(
                          requiresPremium: true,
                          featureName: 'Learning Mode',
                          child: LearningModeScreen(),
                        ),
                      '/performance-insights': (context) => const RouteGuard(
                          requiresPremium: true,
                          featureName: 'Performance Insights',
                          child: PerformanceInsightsScreen(),
                        ),
                      '/practice': (context) => const RouteGuard(
                          requiresPremium: true,
                          featureName: 'Practice Mode',
                          child: PracticeModeScreen(),
                        ),
                      '/trivia-creator': (context) => const RouteGuard(
                          requiresPremium: true,
                          featureName: 'Trivia Creator',
                          child: TriviaCreatorScreen(),
                        ),
                      '/help-center': (context) => const HelpCenterScreen(),
                      '/support-dashboard': (context) =>
                          const SupportDashboardScreen(),
                      '/achievements': (context) => const AchievementsScreen(),
                      '/settings': (context) => const SettingsScreen(),
                    },
                    onGenerateRoute: (settings) {
                      // Handle routes with arguments
                      if (settings.name == '/game' &&
                          settings.arguments != null) {
                        return MaterialPageRoute(
                          builder: (context) => const GameScreen(),
                          settings: settings,
                        );
                      }
                      if (settings.name == '/mode-transition') {
                        // Validate arguments - should be GameMode or Map with 'mode' key
                        final args = settings.arguments;
                        if (args != null) {
                          // Accept GameMode directly or Map with 'mode' key (for shuffle mode)
                          if (args is GameMode ||
                              (args is Map && args.containsKey('mode'))) {
                            return MaterialPageRoute(
                              builder: (context) =>
                                  const ModeTransitionScreen(),
                              settings: settings,
                            );
                          }
                        } else {
                          // Allow null arguments (will use default behavior)
                          return MaterialPageRoute(
                            builder: (context) => const ModeTransitionScreen(),
                            settings: settings,
                          );
                        }
                      }
                      if (settings.name == '/multiplayer-loading' &&
                          settings.arguments != null) {
                        return MaterialPageRoute(
                          builder: (context) => MultiplayerLoadingScreen(
                            mode: settings.arguments as MultiplayerMode,
                          ),
                          settings: settings,
                        );
                      }
                      if (settings.name == '/general-transition') {
                        final args =
                            settings.arguments as Map<String, dynamic>?;
                        // Validate routeAfter exists and is a String, fallback to '/title'
                        final routeAfter =
                            (args != null &&
                                args.containsKey('routeAfter') &&
                                args['routeAfter'] is String)
                            ? args['routeAfter'] as String
                            : '/title';
                        return MaterialPageRoute(
                          builder: (context) => GeneralTransitionScreen(
                            routeAfter: routeAfter,
                            routeArgs: args?['routeArgs'],
                          ),
                          settings: settings,
                        );
                      }
                      // Handle family invitation deep links
                      // Format: /family-invitation?groupId=xxx or /family-invitation/xxx
                      if (settings.name != null &&
                          settings.name!.startsWith('/family-invitation')) {
                        String? groupId;
                        // Check if groupId is in query parameters or path
                        if (settings.arguments is Map) {
                          final args = settings.arguments as Map<String, dynamic>;
                          groupId = args['groupId'] as String?;
                        } else if (settings.arguments is String) {
                          groupId = settings.arguments as String;
                        } else if (settings.name!.contains('?')) {
                          // Extract from query string
                          final uri = Uri.parse(settings.name!);
                          groupId = uri.queryParameters['groupId'];
                        } else if (settings.name!.split('/').length > 2) {
                          // Extract from path: /family-invitation/groupId
                          final parts = settings.name!.split('/');
                          if (parts.length >= 3) {
                            groupId = parts[2];
                          }
                        }
                        return MaterialPageRoute(
                          builder: (context) => FamilyInvitationScreen(
                            groupId: groupId,
                          ),
                          settings: settings,
                        );
                      }
                      if (settings.name == '/ai-edition-input') {
                        final args =
                            settings.arguments as Map<String, dynamic>?;
                        return MaterialPageRoute(
                          builder: (context) => RouteGuard(
                            requiresEditionsAccess: true,
                            featureName: 'AI Edition Input',
                            child: AIEditionInputScreen(
                              isYouthEdition:
                                  args?['isYouthEdition'] as bool? ?? false,
                            ),
                          ),
                          settings: settings,
                        );
                      }
                      return null;
                    },
                    onUnknownRoute: (settings) {
                      if (kDebugMode) {
                        debugPrint('Unknown route: ${settings.name}');
                      }
                      return MaterialPageRoute(
                        builder: (context) => Scaffold(
                          backgroundColor: Colors.black,
                          body: SafeArea(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      size: 64,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'Page Not Found',
                                      style: AppTypography.headlineLarge
                                          .copyWith(color: Colors.white),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'The page "${settings.name}" could not be found.',
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: Colors.white70,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 32),
                                    ElevatedButton(
                                      onPressed: () {
                                        NavigationHelper.safeNavigate(
                                          context,
                                          '/title',
                                          replace: true,
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 32,
                                          vertical: 16,
                                        ),
                                      ),
                                      child: Text(
                                        'Go Home',
                                        style: AppTypography.labelLarge,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    ),
  );
}

/// Widget that listens to auth state changes and navigates accordingly
class _AuthStateListener extends StatefulWidget {
  final Widget child;

  const _AuthStateListener({required this.child});

  @override
  State<_AuthStateListener> createState() => _AuthStateListenerState();
}

class _AuthStateListenerState extends State<_AuthStateListener> {
  @override
  void initState() {
    super.initState();
    // Listen to auth state changes after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final authService = Provider.of<AuthService>(context, listen: false);
        authService.addListener(_onAuthStateChanged);
      }
    });
  }

  @override
  void dispose() {
    if (mounted) {
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        authService.removeListener(_onAuthStateChanged);
      } catch (e) {
        // Ignore if context is not available
      }
    }
    super.dispose();
  }

  void _onAuthStateChanged() {
    if (!mounted) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final navigator = Navigator.of(context);

    // Get current route
    final currentRoute = ModalRoute.of(context)?.settings.name;

    // List of routes that require authentication
    const protectedRoutes = [
      '/title',
      '/modes',
      '/game',
      '/stats',
      '/leaderboard',
      '/settings',
      '/word-of-day',
      '/editions',
      '/subscription-management',
    ];

    // If user logged out and is on a protected route, redirect to login
    // Use pushNamedAndRemoveUntil to clear navigation stack and go to login
    // This works regardless of whether we can pop (removes all routes)
    if (!authService.isAuthenticated &&
        currentRoute != null &&
        protectedRoutes.contains(currentRoute)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.mounted) {
          navigator.pushNamedAndRemoveUntil('/login', (route) => false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
