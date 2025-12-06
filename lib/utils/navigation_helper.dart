import 'package:flutter/material.dart';

/// Helper class for safe navigation operations
class NavigationHelper {
  /// Switch to a main navigation tab (for use within MainNavigationWrapper)
  /// Uses pushReplacementNamed to avoid navigation conflicts
  static void switchToTab(BuildContext context, int tabIndex) {
    if (!context.mounted) return;

    final navigator = Navigator.of(context);

    // Use pushReplacementNamed to switch tabs without creating navigation conflicts
    switch (tabIndex) {
      case 0:
        navigator.pushReplacementNamed('/title');
        break;
      case 1:
        navigator.pushReplacementNamed('/modes');
        break;
      case 2:
        navigator.pushReplacementNamed('/stats');
        break;
      case 3:
        navigator.pushReplacementNamed('/leaderboard');
        break;
      case 4:
        navigator.pushReplacementNamed('/more');
        break;
    }
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
}
