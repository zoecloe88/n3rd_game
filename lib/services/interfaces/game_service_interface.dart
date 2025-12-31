import 'package:n3rd_game/models/game_state.dart';
import 'package:n3rd_game/models/trivia_item.dart';
import 'package:n3rd_game/models/game_mode_config.dart';

/// Interface for game service
/// Provides contract for game operations
abstract class GameServiceInterface {
  /// Get current game state
  GameState get state;

  /// Get current game mode
  GameMode get currentMode;

  /// Get current score
  int get score;

  /// Check if game is over
  bool get isGameOver;

  /// Start a new game round
  void startNewRound(List<TriviaItem> triviaPool);

  /// Submit answers for current round
  void submitAnswers();

  /// Reset game to initial state
  Future<void> resetGame();

  /// Pause the game
  void pauseGame();

  /// Resume the game
  void resumeGame();

  /// Load game state from storage
  Future<void> loadState();

  /// Save game state to storage
  Future<void> saveState();

  /// Dispose resources
  void dispose();
}
