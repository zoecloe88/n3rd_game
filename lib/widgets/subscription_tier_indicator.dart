import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/theme/app_spacing.dart';


/// Widget to display current subscription tier status
/// Shows tier badge with icon and name
class SubscriptionTierIndicator extends StatelessWidget {
  final bool showIcon;
  final bool compact;

  const SubscriptionTierIndicator({
    super.key,
    this.showIcon = true,
    this.compact = false,
  });

  String _getTierName(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return 'Free';
      case SubscriptionTier.basic:
        return 'Basic';
      case SubscriptionTier.premium:
        return 'Premium';
      case SubscriptionTier.familyFriends:
        return 'Family & Friends';
    }
  }

  IconData _getTierIcon(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return Icons.account_circle_outlined;
      case SubscriptionTier.basic:
        return Icons.star_outline;
      case SubscriptionTier.premium:
        return Icons.diamond_outlined;
      case SubscriptionTier.familyFriends:
        return Icons.family_restroom;
    }
  }

  Color _getTierColor(SubscriptionTier tier, AppColorScheme colors) {
    switch (tier) {
      case SubscriptionTier.free:
        return colors.secondaryText;
      case SubscriptionTier.basic:
        return Colors.blue;
      case SubscriptionTier.premium:
        return Colors.purple;
      case SubscriptionTier.familyFriends:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = AppColors.of(context);
    final subscriptionService = Provider.of<SubscriptionService>(context);
    final tier = subscriptionService.currentTier;
    final tierName = _getTierName(tier);
    final tierIcon = _getTierIcon(tier);
    final tierColor = _getTierColor(tier, colorScheme);

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: tierColor.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: tierColor.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon) ...[
              Icon(tierIcon, size: 14, color: tierColor),
              const SizedBox(width: 4),
            ],
            Text(
              tierName,
              style: AppTypography.labelSmall.copyWith(
                color: tierColor,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: tierColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tierColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(tierIcon, size: 20, color: tierColor),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(
            tierName,
            style: AppTypography.labelLarge.copyWith(
              color: tierColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
