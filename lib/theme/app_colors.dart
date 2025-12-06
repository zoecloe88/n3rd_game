import 'package:flutter/material.dart';

/// Application color system with light and dark mode support
///
/// **Usage:**
/// - Use `AppColors.of(context)` to get theme-aware colors
/// - Colors automatically adapt to light/dark mode
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
  static const Color overlayDark = Color(0xFF000000); // Black overlay
  static const Color borderLight = Color(0xFFE0E0E0); // Light borders
  static const Color borderMedium = Color(0xFFBDBDBD); // Medium borders

  // DARK MODE COLORS
  static const Color darkPrimaryText = Color(0xFFFFFFFF); // White
  static const Color darkSecondaryText = Color(0xFFB0B0B0); // Light gray
  static const Color darkTertiaryText = Color(0xFF808080); // Medium gray
  static const Color darkCardBackground = Color(0xFF1E1E1E); // Dark cards
  static const Color darkCardBackgroundAlt = Color(0xFF2A2A2A); // Darker cards
  static const Color darkPrimaryButton = Color(0xFFFFFFFF); // White button
  static const Color darkPrimaryButtonHover = Color(0xFFE0E0E0);
  static const Color darkBorderLight = Color(0xFF404040); // Dark borders
  static const Color darkBorderMedium = Color(0xFF505050); // Darker borders

  /// Get theme-aware colors based on current theme
  static AppColorScheme of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? AppColorScheme.dark()
        : AppColorScheme.light();
  }
}

/// Theme-aware color scheme
class AppColorScheme {
  final Color primaryText;
  final Color secondaryText;
  final Color tertiaryText;
  final Color onDarkText;
  final Color background;
  final Color cardBackground;
  final Color cardBackgroundAlt;
  final Color primaryButton;
  final Color primaryButtonHover;
  final Color buttonText;
  final Color buttonTextDark;
  final Color borderLight;
  final Color borderMedium;
  final Color success;
  final Color error;
  final Color warning;
  final Color info;

  const AppColorScheme({
    required this.primaryText,
    required this.secondaryText,
    required this.tertiaryText,
    required this.onDarkText,
    required this.background,
    required this.cardBackground,
    required this.cardBackgroundAlt,
    required this.primaryButton,
    required this.primaryButtonHover,
    required this.buttonText,
    required this.buttonTextDark,
    required this.borderLight,
    required this.borderMedium,
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
      primaryButton: AppColors.primaryButton,
      primaryButtonHover: AppColors.primaryButtonHover,
      buttonText: AppColors.buttonText,
      buttonTextDark: AppColors.buttonTextDark,
      borderLight: AppColors.borderLight,
      borderMedium: AppColors.borderMedium,
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
      primaryButton: AppColors.darkPrimaryButton,
      primaryButtonHover: AppColors.darkPrimaryButtonHover,
      buttonText: AppColors.buttonTextDark,
      buttonTextDark: AppColors.buttonText,
      borderLight: AppColors.darkBorderLight,
      borderMedium: AppColors.darkBorderMedium,
      success: AppColors.success,
      error: AppColors.error,
      warning: AppColors.warning,
      info: AppColors.info,
    );
  }
}
