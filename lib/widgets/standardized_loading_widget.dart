import 'package:flutter/material.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/theme/app_spacing.dart';

/// Standardized loading widget for consistent loading states across the app
class StandardizedLoadingWidget extends StatelessWidget {
  final String? message;
  final Color? color;
  final double? size;

  const StandardizedLoadingWidget({
    super.key,
    this.message,
    this.color,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final loadingColor = color ?? colors.primaryButton;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: size ?? 48,
            height: size ?? 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(loadingColor),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              message!,
              style: AppTypography.bodyMedium.copyWith(
                color: colors.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}




