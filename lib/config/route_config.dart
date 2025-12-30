import 'package:flutter/material.dart';
import 'package:n3rd_game/models/game_room.dart';
import 'package:n3rd_game/models/game_mode_config.dart';
import 'package:n3rd_game/utils/page_transitions.dart';

/// Transition type for route navigation
enum RouteTransitionType {
  smooth, // Slide + fade transition (default)
  scale, // Scale + fade transition
  fade, // Fade only transition
  none, // No transition (MaterialPageRoute)
}

/// Route parameter definition for validation and documentation
class RouteParameter {
  const RouteParameter({
    required this.name,
    required this.type,
    this.required = false,
    this.description,
    this.defaultValue,
  });

  final String name;
  final Type type;
  final bool required;
  final String? description;
  final dynamic defaultValue;
}

/// Route configuration with metadata, parameters, and documentation
class RouteConfig {
  const RouteConfig({
    required this.path,
    this.requiresAuth = false,
    this.requiresPremium = false,
    this.requiresOnlineAccess = false,
    this.requiresEditionsAccess = false,
    this.requiresFamilyFriends = false,
    this.transitionType = RouteTransitionType.smooth,
    this.parameters = const {},
    this.documentation = '',
    this.transitionDuration = const Duration(milliseconds: 250),
  });

  final String path;
  final bool requiresAuth;
  final bool requiresPremium;
  final bool requiresOnlineAccess;
  final bool requiresEditionsAccess;
  final bool requiresFamilyFriends;
  final RouteTransitionType transitionType;
  final Map<String, RouteParameter> parameters;
  final String documentation;
  final Duration transitionDuration;

  /// Validate route arguments against parameter schema
  bool validateArguments(Object? arguments) {
    if (parameters.isEmpty) {
      return arguments == null || arguments is Map && arguments.isEmpty;
    }

    if (arguments == null) {
      // Check if all required parameters are missing
      return !parameters.values.any((param) => param.required);
    }

    if (arguments is Map) {
      final argsMap = arguments as Map<String, dynamic>;

      // Check required parameters
      for (final param in parameters.values) {
        if (param.required && !argsMap.containsKey(param.name)) {
          return false;
        }
        // Type checking would be more complex - simplified for now
        // In production, you'd want more robust type checking
        // For now, we only validate presence of required parameters
      }
      return true;
    }

    // Single argument (non-Map) - check if we have a single parameter
    if (parameters.length == 1) {
      final param = parameters.values.first;
      return arguments.runtimeType == param.type;
    }

    return false;
  }
}

