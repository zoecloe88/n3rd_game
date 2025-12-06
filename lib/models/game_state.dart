/// Represents the current state of a game session
///
/// This immutable class holds all game state information including:
/// - Score and progress (round, lives)
/// - Answer tracking (correct/selected answers)
/// - Performance metrics (perfect streak)
///
/// The state is immutable - use `copyWith()` to create modified versions.
class GameState {
  /// Current player score
  final int score;

  /// Number of lives remaining
  final int lives;

  /// Current round number (1-based)
  final int round;

  /// Whether the game has ended
  final bool isGameOver;

  /// Count of correct answers in the last round
  final int correctCount;

  /// List of correct answers from the last round
  final List<String> lastCorrectAnswers;

  /// List of answers selected by the player in the last round
  final List<String> lastSelectedAnswers;

  /// Consecutive perfect rounds streak
  final int perfectStreak;

  /// Creates a new GameState instance
  ///
  /// Required parameters:
  /// - [score]: Current score (default: 0)
  /// - [lives]: Number of lives (default: 3)
  /// - [round]: Current round (default: 0)
  /// - [isGameOver]: Game over flag (default: false)
  ///
  /// Optional parameters:
  /// - [correctCount]: Number of correct answers (default: 0)
  /// - [lastCorrectAnswers]: List of correct answers (default: [])
  /// - [lastSelectedAnswers]: List of selected answers (default: [])
  /// - [perfectStreak]: Perfect round streak (default: 0)
  GameState({
    required this.score,
    required this.lives,
    required this.round,
    required this.isGameOver,
    this.correctCount = 0,
    this.lastCorrectAnswers = const [],
    this.lastSelectedAnswers = const [],
    this.perfectStreak = 0, // ADD THIS LINE
  });

  /// Checks if the current round was perfect (all correct answers selected)
  ///
  /// Parameters:
  /// - [expectedCorrect]: Number of correct answers expected (default: 3)
  ///
  /// Returns:
  /// - `true` if correctCount equals expectedCorrect, `false` otherwise
  ///
  /// Example:
  /// ```dart
  /// final state = GameState(..., correctCount: 3);
  /// print(state.isPerfectRound()); // true
  /// ```
  bool isPerfectRound([int expectedCorrect = 3]) =>
      correctCount == expectedCorrect;

  /// Creates a copy of this GameState with updated values
  ///
  /// Only provided parameters will be updated; others remain unchanged.
  /// This is the primary way to update immutable GameState instances.
  ///
  /// Returns a new GameState instance with the updated values.
  ///
  /// Example:
  /// ```dart
  /// final updated = state.copyWith(score: 1000, round: 2);
  /// ```
  GameState copyWith({
    int? score,
    int? lives,
    int? round,
    bool? isGameOver,
    int? correctCount,
    List<String>? lastCorrectAnswers,
    List<String>? lastSelectedAnswers,
    int? perfectStreak, // ADD THIS LINE
  }) {
    return GameState(
      score: score ?? this.score,
      lives: lives ?? this.lives,
      round: round ?? this.round,
      isGameOver: isGameOver ?? this.isGameOver,
      correctCount: correctCount ?? this.correctCount,
      lastCorrectAnswers: lastCorrectAnswers ?? this.lastCorrectAnswers,
      lastSelectedAnswers: lastSelectedAnswers ?? this.lastSelectedAnswers,
      perfectStreak: perfectStreak ?? this.perfectStreak, // ADD THIS LINE
    );
  }
}
