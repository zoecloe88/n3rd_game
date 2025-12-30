import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/widgets/main_navigation_wrapper.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/services/navigation_state_service.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/config/route_config.dart';

/// Navigation source tracking for analytics
enum NavigationSource {
  buttonTap,
  deepLink,
  backButton,
  programmatic,
  tabSwitch,
  unknown,
}

/// Helper class for safe navigation operations with analytics, state management, and error recovery
class NavigationHelper {
  static final NavigationStateService _stateService = NavigationStateService();

  /// Switch to a main navigation tab (for use within MainNavigationWrapper)
  /// CRITICAL FIX: Detects if already inside MainNavigationWrapper and uses its internal switchToTab
  /// This prevents navigation loops and state loss by avoiding recreation of MainNavigationWrapper
  static void switchToTab(
    BuildContext context,
    int tabIndex, {
    NavigationSource source = NavigationSource.tabSwitch,
  }) {
    if (!context.mounted) return;

    // Validate tab index
    if (tabIndex < 0 || tabIndex > 4) {
      LoggerService.warning('Invalid tab index: $tabIndex. Must be 0-4.');
      return;
    }

    // Try to find MainNavigationWrapper state in the widget tree
    // If we're already inside MainNavigationWrapper, use its internal switchToTab method
    final wrapperState =
        context.findAncestorStateOfType<MainNavigationWrapperState>();

    String route;
    switch (tabIndex) {
      case 0:
        route = '/title';
        break;
      case 1:
        route = '/modes';
        break;
      case 2:
        route = '/stats';
        break;
      case 3:
        route = '/friends';
        break;
      case 4:
        route = '/more';
        break;
      default:
        route = '/title';
    }

    if (wrapperState != null) {
      // We're already inside MainNavigationWrapper - use its internal method
      // This prevents recreation and maintains state
      wrapperState.switchToTab(tabIndex);
      _trackNavigation(context, route, source: source);
      return;
    }

    // Not inside MainNavigationWrapper - navigate to the route
    // This will create a new MainNavigationWrapper instance
    safeNavigateAndRemoveUntil(
      context,
      route,
      (route) => route.isFirst,
      source: source,
    );
  }

  /// Safely navigate to a route with error handling, analytics, and state management
  static Future<void> safeNavigate(
    BuildContext context,
    String route, {
    Object? arguments,
    bool replace = false,
    NavigationSource source = NavigationSource.programmatic,
    int maxRetries = 2,
  }) async {
    if (!context.mounted) return;

    // Validate route arguments if route config exists
    if (!RouteRegistry.validateRouteArguments(route, arguments)) {
      LoggerService.warning(
        'Route arguments validation failed for $route',
        error: Exception('Invalid arguments: $arguments'),
      );
    }

    final startTime = DateTime.now();
    final previousRoute = ModalRoute.of(context)?.settings.name ?? 'unknown';
    // Capture NavigatorState before async operations
    final navigator = Navigator.of(context);

    // Retry logic with exponential backoff
    int retries = 0;
    while (retries <= maxRetries) {
      try {
        // Save to navigation state before navigating
        final argsMap = arguments is Map<String, dynamic>
            ? arguments
            : arguments != null
                ? {'single_arg': arguments}
                : null;
        await _stateService.saveLastRoute(route, argsMap);
        await _stateService.addToHistory(route, arguments: argsMap);

        // Check if context is still mounted before using Navigator
        if (!context.mounted) return;

        if (replace) {
          await navigator.pushReplacementNamed(
            route,
            arguments: arguments,
          );
        } else {
          await navigator.pushNamed(route, arguments: arguments);
        }

        // Track successful navigation
        final duration = DateTime.now().difference(startTime).inMilliseconds;
        if (context.mounted) {
          _trackNavigation(
            context,
            route,
            previousRoute: previousRoute,
            duration: duration,
            source: source,
            success: true,
          );
        }

        return; // Success - exit retry loop
      } catch (e, stackTrace) {
        retries++;

        if (retries > maxRetries) {
          // All retries exhausted
          LoggerService.error(
            'Navigation error to route "$route" after $maxRetries retries',
            error: e,
            stack: stackTrace,
          );

          final duration = DateTime.now().difference(startTime).inMilliseconds;
          if (context.mounted) {
            _trackNavigation(
              context,
              route,
              previousRoute: previousRoute,
              duration: duration,
              source: source,
              success: false,
              error: e.toString(),
            );
          }

          if (context.mounted) {
            _showNavigationError(context, route, e);
          }
        } else {
          // Wait before retry with exponential backoff
          await Future.delayed(Duration(milliseconds: 100 * retries));
          LoggerService.debug(
            'Navigation retry $retries/$maxRetries for route "$route"',
          );
        }
      }
    }
  }

