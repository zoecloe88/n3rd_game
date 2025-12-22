import 'package:n3rd_game/models/trivia_item.dart';
import 'package:n3rd_game/models/game_state.dart';
import 'package:n3rd_game/models/difficulty_level.dart';

/// Factory methods for creating test data
class MockFactories {
  /// Create a mock TriviaItem for testing
  static TriviaItem createTriviaItem({
    String? category,
    List<String>? words,
    List<String>? correctAnswers,
    DifficultyLevel? difficulty,
    String? theme,
  }) {
    return TriviaItem(
      category: category ?? 'Test Category',
      words: words ?? ['word1', 'word2', 'word3'],
      correctAnswers: correctAnswers ?? ['word1'],
      difficulty: difficulty ?? DifficultyLevel.medium,
      theme: theme ?? 'general',
    );
  }

  /// Create a list of mock TriviaItems
  static List<TriviaItem> createTriviaItems(int count) {
    return List.generate(
      count,
      (index) => createTriviaItem(
        category: 'Category $index',
        words: ['word${index}1', 'word${index}2', 'word${index}3'],
        correctAnswers: ['word${index}1'],
      ),
    );
  }

  /// Create a mock GameState for testing
  static GameState createGameState({
    int? score,
    int? lives,
    int? round,
    bool? isGameOver,
  }) {
    return GameState(
      score: score ?? 0,
      lives: lives ?? 3,
      round: round ?? 1,
      isGameOver: isGameOver ?? false,
    );
  }
}





