import 'package:flutter/material.dart';
import 'package:n3rd_game/config/route_config.dart';
import 'package:n3rd_game/models/game_room.dart';
import 'package:n3rd_game/widgets/route_guard.dart';
import 'package:n3rd_game/screens/instructions_screen.dart';
import 'package:n3rd_game/screens/login_screen.dart';
import 'package:n3rd_game/screens/mode_transition_screen.dart';
import 'package:n3rd_game/screens/general_transition_screen.dart';
import 'package:n3rd_game/screens/game_screen.dart';
import 'package:n3rd_game/screens/multiplayer_lobby_screen.dart';
import 'package:n3rd_game/screens/multiplayer_loading_screen.dart';
import 'package:n3rd_game/screens/multiplayer_game_screen.dart';
import 'package:n3rd_game/screens/direct_message_screen.dart';
import 'package:n3rd_game/screens/onboarding_screen.dart';
import 'package:n3rd_game/screens/leaderboard_screen.dart';
import 'package:n3rd_game/screens/game_history_screen.dart';
import 'package:n3rd_game/screens/newsfeed_screen.dart';
import 'package:n3rd_game/screens/social_discovery_screen.dart';
import 'package:n3rd_game/screens/word_of_day_screen.dart';
import 'package:n3rd_game/screens/editions_selection_screen.dart';
import 'package:n3rd_game/screens/editions_screen.dart';
import 'package:n3rd_game/screens/youth_editions_screen.dart';
import 'package:n3rd_game/screens/subscription_management_screen.dart';
import 'package:n3rd_game/screens/family_management_screen.dart';
import 'package:n3rd_game/screens/family_invitation_screen.dart';
import 'package:n3rd_game/screens/privacy_policy_screen.dart';
import 'package:n3rd_game/screens/terms_of_service_screen.dart';
import 'package:n3rd_game/screens/ai_edition_history_screen.dart';
import 'package:n3rd_game/screens/ai_edition_input_screen.dart';
import 'package:n3rd_game/screens/analytics_dashboard_screen.dart';
import 'package:n3rd_game/screens/daily_challenges_screen.dart';
import 'package:n3rd_game/screens/voice_calibration_screen.dart';
import 'package:n3rd_game/screens/themes_screen.dart';
import 'package:n3rd_game/screens/learning_mode_screen.dart';
import 'package:n3rd_game/screens/performance_insights_screen.dart';
import 'package:n3rd_game/screens/practice_mode_screen.dart';
import 'package:n3rd_game/screens/help_center_screen.dart';
import 'package:n3rd_game/screens/support_dashboard_screen.dart';
import 'package:n3rd_game/screens/achievements_screen.dart';
import 'package:n3rd_game/screens/settings_screen.dart';
import 'package:n3rd_game/widgets/main_navigation_wrapper.dart';
import 'package:n3rd_game/models/game_mode_config.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/theme/app_typography.dart';

/// Provides centralized route generation and management for the application.
class RouteBuilder {
  /// Defines the static route map for the application.
  static Map<String, WidgetBuilder> get routes => {
        '/instructions': (context) => const InstructionsScreen(),
        '/login': (context) => const LoginScreen(),
        '/title': (context) => const MainNavigationWrapper(initialIndex: 0),
        '/modes': (context) => const MainNavigationWrapper(initialIndex: 1),
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
        '/stats': (context) => const MainNavigationWrapper(initialIndex: 2),
        '/leaderboard': (context) => const RouteGuard(
              requiresOnlineAccess: true,
              featureName: 'Leaderboard',
              child: LeaderboardScreen(),
            ),
        '/game-history': (context) => const GameHistoryScreen(),
        '/friends': (context) => const RouteGuard(
              requiresOnlineAccess: true,
              featureName: 'Friends',
              child: MainNavigationWrapper(initialIndex: 3),
            ),
        '/newsfeed': (context) => const RouteGuard(
              requiresOnlineAccess: true,
              featureName: 'Newsfeed',
              child: NewsfeedScreen(),
            ),
        '/social-discovery': (context) => const RouteGuard(
              requiresOnlineAccess: true,
              featureName: 'Social Discovery',
              child: SocialDiscoveryScreen(),
            ),
        '/more': (context) => const MainNavigationWrapper(initialIndex: 4),
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
        '/privacy-policy': (context) => const PrivacyPolicyScreen(),
        '/terms-of-service': (context) => const TermsOfServiceScreen(),
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
        '/help-center': (context) => const HelpCenterScreen(),
        '/support-dashboard': (context) => const SupportDashboardScreen(),
        '/achievements': (context) => const AchievementsScreen(),
        '/settings': (context) => const SettingsScreen(),
      };

