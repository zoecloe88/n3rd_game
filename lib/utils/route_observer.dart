import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/services/analytics_service.dart';

/// NavigatorObserver that tracks screen views for analytics
class AnalyticsRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _trackScreenView(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _trackScreenView(newRoute);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null && previousRoute is PageRoute) {
      _trackScreenView(previousRoute);
    }
  }

  void _trackScreenView(Route<dynamic> route) {
    if (route is! PageRoute) return;

    final routeName = route.settings.name;
    if (routeName == null) return;

    // Map route names to screen names for analytics
    final screenName = _getScreenName(routeName);

    // Get analytics service from the navigator's context
    final navigatorState = route.navigator;
    final context = navigatorState?.context;
    if (context != null) {
      try {
        final analyticsService = Provider.of<AnalyticsService>(
          context,
          listen: false,
        );
        // Use unawaited since this is fire-and-forget tracking
        unawaited(analyticsService.logScreenView(screenName));
      } catch (e) {
        // Context might not have Provider yet - ignore
        // This is expected during initial app startup
      }
    }
  }

  String _getScreenName(String routeName) {
    // Clean up route names for analytics
    // Remove leading slash and replace hyphens with underscores
    final cleanName = routeName.replaceFirst('/', '').replaceAll('-', '_');

    // Map common routes to readable names
    final routeMap = {
      '/': 'splash',
      '/login': 'login',
      '/title': 'title',
      '/modes': 'modes',
      '/game': 'game',
      '/multiplayer-lobby': 'multiplayer_lobby',
      '/multiplayer-game': 'multiplayer_game',
      '/stats': 'stats',
      '/leaderboard': 'leaderboard',
      '/editions': 'editions',
      '/subscription-management': 'subscription_management',
      '/analytics': 'analytics_dashboard',
      '/daily-challenges': 'daily_challenges',
      '/settings': 'settings',
      '/privacy-policy': 'privacy_policy',
      '/terms-of-service': 'terms_of_service',
    };

    return routeMap[routeName] ?? cleanName;
  }
}
