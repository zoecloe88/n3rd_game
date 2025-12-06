import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';

/// Reusable upgrade dialog component
/// Displays upgrade prompt with features and call-to-action
class UpgradeDialog extends StatelessWidget {
  final String title;
  final String message;
  final String targetTier; // 'basic' or 'premium'
  final String
  source; // 'daily_limit', 'locked_mode', 'editions', 'multiplayer'
  final List<String> features;

  const UpgradeDialog({
    super.key,
    required this.title,
    required this.message,
    required this.targetTier,
    required this.source,
    required this.features,
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
            const SizedBox(height: AppSpacing.md),
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
