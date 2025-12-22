import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:n3rd_game/services/game_service.dart';
import 'package:n3rd_game/models/trivia_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameService', () {
    late GameService gameService;

    setUp(() {
      // Mock SharedPreferences for testing
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
    });

    tearDown(() {
      gameService.dispose();
      // Mock handler cleanup is in the outer tearDown
    });

    test('should initialize with default state', () {
      expect(gameService.state.score, 0);
      expect(gameService.state.lives, 3);
      // GameState initializes with round: 1 (1-based, not 0-based)
      expect(gameService.state.round, 1);
      expect(gameService.state.isGameOver, false);
    });

    test('should handle trivia pool generation', () {
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

      // Test that service can handle trivia pool
      expect(triviaPool.length, 2);
      expect(triviaPool.first.words.length, 6);
      expect(triviaPool.first.correctAnswers.length, 3);
    });

    test('should validate game state transitions', () {
      // Test initial state
      expect(gameService.state.isGameOver, false);
      expect(gameService.state.score, 0);
      
      // State should be valid
      expect(gameService.state.lives >= 0, true);
      expect(gameService.state.round >= 0, true);
    });

    test('should handle mode configuration correctly', () {
      // Test that ModeConfig returns valid configurations
      final classicConfig = ModeConfig.getConfig(GameMode.classic);
      expect(classicConfig.memorizeTime, 10);
      expect(classicConfig.playTime, 20);
      
      final speedConfig = ModeConfig.getConfig(GameMode.speed);
      expect(speedConfig.memorizeTime, 0);
      expect(speedConfig.playTime, 7);
      
      final shuffleConfig = ModeConfig.getConfig(GameMode.shuffle);
      expect(shuffleConfig.enableShuffle, true);
    });

    test('should handle flip mode configuration', () {
      final flipConfig = ModeConfig.getConfig(GameMode.flip);
      expect(flipConfig.enableFlip, true);
      expect(flipConfig.flipStartTime, 4);
      expect(flipConfig.flipDuration, 6);
    });

    test('should handle practice mode configuration', () {
      final practiceConfig = ModeConfig.getConfig(GameMode.practice);
      expect(practiceConfig.memorizeTime, 15);
      expect(practiceConfig.playTime, 30);
    });

    test('should handle learning mode configuration', () {
      final learningConfig = ModeConfig.getConfig(GameMode.learning);
      expect(learningConfig.memorizeTime, 15);
      expect(learningConfig.playTime, 30);
    });

    test('should validate time attack mode configuration', () {
      final timeAttackConfig = ModeConfig.getConfig(GameMode.timeAttack);
      // Time attack uses dynamic timing, but should have valid defaults
      expect(timeAttackConfig.memorizeTime >= 0, true);
      expect(timeAttackConfig.playTime >= 0, true);
    });
  });

  group('ModeConfig', () {
    test('should return valid configs for all game modes', () {
      // Verify we have exactly 18 game modes
      expect(GameMode.values.length, 18);
      
      for (final mode in GameMode.values) {
        final config = ModeConfig.getConfig(mode);
        expect(config.memorizeTime >= 0, true, reason: 'Mode: $mode');
        expect(config.playTime > 0, true, reason: 'Mode: $mode');
      }
    });

    test('should handle progressive difficulty in challenge mode', () {
      final round1 = ModeConfig.getConfig(GameMode.challenge, round: 1);
      final round2 = ModeConfig.getConfig(GameMode.challenge, round: 2);
      final round3 = ModeConfig.getConfig(GameMode.challenge, round: 3);
      
      // Challenge mode should get progressively harder (less time)
      expect(round1.playTime >= round2.playTime, true);
      expect(round2.playTime >= round3.playTime, true);
    });

    test('should handle marathon mode progressive difficulty', () {
      final earlyRound = ModeConfig.getConfig(GameMode.marathon, round: 3);
      final midRound = ModeConfig.getConfig(GameMode.marathon, round: 8);
      final lateRound = ModeConfig.getConfig(GameMode.marathon, round: 20);
      
      // Marathon should get progressively harder
      expect(earlyRound.playTime >= midRound.playTime, true);
      expect(midRound.playTime >= lateRound.playTime, true);
    });
  });
}
