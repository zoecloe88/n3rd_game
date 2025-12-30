import 'package:flutter/material.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/theme/app_radius.dart';

/// Badge component for notifications, counts, and status indicators
///
/// **Usage:**
/// ```dart
/// AppBadge(
///   label: '5',
///   variant: AppBadgeVariant.error,
/// )
/// ```
class AppBadge extends StatelessWidget {

  const AppBadge({
    super.key,
    required this.label,
    this.variant = AppBadgeVariant.primary,
    this.size = AppBadgeSize.medium,
    this.backgroundColor,
    this.textColor,
    this.semanticsLabel,
  });
  final String label;
  final AppBadgeVariant variant;
  final AppBadgeSize size;
  final Color? backgroundColor;
  final Color? textColor;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final badgeStyle = _getBadgeStyle(context, colors, variant);
    final sizeConfig = _getSizeConfig(size);

    return Semantics(
      label: semanticsLabel ?? label,
      child: Container(
        padding: sizeConfig.padding,
        decoration: BoxDecoration(
          color: backgroundColor ?? badgeStyle.backgroundColor,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            fontSize: sizeConfig.fontSize,
            color: textColor ?? badgeStyle.textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  _BadgeStyle _getBadgeStyle(
    BuildContext context,
    AppColorScheme colors,
    AppBadgeVariant variant,
  ) {
    switch (variant) {
      case AppBadgeVariant.primary:
        return _BadgeStyle(
          backgroundColor: colors.accent,
          textColor: colors.onDarkText,
        );
      case AppBadgeVariant.error:
        return _BadgeStyle(
          backgroundColor: colors.error,
          textColor: colors.onDarkText,
        );
      case AppBadgeVariant.success:
        return _BadgeStyle(
          backgroundColor: colors.success,
          textColor: colors.onDarkText,
        );
      case AppBadgeVariant.warning:
        return _BadgeStyle(
          backgroundColor: colors.warning,
          textColor: colors.primaryText,
        );
      case AppBadgeVariant.info:
        return _BadgeStyle(
          backgroundColor: colors.info,
          textColor: colors.onDarkText,
        );
      case AppBadgeVariant.neutral:
        return _BadgeStyle(
          backgroundColor: colors.surfaceVariant,
          textColor: colors.primaryText,
        );
    }
  }

  _BadgeSizeConfig _getSizeConfig(AppBadgeSize size) {
    switch (size) {
      case AppBadgeSize.small:
        return _BadgeSizeConfig(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 2,
          ),
          fontSize: 10,
        );
      case AppBadgeSize.medium:
        return _BadgeSizeConfig(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 4,
          ),
          fontSize: 12,
        );
      case AppBadgeSize.large:
        return _BadgeSizeConfig(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 6,
          ),
          fontSize: 14,
        );
    }
  }
}

/// Badge variant enum
enum AppBadgeVariant {
  primary,
  error,
  success,
  warning,
  info,
  neutral,
}

/// Badge size enum
enum AppBadgeSize {
  small,
  medium,
  large,
}

/// Internal badge style
class _BadgeStyle {

  _BadgeStyle({
    required this.backgroundColor,
    required this.textColor,
  });
  final Color backgroundColor;
  final Color textColor;
}

/// Internal badge size config
class _BadgeSizeConfig {

  _BadgeSizeConfig({
    required this.padding,
    required this.fontSize,
  });
  final EdgeInsets padding;
  final double fontSize;
}
















