import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/services/secure_storage_service.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/config/app_config.dart';

/// Service for persisting and restoring navigation state
/// Handles navigation stack persistence, last route tracking, and deep link restoration
class NavigationStateService {
  static const String _prefsKeyNavigationStack = 'navigation_stack';
  static const String _prefsKeyLastRoute = 'last_route';
  static const String _prefsKeyLastRouteArgs = 'last_route_args';
  static const String _prefsKeyNavigationHistory = 'navigation_history';

  final SecureStorageService _secureStorage = SecureStorageService();

  /// Save navigation stack state
  /// Stack is a list of route names in order from root to current
  Future<void> saveNavigationState(List<String> routeStack) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKeyNavigationStack, routeStack);
      LoggerService.debug(
          'Navigation state saved: ${routeStack.length} routes',);
    } catch (e) {
      LoggerService.warning('Failed to save navigation state', error: e);
    }
  }

  /// Restore navigation stack state
  /// Returns null if no saved state exists
  Future<List<String>?> restoreNavigationState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stack = prefs.getStringList(_prefsKeyNavigationStack);
      if (stack != null && stack.isNotEmpty) {
        LoggerService.debug(
            'Navigation state restored: ${stack.length} routes',);
        return stack;
      }
    } catch (e) {
      LoggerService.warning('Failed to restore navigation state', error: e);
    }
    return null;
  }

  /// Save last visited route with optional arguments
  Future<void> saveLastRoute(
      String route, Map<String, dynamic>? arguments,) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKeyLastRoute, route);

      if (arguments != null) {
        // Convert arguments to JSON for storage
        final argsJson = jsonEncode(arguments);
        await prefs.setString(_prefsKeyLastRouteArgs, argsJson);
      } else {
        await prefs.remove(_prefsKeyLastRouteArgs);
      }

      LoggerService.debug('Last route saved: $route');
    } catch (e) {
      LoggerService.warning('Failed to save last route', error: e);
    }
  }

  /// Get last visited route with arguments
  /// Returns (route, arguments) tuple, or (null, null) if none exists
  Future<(String?, Map<String, dynamic>?)> getLastRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final route = prefs.getString(_prefsKeyLastRoute);

      if (route == null) {
        return (null, null);
      }

      final argsJson = prefs.getString(_prefsKeyLastRouteArgs);
      Map<String, dynamic>? arguments;

      if (argsJson != null) {
        try {
          arguments = Map<String, dynamic>.from(jsonDecode(argsJson));
        } catch (e) {
          LoggerService.warning('Failed to parse last route arguments',
              error: e,);
        }
      }

      return (route, arguments);
    } catch (e) {
      LoggerService.warning('Failed to get last route', error: e);
      return (null, null);
    }
  }

  /// Add route to navigation history
  /// History tracks recent routes for analytics and debugging
  Future<void> addToHistory(String route,
      {Map<String, dynamic>? arguments,}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_prefsKeyNavigationHistory);

      List<Map<String, dynamic>> history = [];
      if (historyJson != null) {
        try {
          history = List<Map<String, dynamic>>.from(
            jsonDecode(historyJson).map((e) => Map<String, dynamic>.from(e)),
          );
        } catch (e) {
          LoggerService.warning('Failed to parse navigation history', error: e);
        }
      }

      // Add new entry with timestamp
      history.add({
        'route': route,
        'arguments': arguments,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Limit history size
      if (history.length > AppConfig.maxNavigationHistorySize) {
        history = history
            .sublist(history.length - AppConfig.maxNavigationHistorySize);
      }

      await prefs.setString(_prefsKeyNavigationHistory, jsonEncode(history));
    } catch (e) {
      LoggerService.warning('Failed to add to navigation history', error: e);
    }
  }

  /// Get navigation history
  Future<List<Map<String, dynamic>>> getHistory({int? limit}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_prefsKeyNavigationHistory);

      if (historyJson == null) {
        return [];
      }

      final history = List<Map<String, dynamic>>.from(
        jsonDecode(historyJson).map((e) => Map<String, dynamic>.from(e)),
      );

      if (limit != null && limit > 0 && history.length > limit) {
        return history.sublist(history.length - limit);
      }

      return history;
    } catch (e) {
      LoggerService.warning('Failed to get navigation history', error: e);
      return [];
    }
  }

  /// Save pending deep link for restoration after authentication
  /// Uses secure storage for sensitive deep links (e.g., family invitations)
  Future<void> savePendingDeepLink(String deepLink) async {
    try {
      await _secureStorage.saveString('pending_deep_link', deepLink);
      LoggerService.debug('Pending deep link saved');
    } catch (e) {
      LoggerService.warning('Failed to save pending deep link', error: e);
    }
  }

  /// Get and clear pending deep link
  Future<String?> getAndClearPendingDeepLink() async {
    try {
      final deepLink = await _secureStorage.getString('pending_deep_link');
      if (deepLink != null) {
        await _secureStorage.delete('pending_deep_link');
        LoggerService.debug('Pending deep link retrieved and cleared');
      }
      return deepLink;
    } catch (e) {
      LoggerService.warning('Failed to get pending deep link', error: e);
      return null;
    }
  }

  /// Clear all navigation state
  Future<void> clearNavigationState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKeyNavigationStack);
      await prefs.remove(_prefsKeyLastRoute);
      await prefs.remove(_prefsKeyLastRouteArgs);
      await prefs.remove(_prefsKeyNavigationHistory);
      await _secureStorage.delete('pending_deep_link');
      LoggerService.debug('Navigation state cleared');
    } catch (e) {
      LoggerService.warning('Failed to clear navigation state', error: e);
    }
  }

  /// Clear navigation history only (keep stack and last route)
  Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKeyNavigationHistory);
      LoggerService.debug('Navigation history cleared');
    } catch (e) {
      LoggerService.warning('Failed to clear navigation history', error: e);
    }
  }
}
