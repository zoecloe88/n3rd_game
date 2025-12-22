import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';

/// Reusable upgrade dialog component
/// Displays upgrade prompt with features and call-to-action
/// Enhanced with feature comparison tooltips
class UpgradeDialog extends StatelessWidget {
  final String title;
  final String message;
  final String targetTier; // 'basic', 'premium', or 'family_friends'
  final String
  source; // 'daily_limit', 'locked_mode', 'editions', 'multiplayer'
  final List<String> features;
  final bool showComparison; // Show tier comparison

  const UpgradeDialog({
    super.key,
    required this.title,
    required this.message,
    required this.targetTier,
    required this.source,
    required this.features,
    this.showComparison = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final analyticsService = Provider.of<AnalyticsService>(
      context,
      listen: false,
    );

    return AlertDialog(
      backgroundColor: colors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: AppTypography.headlineMedium),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: AppTypography.bodyMedium),
            if (features.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'What you get:',
                style: AppTypography.labelLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ...features.map(
                (feature) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle, color: colors.success, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          feature,
                          style: AppTypography.bodyMedium.copyWith(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (showComparison) ...[
              const SizedBox(height: AppSpacing.md),
              const Divider(),
              const SizedBox(height: AppSpacing.md),
              _TierComparisonWidget(targetTier: targetTier),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            analyticsService.logUpgradeDialogDismissed(
              source: source,
              targetTier: targetTier,
            );
            NavigationHelper.safePop(context);
          },
          child: Text('Maybe Later', style: AppTypography.bodyMedium),
        ),
        ElevatedButton(
          onPressed: () {
            analyticsService.logConversionFunnelStep(
              step: 3,
              stepName: 'subscription_screen_opened',
              source: source,
              targetTier: targetTier,
            );
            NavigationHelper.safePop(context);
            NavigationHelper.safeNavigate(context, '/subscription-management');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primaryButton,
            foregroundColor: colors.buttonText,
          ),
          child: Text(
            'Upgrade to ${targetTier.toUpperCase()}',
            style: AppTypography.labelLarge,
          ),
        ),
      ],
    );
  }
}

/// Tier comparison widget showing feature differences
class _TierComparisonWidget extends StatelessWidget {
  final String targetTier;

  const _TierComparisonWidget({required this.targetTier});

  @override
  Widget build(BuildContext context) {
    // Define tier features
    final freeFeatures = [
      '5 games per day',
      'Classic mode only',
      'Basic stats',
    ];
    final basicFeatures = [
      'Unlimited games',
      'All game modes',
      'Advanced challenges',
    ];
    final premiumFeatures = [
      'Everything in Basic',
      'AI Edition',
      'Multiplayer',
      'Advanced analytics',
      'Practice & Learning modes',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Plan Comparison:',
          style: AppTypography.labelLarge.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (targetTier.toLowerCase() == 'basic' || 
            targetTier.toLowerCase() == 'premium' ||
            targetTier.toLowerCase() == 'family_friends')
          _TierRow(
            tierName: 'Free',
            features: freeFeatures,
            isHighlighted: false,
          ),
        if (targetTier.toLowerCase() == 'basic' || 
            targetTier.toLowerCase() == 'premium' ||
            targetTier.toLowerCase() == 'family_friends')
          _TierRow(
            tierName: 'Basic',
            features: basicFeatures,
            isHighlighted: targetTier.toLowerCase() == 'basic',
          ),
        if (targetTier.toLowerCase() == 'premium' ||
            targetTier.toLowerCase() == 'family_friends')
          _TierRow(
            tierName: 'Premium',
            features: premiumFeatures,
            isHighlighted: targetTier.toLowerCase() == 'premium',
          ),
        if (targetTier.toLowerCase() == 'family_friends')
          const _TierRow(
            tierName: 'Family & Friends',
            features: [
              'Everything in Premium',
              'Up to 4 members',
              'Shared progress',
              'Family challenges',
            ],
            isHighlighted: true,
          ),
      ],
    );
  }
}

class _TierRow extends StatelessWidget {
  final String tierName;
  final List<String> features;
  final bool isHighlighted;

  const _TierRow({
    required this.tierName,
    required this.features,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: isHighlighted
            ? colors.primaryButton.withValues(alpha: 0.1)
            : colors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHighlighted ? colors.primaryButton : colors.tertiaryText,
          width: isHighlighted ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tierName,
            style: AppTypography.labelLarge.copyWith(
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
              color: isHighlighted ? colors.primaryButton : colors.primaryText,
            ),
          ),
          const SizedBox(height: 4),
          ...features.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
                        child: Text(
                          '• $feature',
                          style: AppTypography.bodyMedium.copyWith(
                            fontSize: 11,
                            color: colors.secondaryText,
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