  /// Safely pop the current route with analytics tracking
  static void safePop(
    BuildContext context, [
    Object? result,
    NavigationSource source = NavigationSource.backButton,
  ]) {
    if (!context.mounted) return;

    final currentRoute = ModalRoute.of(context)?.settings.name;

    try {
      Navigator.of(context).pop(result);

      // Track back navigation
      if (currentRoute != null) {
        _trackNavigation(
          context,
          'back',
          previousRoute: currentRoute,
          source: source,
          success: true,
        );
      }
    } catch (e) {
      LoggerService.warning('Navigation pop error', error: e);
      _trackNavigation(
        context,
        'back',
        previousRoute: currentRoute,
        source: source,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Safely push a route with analytics and state management
  static Future<T?> safePush<T>(
    BuildContext context,
    Route<T> route, {
    NavigationSource source = NavigationSource.programmatic,
  }) async {
    if (!context.mounted) return null;

    final routeName = route.settings.name ?? 'unknown';
    final previousRoute = ModalRoute.of(context)?.settings.name ?? 'unknown';
    final startTime = DateTime.now();
    // Capture NavigatorState before async operations
    final navigator = Navigator.of(context);

    try {
      // Save to navigation state
      await _stateService.saveLastRoute(
        routeName,
        route.settings.arguments is Map<String, dynamic>
            ? route.settings.arguments as Map<String, dynamic>
            : null,
      );
      await _stateService.addToHistory(
        routeName,
        arguments: route.settings.arguments is Map<String, dynamic>
            ? route.settings.arguments as Map<String, dynamic>
            : null,
      );

      // Check if context is still mounted before using Navigator
      if (!context.mounted) return null;

      final result = await navigator.push(route);

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      if (context.mounted) {
        _trackNavigation(
          context,
          routeName,
          previousRoute: previousRoute,
          duration: duration,
          source: source,
          success: true,
        );
      }

      return result;
    } catch (e) {
      LoggerService.warning('Navigation push error', error: e);

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      if (context.mounted) {
        _trackNavigation(
          context,
          routeName,
          previousRoute: previousRoute,
          duration: duration,
          source: source,
          success: false,
          error: e.toString(),
        );
      }

      if (context.mounted) {
        _showNavigationError(context, routeName, e);
      }
      return null;
    }
  }

  /// Safely navigate and remove all previous routes with analytics and state management
  static Future<void> safeNavigateAndRemoveUntil(
    BuildContext context,
    String route,
    bool Function(Route<dynamic>) predicate, {
    Object? arguments,
    NavigationSource source = NavigationSource.programmatic,
  }) async {
    if (!context.mounted) return;

    final previousRoute = ModalRoute.of(context)?.settings.name ?? 'unknown';
    final startTime = DateTime.now();
    // Capture NavigatorState before async operations
    final navigator = Navigator.of(context);

    try {
      // Save to navigation state
      final argsMap = arguments is Map<String, dynamic>
          ? arguments
          : arguments != null
              ? {'single_arg': arguments}
              : null;
      await _stateService.saveLastRoute(route, argsMap);
      await _stateService.addToHistory(route, arguments: argsMap);

      // Check if context is still mounted before using Navigator
      if (!context.mounted) return;

      await navigator.pushNamedAndRemoveUntil(
        route,
        predicate,
        arguments: arguments,
      );

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      if (context.mounted) {
        _trackNavigation(
          context,
          route,
          previousRoute: previousRoute,
          duration: duration,
          source: source,
          success: true,
        );
      }
    } catch (e, stackTrace) {
      LoggerService.error(
        'Navigation error (removeUntil); to route "$route"',
        error: e,
        stack: stackTrace,
      );

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      if (context.mounted) {
        _trackNavigation(
          context,
          route,
          previousRoute: previousRoute,
          duration: duration,
          source: source,
          success: false,
          error: e.toString(),
        );
      }

      if (context.mounted) {
        _showNavigationError(context, route, e);
      }
    }
  }

  /// Safely push replacement named route with analytics and state management
  static Future<void> safePushReplacementNamed(
    BuildContext context,
    String route, {
    Object? arguments,
    NavigationSource source = NavigationSource.programmatic,
  }) async {
    if (!context.mounted) return;

    final previousRoute = ModalRoute.of(context)?.settings.name ?? 'unknown';
    final startTime = DateTime.now();
    // Capture NavigatorState before async operations
    final navigator = Navigator.of(context);

    try {
      // Save to navigation state
      final argsMap = arguments is Map<String, dynamic>
          ? arguments
          : arguments != null
              ? {'single_arg': arguments}
              : null;
      await _stateService.saveLastRoute(route, argsMap);
      await _stateService.addToHistory(route, arguments: argsMap);

      // Check if context is still mounted before using Navigator
      if (!context.mounted) return;

      await navigator.pushReplacementNamed(
        route,
        arguments: arguments,
      );

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      if (context.mounted) {
        _trackNavigation(
          context,
          route,
          previousRoute: previousRoute,
          duration: duration,
          source: source,
          success: true,
        );
      }
    } catch (e, stackTrace) {
      LoggerService.error(
        'Navigation error (pushReplacementNamed); to route "$route"',
        error: e,
        stack: stackTrace,
      );

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      if (context.mounted) {
        _trackNavigation(
          context,
          route,
          previousRoute: previousRoute,
          duration: duration,
          source: source,
          success: false,
          error: e.toString(),
        );
      }

      if (context.mounted) {
        _showNavigationError(context, route, e);
      }
    }
  }

  /// Track navigation event with analytics
  static void _trackNavigation(
    BuildContext context,
    String route, {
    String? previousRoute,
    int? duration,
    NavigationSource source = NavigationSource.unknown,
    bool success = true,
    String? error,
  }) {
    try {
      final analyticsService = Provider.of<AnalyticsService>(
        context,
        listen: false,
      );

      // Track screen view
      unawaited(analyticsService.logScreenView(route));

      // Track navigation transition if duration provided
      if (duration != null && previousRoute != null) {
        unawaited(
          analyticsService.logNavigationTransition(
            previousRoute,
            route,
            duration,
          ),
        );
      }

      // Track navigation errors
      if (!success && error != null) {
        unawaited(
          analyticsService.logNavigationError(
            route,
            error,
          ),
        );
      }
    } catch (e) {
      // Analytics service might not be available - ignore
      LoggerService.debug('Failed to track navigation analytics', error: e);
    }
  }

  /// Show user-friendly navigation error message
  static void _showNavigationError(
    BuildContext context,
    String route,
    dynamic error,
  ) {
    try {
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizations?.navigationError ??
                'Unable to navigate. Please try again.',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: localizations?.ok ?? 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    } catch (e) {
      // Fallback if ScaffoldMessenger not available
      LoggerService.warning('Failed to show navigation error', error: e);
    }
  }
}
