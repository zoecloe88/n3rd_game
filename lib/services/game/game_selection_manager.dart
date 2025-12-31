import 'package:flutter/foundation.dart';
import 'package:n3rd_game/models/trivia_item.dart';
import 'package:n3rd_game/models/game_mode_config.dart';
import 'package:n3rd_game/models/game_state.dart';
import 'package:n3rd_game/config/game_constants.dart';
import 'package:n3rd_game/services/haptic_service.dart';
import 'package:n3rd_game/services/logger_service.dart';
/// Manages tile selection logic for the game
///
/// Handles tile selection/deselection, validation, and precision mode feedback.
/// Coordinates with flip mode manager for flip mode selections.
class GameSelectionManager {
  /// Toggle tile selection
  ///
  /// Handles selecting/deselecting tiles. Validates selections and handles
  /// precision mode immediate feedback. Delegates to flip mode when in flip mode.
  ///
  /// Returns SelectionResult indicating success or reason for failure.
  SelectionResult toggleTileSelection({
    required String word,
    required GamePhase phase,
    required GameMode currentMode,
    required TriviaItem? currentTrivia,
    required Set<String> selectedAnswers,
    required GameState state,
    required int expectedCorrectAnswers,
    required bool isDisposed,
    required Function(String) onFlipModeSelection,
    required Function(GameState) onStateUpdate,
    required Function(String?) onPrecisionErrorUpdate,
    required VoidCallback onNotifyListeners,
    required VoidCallback onSaveState,
    required HapticService? hapticService,
  }) {
    // Only allow selection during play phase
    if (phase != GamePhase.play) {
      return SelectionResult.notAllowed(
          'Selection can only be made during play phase',);
    }

    // Flip Mode: Must select in correct order (no deselection allowed)
    // Delegate to flip mode handler
    if (currentMode == GameMode.flip) {
      onFlipModeSelection(word);
      return SelectionResult.success();
    }

    // Handle deselection
    if (selectedAnswers.contains(word)) {
      selectedAnswers.remove(word);
      onNotifyListeners();
      return SelectionResult.success();
    }

    // Handle new selection
    if (selectedAnswers.length < expectedCorrectAnswers) {
      // Precision Mode: Check if wrong word selected, lose life immediately
      if (currentMode == GameMode.precision && currentTrivia != null) {
        // CRITICAL: Normalize strings for case-insensitive, whitespace-tolerant comparison
        // This matches the normalization logic used in normal mode for consistency
        final correct = Set<String>.from(
          currentTrivia.correctAnswers.map((w) => w.trim().toLowerCase()),
        );
        if (!correct.contains(word.trim().toLowerCase())) {
          // Wrong word selected - lose life immediately
          // CRITICAL: Clamp lives to prevent negative values (defensive programming)
          final newLives = (state.lives - 1).clamp(0, 999);
          final newState = state.copyWith(lives: newLives);

          if (newState.lives <= 0) {
            final gameOverState = newState.copyWith(isGameOver: true);
            onStateUpdate(gameOverState);
            // Note: submitCompetitiveChallengeScore should be called by GameService
          } else {
            onStateUpdate(newState);
          }

          hapticService?.error();

          // Show visual feedback - don't add wrong word, clear selection
          selectedAnswers.clear();

          // Store error message for UI to display
          onPrecisionErrorUpdate('Wrong answer! Life lost.');
          onNotifyListeners();

          // Clear error message after a short delay (use constant for delay)
          Future.delayed(
            const Duration(
              milliseconds:
                  GameConstants.flipModeInstantRevealDelayMilliseconds,
            ),
            () {
              if (!isDisposed) {
                onPrecisionErrorUpdate(null);
                onNotifyListeners();
              }
            },
          );
          onSaveState();

          return SelectionResult.precisionError('Wrong answer selected');
        }
      }

      // Double-check length before adding (defensive programming)
      if (selectedAnswers.length < expectedCorrectAnswers) {
        selectedAnswers.add(word);
      } else {
        // Already at max - ignore (shouldn't happen, but defensive)
        LoggerService.debug('Attempted to add answer beyond limit, ignoring');
      }
    } else {
      // Already at max - ignore additional selections
      LoggerService.debug(
        'Maximum selections reached, ignoring additional selection',
      );
    }

    onNotifyListeners();
    return SelectionResult.success();
  }
}

/// Result of a selection operation
class SelectionResult {

  const SelectionResult({
    required this.success,
    this.errorMessage,
    this.errorType,
  });

  factory SelectionResult.success() => const SelectionResult(success: true);

  factory SelectionResult.notAllowed(String message) => SelectionResult(
        success: false,
        errorMessage: message,
        errorType: SelectionErrorType.notAllowed,
      );

  factory SelectionResult.precisionError(String message) => SelectionResult(
        success: false,
        errorMessage: message,
        errorType: SelectionErrorType.precisionError,
      );
  final bool success;
  final String? errorMessage;
  final SelectionErrorType? errorType;
}

/// Selection error types
enum SelectionErrorType {
  notAllowed,
  precisionError,
}
