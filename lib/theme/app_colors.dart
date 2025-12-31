import 'package:flutter/material.dart';
import 'package:n3rd_game/services/accessibility_service.dart';
import 'package:n3rd_game/utils/provider_helper.dart';

/// Application color system with light and dark mode support
///
/// **Usage:**
/// - Use `AppColors.of(context)` to get theme-aware colors
/// - Colors automatically adapt to light/dark mode
/// - High contrast mode can be enabled in accessibility settings
/// - Static colors are available for backwards compatibility (default to light mode)
class AppColors {
  // LIGHT MODE COLORS (Default)
  // TEXT COLORS (High Contrast)
  static const Color primaryText = Color(0xFF1A1A1A); // Near black
  static const Color secondaryText = Color(0xFF4A4A4A); // Dark gray
  static const Color tertiaryText = Color(0xFF8A8A8A); // Medium gray
  static const Color onDarkText = Color(
    0xFFFFFFFF,
  ); // White for dark backgrounds

  // BUTTON & INTERACTIVE COLORS
  static const Color primaryButton = Color(0xFF1A1A1A); // Black
  static const Color primaryButtonHover = Color(0xFF2A2A2A);
  static const Color secondaryButton = Color(0xFFFFFFFF); // White
  static const Color buttonText = Color(0xFFFFFFFF); // White text
  static const Color buttonTextDark = Color(0xFF1A1A1A); // Dark text on light

  // ACCENT COLORS (Theme-agnostic)
  static const Color success = Color(0xFF4CAF50); // Green
  static const Color error = Color(0xFFE53935); // Red
  static const Color warning = Color(0xFFFFA726); // Orange
  static const Color info = Color(0xFF29B6F6); // Blue

  // SURFACE & OVERLAY COLORS
  static const Color cardBackground = Color(0xFFFFFFFF); // White cards
  static const Color cardBackgroundAlt = Color(0xFFF5F5F5); // Light gray cards
  static const Color surface = Color(0xFFFFFFFF); // Main surface
  static const Color surfaceVariant = Color(0xFFF5F5F5); // Variant surface
  static const Color surfaceContainer = Color(0xFFFAFAFA); // Container surface
  static const Color overlayDark = Color(0xFF000000); // Black overlay
  static const Color borderLight = Color(0xFFE0E0E0); // Light borders
  static const Color borderMedium = Color(0xFFBDBDBD); // Medium borders
  static const Color borderDark = Color(0xFF9E9E9E); // Dark borders

  // ACCENT COLORS (Extended)
  static const Color accent = Color(0xFF00D9FF); // Primary accent
  static const Color accentVariant = Color(0xFF00B8D4); // Accent variant
  static const Color accentLight = Color(0xFF80EDFF); // Light accent
  static const Color accentDark = Color(0xFF008BA3); // Dark accent

  // STATE COLORS (Interactive states)
  static const Color hover = Color(0xFFF5F5F5); // Hover state
  static const Color pressed = Color(0xFFEEEEEE); // Pressed state
  static const Color disabled = Color(0xFFBDBDBD); // Disabled state
  static const Color disabledText = Color(0xFF9E9E9E); // Disabled text
  static const Color focus = Color(0xFF2196F3); // Focus indicator

  // DARK MODE COLORS
  static const Color darkPrimaryText = Color(0xFFFFFFFF); // White
  static const Color darkSecondaryText = Color(0xFFB0B0B0); // Light gray
  static const Color darkTertiaryText = Color(0xFF808080); // Medium gray
  static const Color darkCardBackground = Color(0xFF1E1E1E); // Dark cards
  static const Color darkCardBackgroundAlt = Color(0xFF2A2A2A); // Darker cards
  static const Color darkSurface = Color(0xFF1E1E1E); // Main dark surface
  static const Color darkSurfaceVariant =
      Color(0xFF2A2A2A); // Variant dark surface
  static const Color darkSurfaceContainer =
      Color(0xFF242424); // Container dark surface
  static const Color darkPrimaryButton = Color(0xFFFFFFFF); // White button
  static const Color darkPrimaryButtonHover = Color(0xFFE0E0E0);
  static const Color darkBorderLight = Color(0xFF404040); // Dark borders
  static const Color darkBorderMedium = Color(0xFF505050); // Darker borders
  static const Color darkBorderDark = Color(0xFF606060); // Darkest borders
  static const Color darkHover = Color(0xFF2A2A2A); // Dark hover state
  static const Color darkPressed = Color(0xFF333333); // Dark pressed state
  static const Color darkDisabled = Color(0xFF505050); // Dark disabled state
  static const Color darkDisabledText = Color(0xFF606060); // Dark disabled text
  static const Color darkFocus = Color(0xFF64B5F6); // Dark focus indicator

