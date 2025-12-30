import 'package:n3rd_game/models/trivia_item.dart';
import 'package:n3rd_game/config/game_constants.dart';

/// Result of trivia item validation
class ValidationResult {
  ValidationResult({
    required this.isValid,
    this.errorMessage,
    this.missingCorrectAnswers,
    this.duplicateCount,
  });

  final bool isValid;
  final String? errorMessage;
  final List<String>? missingCorrectAnswers;
  final int? duplicateCount;
}

/// Result of state validation
class StateValidationResult {
  StateValidationResult({
    required this.isValid,
    this.shuffledWordsNeedReset = false,
    this.flippedTilesNeedReset = false,
    this.flipIndexNeedReset = false,
    this.invalidSelectedWords = const [],
    this.invalidRevealedWords = const [],
    this.invalidHintedWords = const [],
    this.invalidFlipOrderWords = const [],
  });

  final bool isValid;
  final bool shuffledWordsNeedReset;
  final bool flippedTilesNeedReset;
  final bool flipIndexNeedReset;
  final List<String> invalidSelectedWords;
  final List<String> invalidRevealedWords;
  final List<String> invalidHintedWords;
  final List<String> invalidFlipOrderWords;
}

/// Manages validation logic for game trivia items and game state
///
/// Extracted from GameService to reduce complexity and improve maintainability.
/// Handles validation of trivia items, state restoration, and trivia selection.
class GameValidationManager {
  /// Validates a trivia item for game use
  ///
  /// Checks:
  /// - Word count is exactly requiredWordsForGameplay (6)
  /// - Correct answers count is exactly expectedCorrectAnswers (3)
  /// - All correct answers are in words list
  /// - No duplicate words after normalization
  ///
  /// Returns ValidationResult with validation status and error details.
  ValidationResult validateTriviaItem(TriviaItem item) {
    // Check basic structure
    if (item.words.isEmpty || item.correctAnswers.isEmpty) {
      return ValidationResult(
        isValid: false,
        errorMessage:
            'Invalid trivia item - missing words or correct answers.',
      );
    }

    // Normalize and filter words
    final wordsSet = item.words
        .where((w) => w.trim().isNotEmpty)
        .map((w) => w.trim().toLowerCase())
        .toSet();

    final correctAnswersSet = item.correctAnswers
        .where((ca) => ca.trim().isNotEmpty)
        .map((ca) => ca.trim().toLowerCase())
        .toSet();

    // Validate word count
    if (wordsSet.length != GameConstants.requiredWordsForGameplay) {
      return ValidationResult(
        isValid: false,
        errorMessage:
            'Invalid trivia item: incorrect word count (${wordsSet.length} != ${GameConstants.requiredWordsForGameplay}, expected exactly ${GameConstants.requiredWordsForGameplay}).',
      );
    }

    // Validate correct answers count
    if (correctAnswersSet.length != GameConstants.expectedCorrectAnswers) {
      return ValidationResult(
        isValid: false,
        errorMessage:
            'Invalid trivia item: incorrect correct answers count (${correctAnswersSet.length} != ${GameConstants.expectedCorrectAnswers}, expected exactly ${GameConstants.expectedCorrectAnswers}).',
      );
    }

    // Validate all correct answers are in words list
    final missingCorrect = correctAnswersSet
        .where((ca) => !wordsSet.contains(ca))
        .toList();

    if (missingCorrect.isNotEmpty) {
      return ValidationResult(
        isValid: false,
        errorMessage:
            'Invalid trivia item: correct answers not in words list: $missingCorrect.',
        missingCorrectAnswers: missingCorrect,
      );
    }

    // Detect duplicate words after normalization
    final inputWordsCount =
        item.words.where((w) => w.trim().isNotEmpty).length;
    if (inputWordsCount != wordsSet.length) {
      final duplicateCount = inputWordsCount - wordsSet.length;
      return ValidationResult(
        isValid: false,
        errorMessage:
            'Invalid trivia item: contains $duplicateCount duplicate normalized word(s) (input has $inputWordsCount words, but only ${wordsSet.length} unique after normalization).',
        duplicateCount: duplicateCount,
      );
    }

    return ValidationResult(isValid: true);
  }

  /// Checks if a trivia item is valid (quick check)
  bool isValidTriviaItem(TriviaItem item) {
    return validateTriviaItem(item).isValid;
  }

  /// Finds a valid trivia item from a pool
  ///
  /// Attempts to find a trivia item that passes validation.
  /// Uses [random] for selection and validates each candidate.
  ///
  /// Returns a valid TriviaItem or null if none found.
  TriviaItem? findValidTriviaFromPool(
    List<TriviaItem> pool,
    int Function(int) randomNextInt, {
    TriviaItem? excludeItem,
    int maxAttempts = GameConstants.maxCandidateAttempts,
  }) {
    if (pool.isEmpty) return null;

    int attempts = 0;
    while (attempts < maxAttempts) {
      final candidate = pool[randomNextInt(pool.length)];

      // Skip excluded item
      if (excludeItem != null && candidate == excludeItem) {
        attempts++;
        continue;
      }

      // Validate candidate
      if (isValidTriviaItem(candidate)) {
        return candidate;
      }

      attempts++;
    }

    return null;
  }

