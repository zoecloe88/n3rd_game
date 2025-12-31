import 'package:n3rd_game/models/game_mode_config.dart';
import 'package:n3rd_game/models/game_state.dart';
import 'package:n3rd_game/config/game_constants.dart';

/// Manages mode-specific game state and logic
///
/// Handles mode-specific state variables and calculations for different game modes:
/// - Streak Mode: Multiplier tracking (1x to 5x)
/// - Survival Mode: Perfect count tracking (gain life every 3 perfect rounds)
/// - Precision Mode: Error message tracking
class GameModeSpecificManager {
  // Mode-specific state
  int _streakMultiplier = 1; // For Streak Mode (max 5x)
  int _survivalPerfectCount = 0; // For Survival Mode
  String? _precisionError; // For Precision Mode error feedback

  // Getters
  int get streakMultiplier => _streakMultiplier;
  int get survivalPerfectCount => _survivalPerfectCount;
  String? get precisionError => _precisionError;

  /// Handle perfect round for mode-specific logic
  ///
  /// Updates mode-specific state based on current game mode.
  /// Returns updated GameState if survival mode grants a life.
  GameState? handlePerfectRound({
    required GameMode currentMode,
    required GameState currentState,
  }) {
    // Streak Mode: Increment multiplier (max 5x)
    if (currentMode == GameMode.streak) {
      if (_streakMultiplier < 5) {
        _streakMultiplier++;
      }
    }

    // Survival Mode: Increment perfect count, gain life every 3
    if (currentMode == GameMode.survival) {
      _survivalPerfectCount =
          (_survivalPerfectCount + 1).clamp(0, GameConstants.maxPowerUpUses);
      if (_survivalPerfectCount >= 3 && currentState.lives < 5) {
        _survivalPerfectCount = 0; // Reset counter
        return currentState.copyWith(lives: currentState.lives + 1);
      }
    }

    return null; // No state update needed
  }

  /// Handle non-perfect round for mode-specific logic
  ///
  /// Resets mode-specific state when round is not perfect.
  void handleNonPerfectRound({
    required GameMode currentMode,
  }) {
    // Streak Mode: Reset multiplier on non-perfect
    if (currentMode == GameMode.streak) {
      _streakMultiplier = 1;
    }

    // Survival Mode: Reset perfect count on non-perfect
    if (currentMode == GameMode.survival) {
      _survivalPerfectCount = 0;
    }
  }

  /// Calculate mode-specific scoring multiplier
  ///
  /// Returns the multiplier to apply to points based on current mode.
  /// For streak mode, returns the streak multiplier.
  /// For other modes, returns 1.0 (no multiplier).
  double getScoringMultiplier({
    required GameMode currentMode,
  }) {
    if (currentMode == GameMode.streak) {
      return _streakMultiplier.toDouble();
    }
    return 1.0;
  }

  /// Apply mode-specific scoring to points
  ///
  /// Applies mode-specific multipliers to the given points.
  /// Returns the adjusted points value.
  int applyModeScoring({
    required int points,
    required GameMode currentMode,
  }) {
    if (currentMode == GameMode.streak) {
      return (points * _streakMultiplier).clamp(0, GameConstants.maxScore);
    }
    return points;
  }

  /// Set precision mode error message
  void setPrecisionError(String? error) {
    _precisionError = error;
  }

  /// Clear precision mode error message
  void clearPrecisionError() {
    _precisionError = null;
  }

  /// Reset mode-specific state for new game
  void reset({
    required GameMode currentMode,
  }) {
    _streakMultiplier = 1;
    _survivalPerfectCount = 0;
    _precisionError = null;

    // Ensure state consistency based on mode
    if (currentMode != GameMode.streak) {
      _streakMultiplier = 1;
    }
    if (currentMode != GameMode.survival) {
      _survivalPerfectCount = 0;
    }
  }

  /// Reset mode-specific state for new round
  ///
  /// Resets state that should be cleared between rounds.
  void resetForNewRound() {
    // Precision mode error is cleared between rounds
    _precisionError = null;
  }

  /// Restore mode-specific state from saved data
  void restoreState({
    required Map<String, dynamic> extendedStateMap,
    required GameMode currentMode,
  }) {
    _streakMultiplier =
        (extendedStateMap['streakMultiplier'] as int? ?? 1).clamp(1, 5);

    // Reset streak multiplier if not in streak mode (state consistency)
    if (currentMode != GameMode.streak) {
      _streakMultiplier = 1;
    }

    _survivalPerfectCount =
        (extendedStateMap['survivalPerfectCount'] as int? ?? 0).clamp(0, 999);

    // Reset survival perfect count if not in survival mode (state consistency)
    if (currentMode != GameMode.survival) {
      _survivalPerfectCount = 0;
    }
  }

  /// Get mode-specific state for persistence
  Map<String, dynamic> getStateForPersistence() {
    return {
      'streakMultiplier': _streakMultiplier,
      'survivalPerfectCount': _survivalPerfectCount,
    };
  }

  /// Check if mode-specific state should be reset for mode change
  bool shouldResetForModeChange({
    required GameMode oldMode,
    required GameMode newMode,
  }) {
    // Reset if switching to/from streak or survival mode
    final wasStreakMode = oldMode == GameMode.streak;
    final isStreakMode = newMode == GameMode.streak;
    final wasSurvivalMode = oldMode == GameMode.survival;
    final isSurvivalMode = newMode == GameMode.survival;

    return (wasStreakMode != isStreakMode) ||
        (wasSurvivalMode != isSurvivalMode);
  }

  /// Reset state when changing modes
  void resetForModeChange({
    required GameMode newMode,
  }) {
    if (newMode != GameMode.streak) {
      _streakMultiplier = 1;
    }
    if (newMode != GameMode.survival) {
      _survivalPerfectCount = 0;
    }
  }
}