/// Centralized route configuration registry
class RouteRegistry {
  /// All route configurations
  static const Map<String, RouteConfig> _routes = {
    '/instructions': RouteConfig(
      path: '/instructions',
      documentation: 'Game instructions screen',
    ),
    '/login': RouteConfig(
      path: '/login',
      documentation: 'User authentication screen',
    ),
    '/title': RouteConfig(
      path: '/title',
      requiresAuth: true,
      documentation: 'Main title/home screen (MainNavigationWrapper tab 0)',
    ),
    '/modes': RouteConfig(
      path: '/modes',
      requiresAuth: true,
      documentation: 'Game mode selection screen (MainNavigationWrapper tab 1)',
    ),
    '/game': RouteConfig(
      path: '/game',
      requiresAuth: true,
      parameters: {
        'mode': RouteParameter(
          name: 'mode',
          type: GameMode,
          required: false,
          description: 'Game mode to start',
        ),
        'difficulty': RouteParameter(
          name: 'difficulty',
          type: String,
          required: false,
          description: 'Difficulty level (easy, medium, hard, insane)',
        ),
        'customTriviaPool': RouteParameter(
          name: 'customTriviaPool',
          type: List,
          required: false,
          description: 'Custom trivia items for game',
        ),
      },
      documentation:
          'Main game screen. Accepts optional GameMode, difficulty, or custom trivia pool',
      transitionType: RouteTransitionType.smooth,
    ),
    '/mode-transition': RouteConfig(
      path: '/mode-transition',
      requiresAuth: true,
      parameters: {
        'mode': RouteParameter(
          name: 'mode',
          type: GameMode,
          required: false,
          description: 'GameMode object or Map with "mode" key',
        ),
      },
      documentation:
          'Transition screen before game starts. Accepts GameMode or Map with "mode" key',
      transitionType: RouteTransitionType.scale,
      transitionDuration: Duration(milliseconds: 400),
    ),
    '/multiplayer-lobby': RouteConfig(
      path: '/multiplayer-lobby',
      requiresAuth: true,
      requiresOnlineAccess: true,
      documentation: 'Multiplayer game lobby screen',
    ),
    '/multiplayer-loading': RouteConfig(
      path: '/multiplayer-loading',
      requiresAuth: true,
      requiresOnlineAccess: true,
      parameters: {
        'mode': RouteParameter(
          name: 'mode',
          type: MultiplayerMode,
          required: true,
          description: 'Multiplayer game mode',
        ),
      },
      documentation:
          'Loading screen before multiplayer game starts. Requires MultiplayerMode argument',
    ),
    '/multiplayer-game': RouteConfig(
      path: '/multiplayer-game',
      requiresAuth: true,
      requiresOnlineAccess: true,
      documentation: 'Active multiplayer game screen',
    ),
    '/direct-message': RouteConfig(
      path: '/direct-message',
      requiresAuth: true,
      requiresOnlineAccess: true,
      documentation: 'Direct messaging screen',
    ),
    '/onboarding': RouteConfig(
      path: '/onboarding',
      documentation: 'User onboarding flow',
    ),
    '/stats': RouteConfig(
      path: '/stats',
      requiresAuth: true,
      documentation: 'Statistics screen (MainNavigationWrapper tab 2)',
    ),
    '/leaderboard': RouteConfig(
      path: '/leaderboard',
      requiresAuth: true,
      requiresOnlineAccess: true,
      documentation: 'Global leaderboard screen',
    ),
    '/game-history': RouteConfig(
      path: '/game-history',
      requiresAuth: true,
      documentation: 'User game history screen',
    ),
    '/friends': RouteConfig(
      path: '/friends',
      requiresAuth: true,
      requiresOnlineAccess: true,
      documentation:
          'Friends and messages screen (MainNavigationWrapper tab 3)',
    ),
    '/newsfeed': RouteConfig(
      path: '/newsfeed',
      requiresAuth: true,
      requiresOnlineAccess: true,
      documentation: 'Social newsfeed screen',
    ),
    '/social-discovery': RouteConfig(
      path: '/social-discovery',
      requiresAuth: true,
      requiresOnlineAccess: true,
      documentation: 'Social discovery screen',
    ),
    '/more': RouteConfig(
      path: '/more',
      requiresAuth: true,
      documentation: 'More menu screen (MainNavigationWrapper tab 4)',
    ),
    '/word-of-day': RouteConfig(
      path: '/word-of-day',
      requiresAuth: true,
      documentation: 'Word of the day screen',
    ),
    '/editions-selection': RouteConfig(
      path: '/editions-selection',
      requiresAuth: true,
      requiresEditionsAccess: true,
      documentation: 'Trivia edition selection screen',
    ),
    '/editions': RouteConfig(
      path: '/editions',
      requiresAuth: true,
      requiresEditionsAccess: true,
      documentation: 'Available editions screen',
    ),
    '/youth-editions': RouteConfig(
      path: '/youth-editions',
      requiresAuth: true,
      requiresEditionsAccess: true,
      documentation: 'Youth edition selection screen',
    ),
    '/subscription-management': RouteConfig(
      path: '/subscription-management',
      requiresAuth: true,
      documentation: 'Subscription management screen',
    ),
    '/family-management': RouteConfig(
      path: '/family-management',
      requiresAuth: true,
      requiresFamilyFriends: true,
      documentation: 'Family group management screen',
    ),
    '/family-invitation': RouteConfig(
      path: '/family-invitation',
      requiresAuth: true,
      requiresOnlineAccess: true,
      parameters: {
        'groupId': RouteParameter(
          name: 'groupId',
          type: String,
          required: false,
          description:
              'Family group ID from deep link (can be in query params, path, or arguments)',
        ),
      },
      documentation:
          'Family group invitation screen. Supports deep links: /family-invitation?groupId=xxx or /family-invitation/xxx',
      transitionType: RouteTransitionType.smooth,
    ),
    '/general-transition': RouteConfig(
      path: '/general-transition',
      requiresAuth: true,
      parameters: {
        'routeAfter': RouteParameter(
          name: 'routeAfter',
          type: String,
          required: false,
          description: 'Route to navigate to after transition',
          defaultValue: '/title',
        ),
        'routeArgs': RouteParameter(
          name: 'routeArgs',
          type: Object,
          required: false,
          description: 'Arguments for the routeAfter navigation',
        ),
      },
      documentation:
          'General transition screen. Accepts routeAfter (defaults to /title) and optional routeArgs',
      transitionType: RouteTransitionType.smooth,
    ),
    '/privacy-policy': RouteConfig(
      path: '/privacy-policy',
      documentation: 'Privacy policy screen',
    ),
    '/terms-of-service': RouteConfig(
      path: '/terms-of-service',
      documentation: 'Terms of service screen',
    ),
    '/ai-edition-history': RouteConfig(
      path: '/ai-edition-history',
      requiresAuth: true,
      requiresEditionsAccess: true,
      documentation: 'AI edition history screen',
    ),
    '/ai-edition-input': RouteConfig(
      path: '/ai-edition-input',
      requiresAuth: true,
      requiresEditionsAccess: true,
      parameters: {
        'isYouthEdition': RouteParameter(
          name: 'isYouthEdition',
          type: bool,
          required: false,
          description: 'Whether this is a youth edition',
          defaultValue: false,
        ),
      },
      documentation:
          'AI edition input/creation screen. Accepts optional isYouthEdition boolean',
      transitionType: RouteTransitionType.smooth,
    ),
    '/analytics': RouteConfig(
      path: '/analytics',
      requiresAuth: true,
      requiresPremium: true,
      documentation: 'Analytics dashboard screen (Premium only)',
    ),
    '/daily-challenges': RouteConfig(
      path: '/daily-challenges',
      requiresAuth: true,
      requiresOnlineAccess: true,
      documentation: 'Daily challenges screen',
    ),
    '/voice-calibration': RouteConfig(
      path: '/voice-calibration',
      requiresAuth: true,
      requiresPremium: true,
      documentation: 'Voice calibration screen (Premium only)',
    ),
    '/themes': RouteConfig(
      path: '/themes',
      requiresAuth: true,
      documentation: 'Theme selection screen',
    ),
    '/learning': RouteConfig(
      path: '/learning',
      requiresAuth: true,
      requiresPremium: true,
      documentation: 'Learning mode screen (Premium only)',
    ),
    '/performance-insights': RouteConfig(
      path: '/performance-insights',
      requiresAuth: true,
      requiresPremium: true,
      documentation: 'Performance insights screen (Premium only)',
    ),
    '/practice': RouteConfig(
      path: '/practice',
      requiresAuth: true,
      requiresPremium: true,
      documentation: 'Practice mode screen (Premium only)',
    ),
    '/trivia-creator': RouteConfig(
      path: '/trivia-creator',
      requiresAuth: true,
      requiresPremium: true,
      documentation: 'Trivia creator screen (Premium only)',
    ),
    '/help-center': RouteConfig(
      path: '/help-center',
      requiresAuth: true,
      documentation: 'Help center screen',
    ),
    '/support-dashboard': RouteConfig(
      path: '/support-dashboard',
      requiresAuth: true,
      documentation: 'Support dashboard screen',
    ),
    '/achievements': RouteConfig(
      path: '/achievements',
      requiresAuth: true,
      documentation: 'User achievements screen',
    ),
    '/settings': RouteConfig(
      path: '/settings',
      requiresAuth: true,
      documentation: 'Application settings screen',
    ),
  };