  /// Get theme-aware colors based on current theme
  /// Checks accessibility settings for high contrast mode
  /// Falls back to theme brightness if accessibility service is not available
  static AppColorScheme of(BuildContext context) {
    // Check for high contrast mode in accessibility settings
    // CRITICAL: Use safeGet to prevent ProviderNotFoundException
    final accessibilityService = ProviderHelper.safeGet<AccessibilityService>(
      context,
      listen: false,
    );
    if (accessibilityService != null &&
        accessibilityService.settings.highContrastMode) {
      return AppColorScheme.highContrast();
    }

    // Use theme brightness to determine color scheme
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? AppColorScheme.dark()
        : AppColorScheme.light();
  }
}

/// Theme-aware color scheme
class AppColorScheme {

  const AppColorScheme({
    required this.primaryText,
    required this.secondaryText,
    required this.tertiaryText,
    required this.onDarkText,
    required this.background,
    required this.cardBackground,
    required this.cardBackgroundAlt,
    required this.surface,
    required this.surfaceVariant,
    required this.surfaceContainer,
    required this.primaryButton,
    required this.primaryButtonHover,
    required this.buttonText,
    required this.buttonTextDark,
    required this.borderLight,
    required this.borderMedium,
    required this.borderDark,
    required this.accent,
    required this.accentVariant,
    required this.accentLight,
    required this.accentDark,
    required this.hover,
    required this.pressed,
    required this.disabled,
    required this.disabledText,
    required this.focus,
    required this.success,
    required this.error,
    required this.warning,
    required this.info,
  });

  factory AppColorScheme.light() {
    return const AppColorScheme(
      primaryText: AppColors.primaryText,
      secondaryText: AppColors.secondaryText,
      tertiaryText: AppColors.tertiaryText,
      onDarkText: AppColors.onDarkText,
      background: AppColors.cardBackground,
      cardBackground: AppColors.cardBackground,
      cardBackgroundAlt: AppColors.cardBackgroundAlt,
      surface: AppColors.surface,
      surfaceVariant: AppColors.surfaceVariant,
      surfaceContainer: AppColors.surfaceContainer,
      primaryButton: AppColors.primaryButton,
      primaryButtonHover: AppColors.primaryButtonHover,
      buttonText: AppColors.buttonText,
      buttonTextDark: AppColors.buttonTextDark,
      borderLight: AppColors.borderLight,
      borderMedium: AppColors.borderMedium,
      borderDark: AppColors.borderDark,
      accent: AppColors.accent,
      accentVariant: AppColors.accentVariant,
      accentLight: AppColors.accentLight,
      accentDark: AppColors.accentDark,
      hover: AppColors.hover,
      pressed: AppColors.pressed,
      disabled: AppColors.disabled,
      disabledText: AppColors.disabledText,
      focus: AppColors.focus,
      success: AppColors.success,
      error: AppColors.error,
      warning: AppColors.warning,
      info: AppColors.info,
    );
  }

  factory AppColorScheme.dark() {
    return const AppColorScheme(
      primaryText: AppColors.darkPrimaryText,
      secondaryText: AppColors.darkSecondaryText,
      tertiaryText: AppColors.darkTertiaryText,
      onDarkText: AppColors.darkPrimaryText,
      background: AppColors.overlayDark,
      cardBackground: AppColors.darkCardBackground,
      cardBackgroundAlt: AppColors.darkCardBackgroundAlt,
      surface: AppColors.darkSurface,
      surfaceVariant: AppColors.darkSurfaceVariant,
      surfaceContainer: AppColors.darkSurfaceContainer,
      primaryButton: AppColors.darkPrimaryButton,
      primaryButtonHover: AppColors.darkPrimaryButtonHover,
      buttonText: AppColors.buttonTextDark,
      buttonTextDark: AppColors.buttonText,
      borderLight: AppColors.darkBorderLight,
      borderMedium: AppColors.darkBorderMedium,
      borderDark: AppColors.darkBorderDark,
      accent: AppColors.accent,
      accentVariant: AppColors.accentVariant,
      accentLight: AppColors.accentLight,
      accentDark: AppColors.accentDark,
      hover: AppColors.darkHover,
      pressed: AppColors.darkPressed,
      disabled: AppColors.darkDisabled,
      disabledText: AppColors.darkDisabledText,
      focus: AppColors.darkFocus,
      success: AppColors.success,
      error: AppColors.error,
      warning: AppColors.warning,
      info: AppColors.info,
    );
  }

