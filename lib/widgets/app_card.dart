import 'package:flutter/material.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/theme/app_radius.dart';
import 'package:n3rd_game/theme/app_shadows.dart';

/// Standardized card component with variants and consistent styling
///
/// **Variants:**
/// - elevated: Card with shadow elevation
/// - outlined: Card with border outline
/// - filled: Card with filled background
///
/// **Usage:**
/// ```dart
/// AppCard.elevated(
///   child: Text('Card content'),
/// )
/// ```
class AppCard extends StatelessWidget {

  const AppCard({
    super.key,
    required this.child,
    this.variant = AppCardVariant.elevated,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.semanticsLabel,
  });

  /// Elevated card with shadow
  factory AppCard.elevated({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    VoidCallback? onTap,
    Color? backgroundColor,
    String? semanticsLabel,
  }) {
    return AppCard(
      key: key,
      variant: AppCardVariant.elevated,
      padding: padding,
      margin: margin,
      onTap: onTap,
      backgroundColor: backgroundColor,
      semanticsLabel: semanticsLabel,
      child: child,
    );
  }

  /// Outlined card with border
  factory AppCard.outlined({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    VoidCallback? onTap,
    Color? backgroundColor,
    String? semanticsLabel,
  }) {
    return AppCard(
      key: key,
      variant: AppCardVariant.outlined,
      padding: padding,
      margin: margin,
      onTap: onTap,
      backgroundColor: backgroundColor,
      semanticsLabel: semanticsLabel,
      child: child,
    );
  }

  /// Filled card with background
  factory AppCard.filled({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    VoidCallback? onTap,
    Color? backgroundColor,
    String? semanticsLabel,
  }) {
    return AppCard(
      key: key,
      variant: AppCardVariant.filled,
      padding: padding,
      margin: margin,
      onTap: onTap,
      backgroundColor: backgroundColor,
      semanticsLabel: semanticsLabel,
      child: child,
    );
  }
  final Widget child;
  final AppCardVariant variant;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final effectivePadding = padding ?? const EdgeInsets.all(AppSpacing.md);
    final effectiveMargin = margin ?? EdgeInsets.zero;

    // Get variant-specific styling
    final cardStyle = _getCardStyle(context, colors, variant);

    Widget card = Container(
      padding: effectivePadding,
      margin: effectiveMargin,
      decoration: BoxDecoration(
        color: backgroundColor ?? cardStyle.backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: cardStyle.border,
        boxShadow: cardStyle.shadows,
      ),
      child: child,
    );

    // Make tappable if onTap is provided
    if (onTap != null) {
      card = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: card,
      );
    }

    // Wrap with Semantics for accessibility
    if (semanticsLabel != null || onTap != null) {
      return Semantics(
        label: semanticsLabel,
        button: onTap != null,
        child: card,
      );
    }

    return card;
  }

  _CardStyle _getCardStyle(
    BuildContext context,
    AppColorScheme colors,
    AppCardVariant variant,
  ) {
    switch (variant) {
      case AppCardVariant.elevated:
        return _CardStyle(
          backgroundColor: colors.cardBackground,
          border: null,
          shadows: AppShadows.medium,
        );
      case AppCardVariant.outlined:
        return _CardStyle(
          backgroundColor: colors.cardBackground,
          border: Border.all(
            color: colors.borderLight,
            width: 1,
          ),
          shadows: null,
        );
      case AppCardVariant.filled:
        return _CardStyle(
          backgroundColor: colors.cardBackgroundAlt,
          border: null,
          shadows: null,
        );
    }
  }
}

/// Card variant enum
enum AppCardVariant {
  elevated,
  outlined,
  filled,
}

/// Internal card style
class _CardStyle {

  _CardStyle({
    required this.backgroundColor,
    this.border,
    this.shadows,
  });
  final Color backgroundColor;
  final Border? border;
  final List<BoxShadow>? shadows;
}
