  /// Handles dynamic route generation based on `RouteSettings`.
  ///
  /// This method is used for routes that require argument validation or
  /// special handling (e.g., deep links, transitions).
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final routeName = settings.name;

    // Handle /game route
    if (routeName == '/game') {
      RouteRegistry.validateRouteArguments(routeName, settings.arguments);
      return RouteRegistry.createRoute(
        path: routeName ?? '/game',
        page: const GameScreen(),
        settings: settings,
        arguments: settings.arguments,
      );
    }

    // Handle /mode-transition route
    if (routeName == '/mode-transition') {
      final args = settings.arguments;
      if (args == null ||
          args is GameMode ||
          (args is Map && args.containsKey('mode'))) {
        return RouteRegistry.createRoute(
          path: routeName ?? '/mode-transition',
          page: const ModeTransitionScreen(),
          settings: settings,
          arguments: settings.arguments,
        );
      }
    }

    // Handle /multiplayer-loading route
    if (routeName == '/multiplayer-loading') {
      final args = settings.arguments;
      if (args != null && args is MultiplayerMode) {
        return RouteRegistry.createRoute(
          path: routeName ?? '/multiplayer-loading',
          page: MultiplayerLoadingScreen(mode: args),
          settings: settings,
          arguments: settings.arguments,
        );
      } else {
        return RouteRegistry.createRoute(
          path: '/multiplayer-loading',
          page: _buildErrorScreen(
            'Invalid Game Mode',
            'The game mode information is missing or invalid. Please try again.',
            '/modes',
          ),
          settings: settings,
        );
      }
    }

    // Handle /general-transition route
    if (routeName == '/general-transition') {
      final args = settings.arguments as Map<String, dynamic>?;
      final routeAfter = (args != null &&
              args.containsKey('routeAfter') &&
              args['routeAfter'] is String)
          ? args['routeAfter'] as String
          : '/title';
      return RouteRegistry.createRoute(
        path: routeName ?? '/general-transition',
        page: GeneralTransitionScreen(
          routeAfter: routeAfter,
          routeArgs: args?['routeArgs'],
        ),
        settings: settings,
        arguments: settings.arguments,
      );
    }

    // Handle /ai-edition-input route
    if (routeName == '/ai-edition-input') {
      final args = settings.arguments as Map<String, dynamic>?;
      return RouteRegistry.createRoute(
        path: routeName ?? '/ai-edition-input',
        page: RouteGuard(
          requiresEditionsAccess: true,
          featureName: 'AI Edition Input',
          child: AIEditionInputScreen(
            isYouthEdition: args?['isYouthEdition'] as bool? ?? false,
          ),
        ),
        settings: settings,
        arguments: settings.arguments,
      );
    }

    // Handle family invitation deep links
    // Format: /family-invitation?groupId=xxx or /family-invitation/xxx
    if (routeName != null && routeName.startsWith('/family-invitation')) {
      String? groupId;
      // Check if groupId is in query parameters or path
      if (settings.arguments is Map) {
        final args = settings.arguments as Map<String, dynamic>;
        groupId = args['groupId'] as String?;
      } else if (settings.arguments is String) {
        groupId = settings.arguments as String;
      } else if (routeName.contains('?')) {
        // Extract from query string
        final uri = Uri.parse(routeName);
        groupId = uri.queryParameters['groupId'];
      } else if (routeName.split('/').length > 2) {
        // Extract from path: /family-invitation/groupId
        final parts = routeName.split('/');
        if (parts.length >= 3) {
          groupId = parts[2];
        }
      }
      return RouteRegistry.createRoute(
        path: routeName,
        page: RouteGuard(
          requiresOnlineAccess: true,
          featureName: 'Family Invitation',
          child: FamilyInvitationScreen(groupId: groupId),
        ),
        settings: settings,
        arguments: settings.arguments,
      );
    }

    return null;
  }

  /// Handles unknown routes by showing an error screen
  static Route<dynamic> onUnknownRoute(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          // CRITICAL: Wrap in SingleChildScrollView to prevent RenderFlex overflow
          // This allows content to scroll if it exceeds screen height
          child: SingleChildScrollView(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Page Not Found',
                      style: AppTypography.headlineLarge.copyWith(
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The page "${settings.name}" could not be found.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                      // CRITICAL: Add overflow handling for long route names
                      overflow: TextOverflow.ellipsis,
                      maxLines: 3,
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
      ),
    );
  }

  /// Builds error screen widget
  static Widget _buildErrorScreen(
      String title, String message, String fallbackRoute,) {
    return Builder(
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
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed(fallbackRoute);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
