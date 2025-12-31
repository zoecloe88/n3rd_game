import 'package:flutter/material.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/theme/app_radius.dart';
import 'package:n3rd_game/services/haptic_service.dart';

/// Chip component for tags, filters, and selections
///
/// **Usage:**
/// ```dart
/// AppChip(
///   label: 'Tag',
///   onTap: () => _handleTap(),
/// )
/// ```
class AppChip extends StatelessWidget {

  const AppChip({
    super.key,
    required this.label,
    this.leadingIcon,
    this.trailingIcon,
    this.onTap,
    this.onDelete,
    this.selected = false,
    this.variant = AppChipVariant.filter,
    this.semanticsLabel,
  });
  final String label;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool selected;
  final AppChipVariant variant;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final chipStyle = _getChipStyle(context, colors, variant, selected);

    Widget chip = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: chipStyle.backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: chipStyle.border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingIcon != null) ...[
            Icon(
              leadingIcon,
              size: 16,
              color: chipStyle.textColor,
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: chipStyle.textColor,
            ),
          ),
          if (trailingIcon != null || onDelete != null) ...[
            const SizedBox(width: AppSpacing.xs),
            GestureDetector(
              onTap: onDelete,
              child: Icon(
                trailingIcon ?? Icons.close,
                size: 16,
                color: chipStyle.textColor,
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      chip = InkWell(
        onTap: () {
          HapticService().lightImpact();
          onTap?.call();
        },
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: chip,
      );
    }

    return Semantics(
      label: semanticsLabel ?? label,
      button: onTap != null,
      selected: selected,
      child: chip,
    );
  }

  _ChipStyle _getChipStyle(
    BuildContext context,
    AppColorScheme colors,
    AppChipVariant variant,
    bool selected,
  ) {
    if (selected) {
      return _ChipStyle(
        backgroundColor: colors.accent,
        textColor: colors.onDarkText,
        border: null,
      );
    }

    switch (variant) {
      case AppChipVariant.filter:
        return _ChipStyle(
          backgroundColor: colors.surfaceVariant,
          textColor: colors.primaryText,
          border: null,
        );
      case AppChipVariant.outlined:
        return _ChipStyle(
          backgroundColor: Colors.transparent,
          textColor: colors.primaryText,
          border: Border.all(
            color: colors.borderMedium,
            width: 1,
          ),
        );
      case AppChipVariant.filled:
        return _ChipStyle(
          backgroundColor: colors.cardBackgroundAlt,
          textColor: colors.primaryText,
          border: null,
        );
    }
  }
}

/// Chip variant enum
enum AppChipVariant {
  filter,
  outlined,
  filled,
}

/// Internal chip style
class _ChipStyle {

  _ChipStyle({
    required this.backgroundColor,
    required this.textColor,
    this.border,
  });
  final Color backgroundColor;
  final Color textColor;
  final Border? border;
}
















