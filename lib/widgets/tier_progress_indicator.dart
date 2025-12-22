import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/services/free_tier_service.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/theme/app_spacing.dart';

/// Widget showing progress toward next subscription tier
/// Only shown for free tier users
class TierProgressIndicator extends StatelessWidget {
  final bool showIcon;

  const TierProgressIndicator({
    super.key,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final subscriptionService = Provider.of<SubscriptionService>(context);
    final freeTierService = Provider.of<FreeTierService>(context);

    // Only show for free tier users
    if (!subscriptionService.isFree) {
      return const SizedBox.shrink();
    }

    final gamesPlayed = freeTierService.gamesStartedToday;
    final gamesRemaining = freeTierService.gamesRemaining;
    final totalGames = freeTierService.maxGamesPerDay;

    final progress = totalGames > 0 ? gamesPlayed / totalGames : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.tertiaryText.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showIcon) ...[
                Icon(
                  Icons.trending_up,
                  size: 20,
                  color: colors.primaryButton,
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(
                'Progress to Basic Tier',
                style: AppTypography.labelLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$gamesPlayed / $totalGames games played today',
            style: AppTypography.bodyMedium.copyWith(
              color: colors.secondaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: colors.tertiaryText.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(colors.primaryButton),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          if (gamesRemaining > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$gamesRemaining games remaining today',
              style: AppTypography.bodyMedium.copyWith(
                color: colors.secondaryText,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
