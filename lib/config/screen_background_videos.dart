import 'package:flutter/material.dart';

/// Configuration mapping screens/routes to their background videos
/// Videos are intentionally oversized (2000x3000) to preserve logo animation quality
class ScreenBackgroundVideos {
  // Base path for all screen background videos
  static const String _basePath =
      'assets/animations/Green Neutral Simple Serendipity Phone Wallpaper(1)';

  // Video mapping by route name
  static const Map<String, String> _routeToVideo = {
    '/login': '$_basePath/login screen.mp4',
    '/title': '$_basePath/title screen.mp4',
    '/settings': '$_basePath/setting screen.mp4',
    '/stats': '$_basePath/stat screen.mp4',
    '/modes': '$_basePath/mode selection screen.mp4',
    '/game':
        '$_basePath/mode selection screen.mp4', // Game screen uses mode selection background
    '/word-of-day': '$_basePath/word of the day.mp4',
    '/editions': '$_basePath/edition.mp4',
    '/editions-selection': '$_basePath/edition.mp4',
    '/youth-editions': '$_basePath/youth screen.mp4',
    '/mode-transition': '$_basePath/mode selection transition screen.mp4',
    '/friends':
        '$_basePath/title screen.mp4', // Friends screen uses title background
    '/more': '$_basePath/title screen.mp4', // More menu uses title background
  };

  /// Get background video path for a route
  /// Returns null if no video is configured for the route
  static String? getVideoForRoute(String? route) {
    if (route == null) return null;
    return _routeToVideo[route];
  }

  /// Get background video path for current route from context
  static String? getVideoForCurrentRoute(BuildContext context) {
    final route = ModalRoute.of(context)?.settings.name;
    return getVideoForRoute(route);
  }
}
