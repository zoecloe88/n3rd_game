import 'dart:math';
import 'package:n3rd_game/models/trivia_item.dart';
import 'package:n3rd_game/models/game_mode_config.dart';
import 'package:n3rd_game/config/game_constants.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/utils/list_helper.dart';
import 'package:n3rd_game/services/game/game_validation_manager.dart';
import 'package:n3rd_game/services/logger_service.dart';

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
          // Keep only last 5 categories (safe access)
          if (_recentTriviaCategories.length > 5) {
            final firstCategory = ListHelper.safeFirst(_recentTriviaCategories.toList());
            if (firstCategory != null) {
              _recentTriviaCategories.remove(firstCategory);
            }
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
      // Last resort: use validation manager to find any valid trivia
      final validationManager = GameValidationManager();
      selectedTrivia = validationManager.findValidTriviaFromPool(
        _currentTriviaPool,
        (max) => _random.nextInt(max),
        maxAttempts: 50, // More attempts for fallback
      );
    }
    
    if (selectedTrivia == null) {
      throw GameException(
        'No valid trivia item found in pool of ${_currentTriviaPool.length} items. All items failed validation.',
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
      LoggerService.debug('Trivia validation failed: word count ${words.length} != 6');
      return false;
    }

    // Check correct answers
    final correctAnswers =
        trivia.correctAnswers.where((ca) => ca.trim().isNotEmpty).toList();
    if (correctAnswers.length != GameConstants.expectedCorrectAnswers) {
      LoggerService.debug('Trivia validation failed: correct answers count ${correctAnswers.length} != ${GameConstants.expectedCorrectAnswers}');
      return false;
    }

    // Check all correct answers are in words
    final wordsSet = words.map((w) => w.trim().toLowerCase()).toSet();
    final correctSet =
        correctAnswers.map((ca) => ca.trim().toLowerCase()).toSet();
    final missing = correctSet.where((ca) => !wordsSet.contains(ca)).toList();
    if (missing.isNotEmpty) {
      LoggerService.debug('Trivia validation failed: correct answers not in words list: $missing');
      return false;
    }
    
    // Check for duplicate words after normalization
    final inputWordsCount = trivia.words.where((w) => w.trim().isNotEmpty).length;
    if (inputWordsCount != wordsSet.length) {
      final duplicateCount = inputWordsCount - wordsSet.length;
      LoggerService.debug('Trivia validation failed: contains $duplicateCount duplicate normalized word(s)');
      return false;
    }

    return true;
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
