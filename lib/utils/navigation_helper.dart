import 'package:flutter/material.dart';
import 'package:n3rd_game/widgets/main_navigation_wrapper.dart';

/// Helper class for safe navigation operations
class NavigationHelper {
  /// Switch to a main navigation tab (for use within MainNavigationWrapper)
  /// CRITICAL FIX: Detects if already inside MainNavigationWrapper and uses its internal switchToTab
  /// This prevents navigation loops and state loss by avoiding recreation of MainNavigationWrapper
  static void switchToTab(BuildContext context, int tabIndex) {
    if (!context.mounted) return;

    // Validate tab index
    if (tabIndex < 0 || tabIndex > 4) {
      debugPrint('Invalid tab index: $tabIndex. Must be 0-4.');
      return;
    }

    // Try to find MainNavigationWrapper state in the widget tree
    // If we're already inside MainNavigationWrapper, use its internal switchToTab method
    final wrapperState = context.findAncestorStateOfType<MainNavigationWrapperState>();
    
    if (wrapperState != null) {
      // We're already inside MainNavigationWrapper - use its internal method
      // This prevents recreation and maintains state
      wrapperState.switchToTab(tabIndex);
      return;
    }

    // Not inside MainNavigationWrapper - navigate to the route
    // This will create a new MainNavigationWrapper instance
    final navigator = Navigator.of(context);
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
        route = '/friends'; // Fixed: tab 3 is FriendsAndMessagesScreen, not leaderboard
        break;
      case 4:
        route = '/more';
        break;
      default:
        route = '/title';
    }

    // Use pushNamedAndRemoveUntil to prevent navigation loops
    // This removes all previous routes and sets the new route as the only one
    navigator.pushNamedAndRemoveUntil(route, (route) => route.isFirst);
  }

  /// Safely navigate to a route with error handling
  static Future<void> safeNavigate(
    BuildContext context,
    String route, {
    Object? arguments,
    bool replace = false,
  }) async {
    if (!context.mounted) return;

    try {
      if (replace) {
        await Navigator.of(
          context,
        ).pushReplacementNamed(route, arguments: arguments);
      } else {
        await Navigator.of(context).pushNamed(route, arguments: arguments);
      }
    } catch (e) {
      debugPrint('Navigation error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Navigation error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Safely pop the current route
  static void safePop(BuildContext context, [Object? result]) {
    if (!context.mounted) return;
    try {
      Navigator.of(context).pop(result);
    } catch (e) {
      debugPrint('Navigation pop error: $e');
    }
  }

  /// Safely push a route
  static Future<T?> safePush<T>(BuildContext context, Route<T> route) async {
    if (!context.mounted) return null;
    try {
      return await Navigator.of(context).push(route);
    } catch (e) {
      debugPrint('Navigation push error: $e');
      return null;
    }
  }

  /// Safely navigate and remove all previous routes
  static Future<void> safeNavigateAndRemoveUntil(
    BuildContext context,
    String route,
    bool Function(Route<dynamic>) predicate, {
    Object? arguments,
  }) async {
    if (!context.mounted) return;

    try {
      await Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(route, predicate, arguments: arguments);
    } catch (e) {
      debugPrint('Navigation error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Navigation error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Safely push replacement named route
  static Future<void> safePushReplacementNamed(
    BuildContext context,
    String route, {
    Object? arguments,
  }) async {
    if (!context.mounted) return;

    try {
      await Navigator.of(context).pushReplacementNamed(
        route,
        arguments: arguments,
      );
    } catch (e) {
      debugPrint('Navigation error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Navigation error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
