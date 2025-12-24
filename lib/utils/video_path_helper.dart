import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Helper class to select the appropriate video variant based on device aspect ratio
///
/// The video generation tool creates 3 variants:
/// - standard (1080x1920) - 9:16 aspect ratio
/// - tall (1080x2340) - ~19.5:9 aspect ratio
/// - extra_tall (1080x2400) - taller devices
///
/// This helper automatically selects the best matching variant for the device.
class VideoPathHelper {
  /// Get the appropriate video path based on device aspect ratio
  ///
  /// Input: 'assets/videos/title_video.mp4'
  /// Output: 'assets/videos/title_video_standard.mp4' (or tall/extra_tall)
  ///
  /// [context] - BuildContext to access MediaQuery for screen dimensions
  /// [basePath] - Base video path without variant suffix (e.g., 'assets/videos/title_video.mp4')
  ///
  /// Returns the path with the appropriate variant suffix based on device aspect ratio
  /// Falls back to base path if MediaQuery is unavailable or invalid
  static String getVideoPath(BuildContext context, String basePath) {
    try {
      final size = MediaQuery.of(context).size;

      // Validate size to prevent division by zero or invalid calculations
      if (size.width <= 0 || size.height <= 0) {
        if (kDebugMode) {
          debugPrint('VideoPathHelper: Invalid screen size, using base path');
        }
        return basePath;
      }

      final aspectRatio = size.height / size.width;

      // Validate aspect ratio (should be positive and reasonable)
      if (aspectRatio <= 0 || !aspectRatio.isFinite) {
        if (kDebugMode) {
          debugPrint('VideoPathHelper: Invalid aspect ratio, using base path');
        }
        return basePath;
      }

      // Extract base name (e.g., 'assets/videos/title_video' from 'assets/videos/title_video.mp4')
      // Handle files with spaces (e.g., 'transition 1.mp4' -> 'transition 1')
      final lastDotIndex = basePath.lastIndexOf('.');
      final extension = lastDotIndex >= 0 && lastDotIndex < basePath.length - 1
          ? basePath.substring(lastDotIndex + 1)
          : 'mp4';
      final baseName =
          lastDotIndex >= 0 ? basePath.substring(0, lastDotIndex) : basePath;

      String variant;

      // Determine variant based on aspect ratio
      if (aspectRatio >= 2.2) {
        // Extra tall devices (iPhone 14 Pro Max, etc.) - 2400px tall
        variant = 'extra_tall';
      } else if (aspectRatio >= 2.0) {
        // Tall devices (most modern phones) - 2340px tall
        variant = 'tall';
      } else {
        // Standard devices (9:16) - 1920px tall
        variant = 'standard';
      }

      // Return path with variant: 'assets/videos/title_video_tall.mp4'
      // Handles spaces correctly: 'assets/videos/transition 1_standard.mp4'
      return '${baseName}_$variant.$extension';
    } catch (e) {
      // If MediaQuery fails or context is invalid, fall back to base path
      if (kDebugMode) {
        debugPrint(
          'VideoPathHelper: Error getting video path: $e, using base path',
        );
      }
      return basePath;
    }
  }

  /// Get aspect ratio category for debugging
  ///
  /// Returns a string describing the device's aspect ratio category
  static String getAspectRatioCategory(BuildContext context) {
    try {
      final size = MediaQuery.of(context).size;

      if (size.width <= 0 || size.height <= 0) {
        return 'invalid';
      }

      final aspectRatio = size.height / size.width;

      if (aspectRatio <= 0 || !aspectRatio.isFinite) {
        return 'invalid';
      }

      if (aspectRatio >= 2.2) {
        return 'extra_tall (≥2.2)';
      } else if (aspectRatio >= 2.0) {
        return 'tall (≥2.0)';
      } else {
        return 'standard (<2.0)';
      }
    } catch (e) {
      return 'error';
    }
  }
}
