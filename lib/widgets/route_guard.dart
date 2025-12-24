import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/utils/subscription_guard.dart';
import 'package:n3rd_game/widgets/upgrade_dialog.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/widgets/unified_background_widget.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/theme/app_shadows.dart';
import 'package:n3rd_game/services/analytics_service.dart';

/// Route guard widget that enforces subscription requirements
/// Wraps screens to check subscription access before rendering
/// Shows upgrade dialog if access is denied
class RouteGuard extends StatelessWidget {
  final Widget child;
  final bool requiresPremium;
  final bool requiresOnlineAccess;
  final bool requiresEditionsAccess;
  final bool requiresAllModesAccess;
  final bool requiresFamilyFriends;
  final String? featureName; // For upgrade dialog

  const RouteGuard({
    super.key,
    required this.child,
    this.requiresPremium = false,
    this.requiresOnlineAccess = false,
    this.requiresEditionsAccess = false,
    this.requiresAllModesAccess = false,
    this.requiresFamilyFriends = false,
    this.featureName,
  });

  @override
  Widget build(BuildContext context) {
    final subscriptionService = Provider.of<SubscriptionService>(context);

    // Check access using centralized guard
    final hasAccess = SubscriptionGuard.canAccessFeature(
      subscriptionService: subscriptionService,
      requiresPremium: requiresPremium,
      requiresOnlineAccess: requiresOnlineAccess,
      requiresEditionsAccess: requiresEditionsAccess,
      requiresAllModesAccess: requiresAllModesAccess,
      requiresFamilyFriends: requiresFamilyFriends,
    );

    // If access granted, render child
    if (hasAccess) {
      return child;
    }

    // Access denied - show locked screen
    return _LockedScreen(
      subscriptionService: subscriptionService,
      requiresPremium: requiresPremium,
      requiresOnlineAccess: requiresOnlineAccess,
      requiresEditionsAccess: requiresEditionsAccess,
      requiresAllModesAccess: requiresAllModesAccess,
      requiresFamilyFriends: requiresFamilyFriends,
      featureName: featureName,
    );
  }
}

/// Locked screen shown when subscription access is denied
class _LockedScreen extends StatelessWidget {
  final SubscriptionService subscriptionService;
  final bool requiresPremium;
  final bool requiresOnlineAccess;
  final bool requiresEditionsAccess;
  final bool requiresAllModesAccess;
  final bool requiresFamilyFriends;
  final String? featureName;

  const _LockedScreen({
    required this.subscriptionService,
    required this.requiresPremium,
    required this.requiresOnlineAccess,
    required this.requiresEditionsAccess,
    required this.requiresAllModesAccess,
    required this.requiresFamilyFriends,
    this.featureName,
  });

  void _showUpgradeDialog(BuildContext context) {
    final analyticsService = Provider.of<AnalyticsService>(
      context,
      listen: false,
    );

    // Determine target tier
    final targetTier = SubscriptionGuard.getRequiredTierName(
      requiresPremium: requiresPremium,
      requiresOnlineAccess: requiresOnlineAccess,
      requiresEditionsAccess: requiresEditionsAccess,
      requiresAllModesAccess: requiresAllModesAccess,
      requiresFamilyFriends: requiresFamilyFriends,
    ).toLowerCase();

    // Get feature benefits
    final benefits = SubscriptionGuard.getFeatureBenefits(
      requiresPremium: requiresPremium,
      requiresOnlineAccess: requiresOnlineAccess,
      requiresEditionsAccess: requiresEditionsAccess,
      requiresAllModesAccess: requiresAllModesAccess,
      requiresFamilyFriends: requiresFamilyFriends,
    );

    // Log analytics
    analyticsService.logUpgradeDialogShown(
      source: featureName?.toLowerCase().replaceAll(' ', '_') ?? 'route_guard',
      targetTier: targetTier,
    );

    showDialog(
      context: context,
      builder: (dialogContext) => UpgradeDialog(
        title: 'Premium Feature',
        message: featureName != null
            ? '$featureName is available for $targetTier subscribers.'
            : 'This feature is available for $targetTier subscribers.',
        targetTier: targetTier,
        source:
            featureName?.toLowerCase().replaceAll(' ', '_') ?? 'route_guard',
        features: benefits,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    final targetTier = SubscriptionGuard.getRequiredTierName(
      requiresPremium: requiresPremium,
      requiresOnlineAccess: requiresOnlineAccess,
      requiresEditionsAccess: requiresEditionsAccess,
      requiresAllModesAccess: requiresAllModesAccess,
      requiresFamilyFriends: requiresFamilyFriends,
    );

    return Scaffold(
      backgroundColor: colors.background,
      body: UnifiedBackgroundWidget(
        child: SafeArea(
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppShadows.large,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 64,
                    color: colors.tertiaryText,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$targetTier Feature',
                    style: AppTypography.headlineLarge.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: colors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    featureName != null
                        ? '$featureName is available for $targetTier subscribers.'
                        : 'This feature is available for $targetTier subscribers.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(
                      fontSize: 14,
                      color: colors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      _showUpgradeDialog(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primaryButton,
                      foregroundColor: colors.buttonText,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      'Upgrade to $targetTier',
                      style: AppTypography.labelLarge,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => NavigationHelper.safePop(context),
                    child: Text(
                      'Go Back',
                      style: AppTypography.bodyMedium.copyWith(
                        color: colors.secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}