  /// High contrast color scheme for maximum accessibility
  /// All text is pure white on pure black background
  /// Meets WCAG AAA standards (21:1 contrast ratio)
  factory AppColorScheme.highContrast() {
    return const AppColorScheme(
      primaryText: Color(0xFFFFFFFF), // Pure white - maximum contrast
      secondaryText: Color(0xFFFFFFFF), // Pure white (no gray variants)
      tertiaryText: Color(0xFFFFFFFF), // Pure white (no gray variants)
      onDarkText: Color(0xFFFFFFFF), // Pure white
      background: Color(0xFF000000), // Pure black
      cardBackground: Color(0xFF000000), // Pure black
      cardBackgroundAlt: Color(0xFF1A1A1A), // Slightly lighter for depth (still high contrast)
      surface: Color(0xFF000000), // Pure black
      surfaceVariant: Color(0xFF1A1A1A), // Slightly lighter for depth
      surfaceContainer: Color(0xFF1A1A1A), // Slightly lighter for depth
      primaryButton: Color(0xFFFFFFFF), // White button on black
      primaryButtonHover: Color(0xFFE0E0E0), // Slightly darker white for hover
      buttonText: Color(0xFF000000), // Black text on white buttons
      buttonTextDark: Color(0xFFFFFFFF), // White text on dark buttons
      borderLight: Color(0xFFFFFFFF), // White borders for maximum visibility
      borderMedium: Color(0xFFFFFFFF), // White borders
      borderDark: Color(0xFFFFFFFF), // White borders
      accent: Color(0xFFFFFFFF), // White accent (maximum contrast)
      accentVariant: Color(0xFFE0E0E0), // Slightly darker white
      accentLight: Color(0xFFFFFFFF), // White
      accentDark: Color(0xFFE0E0E0), // Slightly darker white
      hover: Color(0xFF1A1A1A), // Slightly lighter black for hover
      pressed: Color(0xFF2A2A2A), // Lighter black for pressed
      disabled: Color(0xFF404040), // Dark gray for disabled (still visible)
      disabledText: Color(0xFF808080), // Medium gray for disabled text (still readable)
      focus: Color(0xFFFFFFFF), // White focus indicator (maximum visibility)
      success: Color(0xFF00FF00), // Bright green (high contrast)
      error: Color(0xFFFF0000), // Bright red (high contrast)
      warning: Color(0xFFFFAA00), // Bright orange (high contrast)
      info: Color(0xFF00AAFF), // Bright blue (high contrast)
    );
  }
  final Color primaryText;
  final Color secondaryText;
  final Color tertiaryText;
  final Color onDarkText;
  final Color background;
  final Color cardBackground;
  final Color cardBackgroundAlt;
  final Color surface;
  final Color surfaceVariant;
  final Color surfaceContainer;
  final Color primaryButton;
  final Color primaryButtonHover;
  final Color buttonText;
  final Color buttonTextDark;
  final Color borderLight;
  final Color borderMedium;
  final Color borderDark;
  final Color accent;
  final Color accentVariant;
  final Color accentLight;
  final Color accentDark;
  final Color hover;
  final Color pressed;
  final Color disabled;
  final Color disabledText;
  final Color focus;
  final Color success;
  final Color error;
  final Color warning;
  final Color info;

  /// Get hover color for interactive elements
  Color getHoverColor(Color baseColor) {
    return hover;
  }

  /// Get pressed color for interactive elements
  Color getPressedColor(Color baseColor) {
    return pressed;
  }

  /// Get disabled color for interactive elements
  Color getDisabledColor() {
    return disabled;
  }

  /// Get disabled text color
  Color getDisabledTextColor() {
    return disabledText;
  }
}
