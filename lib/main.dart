import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/utils/route_observer.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/services/theme_service.dart';
import 'package:n3rd_game/services/language_service.dart';
import 'package:n3rd_game/services/accessibility_service.dart';
import 'package:n3rd_game/widgets/initial_loading_screen_wrapper.dart';
import 'package:n3rd_game/screens/initialization_error_screen.dart';
import 'package:n3rd_game/widgets/error_boundary.dart';
import 'package:n3rd_game/core/app_initializer.dart';
import 'package:n3rd_game/core/service_registry.dart';
import 'package:n3rd_game/core/route_builder.dart';
import 'package:n3rd_game/core/app_configuration.dart';
import 'package:n3rd_game/widgets/auth_state_listener.dart';
import 'package:n3rd_game/utils/provider_helper.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize all core systems using AppInitializer
  final initResult = await AppInitializer.initialize();

  // Extract initialization results for use in app
  final firebaseInitialized = initResult.firebaseInitialized;
  final triviaInitializationFailed = !initResult.triviaInitialized;
  final triviaInitError = initResult.triviaInitError;
  final revenueCatService = initResult.revenueCatService;
  final appStartTime = initResult.appStartTime;

  // Create NavigatorObserver for screen view tracking
  final routeObserver = AnalyticsRouteObserver();

  runApp(
    MultiProvider(
      providers: [
        ...ServiceRegistry.createProviders(
          revenueCatService: revenueCatService,
        ),
        ...ServiceRegistry.createProxyProviders(),
      ],
      child: ErrorBoundary(
        child: AuthStateListener(
          child: Builder(
            builder: (context) {
              // CRITICAL: Use safe access instead of Consumer to prevent ProviderNotFoundException
              // Services are created but may not be initialized yet during first build
              final accessibilityService = ProviderHelper.safeGet<AccessibilityService>(context, listen: false);
              final themeService = ProviderHelper.safeGet<ThemeService>(context, listen: false);
              final languageService = ProviderHelper.safeGet<LanguageService>(context, listen: false);

              // Show blocking error screen if trivia initialization failed
              if (triviaInitializationFailed) {
                // Use safe defaults if services aren't available yet
                final fontSizeMultiplier = accessibilityService?.settings.fontSizeMultiplier ?? 1.0;

                return MaterialApp(
                  localizationsDelegates:
                      AppConfiguration.getLocalizationDelegates(),
                  supportedLocales: AppConfiguration.getSupportedLocales(),
                  locale: const Locale('en', ''),
                  debugShowCheckedModeBanner: false,
                  builder: AppConfiguration.createAccessibilityBuilder(
                    fontSizeMultiplier: fontSizeMultiplier,
                  ),
                  home: InitializationErrorScreen(
                    errorMessage:
                        'Failed to initialize trivia content. The app cannot start without valid trivia templates.',
                    recoveryAction:
                        'Please restart the app. If the problem persists, contact support.',
                    errorDetails: triviaInitError,
                  ),
                );
              }

              // Use safe defaults if services aren't available yet
              final fontSizeMultiplier = accessibilityService?.settings.fontSizeMultiplier ?? 1.0;
              final currentLocale = languageService?.currentLocale ?? const Locale('en', '');
              final isDarkMode = themeService?.isDarkMode ?? false;

              // Track app startup time after first frame
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final analyticsService = ProviderHelper.safeGet<AnalyticsService>(
                  context,
                  listen: false,
                );
                if (analyticsService != null) {
                  final startupDuration =
                      DateTime.now().difference(appStartTime);
                  analyticsService.logAppStartup(
                    startupDuration,
                    success: !triviaInitializationFailed,
                    firebaseInitialized: firebaseInitialized,
                    templatesInitialized: !triviaInitializationFailed,
                  );
                }

                // Initialize all services asynchronously
                AppInitializer.initializeServices(context).catchError((e) {
                if (kDebugMode) {
                  LoggerService.debug(
                      'Service initialization error (non-critical);: $e',
                    );
                  }
                  // Return a result indicating partial initialization
                  return ServiceInitializationResult(
                    initialized: false,
                    errors: {'General': e.toString()},
                  );
                });
              });

              return MaterialApp(
                // Force rebuild when language changes
                key: ValueKey(currentLocale.toString()),
                localizationsDelegates:
                    AppConfiguration.getLocalizationDelegates(),
                supportedLocales: AppConfiguration.getSupportedLocales(),
                locale: currentLocale,
                theme: AppConfiguration.createTheme(
                  isDarkMode: isDarkMode,
                ),
                darkTheme: AppConfiguration.createDarkTheme(),
                themeMode: AppConfiguration.getThemeMode(
                  isDarkMode: isDarkMode,
                ),
                builder: AppConfiguration.createAccessibilityBuilder(
                  fontSizeMultiplier: fontSizeMultiplier,
                ),
                home: const InitialLoadingScreenWrapper(),
                debugShowCheckedModeBanner: false,
                navigatorObservers: [routeObserver],
                routes: RouteBuilder.routes,
                onGenerateRoute: RouteBuilder.onGenerateRoute,
                onUnknownRoute: RouteBuilder.onUnknownRoute,
              );
            },
          ),
        ),
      ),
    ),
  );
}
