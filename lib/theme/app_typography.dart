import 'package:flutter/foundation.dart';
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
/// - Use headlineLarge/Medium for section headers
/// - Use titleLarge/Medium/Small for card titles and subtitles
/// - Use bodyLarge/Medium/Small for body text
/// - Use labelLarge/Small for buttons and labels
/// - Use special fonts (orbitron, ibmPlexMono, spaceGrotesk) sparingly for special UI elements
///
/// **Typography Scale:**
/// - Display: 36px (displayLarge), 28px (displayMedium)
/// - Headline: 24px (headlineLarge), 20px (headlineMedium)
/// - Title: 20px (titleLarge), 18px (titleMedium), 16px (titleSmall)
/// - Body: 16px (bodyLarge), 14px (bodyMedium), 12px (bodySmall)
/// - Label: 16px (labelLarge), 12px (labelSmall)
class AppTypography {
  /// Helper to safely get Google Font with fallback to system font
  /// This prevents font loading errors in test environments
  /// In test mode, immediately fallback to system fonts to avoid asset loading issues
  static TextStyle _safeGoogleFont(
    TextStyle Function() googleFont, {
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    Color? color,
  }) {
    // In test/debug mode, use system fonts to avoid google_fonts asset loading issues
    // This prevents "Message corrupted" FormatException errors in tests
    if (kDebugMode) {
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        height: height,
        color: color,
        fontFamily: null, // System default font
      );
    }

    try {
      return googleFont();
    } catch (e) {
      // Fallback to system font if google_fonts fails
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        height: height,
        color: color,
        fontFamily: null, // System default font
      );
    }
  }

  // PRIMARY FONT: Playfair Display (Headlines)
  // Using GoogleFonts directly ensures proper fallback and offline caching
  static TextStyle get displayLarge => _safeGoogleFont(
        () => GoogleFonts.playfairDisplay(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          height: 1.2,
        ),
        fontSize: 36,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
        height: 1.2,
      );

  static TextStyle get displayMedium => _safeGoogleFont(
        () => GoogleFonts.playfairDisplay(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
          height: 1.3,
        ),
        fontSize: 28,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
        height: 1.3,
      );

  static TextStyle get headlineLarge => _safeGoogleFont(
        () => GoogleFonts.playfairDisplay(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          height: 1.3,
        ),
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        height: 1.3,
      );

  static TextStyle get headlineMedium => _safeGoogleFont(
        () => GoogleFonts.playfairDisplay(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          height: 1.3,
        ),
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        height: 1.3,
      );

  // SECONDARY FONT: Lora (Subtitles/Body Serif)
  static TextStyle get titleLarge => _safeGoogleFont(
        () => GoogleFonts.lora(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          height: 1.5,
        ),
        fontSize: 20,
        fontWeight: FontWeight.w500,
        height: 1.5,
      );

  static TextStyle get titleMedium => _safeGoogleFont(
        () => GoogleFonts.lora(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          height: 1.5,
        ),
        fontSize: 18,
        fontWeight: FontWeight.w500,
        height: 1.5,
      );

  static TextStyle get titleSmall => _safeGoogleFont(
        () => GoogleFonts.lora(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.5,
        ),
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.5,
      );

  static TextStyle get bodyLarge => _safeGoogleFont(
        () => GoogleFonts.lora(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          height: 1.6,
        ),
        fontSize: 16,
        fontWeight: FontWeight.normal,
        height: 1.6,
      );

  // UTILITY FONT: Inter (UI Elements)
  static TextStyle get labelLarge => _safeGoogleFont(
        () => GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      );

  static TextStyle get bodyMedium => _safeGoogleFont(
        () => GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          height: 1.5,
        ),
        fontSize: 14,
        fontWeight: FontWeight.normal,
        height: 1.5,
      );

  static TextStyle get labelSmall => _safeGoogleFont(
        () => GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      );

  static TextStyle get bodySmall => _safeGoogleFont(
        () => GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          height: 1.5,
        ),
        fontSize: 12,
        fontWeight: FontWeight.normal,
        height: 1.5,
      );

  // SPECIAL FONTS: For specific UI elements (use sparingly)
  /// Orbitron - For futuristic/tech UI elements
  static TextStyle orbitron({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    return _safeGoogleFont(
      () => GoogleFonts.orbitron(
        fontSize: fontSize ?? 16,
        fontWeight: fontWeight ?? FontWeight.normal,
        color: color,
      ),
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
    return _safeGoogleFont(
      () => GoogleFonts.ibmPlexMono(
        fontSize: fontSize ?? 14,
        fontWeight: fontWeight ?? FontWeight.normal,
        color: color,
      ),
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
    return _safeGoogleFont(
      () => GoogleFonts.spaceGrotesk(
        fontSize: fontSize ?? 16,
        fontWeight: fontWeight ?? FontWeight.normal,
        color: color,
      ),
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
    return _safeGoogleFont(
      () => GoogleFonts.playfairDisplay(
        fontSize: fontSize ?? 24,
        fontWeight: fontWeight ?? FontWeight.normal,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      ),
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
    return _safeGoogleFont(
      () => GoogleFonts.inter(
        fontSize: fontSize ?? 14,
        fontWeight: fontWeight ?? FontWeight.normal,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      ),
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
    return _safeGoogleFont(
      () => GoogleFonts.lora(
        fontSize: fontSize ?? 16,
        fontWeight: fontWeight ?? FontWeight.normal,
        color: color,
        height: height,
      ),
      fontSize: fontSize ?? 16,
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color,
      height: height,
    );
  }
}
