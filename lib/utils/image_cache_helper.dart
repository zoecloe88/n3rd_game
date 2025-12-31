import 'package:flutter/material.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Image cache helper for optimizing network image loading
/// Provides caching, error handling, and placeholder support
class ImageCacheHelper {
  /// Precache network images for better performance
  /// Call this before displaying images to reduce loading time
  static Future<void> precacheNetworkImage(
    BuildContext context,
    String imageUrl, {
    ImageErrorWidgetBuilder? errorBuilder,
  }) async {
    try {
      final image = NetworkImage(imageUrl);
      await precacheImage(image, context);
      LoggerService.debug('Precached network image: $imageUrl');
    } catch (e) {
      LoggerService.warning(
        'Failed to precache network image: $imageUrl',
        error: e,
      );
    }
  }

  /// Precache multiple network images
  static Future<void> precacheNetworkImages(
    BuildContext context,
    List<String> imageUrls,
  ) async {
    for (final url in imageUrls) {
      try {
        await precacheNetworkImage(context, url);
      } catch (e) {
        // Continue with other images even if one fails
        LoggerService.debug('Skipped precaching image: $url');
      }
    }
  }

  /// Get cached network image widget with error handling
  static Widget cachedNetworkImage(
    String imageUrl, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return placeholder ??
            Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
      },
      errorBuilder: (context, error, stackTrace) {
        LoggerService.warning(
          'Failed to load network image: $imageUrl',
          error: error,
        );
        return errorWidget ??
            const Icon(
              Icons.error_outline,
              color: Colors.grey,
            );
      },
      // Enable caching
      cacheWidth: width?.toInt(),
      cacheHeight: height?.toInt(),
    );
  }

  /// Clear image cache to free memory
  static void clearImageCache() {
    try {
      imageCache.clear();
      imageCache.clearLiveImages();
      LoggerService.debug('Image cache cleared');
    } catch (e) {
      LoggerService.warning('Failed to clear image cache', error: e);
    }
  }

  /// Set image cache size limits
  static void configureImageCache({
    int? maximumSize,
    int? maximumSizeBytes,
  }) {
    try {
      if (maximumSize != null) {
        imageCache.maximumSize = maximumSize;
      }
      if (maximumSizeBytes != null) {
        imageCache.maximumSizeBytes = maximumSizeBytes;
      }
      LoggerService.debug(
        'Image cache configured: maxSize=$maximumSize, maxSizeBytes=$maximumSizeBytes',
      );
    } catch (e) {
      LoggerService.warning('Failed to configure image cache', error: e);
    }
  }
}
