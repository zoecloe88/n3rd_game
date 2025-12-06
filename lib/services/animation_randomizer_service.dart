import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service for randomly selecting animation MP4 files from categories
///
/// This service provides animation asset management with:
/// - Category-based organization
/// - Path validation to ensure assets exist
/// - Caching for performance optimization
/// - Random selection from available animations
///
/// Usage:
/// ```dart
/// final service = AnimationRandomizerService();
/// await service.init();
/// final animation = await service.getRandomAnimation('logo');
/// ```
///
/// The service must be initialized before use. It's registered as a Provider
/// in main.dart and can be accessed via `Provider.of<AnimationRandomizerService>`.
class AnimationRandomizerService extends ChangeNotifier {
  /// Cache of animations by category to avoid repeated manifest lookups
  final Map<String, List<String>> _cachedAnimations = {};

  /// Set of validated paths to prevent redundant validation checks
  final Set<String> _validatedPaths = {};

  /// Random number generator for animation selection
  final Random _random = Random();

  /// Initialization flag to ensure service is ready before use
  bool _isInitialized = false;

  /// Check if service is initialized and ready to use
  ///
  /// Returns `true` if the service has successfully initialized,
  /// `false` otherwise. The service must be initialized before
  /// calling any animation retrieval methods.
  bool get isInitialized => _isInitialized;

  /// Initialize the service by validating asset manifest availability
  ///
  /// This method should be called before using the service. It validates
  /// that the AssetManifest can be loaded, which is required for all
  /// animation retrieval operations.
  ///
  /// This is idempotent - safe to call multiple times.
  ///
  /// Throws no exceptions - failures are logged and the service
  /// will fail gracefully when accessing animations.
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Pre-validate that AssetManifest can be loaded
      await rootBundle.loadString('AssetManifest.json');
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ AnimationRandomizerService: Failed to initialize: $e');
      }
      // Continue - will fail gracefully when accessing animations
    }
  }

  /// Get all animations for a category with validation
  ///
  /// Returns a list of all animation asset paths for the given category.
  /// Results are cached to improve performance on subsequent calls.
  ///
  /// Parameters:
  /// - [category]: The animation category (e.g., 'logo', 'title', 'shared')
  ///
  /// Returns:
  /// - List of asset paths for the category, empty list if none found
  ///
  /// Example:
  /// ```dart
  /// final animations = await service.getAllAnimations('logo');
  /// // Returns: ['assets/animations/Green Neutral Simple Serendipity Phone Wallpaper(1)/Green Neutral Simple Serendipity Phone Wallpaper.mp4', ...]
  /// ```
  Future<List<String>> getAllAnimations(String category) async {
    // Validate category is not empty
    if (category.isEmpty) {
      if (kDebugMode) {
        debugPrint('⚠️ AnimationRandomizerService: Empty category provided');
      }
      return [];
    }

    if (_cachedAnimations.containsKey(category)) {
      return _cachedAnimations[category]!;
    }

    try {
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap =
          jsonDecode(manifestContent) as Map<String, dynamic>;

      final categoryPath = 'assets/animations/$category/';
      final animations = manifestMap.keys
          .where(
            (String key) =>
                key.startsWith(categoryPath) && key.endsWith('.mp4'),
          )
          .toList();

      // Validate that we found animations
      if (animations.isEmpty && kDebugMode) {
        debugPrint(
          '⚠️ AnimationRandomizerService: No animations found for category: $category',
        );
      }

      _cachedAnimations[category] = animations;
      return animations;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '❌ AnimationRandomizerService: Error loading animations for category $category: $e',
        );
      }
      return [];
    }
  }

  /// Get a random animation from a category with validation
  ///
  /// Selects and validates a random animation from the specified category.
  /// If the selected animation doesn't exist, it will retry with other
  /// available animations before returning null.
  ///
  /// Parameters:
  /// - [category]: The animation category to select from
  ///
  /// Returns:
  /// - A validated animation path, or null if no valid animations found
  ///
  /// Example:
  /// ```dart
  /// final animation = await service.getRandomAnimation('title');
  /// // Returns: 'assets/animations/title/title screen.mp4' or null
  /// ```
  Future<String?> getRandomAnimation(String category) async {
    final animations = await getAllAnimations(category);
    if (animations.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ AnimationRandomizerService: No animations available for category: $category',
        );
      }
      return null;
    }
    final selected = animations[_random.nextInt(animations.length)];

    // Validate path exists
    if (!_validatedPaths.contains(selected)) {
      try {
        await rootBundle.load(selected);
        _validatedPaths.add(selected);
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            '⚠️ AnimationRandomizerService: Animation path does not exist: $selected',
          );
        }
        // Remove invalid path from cache
        _cachedAnimations[category]?.remove(selected);
        // Try again if there are other animations
        if (animations.length > 1) {
          return getRandomAnimation(category);
        }
        return null;
      }
    }

    return selected;
  }

  /// Get a specific animation by filename from a category with validation
  ///
  /// Constructs and validates a specific animation path. If the path
  /// doesn't exist, returns null.
  ///
  /// Parameters:
  /// - [category]: The animation category
  /// - [filename]: The animation filename (e.g., 'Green Neutral Simple Serendipity Phone Wallpaper.mp4')
  ///
  /// Returns:
  /// - A validated animation path, or null if not found
  ///
  /// Example:
  /// ```dart
  /// final path = await service.getAnimationPath('Green Neutral Simple Serendipity Phone Wallpaper(1)', 'Green Neutral Simple Serendipity Phone Wallpaper.mp4');
  /// // Returns: 'assets/animations/Green Neutral Simple Serendipity Phone Wallpaper(1)/Green Neutral Simple Serendipity Phone Wallpaper.mp4' or null
  /// ```
  Future<String?> getAnimationPath(String category, String filename) async {
    if (category.isEmpty || filename.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ AnimationRandomizerService: Empty category or filename provided',
        );
      }
      return null;
    }

    final path = 'assets/animations/$category/$filename';

    // Validate path exists
    if (!_validatedPaths.contains(path)) {
      try {
        await rootBundle.load(path);
        _validatedPaths.add(path);
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            '⚠️ AnimationRandomizerService: Animation path does not exist: $path',
          );
        }
        return null;
      }
    }

    return path;
  }

  /// Clear cache (useful for testing or reloading)
  void clearCache() {
    _cachedAnimations.clear();
    _validatedPaths.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    clearCache();
    super.dispose();
  }
}
