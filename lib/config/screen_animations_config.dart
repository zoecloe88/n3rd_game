/// Configuration for which screens should have animation overlays (1012x1024)
///
/// Maps screen routes to their corresponding animation video paths.
/// Animations are displayed as overlays on the common background.
class ScreenAnimationsConfig {
  /// Map of screen routes to animation paths
  ///
  /// Key: Screen route (e.g., '/title', '/settings')
  /// Value: Path to 1012x1024 animation video
  static const Map<String, String> screenAnimations = {
    // Main navigation screens with specific animations
    '/title': 'assets/animations/title/title screen.mp4',
    '/settings': 'assets/animations/settings/setting screen.mp4',
    '/modes': 'assets/animations/mode_selection/mode selection screen.mp4',
    '/stats': 'assets/animations/stats/stat screen.mp4',
    '/word-of-day': 'assets/animations/word_of_day/word of the day.mp4',

    // Social and competitive screens
    '/login': 'assets/animations/shared/8.mp4',
    '/leaderboard': 'assets/animations/shared/11.mp4',
    '/friends': 'assets/animations/shared/10.mp4',
    '/direct-message': 'assets/animations/shared/10.mp4',
    '/conversations': 'assets/animations/shared/10.mp4',

    // Feature screens
    '/daily-challenges': 'assets/animations/shared/11.mp4',
    '/analytics': 'assets/animations/shared/8.mp4',
    '/help-center': 'assets/animations/shared/10.mp4',
  };

  /// Get animation path for a specific route
  ///
  /// Returns the animation path if configured, null otherwise
  static String? getAnimationForRoute(String? route) {
    if (route == null) return null;
    return screenAnimations[route];
  }

  /// Check if a route has an animation configured
  static bool hasAnimation(String? route) {
    return route != null && screenAnimations.containsKey(route);
  }
}
