import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:n3rd_game/models/trivia_item.dart';
import 'package:n3rd_game/models/game_mode_config.dart';
import 'package:n3rd_game/config/game_constants.dart';

/// Manages all power-up functionality
///
/// Handles reveal all, clear selections, skip round, hints, time freeze,
/// double score, and streak shield power-ups with proper validation and state management.
class GamePowerupManager {
  // Power-up uses
  int revealAllUses = 3;
  int clearUses = 3;
  int skipUses = 3;
  int streakShieldUses = 0;
  int timeFreezeUses = 0;
  int hintUses = 0;
  int doubleScoreUses = 0;

  // Power-up active states
  bool isTimeFrozen = false;
  bool hasDoubleScore = false;
  bool hasStreakShield = false;
  int? playTimeAtFreeze;

  // Hint tracking
  final List<String> hintedWords = [];

  // Random number generator
  final Random _random = Random();

  /// Reveal all correct answers
  ///
  /// Reveals all correct answers in the current trivia item.
  /// Only works in play phase and requires uses remaining.
  PowerupResult revealAllWords({
    required GamePhase phase,
    required bool isGameOver,
    required TriviaItem? currentTrivia,
    required Set<String> revealedWords,
  }) {
    if (phase != GamePhase.play) {
      return PowerupResult.notAllowed(
          'Power-up can only be used during play phase',);
    }
    if (isGameOver) {
      return PowerupResult.notAllowed('Cannot use power-ups when game is over');
    }
    if (revealAllUses <= 0) {
      return PowerupResult.noUses('No reveal all uses remaining');
    }

    final trivia = currentTrivia;
    if (trivia == null) {
      return PowerupResult.error('No trivia item available');
    }

    // Validate correct answers exist in current trivia words list
    final currentWords = trivia.words.toSet();
    final validCorrectAnswers = trivia.correctAnswers
        .where((word) => currentWords.contains(word))
        .toList();

    if (validCorrectAnswers.length != trivia.correctAnswers.length &&
        kDebugMode) {
      debugPrint(
        '⚠️ Warning: Some correct answers not found in trivia words list - filtered invalid entries',
      );
    }

    // Reveal valid correct answers
    revealedWords.addAll(validCorrectAnswers);

    // Decrement uses
    revealAllUses = (revealAllUses - 1).clamp(0, GameConstants.maxPowerUpUses);

    return PowerupResult.success();
  }

  /// Clear all selected answers
  ///
  /// Clears all currently selected answers.
  /// Only works in play phase and requires uses remaining.
  PowerupResult clearSelections({
    required GamePhase phase,
    required bool isGameOver,
    required Set<String> selectedAnswers,
  }) {
    if (phase != GamePhase.play) {
      return PowerupResult.notAllowed(
          'Power-up can only be used during play phase',);
    }
    if (isGameOver) {
      return PowerupResult.notAllowed('Cannot use power-ups when game is over');
    }
    if (clearUses <= 0) {
      return PowerupResult.noUses('No clear uses remaining');
    }

    selectedAnswers.clear();
    clearUses = (clearUses - 1).clamp(0, GameConstants.maxPowerUpUses);

    return PowerupResult.success();
  }

  /// Activate hint - eliminates one wrong answer
  ///
  /// Removes a random wrong answer from the shuffled words.
  /// Practice mode has unlimited hints.
  PowerupResult activateHint({
    required GamePhase phase,
    required bool isGameOver,
    required GameMode currentMode,
    required TriviaItem? currentTrivia,
    required List<String> shuffledWords,
  }) {
    // Practice Mode: Unlimited hints
    if (currentMode != GameMode.practice) {
      if (hintUses <= 0) {
        return PowerupResult.noUses('No hint uses remaining');
      }
    }
    if (phase != GamePhase.play) {
      return PowerupResult.notAllowed(
          'Power-up can only be used during play phase',);
    }
    if (isGameOver) {
      return PowerupResult.notAllowed('Cannot use power-ups when game is over');
    }

    final trivia = currentTrivia;
    if (trivia == null) {
      return PowerupResult.error('No trivia item available');
    }

    // Only decrement hint uses in non-practice modes
    if (currentMode != GameMode.practice) {
      hintUses = (hintUses - 1).clamp(0, GameConstants.maxPowerUpUses);
    }

    // Find wrong answers to eliminate
    final correctAnswers = Set<String>.from(
      trivia.correctAnswers
          .where((w) => w.trim().isNotEmpty)
          .map((w) => w.trim().toLowerCase()),
    );
    final wrongAnswers = shuffledWords
        .where((w) => w.trim().isNotEmpty)
        .where((w) => !correctAnswers.contains(w.trim().toLowerCase()))
        .toList();

    if (wrongAnswers.isNotEmpty) {
      // Remove a random wrong answer
      final wordToHint = wrongAnswers[_random.nextInt(wrongAnswers.length)];
      hintedWords.add(wordToHint);
      return PowerupResult.success();
    }

    return PowerupResult.error('No wrong answers to eliminate');
  }

  /// Activate streak shield
  ///
  /// Protects from losing a life on the next wrong answer.
  PowerupResult activateStreakShield({
    required GamePhase phase,
    required bool isGameOver,
  }) {
    if (streakShieldUses <= 0) {
      return PowerupResult.noUses('No streak shield uses remaining');
    }
    if (phase != GamePhase.play) {
      return PowerupResult.notAllowed(
          'Power-up can only be used during play phase',);
    }
    if (isGameOver) {
      return PowerupResult.notAllowed('Cannot use power-ups when game is over');
    }

    streakShieldUses =
        (streakShieldUses - 1).clamp(0, GameConstants.maxPowerUpUses);
    hasStreakShield = true;

    return PowerupResult.success();
  }

