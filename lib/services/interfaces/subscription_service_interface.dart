/// Subscription tier enumeration
enum SubscriptionTier {
  free,
  basic,
  premium,
  familyFriends,
}

/// Interface for subscription service
/// Provides contract for subscription operations
abstract class SubscriptionServiceInterface {
  /// Get current subscription tier
  SubscriptionTier get currentTier;

  /// Check if user is on free tier
  bool get isFree;

  /// Check if user is on premium tier
  bool get isPremium;

  /// Check if user has editions access
  bool get hasEditionsAccess;

  /// Check if user has online access
  bool get hasOnlineAccess;

  /// Set subscription tier
  Future<void> setTier(SubscriptionTier tier);

  /// Check subscription status
  Future<void> checkSubscriptionStatus();

  /// Dispose resources
  void dispose();
}
