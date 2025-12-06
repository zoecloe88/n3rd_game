import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for gamification features: streaks, badges, unlockables
class TriviaGamificationService extends ChangeNotifier {
  static const String _currentStreakKey = 'current_streak';
  static const String _bestStreakKey = 'best_streak';
  static const String _categoryStreaksKey = 'category_streaks';
  static const String _categoryMasteryKey = 'category_mastery';
  static const String _unlockedBadgesKey = 'unlocked_badges';
  static const String _unlockedContentKey = 'unlocked_content';

  int _currentStreak = 0;
  int _bestStreak = 0;
  final Map<String, int> _categoryStreaks = {};
  final Map<String, bool> _categoryMastery = {};
  final Set<String> _unlockedBadges = {};
  final Set<String> _unlockedContent = {};

  int get currentStreak => _currentStreak;
  int get bestStreak => _bestStreak;
  Set<String> get unlockedBadges => Set.unmodifiable(_unlockedBadges);
  Set<String> get unlockedContent => Set.unmodifiable(_unlockedContent);

  TriviaGamificationService() {
    _loadPreferences();
  }

  /// Load gamification data from SharedPreferences
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _currentStreak = prefs.getInt(_currentStreakKey) ?? 0;
      _bestStreak = prefs.getInt(_bestStreakKey) ?? 0;

      // Load category streaks (as JSON)
      final categoryStreaksJson = prefs.getString(_categoryStreaksKey);
      if (categoryStreaksJson != null) {
        try {
          final decoded =
              jsonDecode(categoryStreaksJson) as Map<String, dynamic>;
          _categoryStreaks.clear();
          decoded.forEach((key, value) {
            if (value is int) {
              _categoryStreaks[key] = value;
            }
          });
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error parsing category streaks: $e');
          }
        }
      }

      // Load category mastery (as JSON)
      final categoryMasteryJson = prefs.getString(_categoryMasteryKey);
      if (categoryMasteryJson != null) {
        try {
          final decoded =
              jsonDecode(categoryMasteryJson) as Map<String, dynamic>;
          _categoryMastery.clear();
          decoded.forEach((key, value) {
            if (value is bool) {
              _categoryMastery[key] = value;
            }
          });
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error parsing category mastery: $e');
          }
        }
      }

      // Load unlocked badges
      final badgesList = prefs.getStringList(_unlockedBadgesKey);
      if (badgesList != null) {
        _unlockedBadges.addAll(badgesList);
      }

      // Load unlocked content
      final contentList = prefs.getStringList(_unlockedContentKey);
      if (contentList != null) {
        _unlockedContent.addAll(contentList);
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading gamification preferences: $e');
      }
    }
  }

  /// Save gamification data to SharedPreferences
  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setInt(_currentStreakKey, _currentStreak);
      await prefs.setInt(_bestStreakKey, _bestStreak);

      // Save category streaks (as JSON)
      await prefs.setString(_categoryStreaksKey, jsonEncode(_categoryStreaks));

      // Save category mastery (as JSON)
      await prefs.setString(_categoryMasteryKey, jsonEncode(_categoryMastery));

      await prefs.setStringList(_unlockedBadgesKey, _unlockedBadges.toList());
      await prefs.setStringList(_unlockedContentKey, _unlockedContent.toList());

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving gamification preferences: $e');
      }
    }
  }

  /// Update streak after a round
  void updateStreak({
    required String category,
    required bool perfectRound,
    required int score,
  }) {
    if (perfectRound) {
      _currentStreak++;
      _bestStreak = _currentStreak > _bestStreak ? _currentStreak : _bestStreak;

      _categoryStreaks[category] = (_categoryStreaks[category] ?? 0) + 1;

      // Check for streak milestones (badges)
      _checkStreakMilestones();

      // Check for category mastery (10 perfect rounds in category)
      if (_categoryStreaks[category]! >= 10 &&
          (_categoryMastery[category] != true)) {
        _categoryMastery[category] = true;
        _unlockCategoryBadge(category);
      }
    } else {
      _currentStreak = 0;
      _categoryStreaks[category] = 0;
    }

    _savePreferences();
    notifyListeners();
  }

  /// Get streak bonus multiplier
  double getStreakMultiplier() {
    if (_currentStreak >= 20) return 3.0;
    if (_currentStreak >= 15) return 2.5;
    if (_currentStreak >= 10) return 2.0;
    if (_currentStreak >= 5) return 1.5;
    return 1.0;
  }

  /// Check for streak milestone badges
  void _checkStreakMilestones() {
    if (_currentStreak == 5 && !_unlockedBadges.contains('streak_5')) {
      _unlockBadge('streak_5', '5 in a Row');
    } else if (_currentStreak == 10 && !_unlockedBadges.contains('streak_10')) {
      _unlockBadge('streak_10', '10 in a Row');
    } else if (_currentStreak == 15 && !_unlockedBadges.contains('streak_15')) {
      _unlockBadge('streak_15', '15 in a Row');
    } else if (_currentStreak == 20 && !_unlockedBadges.contains('streak_20')) {
      _unlockBadge('streak_20', '20 in a Row');
    } else if (_currentStreak == 25 && !_unlockedBadges.contains('streak_25')) {
      _unlockBadge('streak_25', '25 in a Row');
    } else if (_currentStreak == 50 && !_unlockedBadges.contains('streak_50')) {
      _unlockBadge('streak_50', '50 in a Row');
    }
  }

  /// Unlock a category mastery badge
  void _unlockCategoryBadge(String category) {
    final badgeId = 'mastery_${category.replaceAll(' ', '_').toLowerCase()}';
    if (!_unlockedBadges.contains(badgeId)) {
      _unlockBadge(badgeId, 'Master of $category');
    }
  }

  /// Unlock a badge
  void _unlockBadge(String badgeId, String badgeName) {
    _unlockedBadges.add(badgeId);
    if (kDebugMode) {
      debugPrint('Badge unlocked: $badgeName ($badgeId)');
    }
    _savePreferences();
    notifyListeners();
  }

  /// Check if user has mastery in a category
  bool hasCategoryMastery(String category) {
    return _categoryMastery[category] ?? false;
  }

  /// Get category streak
  int getCategoryStreak(String category) {
    return _categoryStreaks[category] ?? 0;
  }

  /// Unlock content (e.g., special categories, game modes)
  void unlockContent(String contentId) {
    _unlockedContent.add(contentId);
    _savePreferences();
    notifyListeners();
  }

  /// Check if content is unlocked
  bool isContentUnlocked(String contentId) {
    return _unlockedContent.contains(contentId);
  }

  /// Get all mastery categories
  List<String> getMasteryCategories() {
    return _categoryMastery.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
  }

  /// Reset all gamification data (for testing)
  Future<void> resetGamification() async {
    _currentStreak = 0;
    _bestStreak = 0;
    _categoryStreaks.clear();
    _categoryMastery.clear();
    _unlockedBadges.clear();
    _unlockedContent.clear();
    await _savePreferences();
    notifyListeners();
  }
}
