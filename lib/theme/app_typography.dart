import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Professional typography matching NYT Games "Pips" design system
///
/// **Font Strategy (Production-Ready):**
/// - Primary: Google Fonts package for dynamic loading (recommended for production)
///   - Fonts are cached after first load, providing excellent offline support
///   - Ensures fonts are always up-to-date
///   - Reduces app bundle size
/// - Fallback: Bundled fonts (optional, for guaranteed offline availability)
///   - Configured in pubspec.yaml when font files are added to fonts/ directory
///   - Not required - Google Fonts caching provides sufficient offline support
///
/// **Font Families:**
/// - Playfair Display: Headlines and display text
/// - Lora: Body text and serif content
/// - Inter: UI elements, labels, and interface text
///
/// **Usage Guidelines:**
/// - Use displayLarge/Medium for hero headlines
/// - Use headlineLarge for section headers
/// - Use titleLarge for card titles
/// - Use bodyLarge/Medium for body text
/// - Use labelLarge/Small for buttons and labels
/// - Use special fonts (orbitron, ibmPlexMono, spaceGrotesk) sparingly for special UI elements
class AppTypography {
  // PRIMARY FONT: Playfair Display (Headlines)
  // Using GoogleFonts directly ensures proper fallback and offline caching
  static TextStyle get displayLarge => GoogleFonts.playfairDisplay(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
        height: 1.2,
      );

  static TextStyle get displayMedium => GoogleFonts.playfairDisplay(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
        height: 1.3,
      );

  static TextStyle get headlineLarge => GoogleFonts.playfairDisplay(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        height: 1.3,
      );

  static TextStyle get headlineMedium => GoogleFonts.playfairDisplay(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        height: 1.3,
      );

  // SECONDARY FONT: Lora (Subtitles/Body Serif)
  static TextStyle get titleLarge => GoogleFonts.lora(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        height: 1.5,
      );

  static TextStyle get bodyLarge => GoogleFonts.lora(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        height: 1.6,
      );

  // UTILITY FONT: Inter (UI Elements)
  static TextStyle get labelLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        height: 1.5,
      );

  static TextStyle get labelSmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      );

  // SPECIAL FONTS: For specific UI elements (use sparingly)
  /// Orbitron - For futuristic/tech UI elements
  static TextStyle orbitron({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    return GoogleFonts.orbitron(
      fontSize: fontSize ?? 16,
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color,
    );
  }

  /// IBM Plex Mono - For code/technical displays
  static TextStyle ibmPlexMono({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    return GoogleFonts.ibmPlexMono(
      fontSize: fontSize ?? 14,
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color,
    );
  }

  /// Space Grotesk - For modern/geometric UI elements
  static TextStyle spaceGrotesk({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: fontSize ?? 16,
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color,
    );
  }

  /// Playfair Display - Direct access with customization
  /// Uses Google Fonts directly for proper fallback and offline caching
  static TextStyle playfairDisplay({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.playfairDisplay(
      fontSize: fontSize ?? 24,
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Inter - Direct access with customization
  /// Uses Google Fonts directly for proper fallback and offline caching
  static TextStyle inter({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize ?? 14,
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Lora - Direct access with customization
  /// Uses Google Fonts directly for proper fallback and offline caching
  static TextStyle lora({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
  }) {
    return GoogleFonts.lora(
      fontSize: fontSize ?? 16,
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color,
      height: height,
    );
  }
}
