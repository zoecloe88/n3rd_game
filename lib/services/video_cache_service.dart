import 'package:video_player/video_player.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Service for managing video preloading and caching
/// Improves performance by preloading frequently used videos
class VideoCacheService {
  static final VideoCacheService _instance = VideoCacheService._internal();
  factory VideoCacheService() => _instance;
  VideoCacheService._internal();

  // Cache of preloaded video controllers
  final Map<String, VideoPlayerController> _cachedControllers = {};
  
  // Videos that should be preloaded on app start
  static const List<String> _preloadVideos = [
    'assets/logoloadingscreen.mp4', // First screen - highest priority
    'assets/titlescreen.mp4', // Frequently accessed
    'assets/modeselectionscreen.mp4', // Frequently accessed
  ];

  // Maximum number of cached videos to prevent memory issues
  static const int _maxCacheSize = 5;

  /// Preload a video and cache the controller
  Future<VideoPlayerController?> preloadVideo(String videoPath) async {
    // Return cached controller if available and valid
    if (_cachedControllers.containsKey(videoPath)) {
      final controller = _cachedControllers[videoPath]!;
      try {
        // Validate controller is still valid and initialized
        if (controller.value.isInitialized) {
          return controller;
        } else {
          // Controller exists but not initialized - remove and reinitialize
          _cachedControllers.remove(videoPath);
          try {
            controller.dispose();
          } catch (e) {
            // Controller already disposed - ignore
          }
        }
      } catch (e) {
        // Controller was disposed - remove from cache
        _cachedControllers.remove(videoPath);
        LoggerService.debug('Removed disposed controller during preload: $videoPath');
      }
    }

    try {
      final controller = VideoPlayerController.asset(videoPath);
      await controller.initialize();
      
      // Cache the controller
      _cachedControllers[videoPath] = controller;
      
      // Enforce cache size limit
      _enforceCacheLimit();
      
      LoggerService.debug('Video preloaded: $videoPath');
      return controller;
    } catch (e) {
      LoggerService.warning(
        'Failed to preload video: $videoPath',
        error: e,
      );
      return null;
    }
  }

  /// Get a cached video controller or return null if not cached
  /// Returns null if controller is disposed or not initialized
  VideoPlayerController? getCachedController(String videoPath) {
    final controller = _cachedControllers[videoPath];
    if (controller == null) {
      return null;
    }
    
    // CRITICAL: Validate controller is still valid and initialized
    // Check if controller is initialized and can be safely used
    try {
      // Accessing value will throw if controller is disposed
      if (controller.value.isInitialized) {
        return controller;
      }
    } catch (e) {
      // Controller was disposed - remove from cache
      _cachedControllers.remove(videoPath);
      LoggerService.debug('Removed disposed controller from cache: $videoPath');
      return null;
    }
    
    // Controller exists but not initialized - remove from cache
    _cachedControllers.remove(videoPath);
    return null;
  }

  /// Preload all priority videos
  Future<void> preloadPriorityVideos() async {
    for (final videoPath in _preloadVideos) {
      try {
        await preloadVideo(videoPath);
      } catch (e) {
        LoggerService.warning(
          'Failed to preload priority video: $videoPath',
          error: e,
        );
      }
    }
  }

  /// Remove a video from cache
  void removeFromCache(String videoPath) {
    final controller = _cachedControllers.remove(videoPath);
    controller?.dispose();
  }

  /// Clear all cached videos
  void clearCache() {
    for (final controller in _cachedControllers.values) {
      controller.dispose();
    }
    _cachedControllers.clear();
    LoggerService.debug('Video cache cleared');
  }

  /// Enforce cache size limit by removing least recently used videos
  void _enforceCacheLimit() {
    if (_cachedControllers.length <= _maxCacheSize) {
      return;
    }

    // Remove videos that are not in the preload list
    final preloadSet = _preloadVideos.toSet();
    final nonPreloadVideos = _cachedControllers.keys
        .where((path) => !preloadSet.contains(path))
        .toList();

    // Remove excess non-preload videos
    final excessCount = _cachedControllers.length - _maxCacheSize;
    if (excessCount > 0 && nonPreloadVideos.isNotEmpty) {
      final toRemove = nonPreloadVideos.take(excessCount);
      for (final path in toRemove) {
        removeFromCache(path);
      }
    }
  }

  /// Dispose all cached controllers (call on app shutdown)
  void dispose() {
    clearCache();
  }

  /// Get cache statistics for debugging
  Map<String, dynamic> getCacheStats() {
    return {
      'cachedVideos': _cachedControllers.length,
      'maxCacheSize': _maxCacheSize,
      'cachedPaths': _cachedControllers.keys.toList(),
    };
  }
}