  /// Activate time freeze
  ///
  /// Pauses the timer for the configured duration.
  /// Returns a callback to resume the timer.
  PowerupResultWithCallback activateTimeFreeze({
    required GamePhase phase,
    required bool isGameOver,
    required int currentPlayTimeLeft,
    required VoidCallback onResumeTimer,
    required Function(int) onUpdatePlayTime,
  }) {
    if (timeFreezeUses <= 0 || isTimeFrozen) {
      return PowerupResultWithCallback(
        PowerupResult.noUses('No time freeze uses remaining or already frozen'),
        null,
      );
    }
    if (phase != GamePhase.play) {
      return PowerupResultWithCallback(
        PowerupResult.notAllowed('Power-up can only be used during play phase'),
        null,
      );
    }
    if (isGameOver) {
      return PowerupResultWithCallback(
        PowerupResult.notAllowed('Cannot use power-ups when game is over'),
        null,
      );
    }

    timeFreezeUses =
        (timeFreezeUses - 1).clamp(0, GameConstants.maxPowerUpUses);
    isTimeFrozen = true;
    playTimeAtFreeze = currentPlayTimeLeft;

    // Create callback to resume timer after freeze duration
    Timer? resumeTimer;
    resumeTimer = Timer(
      const Duration(seconds: GameConstants.timeFreezeDurationSeconds),
      () {
        isTimeFrozen = false;
        if (phase == GamePhase.play && currentPlayTimeLeft > 0) {
          // Restore play time to what it was when freeze started
          if (playTimeAtFreeze != null) {
            onUpdatePlayTime(playTimeAtFreeze!);
            playTimeAtFreeze = null;
          }
          onResumeTimer();
        }
      },
    );

    return PowerupResultWithCallback(
      PowerupResult.success(),
      () => resumeTimer?.cancel(),
    );
  }

  /// Activate double score
  ///
  /// Doubles points for the next round.
  PowerupResult activateDoubleScore({
    required GamePhase phase,
    required bool isGameOver,
  }) {
    if (doubleScoreUses <= 0) {
      return PowerupResult.noUses('No double score uses remaining');
    }
    if (phase != GamePhase.play) {
      return PowerupResult.notAllowed(
          'Power-up can only be used during play phase',);
    }
    if (isGameOver) {
      return PowerupResult.notAllowed('Cannot use power-ups when game is over');
    }

    doubleScoreUses =
        (doubleScoreUses - 1).clamp(0, GameConstants.maxPowerUpUses);
    hasDoubleScore = true;

    return PowerupResult.success();
  }

  /// Award power-up based on streak
  ///
  /// Awards power-ups at specific streak milestones:
  /// - 3 perfect: +1 life
  /// - 6 perfect: +1 skip
  /// - 9 perfect: +1 clear
  /// - 12 perfect: +1 reveal
  void awardStreakReward({
    required int streak,
    required Function(int) onAddLife,
    required int currentLives,
  }) {
    if (streak == 3) {
      // 3rd perfect streak: +1 life
      if (currentLives < GameConstants.maxLives) {
        onAddLife(1);
      }
    } else if (streak == 6) {
      // 6th perfect streak: +1 skip
      skipUses = (skipUses + 1).clamp(0, GameConstants.maxPowerUpUses);
    } else if (streak == 9) {
      // 9th perfect streak: +1 clear
      clearUses = (clearUses + 1).clamp(0, GameConstants.maxPowerUpUses);
    } else if (streak == 12) {
      // 12th perfect streak: +1 reveal
      revealAllUses =
          (revealAllUses + 1).clamp(0, GameConstants.maxPowerUpUses);
    }
  }

  /// Reset all power-up states
  void reset() {
    revealAllUses = 3;
    clearUses = 3;
    skipUses = 3;
    streakShieldUses = 0;
    timeFreezeUses = 0;
    hintUses = 0;
    doubleScoreUses = 0;
    isTimeFrozen = false;
    hasDoubleScore = false;
    hasStreakShield = false;
    playTimeAtFreeze = null;
    hintedWords.clear();
  }

  /// Get list of hinted (eliminated) words
  List<String> getHintedWords() => List.unmodifiable(hintedWords);

  /// Check if streak shield is active and consume it
  bool consumeStreakShield() {
    if (hasStreakShield) {
      hasStreakShield = false;
      return true;
    }
    return false;
  }

  /// Check if double score is active and consume it
  bool consumeDoubleScore() {
    if (hasDoubleScore) {
      hasDoubleScore = false;
      return true;
    }
    return false;
  }
}

/// Result of a power-up operation
class PowerupResult {

  const PowerupResult({
    required this.success,
    this.errorMessage,
    this.errorType,
  });

  factory PowerupResult.success() => const PowerupResult(success: true);
  factory PowerupResult.notAllowed(String message) => PowerupResult(
        success: false,
        errorMessage: message,
        errorType: PowerupErrorType.notAllowed,
      );
  factory PowerupResult.noUses(String message) => PowerupResult(
        success: false,
        errorMessage: message,
        errorType: PowerupErrorType.noUses,
      );
  factory PowerupResult.error(String message) => PowerupResult(
        success: false,
        errorMessage: message,
        errorType: PowerupErrorType.error,
      );
  final bool success;
  final String? errorMessage;
  final PowerupErrorType? errorType;
}

/// Power-up error types
enum PowerupErrorType {
  notAllowed,
  noUses,
  error,
}

/// Power-up result with callback for cleanup
class PowerupResultWithCallback {

  const PowerupResultWithCallback(this.result, this.cleanupCallback);
  final PowerupResult result;
  final VoidCallback? cleanupCallback;
}
