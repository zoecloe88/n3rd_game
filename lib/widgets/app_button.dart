import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/theme/app_radius.dart';
import 'package:n3rd_game/services/haptic_service.dart';
import 'package:n3rd_game/services/accessibility_service.dart';

/// Standardized button component with variants, sizes, and states
///
/// **Variants:**
/// - primary: Main action button with filled background
/// - secondary: Secondary action with outlined style
/// - tertiary: Subtle action with minimal styling
/// - text: Text-only button
/// - icon: Icon-only button
///
/// **Sizes:**
/// - small: Compact button for tight spaces
/// - medium: Standard button size (default)
/// - large: Prominent button for primary actions
///
/// **Usage:**
/// ```dart
/// AppButton.primary(
///   label: 'Submit',
///   onPressed: () => _handleSubmit(),
/// )
/// ```
class AppButton extends StatelessWidget {

  const AppButton({
    super.key,
    this.label,
    this.icon,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.isFullWidth = false,
    this.backgroundColor,
    this.foregroundColor,
    this.semanticsLabel,
  }) : assert(
          label != null || icon != null,
          'Either label or icon must be provided',
        );

  /// Primary button - main action
  factory AppButton.primary({
    Key? key,
    String? label,
    IconData? icon,
    VoidCallback? onPressed,
    AppButtonSize size = AppButtonSize.medium,
    bool isLoading = false,
    bool isFullWidth = false,
    String? semanticsLabel,
  }) {
    return AppButton(
      key: key,
      label: label,
      icon: icon,
      onPressed: onPressed,
      variant: AppButtonVariant.primary,
      size: size,
      isLoading: isLoading,
      isFullWidth: isFullWidth,
      semanticsLabel: semanticsLabel,
    );
  }

  /// Secondary button - outlined style
  factory AppButton.secondary({
    Key? key,
    String? label,
    IconData? icon,
    VoidCallback? onPressed,
    AppButtonSize size = AppButtonSize.medium,
    bool isLoading = false,
    bool isFullWidth = false,
    String? semanticsLabel,
  }) {
    return AppButton(
      key: key,
      label: label,
      icon: icon,
      onPressed: onPressed,
      variant: AppButtonVariant.secondary,
      size: size,
      isLoading: isLoading,
      isFullWidth: isFullWidth,
      semanticsLabel: semanticsLabel,
    );
  }

  /// Tertiary button - minimal styling
  factory AppButton.tertiary({
    Key? key,
    String? label,
    IconData? icon,
    VoidCallback? onPressed,
    AppButtonSize size = AppButtonSize.medium,
    bool isLoading = false,
    bool isFullWidth = false,
    String? semanticsLabel,
  }) {
    return AppButton(
      key: key,
      label: label,
      icon: icon,
      onPressed: onPressed,
      variant: AppButtonVariant.tertiary,
      size: size,
      isLoading: isLoading,
      isFullWidth: isFullWidth,
      semanticsLabel: semanticsLabel,
    );
  }

  /// Text button - text only
  factory AppButton.text({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    AppButtonSize size = AppButtonSize.medium,
    bool isLoading = false,
    String? semanticsLabel,
  }) {
    return AppButton(
      key: key,
      label: label,
      onPressed: onPressed,
      variant: AppButtonVariant.text,
      size: size,
      isLoading: isLoading,
      semanticsLabel: semanticsLabel,
    );
  }

  /// Icon button - icon only
  factory AppButton.icon({
    Key? key,
    required IconData icon,
    VoidCallback? onPressed,
    AppButtonSize size = AppButtonSize.medium,
    bool isLoading = false,
    String? semanticsLabel,
  }) {
    return AppButton(
      key: key,
      icon: icon,
      onPressed: onPressed,
      variant: AppButtonVariant.icon,
      size: size,
      isLoading: isLoading,
      semanticsLabel: semanticsLabel,
    );
  }
  final String? label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool isLoading;
  final bool isFullWidth;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDisabled = onPressed == null || isLoading;
    final effectiveLabel = semanticsLabel ?? label;

    // Get size-specific values
    final sizeConfig = _getSizeConfig(size);
    final padding = sizeConfig.padding;
    double minHeight = sizeConfig.minHeight;
    final fontSize = sizeConfig.fontSize;
    final iconSize = sizeConfig.iconSize;
    
    // Enforce 48px minimum when largerTouchTargets setting is enabled
    try {
      final accessibilityService = Provider.of<AccessibilityService>(
        context,
        listen: false,
      );
      if (accessibilityService.settings.largerTouchTargets && minHeight < 48) {
        minHeight = 48;
      }
    } catch (e) {
      // AccessibilityService not available, use default
    }

    // Get variant-specific styling
    final buttonStyle = _getButtonStyle(context, colors, variant, isDisabled);

