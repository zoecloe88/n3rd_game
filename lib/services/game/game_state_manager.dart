import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/models/game_state.dart';
import 'package:n3rd_game/models/trivia_item.dart';
import 'package:n3rd_game/models/game_mode_config.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Manages game state transitions, persistence, and restoration
///
/// This service handles all game state management logic including:
/// - State transitions and updates
/// - State persistence to SharedPreferences
/// - State restoration from saved data
/// - State validation
class GameStateManager {
  /// Current game state
  GameState _state = GameState(
    score: 0,
    lives: 3,
    round: 1,
    isGameOver: false,
  );

  /// Current game phase
  GamePhase _phase = GamePhase.memorize;

  /// Current trivia item
  TriviaItem? currentTrivia;

  /// Storage key for game state
  static const String _storageKeyGameState = 'game_state';

  /// Cache SharedPreferences instance
  SharedPreferences? _prefs;

  /// Get current game state
  GameState get state => _state;

  /// Get current game phase
  GamePhase get phase => _phase;

  /// Update game state
  void updateState(GameState newState) {
    _state = newState;
  }

  /// Update game phase
  void updatePhase(GamePhase newPhase) {
    _phase = newPhase;
  }

  /// Reset game state to initial values
  void resetState() {
    _state = GameState(
      score: 0,
      lives: 3,
      round: 1,
      isGameOver: false,
    );
    _phase = GamePhase.memorize;
    currentTrivia = null;
  }

  /// Get or initialize SharedPreferences
  Future<SharedPreferences> _getPrefs() async {
    if (_prefs != null) return _prefs!;
    try {
      _prefs = await SharedPreferences.getInstance();
      return _prefs!;
    } catch (e) {
      LoggerService.error(
        'GameStateManager: Failed to initialize SharedPreferences',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
      rethrow;
    }
  }

  /// Save game state to SharedPreferences
  Future<void> saveState() async {
    try {
      final prefs = await _getPrefs();
      final stateJson = {
        'score': _state.score,
        'lives': _state.lives,
        'round': _state.round,
        'isGameOver': _state.isGameOver,
        'correctCount': _state.correctCount,
        'lastCorrectAnswers': _state.lastCorrectAnswers,
        'lastSelectedAnswers': _state.lastSelectedAnswers,
        'perfectStreak': _state.perfectStreak,
        'phase': _phase.toString(),
      };
      await prefs.setString(_storageKeyGameState, jsonEncode(stateJson));
    } catch (e) {
      LoggerService.error(
        'GameStateManager: Failed to save game state',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
    }
  }

  /// Load game state from SharedPreferences
  Future<bool> loadState() async {
    try {
      final prefs = await _getPrefs();
      final stateJsonString = prefs.getString(_storageKeyGameState);
      if (stateJsonString == null || stateJsonString.isEmpty) {
        return false;
      }

      // Parse JSON string
      final Map<String, dynamic> stateJson;
      try {
        stateJson = jsonDecode(stateJsonString) as Map<String, dynamic>;
      } catch (e) {
        LoggerService.warning(
          'GameStateManager: Failed to parse game state JSON',
          error: e,
        );
        return false;
      }

      // Extract and validate state fields with defaults
      final score = (stateJson['score'] as num?)?.toInt() ?? 0;
      final lives = (stateJson['lives'] as num?)?.toInt() ?? 3;
      final round = (stateJson['round'] as num?)?.toInt() ?? 1;
      final isGameOver = stateJson['isGameOver'] as bool? ?? false;
      final correctCount = (stateJson['correctCount'] as num?)?.toInt() ?? 0;
      final lastCorrectAnswers = (stateJson['lastCorrectAnswers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[];
      final lastSelectedAnswers = (stateJson['lastSelectedAnswers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[];
      final perfectStreak = (stateJson['perfectStreak'] as num?)?.toInt() ?? 0;

      // Parse phase string back to enum
      GamePhase phase = GamePhase.memorize; // Default phase
      final phaseString = stateJson['phase'] as String?;
      if (phaseString != null) {
        // Handle format: "GamePhase.memorize" or just "memorize"
        final phaseName = phaseString.contains('.')
            ? phaseString.split('.').last
            : phaseString;
        try {
          phase = GamePhase.values.firstWhere(
            (p) => p.toString().split('.').last == phaseName,
            orElse: () => GamePhase.memorize,
          );
        } catch (e) {
          LoggerService.warning(
            'GameStateManager: Invalid phase string: $phaseString, using default',
          );
          phase = GamePhase.memorize;
        }
      }

      // Restore state
      final restoredState = GameState(
        score: score,
        lives: lives,
        round: round,
        isGameOver: isGameOver,
        correctCount: correctCount,
        lastCorrectAnswers: lastCorrectAnswers,
        lastSelectedAnswers: lastSelectedAnswers,
        perfectStreak: perfectStreak,
      );

      updateState(restoredState);
      updatePhase(phase);

      LoggerService.debug('GameStateManager: Successfully restored game state');
      return true;
    } catch (e) {
      LoggerService.error(
        'GameStateManager: Failed to load game state',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
      return false;
    }
  }
}
