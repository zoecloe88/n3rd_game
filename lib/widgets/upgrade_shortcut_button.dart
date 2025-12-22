import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_typography.dart';

/// Floating upgrade shortcut button for free users
/// Provides quick access to subscription management
class UpgradeShortcutButton extends StatelessWidget {
  final bool persistent; // Always show, or only show for free users

  const UpgradeShortcutButton({
    super.key,
    this.persistent = false,
  });

  @override
  Widget build(BuildContext context) {
    final subscriptionService = Provider.of<SubscriptionService>(context);

    // Only show for free users (or always if persistent)
    if (!persistent && !subscriptionService.isFree) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 16,
      right: 16,
      child: FloatingActionButton.extended(
        onPressed: () {
          final analyticsService = Provider.of<AnalyticsService>(
            context,
            listen: false,
          );
          analyticsService.logConversionFunnelStep(
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