    Widget buttonContent;
    if (isLoading) {
      buttonContent = Semantics(
        label: effectiveLabel != null ? '$effectiveLabel, loading' : 'Loading',
        child: SizedBox(
          width: iconSize,
          height: iconSize,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              buttonStyle.foregroundColor,
            ),
          ),
        ),
      );
    } else if (icon != null && label != null) {
      // Icon + Label
      buttonContent = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: iconSize, color: buttonStyle.foregroundColor),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label!,
            style: AppTypography.labelLarge.copyWith(
              fontSize: fontSize,
              color: buttonStyle.foregroundColor,
            ),
          ),
        ],
      );
    } else if (icon != null) {
      // Icon only
      buttonContent = Icon(
        icon,
        size: iconSize,
        color: buttonStyle.foregroundColor,
      );
    } else {
      // Label only
      buttonContent = Text(
        label!,
        style: AppTypography.labelLarge.copyWith(
          fontSize: fontSize,
          color: buttonStyle.foregroundColor,
        ),
      );
    }

    Widget button;
    switch (variant) {
      case AppButtonVariant.primary:
        button = ElevatedButton(
          onPressed: isDisabled
              ? null
              : () {
                  HapticService().lightImpact();
                  onPressed?.call();
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor ?? buttonStyle.backgroundColor,
            foregroundColor: foregroundColor ?? buttonStyle.foregroundColor,
            padding: padding,
            minimumSize: Size(isFullWidth ? double.infinity : 0, minHeight),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            elevation: buttonStyle.elevation,
          ),
          child: buttonContent,
        );
        break;
      case AppButtonVariant.secondary:
        button = OutlinedButton(
          onPressed: isDisabled
              ? null
              : () {
                  HapticService().lightImpact();
                  onPressed?.call();
                },
          style: OutlinedButton.styleFrom(
            foregroundColor: foregroundColor ?? buttonStyle.foregroundColor,
            padding: padding,
            minimumSize: Size(isFullWidth ? double.infinity : 0, minHeight),
            side: BorderSide(
              color: backgroundColor ??
                  buttonStyle.borderColor ??
                  colors.borderMedium,
              width: 1,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
          ),
          child: buttonContent,
        );
        break;
      case AppButtonVariant.tertiary:
        button = OutlinedButton(
          onPressed: isDisabled
              ? null
              : () {
                  HapticService().lightImpact();
                  onPressed?.call();
                },
          style: OutlinedButton.styleFrom(
            foregroundColor: foregroundColor ?? buttonStyle.foregroundColor,
            padding: padding,
            minimumSize: Size(isFullWidth ? double.infinity : 0, minHeight),
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
          ),
          child: buttonContent,
        );
        break;
      case AppButtonVariant.text:
        button = TextButton(
          onPressed: isDisabled
              ? null
              : () {
                  HapticService().lightImpact();
                  onPressed?.call();
                },
          style: TextButton.styleFrom(
            foregroundColor: foregroundColor ?? buttonStyle.foregroundColor,
            padding: padding,
            minimumSize: Size(isFullWidth ? double.infinity : 0, minHeight),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
          ),
          child: buttonContent,
        );
        break;
      case AppButtonVariant.icon:
        button = IconButton(
          onPressed: isDisabled
              ? null
              : () {
                  HapticService().lightImpact();
                  onPressed?.call();
                },
          icon: buttonContent,
          iconSize: iconSize,
          color: foregroundColor ?? buttonStyle.foregroundColor,
          padding: padding,
          constraints: BoxConstraints(
            minWidth: minHeight,
            minHeight: minHeight,
          ),
          style: IconButton.styleFrom(
            backgroundColor: backgroundColor ?? buttonStyle.backgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
          ),
        );
        break;
    }

    // Wrap with Semantics for accessibility
    return Semantics(
      label: effectiveLabel,
      button: true,
      enabled: !isDisabled,
      child: button,
    );
  }

  _ButtonSizeConfig _getSizeConfig(AppButtonSize size) {
    switch (size) {
      case AppButtonSize.small:
        return _ButtonSizeConfig(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          minHeight: 32,
          fontSize: 14,
          iconSize: 16,
        );
      case AppButtonSize.medium:
        return _ButtonSizeConfig(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          minHeight: 44,
          fontSize: 16,
          iconSize: 20,
        );
      case AppButtonSize.large:
        return _ButtonSizeConfig(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          minHeight: 56,
          fontSize: 18,
          iconSize: 24,
        );
    }
  }

  _ButtonStyle _getButtonStyle(
    BuildContext context,
    AppColorScheme colors,
    AppButtonVariant variant,
    bool isDisabled,
  ) {
    if (isDisabled) {
      return _ButtonStyle(
        backgroundColor: colors.disabled,
        foregroundColor: colors.disabledText,
        borderColor: colors.borderLight,
        elevation: 0,
      );
    }

    switch (variant) {
      case AppButtonVariant.primary:
        return _ButtonStyle(
          backgroundColor: colors.primaryButton,
          foregroundColor: colors.buttonText,
          borderColor: null,
          elevation: 2,
        );
      case AppButtonVariant.secondary:
        return _ButtonStyle(
          backgroundColor: Colors.transparent,
          foregroundColor: colors.primaryText,
          borderColor: colors.borderMedium,
          elevation: 0,
        );
      case AppButtonVariant.tertiary:
        return _ButtonStyle(
          backgroundColor: colors.surfaceVariant,
          foregroundColor: colors.primaryText,
          borderColor: null,
          elevation: 0,
        );
      case AppButtonVariant.text:
        return _ButtonStyle(
          backgroundColor: Colors.transparent,
          foregroundColor: colors.primaryText,
          borderColor: null,
          elevation: 0,
        );
      case AppButtonVariant.icon:
        return _ButtonStyle(
          backgroundColor: colors.surfaceVariant,
          foregroundColor: colors.primaryText,
          borderColor: null,
          elevation: 0,
        );
    }
  }
}

/// Button variant enum
enum AppButtonVariant {
  primary,
  secondary,
  tertiary,
  text,
  icon,
}

/// Button size enum
enum AppButtonSize {
  small,
  medium,
  large,
}

/// Internal size configuration
class _ButtonSizeConfig {

  _ButtonSizeConfig({
    required this.padding,
    required this.minHeight,
    required this.fontSize,
    required this.iconSize,
  });
  final EdgeInsets padding;
  final double minHeight;
  final double fontSize;
  final double iconSize;
}

/// Internal button style
class _ButtonStyle {

  _ButtonStyle({
    required this.backgroundColor,
    required this.foregroundColor,
    this.borderColor,
    required this.elevation,
  });
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final double elevation;
}