  /// Get route configuration by path
  static RouteConfig? getRouteConfig(String? path) {
    if (path == null) return null;
    return _routes[path];
  }

  /// Get all route paths
  static List<String> getAllRoutes() {
    return _routes.keys.toList();
  }

  /// Check if route requires authentication
  static bool requiresAuth(String? path) {
    return getRouteConfig(path)?.requiresAuth ?? false;
  }

  /// Check if route requires premium subscription
  static bool requiresPremium(String? path) {
    return getRouteConfig(path)?.requiresPremium ?? false;
  }

  /// Check if route requires online access
  static bool requiresOnlineAccess(String? path) {
    return getRouteConfig(path)?.requiresOnlineAccess ?? false;
  }

  /// Check if route requires editions access
  static bool requiresEditionsAccess(String? path) {
    return getRouteConfig(path)?.requiresEditionsAccess ?? false;
  }

  /// Check if route requires family/friends access
  static bool requiresFamilyFriends(String? path) {
    return getRouteConfig(path)?.requiresFamilyFriends ?? false;
  }

  /// Get transition type for route
  static RouteTransitionType getTransitionType(String? path) {
    return getRouteConfig(path)?.transitionType ?? RouteTransitionType.smooth;
  }

  /// Create a Route with appropriate transition based on config
  static Route<T> createRoute<T>({
    required String path,
    required Widget page,
    RouteSettings? settings,
    Object? arguments,
  }) {
    final config = getRouteConfig(path);
    if (config == null) {
      // Fallback to MaterialPageRoute for unknown routes
      return MaterialPageRoute<T>(
        builder: (_) => page,
        settings: settings ?? RouteSettings(name: path, arguments: arguments),
      );
    }

    final routeSettings = settings ??
        RouteSettings(
          name: path,
          arguments: arguments,
        );

    switch (config.transitionType) {
      case RouteTransitionType.smooth:
        return PageTransitions.smoothTransition<T>(
          page: page,
          settings: routeSettings,
          duration: config.transitionDuration,
        );
      case RouteTransitionType.scale:
        return PageTransitions.scaleTransition<T>(
          page: page,
          settings: routeSettings,
          duration: config.transitionDuration,
        );
      case RouteTransitionType.fade:
        return PageTransitions.fadeTransition<T>(
          page: page,
          settings: routeSettings,
          duration: config.transitionDuration,
        );
      case RouteTransitionType.none:
        return MaterialPageRoute<T>(
          builder: (_) => page,
          settings: routeSettings,
        );
    }
  }

  /// Get documentation for a route
  static String getDocumentation(String? path) {
    final config = getRouteConfig(path);
    if (config == null) return 'Unknown route: $path';

    final buffer = StringBuffer();
    buffer.writeln(config.documentation);

    if (config.parameters.isNotEmpty) {
      buffer.writeln('\nParameters:');
      for (final param in config.parameters.values) {
        buffer.write('  - ${param.name} (${param.type}): ');
        if (param.required) {
          buffer.write('REQUIRED');
        } else {
          buffer.write('OPTIONAL');
          if (param.defaultValue != null) {
            buffer.write(' (default: ${param.defaultValue})');
          }
        }
        if (param.description != null) {
          buffer.write(' - ${param.description}');
        }
        buffer.writeln();
      }
    }

    return buffer.toString();
  }

  /// Validate route arguments
  static bool validateRouteArguments(String? path, Object? arguments) {
    final config = getRouteConfig(path);
    if (config == null) return true; // Unknown routes pass validation
    return config.validateArguments(arguments);
  }
}
