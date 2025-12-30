import 'package:flutter/material.dart';

/// Utility class for calculating and validating color contrast ratios
/// Implements WCAG 2.1 contrast ratio formulas
///
/// **WCAG Standards:**
/// - AA (Normal text): 4.5:1 minimum
/// - AA (Large text): 3:1 minimum
/// - AAA (Normal text): 7:1 minimum
/// - AAA (Large text): 4.5:1 minimum
class ContrastValidator {
  /// Calculate relative luminance of a color (WCAG formula)
  ///
  /// Returns a value between 0 (black) and 1 (white)
  /// Formula: L = 0.2126 * R + 0.7152 * G + 0.0722 * B
  /// where R, G, B are the linear RGB values
  static double getRelativeLuminance(Color color) {
    // Convert sRGB to linear RGB
    double linearize(int component) {
      final normalized = component / 255.0;
      if (normalized <= 0.03928) {
        return normalized / 12.92;
      } else {
        return ((normalized + 0.055) / 1.055).pow(2.4);
      }
    }

    final r = linearize(color.red);
    final g = linearize(color.green);
    final b = linearize(color.blue);

    // Calculate relative luminance
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Calculate contrast ratio between two colors (WCAG formula)
  ///
  /// Returns a value between 1:1 (same color) and 21:1 (white on black)
  /// Formula: (L1 + 0.05) / (L2 + 0.05)
  /// where L1 is the lighter color and L2 is the darker color
  static double getContrastRatio(Color foreground, Color background) {
    final l1 = getRelativeLuminance(foreground);
    final l2 = getRelativeLuminance(background);

    // Ensure lighter color is in numerator
    final lighter = l1 > l2 ? l1 : l2;
    final darker = l1 > l2 ? l2 : l1;

    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Check if contrast meets WCAG AA for normal text (4.5:1)
  static bool meetsWCAGAA(Color foreground, Color background) {
    return getContrastRatio(foreground, background) >= 4.5;
  }

  /// Check if contrast meets WCAG AA for large text (3:1)
  /// Large text is typically 18pt+ or 14pt+ bold
  static bool meetsWCAGAAForLargeText(Color foreground, Color background) {
    return getContrastRatio(foreground, background) >= 3.0;
  }

  /// Check if contrast meets WCAG AAA for normal text (7:1)
  static bool meetsWCAGAAA(Color foreground, Color background) {
    return getContrastRatio(foreground, background) >= 7.0;
  }

  /// Check if contrast meets WCAG AAA for large text (4.5:1)
  static bool meetsWCAGAAAForLargeText(Color foreground, Color background) {
    return getContrastRatio(foreground, background) >= 4.5;
  }

  /// Get WCAG compliance level for a color pair
  ///
  /// Returns:
  /// - 'AAA' if meets AAA standards
  /// - 'AA' if meets AA standards
  /// - 'Fail' if does not meet AA standards
  static String getComplianceLevel(
    Color foreground,
    Color background, {
    bool isLargeText = false,
  }) {
    final ratio = getContrastRatio(foreground, background);

    if (isLargeText) {
      if (ratio >= 4.5) return 'AAA';
      if (ratio >= 3.0) return 'AA';
    } else {
      if (ratio >= 7.0) return 'AAA';
      if (ratio >= 4.5) return 'AA';
    }

    return 'Fail';
  }

  /// Validate contrast and return detailed information
  static ContrastValidationResult validate(
    Color foreground,
    Color background, {
    bool isLargeText = false,
  }) {
    final ratio = getContrastRatio(foreground, background);
    final meetsAA = isLargeText
        ? meetsWCAGAAForLargeText(foreground, background)
        : meetsWCAGAA(foreground, background);
    final meetsAAA = isLargeText
        ? meetsWCAGAAAForLargeText(foreground, background)
        : meetsWCAGAAA(foreground, background);
    final complianceLevel = getComplianceLevel(
      foreground,
      background,
      isLargeText: isLargeText,
    );

    return ContrastValidationResult(
      contrastRatio: ratio,
      meetsWCAGAA: meetsAA,
      meetsWCAGAAA: meetsAAA,
      complianceLevel: complianceLevel,
      foreground: foreground,
      background: background,
      isLargeText: isLargeText,
    );
  }
}

/// Result of contrast validation
class ContrastValidationResult {
  const ContrastValidationResult({
    required this.contrastRatio,
    required this.meetsWCAGAA,
    required this.meetsWCAGAAA,
    required this.complianceLevel,
    required this.foreground,
    required this.background,
    required this.isLargeText,
  });

  final double contrastRatio;
  final bool meetsWCAGAA;
  final bool meetsWCAGAAA;
  final String complianceLevel; // 'AAA', 'AA', or 'Fail'
  final Color foreground;
  final Color background;
  final bool isLargeText;

  /// Get a human-readable description of the contrast
  String get description {
    final ratioStr = contrastRatio.toStringAsFixed(2);
    return 'Contrast ratio: $ratioStr:1 ($complianceLevel)';
  }

  /// Check if the contrast is acceptable for accessibility
  bool get isAcceptable => meetsWCAGAA;
}














