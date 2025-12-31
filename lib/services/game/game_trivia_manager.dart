import 'package:n3rd_game/models/trivia_item.dart';
import 'package:flutter/foundation.dart';
import 'package:n3rd_game/utils/list_helper.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Manages trivia pool and category tracking
///
/// Handles trivia pool storage, recent category tracking,
/// and trivia selection logic for game rounds.
class GameTriviaManager {
  /// Current trivia pool for the game session
  List<TriviaItem> _currentTriviaPool = [];

  /// Recent trivia categories to avoid repetition
  final List<String> _recentTriviaCategories = [];

  /// Maximum number of recent categories to track
  static const int maxRecentCategories = 10;

  /// Get current trivia pool
  List<TriviaItem> get currentTriviaPool =>
      List.unmodifiable(_currentTriviaPool);

  /// Set trivia pool
  void setTriviaPool(List<TriviaItem> pool) {
    _currentTriviaPool = List.from(pool);
  }

  /// Clear trivia pool
  void clearTriviaPool() {
    _currentTriviaPool.clear();
  }

  /// Check if trivia pool is empty
  bool get isPoolEmpty => _currentTriviaPool.isEmpty;

  /// Get pool size
  int get poolSize => _currentTriviaPool.length;

  /// Get recent categories
  List<String> get recentCategories =>
      List.unmodifiable(_recentTriviaCategories);

  /// Clear recent categories
  void clearRecentCategories() {
    _recentTriviaCategories.clear();
  }

  /// Add category to recent list
  void addRecentCategory(String category) {
    if (category.isEmpty) return;

    // Remove if already exists (to move to front)
    _recentTriviaCategories.remove(category);

    // Add to front
    _recentTriviaCategories.insert(0, category);

    // Limit size
    if (_recentTriviaCategories.length > maxRecentCategories) {
      _recentTriviaCategories.removeRange(
        maxRecentCategories,
        _recentTriviaCategories.length,
      );
    }
  }

  /// Check if category is recent
  bool isCategoryRecent(String category) {
    return _recentTriviaCategories.contains(category);
  }

  /// Get unique categories in pool
  Set<String> getUniqueCategoriesInPool() {
    return _currentTriviaPool
        .where((trivia) => trivia.category.isNotEmpty)
        .map((trivia) => trivia.category)
        .toSet();
  }

  /// Find trivia item by category (excluding recent categories)
  ///
  /// Returns a trivia item from the pool that matches the category
  /// and hasn't been used recently.
  TriviaItem? findTriviaByCategory(String category) {
    if (_currentTriviaPool.isEmpty) return null;

    // Filter by category and exclude recent
    final candidates = _currentTriviaPool.where((trivia) {
      return trivia.category == category && !isCategoryRecent(category);
    }).toList();

    if (candidates.isEmpty) return null;

    // Return first available (safe access)
    final firstCandidate = ListHelper.safeFirst(candidates);
    if (firstCandidate == null) {
      LoggerService.warning('GameTriviaManager: candidates list is empty after isEmpty check');
    }
    return firstCandidate;
  }

  /// Find trivia item avoiding recent categories
  ///
  /// Returns a trivia item that hasn't been used recently.
  TriviaItem? findTriviaAvoidingRecent() {
    if (_currentTriviaPool.isEmpty) return null;

    // Filter out recent categories
    final candidates = _currentTriviaPool.where((trivia) {
      if (trivia.category.isEmpty) return true;
      return !isCategoryRecent(trivia.category);
    }).toList();

    if (candidates.isEmpty) {
      // If all categories are recent, clear recent list and try again
      if (kDebugMode) {
        debugPrint(
          'All categories are recent, clearing recent list and retrying',
        );
      }
      clearRecentCategories();
      return ListHelper.safeFirst(_currentTriviaPool);
    }

    // Return first available (safe access)
    final firstCandidate = ListHelper.safeFirst(candidates);
    if (firstCandidate == null) {
      LoggerService.warning('GameTriviaManager: candidates list is empty after isEmpty check');
    }
    return firstCandidate;
  }

  /// Reset manager state
  void reset() {
    _currentTriviaPool.clear();
    _recentTriviaCategories.clear();
  }
}