  /// Validates that shuffled words match trivia words
  ///
  /// Checks that all shuffled words are present in trivia words
  /// and all trivia words are present in shuffled words.
  ///
  /// Returns true if valid, false otherwise.
  bool validateShuffledWordsConsistency(
    TriviaItem trivia,
    List<String> shuffledWords,
  ) {
    if (trivia.words.isEmpty || shuffledWords.isEmpty) return false;

    final triviaWords = Set<String>.from(
      trivia.words.map((w) => w.trim().toLowerCase()),
    );
    final shuffledWordsSet = Set<String>.from(
      shuffledWords.map((w) => w.trim().toLowerCase()),
    );

    return triviaWords.containsAll(shuffledWordsSet) &&
        shuffledWordsSet.containsAll(triviaWords);
  }

  /// Validates that a word list contains only valid words from trivia
  ///
  /// Returns list of invalid words that should be removed.
  List<String> findInvalidWords(
    List<String> wordsToValidate,
    TriviaItem trivia,
  ) {
    if (wordsToValidate.isEmpty) return [];

    final triviaWordsSet = Set<String>.from(
      trivia.words.map((w) => w.trim().toLowerCase()),
    );

    return wordsToValidate
        .where((word) => !triviaWordsSet.contains(word.trim().toLowerCase()))
        .toList();
  }

  /// Validates flipped tiles length matches shuffled words length
  ///
  /// Returns true if lengths match, false otherwise.
  bool validateFlippedTilesLength(int flippedTilesLength, int shuffledWordsLength) {
    return flippedTilesLength == shuffledWordsLength;
  }

  /// Validates flip current index is within bounds
  ///
  /// Returns true if index is valid, false otherwise.
  bool validateFlipCurrentIndex(int index, int maxLength) {
    return index >= 0 && index < maxLength;
  }

  /// Validates restored game state
  ///
  /// Checks state consistency for a restored game.
  /// Validates trivia/shuffled words consistency, flip mode state,
  /// and various word lists.
  StateValidationResult validateRestoredState({
    required TriviaItem? trivia,
    required List<String> shuffledWords,
    required int flippedTilesLength,
    required int flipCurrentIndex,
    required List<String> selectedAnswers,
    required List<String> revealedWords,
    required List<String> hintedWords,
    required List<String> flipModeSelectedOrder,
  }) {
    // If no trivia, state is invalid
    if (trivia == null) {
      return StateValidationResult(isValid: false);
    }

    bool isValid = true;
    bool shuffledWordsNeedReset = false;
    bool flippedTilesNeedReset = false;
    bool flipIndexNeedReset = false;
    List<String> invalidSelectedWords = [];
    List<String> invalidRevealedWords = [];
    List<String> invalidHintedWords = [];
    List<String> invalidFlipOrderWords = [];

    // Validate shuffled words consistency
    if (shuffledWords.isNotEmpty) {
      if (!validateShuffledWordsConsistency(trivia, shuffledWords)) {
        shuffledWordsNeedReset = true;
        isValid = false;
      }
    }

    // Validate flipped tiles length
    if (shuffledWords.isNotEmpty &&
        !validateFlippedTilesLength(flippedTilesLength, shuffledWords.length)) {
      flippedTilesNeedReset = true;
      isValid = false;
    }

    // Validate flip current index
    if (flippedTilesLength > 0 &&
        !validateFlipCurrentIndex(flipCurrentIndex, flippedTilesLength)) {
      flipIndexNeedReset = true;
      isValid = false;
    }

    // Validate selected answers
    if (shuffledWords.isNotEmpty) {
      final shuffledWordsSet = Set<String>.from(
        shuffledWords.map((w) => w.trim().toLowerCase()),
      );
      invalidSelectedWords = selectedAnswers
          .where((word) => !shuffledWordsSet.contains(word.trim().toLowerCase()))
          .toList();
      if (invalidSelectedWords.isNotEmpty) {
        isValid = false;
      }
    }

    // Validate revealed words
    if (shuffledWords.isNotEmpty) {
      final shuffledWordsSet = Set<String>.from(
        shuffledWords.map((w) => w.trim().toLowerCase()),
      );
      invalidRevealedWords = revealedWords
          .where((word) => !shuffledWordsSet.contains(word.trim().toLowerCase()))
          .toList();
      if (invalidRevealedWords.isNotEmpty) {
        isValid = false;
      }
    }

    // Validate hinted words
    if (shuffledWords.isNotEmpty) {
      final shuffledWordsSet = Set<String>.from(
        shuffledWords.map((w) => w.trim().toLowerCase()),
      );
      invalidHintedWords = hintedWords
          .where((word) => !shuffledWordsSet.contains(word.trim().toLowerCase()))
          .toList();
      if (invalidHintedWords.isNotEmpty) {
        isValid = false;
      }
    }

    // Validate flip mode selected order
    if (shuffledWords.isNotEmpty) {
      final shuffledWordsSet = Set<String>.from(
        shuffledWords.map((w) => w.trim().toLowerCase()),
      );
      invalidFlipOrderWords = flipModeSelectedOrder
          .where((word) => !shuffledWordsSet.contains(word.trim().toLowerCase()))
          .toList();
      if (invalidFlipOrderWords.isNotEmpty) {
        isValid = false;
      }
    }

    return StateValidationResult(
      isValid: isValid,
      shuffledWordsNeedReset: shuffledWordsNeedReset,
      flippedTilesNeedReset: flippedTilesNeedReset,
      flipIndexNeedReset: flipIndexNeedReset,
      invalidSelectedWords: invalidSelectedWords,
      invalidRevealedWords: invalidRevealedWords,
      invalidHintedWords: invalidHintedWords,
      invalidFlipOrderWords: invalidFlipOrderWords,
    );
  }
}

