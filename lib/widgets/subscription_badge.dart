import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';

/// Subscription status badge widget
/// Displays current tier and allows navigation to subscription management
class SubscriptionBadge extends StatelessWidget {
  final bool showUpgradeButton;

  const SubscriptionBadge({super.key, this.showUpgradeButton = true});

  @override
  Widget build(BuildContext context) {
    final subscriptionService = Provider.of<SubscriptionService>(context);
    final colors = AppColors.of(context);
    final tier = subscriptionService.tierName;

    Color badgeColor;
    IconData icon;

    switch (subscriptionService.currentTier) {
      case SubscriptionTier.premium:
        badgeColor = colors.success;
        icon = Icons.star;
        break;
      case SubscriptionTier.familyFriends:
        badgeColor = colors.success;
        icon = Icons.group;
        break;
      case SubscriptionTier.basic:
        badgeColor = colors.primaryButton;
        icon = Icons.check_circle;
        break;
      case SubscriptionTier.free:
        badgeColor = colors.tertiaryText;
        icon = Icons.lock_outline;
        break;
    }

    return GestureDetector(
      onTap: () {
        NavigationHelper.safeNavigate(context, '/subscription-management');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: badgeColor),
            const SizedBox(width: 6),
            Text(
              tier,
              style: AppTypography.labelSmall.copyWith(
                color: badgeColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (showUpgradeButton && subscriptionService.isFree) ...[
              const SizedBox(width: 8),
              Text(
                'Upgrade',
                style: AppTypography.labelSmall.copyWith(
                  color: badgeColor,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
