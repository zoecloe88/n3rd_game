/// Maps screen routes to their icon animation paths
/// Videos are labeled by screen and should replace icons on those screens
class IconAnimationMapping {
  /// Get animation path for icons on a specific screen
  /// Uses screen-specific animations that correlate with screen names
  static String? getAnimationForScreen(String? route) {
    if (route == null) return null;
    
    // Map routes to their corresponding screen animations
    String? result;
    switch (route) {
      case '/title':
        result = 'assets/animations/title/title screen.mp4';
        break;
      case '/stats':
        result = 'assets/animations/stats/stat screen.mp4';
        break;
      case '/settings':
        result = 'assets/animations/settings/setting screen.mp4';
        break;
      case '/modes':
      case '/mode-selection':
        result = 'assets/animations/mode_selection/mode selection screen.mp4';
        break;
      case '/word-of-day':
        result = 'assets/animations/word_of_day/word of the day.mp4';
        break;
      case '/more':
        // More menu uses settings animation (similar screen type)
        result = 'assets/animations/settings/setting screen.mp4';
        break;
      case '/friends':
      case '/direct-message':
      case '/conversations':
        result = 'assets/animations/shared/10.mp4';
        break;
      default:
        result = null;
    }
    return result;
  }

  /// Check if a screen has an icon animation
  static bool hasAnimationForScreen(String? route) {
    return getAnimationForScreen(route) != null;
  }
}

