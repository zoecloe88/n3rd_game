import 'package:flutter/material.dart';

/// RTL (Right-to-Left) language support helper
/// Provides utilities for detecting and handling RTL languages
class RTLHelper {
  /// RTL language codes
  static const List<String> rtlLanguages = [
    'ar', // Arabic
    'he', // Hebrew
    'fa', // Persian (Farsi)
    'ur', // Urdu
    'yi', // Yiddish
    'sd', // Sindhi
    'ug', // Uyghur
  ];

  /// Check if a locale is RTL
  static bool isRTL(Locale locale) {
    return rtlLanguages.contains(locale.languageCode);
  }

  /// Check if current locale is RTL based on context
  static bool isRTLFromContext(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return isRTL(locale);
  }

  /// Get text direction for a locale
  static TextDirection getTextDirection(Locale locale) {
    return isRTL(locale) ? TextDirection.rtl : TextDirection.ltr;
  }

  /// Get text direction from context
  static TextDirection getTextDirectionFromContext(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return getTextDirection(locale);
  }

  /// Mirror icon horizontally for RTL
  static Widget mirrorIcon(Widget icon, BuildContext context) {
    if (isRTLFromContext(context)) {
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(3.14159), // 180 degrees
        child: icon,
      );
    }
    return icon;
  }

  /// Get RTL-aware edge insets
  static EdgeInsetsGeometry getEdgeInsets(
    BuildContext context, {
    double start = 0,
    double end = 0,
    double top = 0,
    double bottom = 0,
  }) {
    return EdgeInsetsDirectional.only(
      start: start,
      end: end,
      top: top,
      bottom: bottom,
    );
  }

  /// Get RTL-aware padding
  static EdgeInsetsGeometry getPadding(
    BuildContext context, {
    double horizontal = 0,
    double vertical = 0,
  }) {
    return EdgeInsetsDirectional.symmetric(
      horizontal: horizontal,
      vertical: vertical,
    );
  }

  /// Get RTL-aware margin
  static EdgeInsetsGeometry getMargin(
    BuildContext context, {
    double horizontal = 0,
    double vertical = 0,
  }) {
    return EdgeInsetsDirectional.symmetric(
      horizontal: horizontal,
      vertical: vertical,
    );
  }
}
