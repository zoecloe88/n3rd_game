import 'package:flutter/material.dart';

/// Utility class for responsive design and device detection
class ResponsiveHelper {
  /// Check if device is a tablet (iPad, Android tablet)
  static bool isTablet(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final shortestSide = size.shortestSide;
    // Tablets typically have shortest side >= 600
    return shortestSide >= 600;
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
    
    // Apply multiplier for tablets
    if (isTablet(context)) {
      responsiveSize *= 1.15; // Slightly larger on tablets
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
}
