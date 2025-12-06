import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/models/difficulty_level.dart';
import 'package:n3rd_game/services/trivia_generator_service.dart';

/// Service for personalizing trivia content based on user behavior
class TriviaPersonalizationService extends ChangeNotifier {
  static const String _themeFrequencyKey = 'theme_frequency';
  static const String _recentCategoriesKey = 'recent_categories';
  static const String _preferredDifficultyKey = 'preferred_difficulty';
  static const int _recentCategoryLimit = 20;

  final Random _random = Random();
  Timer? _saveDebounceTimer; // Debounce timer for batching saves

  // Track user interests by theme
  final Map<String, int> _themeFrequency = {};
  final Map<String, double> _themeAccuracy = {};

  // Track recently seen categories (avoid repetition)
  // Using synchronized access to prevent race conditions in async operations
  final List<String> _recentCategories = [];
  bool _isUpdatingRecent = false; // Guard flag for async operations

  // Track user's preferred difficulty
  DifficultyLevel _preferredDifficulty = DifficultyLevel.medium;

  // Track category performance
  final Map<String, CategoryPerformance> _categoryPerformance = {};

  DifficultyLevel get preferredDifficulty => _preferredDifficulty;

  TriviaPersonalizationService() {
    _loadPreferences();
  }

  /// Load personalization data from SharedPreferences
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load theme frequency
      final themeFreqJson = prefs.getString(_themeFrequencyKey);
      if (themeFreqJson != null) {
        try {
          final decoded = jsonDecode(themeFreqJson) as Map<String, dynamic>;
          _themeFrequency.clear();
          decoded.forEach((key, value) {
            if (value is int) {
              _themeFrequency[key] = value;
            }
          });
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error parsing theme frequency: $e');
          }
        }
      }

      // Load theme accuracy
      final themeAccJson = prefs.getString('${_themeFrequencyKey}_accuracy');
      if (themeAccJson != null) {
        try {
          final decoded = jsonDecode(themeAccJson) as Map<String, dynamic>;
          _themeAccuracy.clear();
          decoded.forEach((key, value) {
            if (value is num) {
              _themeAccuracy[key] = value.toDouble();
            }
          });
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error parsing theme accuracy: $e');
          }
        }
      }

      // Load recent categories
      final recentCategoriesJson = prefs.getString(_recentCategoriesKey);
      if (recentCategoriesJson != null) {
        try {
          final decoded = jsonDecode(recentCategoriesJson) as List;
          _recentCategories.clear();
          _recentCategories.addAll(decoded.map((e) => e.toString()));
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error parsing recent categories: $e');
          }
        }
      }

      // Load category performance
      final categoryPerfJson = prefs.getString(
        '${_themeFrequencyKey}_category_perf',
      );
      if (categoryPerfJson != null) {
        try {
          final decoded = jsonDecode(categoryPerfJson) as Map<String, dynamic>;
          _categoryPerformance.clear();
          decoded.forEach((key, value) {
            if (value is Map<String, dynamic>) {
              final perf = CategoryPerformance();
              perf.totalAttempts = value['totalAttempts'] as int? ?? 0;
              perf.correctAttempts = value['correctAttempts'] as int? ?? 0;
              perf.totalScore = value['totalScore'] as int? ?? 0;
              _categoryPerformance[key] = perf;
            }
          });
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error parsing category performance: $e');
          }
        }
      }

      // Load preferred difficulty
      final difficultyStr = prefs.getString(_preferredDifficultyKey);
      if (difficultyStr != null) {
        _preferredDifficulty = DifficultyLevel.values.firstWhere(
          (d) => d.name == difficultyStr,
          orElse: () => DifficultyLevel.medium,
        );
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading personalization preferences: $e');
      }
    }
  }

  /// Save personalization data to SharedPreferences
  /// Uses debouncing to batch multiple rapid saves into a single write
  Future<void> _savePreferences() async {
    // Cancel existing timer if any
    _saveDebounceTimer?.cancel();

    // Schedule save after 500ms of inactivity (debouncing)
    _saveDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final prefs = await SharedPreferences.getInstance();

        // Save theme frequency (as JSON)
        await prefs.setString(_themeFrequencyKey, jsonEncode(_themeFrequency));

        // Save theme accuracy (as JSON)
        await prefs.setString(
          '${_themeFrequencyKey}_accuracy',
          jsonEncode(_themeAccuracy),
        );

        // Save recent categories (as JSON)
        await prefs.setString(
          _recentCategoriesKey,
          jsonEncode(_recentCategories),
        );

        // Save category performance (as JSON)
        final categoryPerfMap = <String, Map<String, dynamic>>{};
        _categoryPerformance.forEach((key, perf) {
          categoryPerfMap[key] = {
            'totalAttempts': perf.totalAttempts,
            'correctAttempts': perf.correctAttempts,
            'totalScore': perf.totalScore,
          };
        });
        await prefs.setString(
          '${_themeFrequencyKey}_category_perf',
          jsonEncode(categoryPerfMap),
        );

        // Save preferred difficulty
        await prefs.setString(
          _preferredDifficultyKey,
          _preferredDifficulty.name,
        );

        notifyListeners();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error saving personalization preferences: $e');
        }
      }
    });
  }

  /// Force immediate save (for critical operations like app shutdown)
  Future<void> _savePreferencesImmediate() async {
    _saveDebounceTimer?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(_themeFrequencyKey, jsonEncode(_themeFrequency));
      await prefs.setString(
        '${_themeFrequencyKey}_accuracy',
        jsonEncode(_themeAccuracy),
      );
      await prefs.setString(
        _recentCategoriesKey,
        jsonEncode(_recentCategories),
      );

      final categoryPerfMap = <String, Map<String, dynamic>>{};
      _categoryPerformance.forEach((key, perf) {
        categoryPerfMap[key] = {
          'totalAttempts': perf.totalAttempts,
          'correctAttempts': perf.correctAttempts,
          'totalScore': perf.totalScore,
        };
      });
      await prefs.setString(
        '${_themeFrequencyKey}_category_perf',
        jsonEncode(categoryPerfMap),
      );
      await prefs.setString(_preferredDifficultyKey, _preferredDifficulty.name);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving personalization preferences: $e');
      }
    }
  }

  /// Mark a template as recently seen (called when template is actually selected)
  /// Thread-safe: Uses guard flag and queue to prevent concurrent modifications
  final List<String> _pendingRecentCategories = [];
  static const int _maxPendingQueueSize =
      50; // Prevent memory leak from unbounded queue growth

  void markTemplateAsRecent(String categoryPattern) {
    // Prevent concurrent modifications (Dart is single-threaded but async operations can interleave)
    if (_isUpdatingRecent) {
      // Queue this operation instead of using Future.microtask (prevents stack overflow)
      if (!_pendingRecentCategories.contains(categoryPattern)) {
        // Prevent unbounded queue growth (memory leak prevention)
        if (_pendingRecentCategories.length >= _maxPendingQueueSize) {
          if (kDebugMode) {
            debugPrint(
              '⚠️ Recent categories queue full (${_pendingRecentCategories.length}), removing oldest items',
            );
          }
          // Remove oldest items to make room
          _pendingRecentCategories.removeRange(
            0,
            _pendingRecentCategories.length - (_maxPendingQueueSize ~/ 2),
          );
        }
        _pendingRecentCategories.add(categoryPattern);
      }
      // Process queue asynchronously
      Future.microtask(_processPendingRecentCategories);
      return;
    }

    _isUpdatingRecent = true;
    try {
      if (!_recentCategories.contains(categoryPattern)) {
        _recentCategories.add(categoryPattern);
        // Enforce limit strictly: always remove oldest if over limit
        while (_recentCategories.length > _recentCategoryLimit) {
          _recentCategories.removeAt(0);
        }
        _savePreferences();
      }

      // Process any pending items
      if (_pendingRecentCategories.isNotEmpty) {
        _processPendingRecentCategories();
      }
    } finally {
      _isUpdatingRecent = false;
    }
  }

  /// Process queued recent category updates
  void _processPendingRecentCategories() {
    // Guard: Prevent concurrent processing (multiple microtasks could call this)
    if (_isUpdatingRecent || _pendingRecentCategories.isEmpty) return;

    _isUpdatingRecent = true;
    try {
      // Process all pending items atomically
      final itemsToProcess = List<String>.from(_pendingRecentCategories);
      _pendingRecentCategories
          .clear(); // Clear immediately to prevent duplicate processing

      for (final categoryPattern in itemsToProcess) {
        if (!_recentCategories.contains(categoryPattern)) {
          _recentCategories.add(categoryPattern);
          while (_recentCategories.length > _recentCategoryLimit) {
            _recentCategories.removeAt(0);
          }
        }
      }
      _savePreferences();
    } finally {
      _isUpdatingRecent = false;
    }
  }

  /// Get personalized trivia selection
  /// Filters out recently seen categories and weights by interest/accuracy
  List<TriviaTemplate> getPersonalizedTemplates(
    List<TriviaTemplate> allTemplates,
    int count,
  ) {
    // Filter out recently seen
    var available = allTemplates
        .where((t) => !_recentCategories.contains(t.categoryPattern))
        .toList();

    if (available.isEmpty) {
      // If all categories were recent, use sliding window approach
      // Remove oldest 50% of recent categories instead of clearing all
      // This maintains some personalization while allowing variety
      final removeCount = (_recentCategories.length / 2).round();
      if (removeCount > 0 && removeCount < _recentCategories.length) {
        // Ensure we don't remove all categories (keep at least 1 for variety)
        final safeRemoveCount = removeCount < _recentCategories.length
            ? removeCount
            : (_recentCategories.length - 1).clamp(0, _recentCategories.length);
        if (safeRemoveCount > 0) {
          _recentCategories.removeRange(0, safeRemoveCount);
        }
      } else if (_recentCategories.length >= allTemplates.length) {
        // Edge case: user has seen ALL templates (or more, which shouldn't happen but handle gracefully)
        // Keep only the most recent 25% to maintain some personalization
        final keepCount = (allTemplates.length * 0.25).round().clamp(
          1,
          allTemplates.length,
        );
        // Remove all but the most recent keepCount items
        if (_recentCategories.length > keepCount) {
          _recentCategories.removeRange(
            0,
            _recentCategories.length - keepCount,
          );
        } else if (_recentCategories.length == allTemplates.length) {
          // Exact match: keep 25% of all templates
          _recentCategories.removeRange(
            0,
            _recentCategories.length - keepCount,
          );
        }
      }

      // Re-filter with reduced recent categories
      available = allTemplates
          .where((t) => !_recentCategories.contains(t.categoryPattern))
          .toList();

      // If still empty (edge case: all templates are in recent list after reduction)
      // This can happen if keepCount == allTemplates.length, so use all templates
      if (available.isEmpty) {
        if (kDebugMode) {
          debugPrint(
            '⚠️ All templates are recent after reduction, using all templates for variety',
          );
        }
        available = List.from(allTemplates);
      }
    }

    // Weight by interest and accuracy (using cached scores for performance)
    available.sort((a, b) {
      final aScore = _calculateTemplateScore(a);
      final bScore = _calculateTemplateScore(b);
      return bScore.compareTo(aScore);
    });

    // Clear score cache when personalization data changes (ensure fresh scores)
    _templateScoreCache.clear();
    _scoreCacheTimestamps.clear();

    // Return sorted list - actual selection happens in TriviaGeneratorService
    // Recent categories will be marked when template is actually selected
    // This prevents marking templates as recent that aren't actually used
    _savePreferences();
    return available;
  }

  // Cache template scores to avoid recalculation (performance optimization)
  final Map<String, double> _templateScoreCache = {};
  static const Duration _scoreCacheTTL = Duration(minutes: 5);
  final Map<String, DateTime> _scoreCacheTimestamps = {};

  /// Calculate score for a template based on user interests and performance
  /// Uses caching to avoid recalculation on every call
  double _calculateTemplateScore(TriviaTemplate template) {
    // Create cache key from template properties
    final cacheKey =
        '${template.categoryPattern}_${template.theme}_${template.difficulty.name}';

    // Check cache (with TTL)
    final cachedTimestamp = _scoreCacheTimestamps[cacheKey];
    if (cachedTimestamp != null &&
        DateTime.now().difference(cachedTimestamp) < _scoreCacheTTL &&
        _templateScoreCache.containsKey(cacheKey)) {
      return _templateScoreCache[cacheKey]!;
    }

    // Validate theme is not empty (should never happen due to validation, but safety check)
    // Normalize theme to match stored theme names (lowercase)
    final templateTheme = template.theme.isNotEmpty
        ? template.theme.toLowerCase().trim()
        : 'general';

    double score = 1.0; // Base score

    // Boost score based on theme frequency (user likes this theme)
    final themeFreq = _themeFrequency[templateTheme] ?? 0;
    score += themeFreq * 0.1;

    // Boost score based on theme accuracy (user performs well in this theme)
    // Initialize to 0.5 if theme is new (neutral starting point)
    final themeAcc = _themeAccuracy[templateTheme] ?? 0.5;
    score += themeAcc * 0.5;

    // Slight preference for medium difficulty (balanced)
    if (template.difficulty == _preferredDifficulty) {
      score += 0.2;
    }

    // Randomize slightly to avoid always same order
    score += _random.nextDouble() * 0.1;

    // Cache the result
    _templateScoreCache[cacheKey] = score;
    _scoreCacheTimestamps[cacheKey] = DateTime.now();

    // Clean up old cache entries (keep cache size manageable)
    if (_templateScoreCache.length > 100) {
      final now = DateTime.now();
      final keysToRemove = <String>[];
      _scoreCacheTimestamps.forEach((key, timestamp) {
        if (now.difference(timestamp) > _scoreCacheTTL) {
          keysToRemove.add(key);
        }
      });
      for (final key in keysToRemove) {
        _templateScoreCache.remove(key);
        _scoreCacheTimestamps.remove(key);
      }
    }

    return score;
  }

  /// Update performance after a round
  void updatePerformance({
    required String category,
    required String theme,
    required bool wasCorrect,
    required DifficultyLevel difficulty,
    required int score,
  }) {
    // Normalize theme to lowercase for consistency
    final normalizedTheme = theme.toLowerCase().trim();

    // Update theme frequency
    _themeFrequency[normalizedTheme] =
        (_themeFrequency[normalizedTheme] ?? 0) + 1;

    // Update theme accuracy (running average)
    // Initialize to 0.5 (neutral) if theme is new, otherwise use existing accuracy
    final currentAccuracy = _themeAccuracy[normalizedTheme] ?? 0.5;
    final newAccuracy = (currentAccuracy * 0.9) + (wasCorrect ? 0.1 : 0.0);
    _themeAccuracy[normalizedTheme] = newAccuracy;

    // Ensure theme accuracy is initialized (safety check, shouldn't be needed due to above)
    if (!_themeAccuracy.containsKey(normalizedTheme)) {
      _themeAccuracy[normalizedTheme] = 0.5; // Neutral starting point
    }

    // Update category performance
    final perf = _categoryPerformance[category] ?? CategoryPerformance();
    perf.totalAttempts++;
    if (wasCorrect) perf.correctAttempts++;
    perf.totalScore += score;
    _categoryPerformance[category] = perf;

    // Adjust preferred difficulty based on performance
    _adjustDifficulty(wasCorrect, difficulty);

    _savePreferences();
    notifyListeners();
  }

  /// Adjust preferred difficulty based on performance
  void _adjustDifficulty(bool wasCorrect, DifficultyLevel currentDifficulty) {
    if (wasCorrect) {
      // If user got it right, might want to increase difficulty
      if (currentDifficulty == DifficultyLevel.easy &&
          _preferredDifficulty == DifficultyLevel.easy) {
        _preferredDifficulty = DifficultyLevel.medium;
      } else if (currentDifficulty == DifficultyLevel.medium &&
          _preferredDifficulty == DifficultyLevel.medium) {
        // Only increase to hard if consistently getting medium right
        final recentAccuracy = _getRecentAccuracy();
        if (recentAccuracy > 0.8) {
          _preferredDifficulty = DifficultyLevel.hard;
        }
      }
    } else {
      // If user got it wrong, might want to decrease difficulty
      if (currentDifficulty == DifficultyLevel.hard &&
          _preferredDifficulty == DifficultyLevel.hard) {
        _preferredDifficulty = DifficultyLevel.medium;
      } else if (currentDifficulty == DifficultyLevel.medium &&
          _preferredDifficulty == DifficultyLevel.medium) {
        final recentAccuracy = _getRecentAccuracy();
        if (recentAccuracy < 0.4) {
          _preferredDifficulty = DifficultyLevel.easy;
        }
      }
    }
  }

  /// Get recent accuracy across all categories
  double _getRecentAccuracy() {
    if (_categoryPerformance.isEmpty) return 0.5;

    int totalAttempts = 0;
    int correctAttempts = 0;

    for (final perf in _categoryPerformance.values) {
      totalAttempts += perf.totalAttempts;
      correctAttempts += perf.correctAttempts;
    }

    if (totalAttempts == 0) return 0.5;
    return correctAttempts / totalAttempts;
  }

  /// Get suggested related categories based on theme similarity
  List<String> getRelatedCategories(
    String currentCategory,
    List<TriviaTemplate> allTemplates,
  ) {
    // Find templates with the same theme
    final related = <String>[];

    // Find the theme of the current category
    String? currentTheme;
    for (final template in allTemplates) {
      if (template.categoryPattern == currentCategory) {
        // Normalize theme for comparison
        currentTheme = template.theme.toLowerCase().trim();
        break;
      }
    }

    if (currentTheme != null) {
      for (final template in allTemplates) {
        // Normalize both themes for comparison
        final templateTheme = template.theme.toLowerCase().trim();
        if (templateTheme == currentTheme &&
            template.categoryPattern != currentCategory) {
          related.add(template.categoryPattern);
        }
      }
    }

    // Return top 3 related categories
    return related.take(3).toList();
  }

  /// Get user's favorite themes (top 3 by frequency)
  List<String> getFavoriteThemes() {
    final sorted = _themeFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(3).map((e) => e.key).toList();
  }

  /// Get user's best performing themes (top 3 by accuracy)
  List<String> getBestPerformingThemes({
    int limit = 3,
    bool ascending = false,
  }) {
    final sorted = _themeAccuracy.entries.toList()
      ..sort(
        (a, b) =>
            ascending ? a.value.compareTo(b.value) : b.value.compareTo(a.value),
      );
    return sorted.take(limit).map((e) => e.key).toList();
  }

  /// Clear personalization data (for testing or reset)
  Future<void> clearPersonalization() async {
    _themeFrequency.clear();
    _themeAccuracy.clear();
    _recentCategories.clear();
    _preferredDifficulty = DifficultyLevel.medium;
    _categoryPerformance.clear();
    await _savePreferencesImmediate();
    notifyListeners();
  }

  /// Dispose resources
  @override
  void dispose() {
    _saveDebounceTimer?.cancel();
    // Force save on dispose to ensure data is persisted
    _savePreferencesImmediate();
    super.dispose();
  }
}

/// Category performance tracking
class CategoryPerformance {
  int totalAttempts = 0;
  int correctAttempts = 0;
  int totalScore = 0;

  double get accuracy {
    if (totalAttempts == 0) return 0.0;
    return correctAttempts / totalAttempts;
  }

  double get averageScore {
    if (totalAttempts == 0) return 0.0;
    return totalScore / totalAttempts;
  }
}
