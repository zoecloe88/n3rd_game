import 'package:n3rd_game/services/subscription_service.dart';

/// Utility class for centralized subscription access validation
/// Provides consistent subscription checking across the app
class SubscriptionGuard {
  /// Check if user has access to a feature based on subscription requirements
  ///
  /// Returns true if user has access, false otherwise
  ///
  /// [subscriptionService] - The subscription service instance
  /// [requiresPremium] - Feature requires Premium tier (includes Family & Friends)
  /// [requiresOnlineAccess] - Feature requires online access (Premium/Family & Friends)
  /// [requiresEditionsAccess] - Feature requires editions access (Premium/Family & Friends)
  /// [requiresAllModesAccess] - Feature requires Basic tier or higher
  /// [requiresFamilyFriends] - Feature requires Family & Friends tier specifically
  static bool canAccessFeature({
    required SubscriptionService subscriptionService,
    bool requiresPremium = false,
    bool requiresOnlineAccess = false,
    bool requiresEditionsAccess = false,
    bool requiresAllModesAccess = false,
    bool requiresFamilyFriends = false,
  }) {
    // Family & Friends has all Premium features
    if (requiresFamilyFriends) {
      return subscriptionService.isFamilyFriends;
    }

    // Premium features (includes Family & Friends)
    if (requiresPremium) {
      return subscriptionService.isPremium ||
          subscriptionService.isFamilyFriends;
    }

    // Online access features
    if (requiresOnlineAccess) {
      return subscriptionService.hasOnlineAccess;
    }

    // Editions access features
    if (requiresEditionsAccess) {
      return subscriptionService.hasEditionsAccess;
    }

    // All modes access (Basic and above)
    if (requiresAllModesAccess) {
      return subscriptionService.hasAllModesAccess;
    }

    // No restrictions
    return true;
  }

  /// Get the required tier name for a feature
  /// Returns user-friendly tier name for display
  static String getRequiredTierName({
    bool requiresPremium = false,
    bool requiresOnlineAccess = false,
    bool requiresEditionsAccess = false,
    bool requiresAllModesAccess = false,
    bool requiresFamilyFriends = false,
  }) {
    if (requiresFamilyFriends) {
      return 'Family & Friends';
    }
    if (requiresPremium || requiresOnlineAccess || requiresEditionsAccess) {
      return 'Premium';
    }
    if (requiresAllModesAccess) {
      return 'Basic';
    }
    return 'Free';
  }

  /// Get feature description for upgrade dialog
  /// Returns a list of benefits for the required tier
  static List<String> getFeatureBenefits({
    bool requiresPremium = false,
    bool requiresOnlineAccess = false,
    bool requiresEditionsAccess = false,
    bool requiresAllModesAccess = false,
    bool requiresFamilyFriends = false,
  }) {
    if (requiresFamilyFriends) {
      return [
        'Access for up to 4 family members',
        'All Premium features',
        'Family group management',
        'Shared progress tracking',
        'Special family challenges',
      ];
    }
    if (requiresPremium || requiresOnlineAccess || requiresEditionsAccess) {
      return [
        'Unlimited games',
        'All game modes',
        'AI Edition & Custom Editions',
        'Multiplayer & Online features',
        'Advanced analytics',
        'Practice & Learning modes',
      ];
    }
    if (requiresAllModesAccess) {
      return [
        'All game modes',
        'Advanced challenges',
        'More customization options',
      ];
    }
    return [];
  }
}




