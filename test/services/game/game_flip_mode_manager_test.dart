import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/services/game/game_flip_mode_manager.dart';
import 'package:n3rd_game/models/trivia_item.dart';
import 'package:n3rd_game/models/game_mode_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameFlipModeManager', () {
    late GameFlipModeManager manager;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      manager = GameFlipModeManager();
      await manager.loadFlipRevealMode();
    });

    tearDown(() {
      manager.dispose();
    });

    test('initializes with default instant reveal mode', () {
      expect(manager.flipRevealMode, equals('instant'));
      expect(manager.flipRevealModeIsInstant, isTrue);
    });

    test('getters return correct values', () {
      expect(manager.flippedTiles, isEmpty);
      expect(manager.flipModeSelectedOrder, isEmpty);
      expect(manager.flipCurrentIndex, equals(0));
    });

    test('setFlipRevealMode updates mode correctly', () async {
      var notified = false;
      await manager.setFlipRevealMode(
        'blind',
        currentMode: GameMode.flip,
        phase: GamePhase.result,
        isGameOver: false,
        onNotifyListeners: () => notified = true,
      );

      expect(manager.flipRevealMode, equals('blind'));
      expect(manager.flipRevealModeIsInstant, isFalse);
      expect(notified, isTrue);
    });

    test('setFlipRevealMode prevents change during active round', () async {
      var notified = false;
      final originalMode = manager.flipRevealMode;

      await manager.setFlipRevealMode(
        'blind',
        currentMode: GameMode.flip,
        phase: GamePhase.play,
        isGameOver: false,
        onNotifyListeners: () => notified = true,
      );

      expect(manager.flipRevealMode, equals(originalMode));
      expect(notified, isFalse);
    });

    test('initializeFlippedTiles sets up tiles correctly', () {
      manager.initializeFlippedTiles(6);
      expect(manager.flippedTiles.length, equals(6));
      expect(manager.flippedTiles.every((tile) => tile == true), isTrue);
      expect(manager.flipCurrentIndex, equals(0));
    });

    test('addToFlipModeSelectedOrder adds words correctly', () {
      manager.addToFlipModeSelectedOrder('word1');
      manager.addToFlipModeSelectedOrder('word2');

      expect(manager.flipModeSelectedOrder.length, equals(2));
      expect(manager.flipModeSelectedOrder, contains('word1'));
      expect(manager.flipModeSelectedOrder, contains('word2'));
    });

    test('addToFlipModeSelectedOrder prevents duplicates', () {
      manager.addToFlipModeSelectedOrder('word1');
      manager.addToFlipModeSelectedOrder('word1');

      expect(manager.flipModeSelectedOrder.length, equals(1));
    });

    test('clear resets all state', () {
      manager.initializeFlippedTiles(6);
      manager.addToFlipModeSelectedOrder('word1');
      manager.clear();

      expect(manager.flippedTiles, isEmpty);
      expect(manager.flipModeSelectedOrder, isEmpty);
      expect(manager.flipCurrentIndex, equals(0));
    });

    test('reset clears selection order and resets index', () {
      manager.addToFlipModeSelectedOrder('word1');
      manager.reset();

      expect(manager.flipModeSelectedOrder, isEmpty);
      expect(manager.flipCurrentIndex, equals(0));
    });

    test('cancelTimers cancels all timers', () {
      // Test that cancelTimers doesn't throw
      expect(() => manager.cancelTimers(), returnsNormally);
    });

    test('revealFlipModeResults returns true for perfect selection', () {
      final trivia = TriviaItem(
        category: 'test',
        words: ['word1', 'word2', 'word3', 'dist1', 'dist2', 'dist3'],
        correctAnswers: ['word1', 'word2', 'word3'],
      );

      manager.initializeFlippedTiles(6);
      manager.addToFlipModeSelectedOrder('word1');
      manager.addToFlipModeSelectedOrder('word2');
      manager.addToFlipModeSelectedOrder('word3');

      final shuffledWords = [
        'word1',
        'word2',
        'word3',
        'dist1',
        'dist2',
        'dist3',
      ];
      final shuffledWordsMap = {
        'word1': 0,
        'word2': 1,
        'word3': 2,
        'dist1': 3,
        'dist2': 4,
        'dist3': 5,
      };

      final isPerfect = manager.revealFlipModeResults(
        currentTrivia: trivia,
        shuffledWords: shuffledWords,
        shuffledWordsMap: shuffledWordsMap,
        expectedCorrectAnswers: 3,
      );

      expect(isPerfect, isTrue);
    });

    test('revealFlipModeResults returns false for incorrect selection', () {
      final trivia = TriviaItem(
        category: 'test',
        words: ['word1', 'word2', 'word3', 'dist1', 'dist2', 'dist3'],
        correctAnswers: ['word1', 'word2', 'word3'],
      );

      manager.initializeFlippedTiles(6);
      manager.addToFlipModeSelectedOrder('word1');
      manager.addToFlipModeSelectedOrder('dist1');
      manager.addToFlipModeSelectedOrder('word2');

      final shuffledWords = [
        'word1',
        'word2',
        'word3',
        'dist1',
        'dist2',
        'dist3',
      ];
      final shuffledWordsMap = {
        'word1': 0,
        'word2': 1,
        'word3': 2,
        'dist1': 3,
        'dist2': 4,
        'dist3': 5,
      };

      final isPerfect = manager.revealFlipModeResults(
        currentTrivia: trivia,
        shuffledWords: shuffledWords,
        shuffledWordsMap: shuffledWordsMap,
        expectedCorrectAnswers: 3,
      );

      expect(isPerfect, isFalse);
    });
  });
}
