import 'package:flutter/material.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/utils/provider_helper.dart';

/// Floating upgrade shortcut button for free users
/// Provides quick access to subscription management
class UpgradeShortcutButton extends StatelessWidget { // Always show, or only show for free users

  const UpgradeShortcutButton({
    super.key,
    this.persistent = false,
  });
  final bool persistent;

  @override
  Widget build(BuildContext context) {
    // CRITICAL: Use safeGet to prevent ProviderNotFoundException
    final subscriptionService = ProviderHelper.safeGet<SubscriptionService>(context, listen: false);
    if (subscriptionService == null) {
      return const SizedBox.shrink(); // Hide if service not available
    }

    // Only show for free users (or always if persistent)
    if (!persistent && !subscriptionService.isFree) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 16,
      right: 16,
      child: FloatingActionButton.extended(
        onPressed: () {
          // CRITICAL: Use safeGet to prevent ProviderNotFoundException
          final analyticsService = ProviderHelper.safeGet<AnalyticsService>(
            context,
            listen: false,
          );
          analyticsService?.logConversionFunnelStep(
            step: 1,
            stepName: 'upgrade_shortcut_clicked',
            source: 'floating_button',
            targetTier: 'premium',
          );
          NavigationHelper.safeNavigate(context, '/subscription-management');
        },
        backgroundColor: AppColors.of(context).primaryButton,
        foregroundColor: AppColors.of(context).buttonText,
        icon: const Icon(Icons.arrow_upward),
        label: Text(
          subscriptionService.isFree ? 'Upgrade' : 'Manage',
          style: AppTypography.labelLarge,
        ),
        tooltip: subscriptionService.isFree
            ? 'Upgrade to Premium'
            : 'Manage Subscription',
      ),
    );
  }
}
