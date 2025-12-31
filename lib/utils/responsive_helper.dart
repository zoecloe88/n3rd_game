import 'package:flutter/material.dart';

/// Utility class for responsive design and device detection
class ResponsiveHelper {
  // Breakpoints
  static const double smallPhoneMax = 360;
  static const double largePhoneMin = 360;
  static const double largePhoneMax = 600;
  static const double tabletMin = 600;
  static const double tabletMax = 840;
  static const double largeTabletMin = 840;

  /// Check if device is a small phone (< 360px)
  static bool isSmallPhone(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final shortestSide = size.shortestSide;
    return shortestSide < smallPhoneMax;
  }

  /// Check if device is a large phone (360-600px)
  static bool isLargePhone(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final shortestSide = size.shortestSide;
    return shortestSide >= largePhoneMin && shortestSide < largePhoneMax;
  }

  /// Check if device is a tablet (iPad, Android tablet) (600-840px)
  static bool isTablet(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final shortestSide = size.shortestSide;
    return shortestSide >= tabletMin && shortestSide < tabletMax;
  }

  /// Check if device is a large tablet (> 840px)
  static bool isLargeTablet(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final shortestSide = size.shortestSide;
    return shortestSide >= largeTabletMin;
  }

  /// Get responsive size based on screen height percentage
  /// Works well for both phones and tablets
  static double responsiveHeight(BuildContext context, double percentage) {
    return MediaQuery.of(context).size.height * percentage;
  }

  /// Get responsive size based on screen width percentage
  static double responsiveWidth(BuildContext context, double percentage) {
    return MediaQuery.of(context).size.width * percentage;
  }

  /// Get responsive Lottie animation height
  /// Scales appropriately for tablets vs phones
  static double lottieHeight(
    BuildContext context, {
    double phonePercentage = 0.1,
    double tabletPercentage = 0.15,
  }) {
    if (isTablet(context)) {
      return responsiveHeight(context, tabletPercentage);
    }
    return responsiveHeight(context, phonePercentage);
  }

  /// Get responsive font size multiplier
  /// Tablets can use slightly larger fonts
  static double fontSizeMultiplier(BuildContext context) {
    return isTablet(context) ? 1.2 : 1.0;
  }

  /// Get responsive font size based on screen width
  /// Ensures text scales appropriately across all device sizes
  /// [baseSize] - Base font size for reference device (typically iPhone width ~375)
  /// [minSize] - Minimum font size to ensure readability
  /// [maxSize] - Maximum font size to prevent overflow
  static double responsiveFontSize(
    BuildContext context, {
    required double baseSize,
    double? minSize,
    double? maxSize,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Base reference width (iPhone standard ~375)
    const baseWidth = 375.0;

    // Calculate responsive size based on screen width
    double responsiveSize = (screenWidth / baseWidth) * baseSize;

    // Apply multiplier based on device type
    if (isLargeTablet(context)) {
      responsiveSize *= 1.25; // Larger on large tablets
    } else if (isTablet(context)) {
      responsiveSize *= 1.15; // Slightly larger on tablets
    } else if (isSmallPhone(context)) {
      responsiveSize *= 0.95; // Slightly smaller on small phones
    }

    // Clamp to min/max if provided
    if (minSize != null && responsiveSize < minSize) {
      responsiveSize = minSize;
    }
    if (maxSize != null && responsiveSize > maxSize) {
      responsiveSize = maxSize;
    }

    return responsiveSize;
  }

  /// Get responsive spacing based on device type
  /// Returns spacing multiplier for different device sizes
  static double getSpacingMultiplier(BuildContext context) {
    if (isLargeTablet(context)) {
      return 1.3; // More spacing on large tablets
    } else if (isTablet(context)) {
      return 1.15; // Slightly more spacing on tablets
    } else if (isSmallPhone(context)) {
      return 0.9; // Less spacing on small phones
    }
    return 1.0; // Default spacing
  }

  /// Get responsive spacing value
  static double responsiveSpacing(
    BuildContext context,
    double baseSpacing,
  ) {
    return baseSpacing * getSpacingMultiplier(context);
  }

  /// Get responsive padding based on device type
  static EdgeInsets responsivePadding(
    BuildContext context, {
    double? all,
    double? horizontal,
    double? vertical,
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) {
    final multiplier = getSpacingMultiplier(context);
    return EdgeInsets.only(
      top: (top ?? vertical ?? all ?? 0) * multiplier,
      bottom: (bottom ?? vertical ?? all ?? 0) * multiplier,
      left: (left ?? horizontal ?? all ?? 0) * multiplier,
      right: (right ?? horizontal ?? all ?? 0) * multiplier,
    );
  }

  /// Get responsive margin based on device type
  static EdgeInsets responsiveMargin(
    BuildContext context, {
    double? all,
    double? horizontal,
    double? vertical,
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) {
    final multiplier = getSpacingMultiplier(context);
    return EdgeInsets.only(
      top: (top ?? vertical ?? all ?? 0) * multiplier,
      bottom: (bottom ?? vertical ?? all ?? 0) * multiplier,
      left: (left ?? horizontal ?? all ?? 0) * multiplier,
      right: (right ?? horizontal ?? all ?? 0) * multiplier,
    );
  }

  /// Check if device is in landscape orientation
  static bool isLandscape(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width > size.height;
  }

  /// Check if device is in portrait orientation
  static bool isPortrait(BuildContext context) {
    return !isLandscape(context);
  }

  /// Get responsive column count for grid layouts
  static int getColumnCount(
    BuildContext context, {
    int smallPhone = 1,
    int largePhone = 2,
    int tablet = 3,
    int largeTablet = 4,
  }) {
    if (isLargeTablet(context)) {
      return largeTablet;
    } else if (isTablet(context)) {
      return tablet;
    } else if (isLargePhone(context)) {
      return largePhone;
    } else {
      return smallPhone;
    }
  }

  /// Get responsive typography scale multiplier
  static double getTypographyScale(BuildContext context) {
    if (isLargeTablet(context)) {
      return 1.2;
    } else if (isTablet(context)) {
      return 1.1;
    } else if (isSmallPhone(context)) {
      return 0.95;
    }
    return 1.0;
  }
}
