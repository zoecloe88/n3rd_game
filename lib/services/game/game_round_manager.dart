import 'dart:math';
import 'package:n3rd_game/models/trivia_item.dart';
import 'package:n3rd_game/models/game_mode_config.dart';
import 'package:n3rd_game/config/game_constants.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';

/// Manages game round progression, trivia selection, and answer validation
///
/// This service handles:
/// - Round initialization and progression
/// - Trivia item selection and validation
/// - Answer validation and submission
/// - Round transitions
class GameRoundManager {
  /// Random number generator
  final Random _random = Random();

  /// Current trivia item
  TriviaItem? _currentTrivia;

  /// Current trivia pool
  List<TriviaItem> _currentTriviaPool = [];

  /// Recent trivia categories (for variety)
  final Set<String> _recentTriviaCategories = {};

  /// Selected answers for current round
  List<String> _selectedAnswers = [];

  /// Get current trivia item
  TriviaItem? get currentTrivia => _currentTrivia;

  /// Get current trivia pool
  List<TriviaItem> get currentTriviaPool =>
      List.unmodifiable(_currentTriviaPool);

  /// Get selected answers
  List<String> get selectedAnswers => List.unmodifiable(_selectedAnswers);

  /// Set trivia pool
  void setTriviaPool(List<TriviaItem> pool) {
    _currentTriviaPool = List.from(pool);
  }

  /// Clear recent categories
  void clearRecentCategories() {
    _recentTriviaCategories.clear();
  }

  /// Select trivia item for new round
  ///
  /// [mode] - Current game mode
  /// [recursionDepth] - Recursion depth for validation retries
  ///
  /// Returns selected trivia item
  /// Throws GameException if no valid trivia found
  TriviaItem selectTriviaForRound({
    required GameMode mode,
    int recursionDepth = 0,
  }) {
    if (_currentTriviaPool.isEmpty) {
      throw GameException('Cannot select trivia: pool is empty');
    }

    // Try to find trivia from different category than recent ones
    TriviaItem? selectedTrivia;
    int attempts = 0;
    const maxAttempts = 10;

    while (attempts < maxAttempts && selectedTrivia == null) {
      final candidate =
          _currentTriviaPool[_random.nextInt(_currentTriviaPool.length)];

      // Prefer trivia from categories not recently used
      if (!_recentTriviaCategories.contains(candidate.category) ||
          attempts >= maxAttempts - 3) {
        // Validate trivia item
        if (_validateTriviaItem(candidate)) {
          selectedTrivia = candidate;
          _recentTriviaCategories.add(candidate.category);
          // Keep only last 5 categories
          if (_recentTriviaCategories.length > 5) {
            _recentTriviaCategories.remove(_recentTriviaCategories.first);
          }
        }
      }
      attempts++;
    }

    // Fallback: use any valid trivia
    if (selectedTrivia == null) {
      for (final trivia in _currentTriviaPool) {
        if (_validateTriviaItem(trivia)) {
          selectedTrivia = trivia;
          break;
        }
      }
    }

    if (selectedTrivia == null) {
      throw GameException(
        'No valid trivia item found in pool after $maxAttempts attempts',
      );
    }

    _currentTrivia = selectedTrivia;
    _selectedAnswers = [];

    return selectedTrivia;
  }

  /// Validate trivia item
  bool _validateTriviaItem(TriviaItem trivia) {
    // Check word count
    final words = trivia.words.where((w) => w.trim().isNotEmpty).toList();
    if (words.length != 6) {
      return false;
    }

    // Check correct answers
    final correctAnswers =
        trivia.correctAnswers.where((ca) => ca.trim().isNotEmpty).toList();
    if (correctAnswers.length != GameConstants.expectedCorrectAnswers) {
      return false;
    }

    // Check all correct answers are in words
    final wordsSet = words.map((w) => w.trim().toLowerCase()).toSet();
    final correctSet =
        correctAnswers.map((ca) => ca.trim().toLowerCase()).toSet();
    final missing = correctSet.where((ca) => !wordsSet.contains(ca)).toList();

    return missing.isEmpty;
  }

  /// Add selected answer
  void addSelectedAnswer(String answer) {
    if (!_selectedAnswers.contains(answer) && _selectedAnswers.length < 4) {
      _selectedAnswers.add(answer);
    }
  }

  /// Remove selected answer
  void removeSelectedAnswer(String answer) {
    _selectedAnswers.remove(answer);
  }

  /// Clear selected answers
  void clearSelectedAnswers() {
    _selectedAnswers.clear();
  }

  /// Validate answers
  ///
  /// Returns number of correct answers
  int validateAnswers() {
    if (_currentTrivia == null) return 0;

    final correctAnswers = _currentTrivia!.correctAnswers
        .map((ca) => ca.trim().toLowerCase())
        .toSet();
    final selectedSet =
        _selectedAnswers.map((sa) => sa.trim().toLowerCase()).toSet();

    int correctCount = 0;
    for (final selected in selectedSet) {
      if (correctAnswers.contains(selected)) {
        correctCount++;
      }
    }

    return correctCount;
  }

  /// Reset for new round
  void resetForNewRound() {
    _selectedAnswers = [];
  }

  /// Reset all state
  void reset() {
    _currentTrivia = null;
    _currentTriviaPool = [];
    _recentTriviaCategories.clear();
    _selectedAnswers = [];
  }
}
