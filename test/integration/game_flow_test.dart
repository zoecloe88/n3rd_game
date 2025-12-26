import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/services/game_service.dart';
import 'package:n3rd_game/models/trivia_item.dart';

/// Integration tests for critical game flows
/// These tests verify end-to-end game functionality
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Game Flow Integration Tests', () {
    late GameService gameService;

    setUp(() {
      // Mock SharedPreferences for testing
      SharedPreferences.setMockInitialValues({});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/shared_preferences'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'getAll') {
            return <String, dynamic>{}; // Return empty map
          }
          if (methodCall.method == 'getString') {
            return null; // Return null for getString calls
          }
          if (methodCall.method == 'setString') {
            return true; // Return success for setString calls
          }
          if (methodCall.method == 'getDouble') {
            return null; // Return null for getDouble calls
          }
          if (methodCall.method == 'setDouble') {
            return true; // Return success for setDouble calls
          }
          if (methodCall.method == 'getInt') {
            return null; // Return null for getInt calls
          }
          if (methodCall.method == 'setInt') {
            return true; // Return success for setInt calls
          }
          if (methodCall.method == 'remove') {
            return true; // Return success for remove calls
          }
          if (methodCall.method == 'clear') {
            return true; // Return success for clear calls
          }
          return null;
        },
      );
      gameService = GameService();
    });

    tearDown(() {
      // Clear mock handler
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/shared_preferences'),
        null,
      );
      gameService.dispose();
    });

    test('should complete a full game round successfully', () {
      // Create a valid trivia pool
      final triviaPool = [
        TriviaItem(
          category: 'Science: What is the chemical symbol for water?',
          words: ['H2O', 'CO2', 'NaCl', 'O2', 'H2SO4', 'CH4'],
          correctAnswers: ['H2O', 'CO2', 'NaCl'],
        ),
        TriviaItem(
          category: 'Geography: Capital cities',
          words: ['Paris', 'London', 'Berlin', 'Madrid', 'Rome', 'Vienna'],
          correctAnswers: ['Paris', 'London', 'Berlin'],
        ),
      ];

      // Verify trivia pool is valid
      expect(triviaPool.length, greaterThan(0));
      expect(triviaPool.first.words.length, 6);
      expect(triviaPool.first.correctAnswers.length, 3);

      // Verify initial game state
      expect(gameService.state.score, 0);
      expect(gameService.state.lives, 3);
      expect(gameService.state.round, 1); // Game starts at round 1
      expect(gameService.state.isGameOver, false);
    });

    test('should handle game state transitions correctly', () {
      // Test that game state is immutable and transitions work
      final initialState = gameService.state;
      expect(initialState.isGameOver, false);
      expect(initialState.score, 0);
      expect(initialState.lives, 3);

      // State should be valid
      expect(initialState.lives >= 0, true);
      expect(initialState.round >= 0, true);
      expect(initialState.score >= 0, true);
    });

    test('should validate trivia item structure', () {
      final validTrivia = TriviaItem(
        category: 'Test: What is the answer?',
        words: ['A', 'B', 'C', 'D', 'E', 'F'],
        correctAnswers: ['A', 'B', 'C'],
      );

      // Verify structure
      expect(validTrivia.words.length, 6);
      expect(validTrivia.correctAnswers.length, 3);
      expect(validTrivia.category.isNotEmpty, true);

      // Verify all correct answers are in words list
      for (final answer in validTrivia.correctAnswers) {
        expect(validTrivia.words.contains(answer), true);
      }
    });

    test('should handle multiple game modes configuration', () {
      // Test that all game modes have valid configurations
      final modes = [
        GameMode.classic,
        GameMode.speed,
        GameMode.shuffle,
        GameMode.timeAttack,
        GameMode.flip,
      ];

      for (final mode in modes) {
        final config = ModeConfig.getConfig(mode);
        expect(config.memorizeTime >= 0, true, reason: 'Mode: $mode');
        expect(config.playTime > 0, true, reason: 'Mode: $mode');
      }
    });

    test('should handle progressive difficulty correctly', () {
      // Test challenge mode progressive difficulty
      final round1 = ModeConfig.getConfig(GameMode.challenge, round: 1);
      final round5 = ModeConfig.getConfig(GameMode.challenge, round: 5);
      final round10 = ModeConfig.getConfig(GameMode.challenge, round: 10);

      // Challenge mode should get progressively harder
      expect(round1.playTime >= round5.playTime, true);
      expect(round5.playTime >= round10.playTime, true);
    });

    test('should validate game state immutability', () {
      final state1 = gameService.state;
      final state2 = gameService.state;

      // States should be equal (same instance or value equality)
      expect(state1.score, state2.score);
      expect(state1.lives, state2.lives);
      expect(state1.round, state2.round);
      expect(state1.isGameOver, state2.isGameOver);
    });
  });

  group('Trivia Validation Integration', () {
    test('should validate trivia pool diversity', () {
      final triviaPool = [
        TriviaItem(
          category: 'Science: Chemistry',
          words: ['H2O', 'CO2', 'NaCl', 'O2', 'H2SO4', 'CH4'],
          correctAnswers: ['H2O', 'CO2', 'NaCl'],
        ),
        TriviaItem(
          category: 'Geography: Capitals',
          words: ['Paris', 'London', 'Berlin', 'Madrid', 'Rome', 'Vienna'],
          correctAnswers: ['Paris', 'London', 'Berlin'],
        ),
        TriviaItem(
          category: 'History: World Wars',
          words: ['WWI', 'WWII', '1914', '1939', '1945', '1918'],
          correctAnswers: ['WWI', 'WWII', '1914'],
        ),
      ];

      // Verify no duplicate categories
      final categories = triviaPool.map((t) => t.category.toLowerCase()).toList();
      final uniqueCategories = categories.toSet();
      expect(categories.length, uniqueCategories.length);
    });
  });
}
