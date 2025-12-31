import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/utils/subscription_guard.dart';
import 'package:n3rd_game/utils/provider_helper.dart';

/// Widget that wraps a feature with a tooltip explaining tier requirements
/// Shows tooltip on long press for locked features
class FeatureTooltipWidget extends StatelessWidget {

  const FeatureTooltipWidget({
    super.key,
    required this.child,
    required this.featureName,
    this.requiresPremium = false,
    this.requiresOnlineAccess = false,
    this.requiresEditionsAccess = false,
    this.requiresAllModesAccess = false,
    this.requiresFamilyFriends = false,
  });
  final Widget child;
  final String featureName;
  final bool requiresPremium;
  final bool requiresOnlineAccess;
  final bool requiresEditionsAccess;
  final bool requiresAllModesAccess;
  final bool requiresFamilyFriends;

  @override
  Widget build(BuildContext context) {
    // CRITICAL: Use safeGet to prevent ProviderNotFoundException
    final subscriptionService = ProviderHelper.safeGet<SubscriptionService>(context, listen: false);
    if (subscriptionService == null) {
      return child; // Show child if service not available (fail open)
    }

    // Check if feature is locked
    final isLocked = !SubscriptionGuard.canAccessFeature(
      subscriptionService: subscriptionService,
      requiresPremium: requiresPremium,
      requiresOnlineAccess: requiresOnlineAccess,
      requiresEditionsAccess: requiresEditionsAccess,
      requiresAllModesAccess: requiresAllModesAccess,
      requiresFamilyFriends: requiresFamilyFriends,
    );

    if (!isLocked) {
      return child;
    }

    // Get required tier and benefits
    final requiredTier = SubscriptionGuard.getRequiredTierName(
      requiresPremium: requiresPremium,
      requiresOnlineAccess: requiresOnlineAccess,
      requiresEditionsAccess: requiresEditionsAccess,
      requiresAllModesAccess: requiresAllModesAccess,
      requiresFamilyFriends: requiresFamilyFriends,
    );

    final benefits = SubscriptionGuard.getFeatureBenefits(
      requiresPremium: requiresPremium,
      requiresOnlineAccess: requiresOnlineAccess,
      requiresEditionsAccess: requiresEditionsAccess,
      requiresAllModesAccess: requiresAllModesAccess,
      requiresFamilyFriends: requiresFamilyFriends,
    );

    return Tooltip(
      message: '$featureName is available for $requiredTier subscribers.\n\n'
          'Benefits:\n${benefits.take(3).join('\n• ')}',
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 500),
      child: child,
    );
  }
}
