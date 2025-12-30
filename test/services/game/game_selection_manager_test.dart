import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/services/game/game_selection_manager.dart';
import 'package:n3rd_game/models/game_mode_config.dart';
import 'package:n3rd_game/models/game_state.dart';
import 'package:n3rd_game/models/trivia_item.dart';
import 'package:n3rd_game/services/haptic_service.dart';

void main() {
  group('GameSelectionManager', () {
    late GameSelectionManager manager;
    late Set<String> selectedAnswers;
    late GameState gameState;
    late TriviaItem testTrivia;
    bool notified = false;
    bool saved = false;
    String? precisionError;
    GameState? updatedState;

    setUp(() {
      manager = GameSelectionManager();
      selectedAnswers = {};
      gameState = GameState(score: 0, lives: 3, round: 1, isGameOver: false);
      testTrivia = TriviaItem(
        category: 'Test question',
        words: ['word1', 'word2', 'word3', 'word4'],
        correctAnswers: ['word1', 'word2'],
      );
      notified = false;
      saved = false;
      precisionError = null;
      updatedState = null;
    });

    tearDown(() {
      // Manager doesn't require disposal, but keeping structure consistent
    });

    test('should not allow selection outside play phase', () {
      final result = manager.toggleTileSelection(
        word: 'word1',
        phase: GamePhase.memorize,
        currentMode: GameMode.classic,
        currentTrivia: testTrivia,
        selectedAnswers: selectedAnswers,
        state: gameState,
        expectedCorrectAnswers: 2,
        isDisposed: false,
        onFlipModeSelection: (_) {},
        onStateUpdate: (_) {},
        onPrecisionErrorUpdate: (_) {},
        onNotifyListeners: () {},
        onSaveState: () {},
        hapticService: null,
      );

      expect(result.success, false);
      expect(result.errorType, SelectionErrorType.notAllowed);
    });

    test('should allow deselection in play phase', () {
      selectedAnswers.add('word1');

      final result = manager.toggleTileSelection(
        word: 'word1',
        phase: GamePhase.play,
        currentMode: GameMode.classic,
        currentTrivia: testTrivia,
        selectedAnswers: selectedAnswers,
        state: gameState,
        expectedCorrectAnswers: 2,
        isDisposed: false,
        onFlipModeSelection: (_) {},
        onStateUpdate: (_) {},
        onPrecisionErrorUpdate: (_) {},
        onNotifyListeners: () {
          notified = true;
        },
        onSaveState: () {},
        hapticService: null,
      );

      expect(result.success, true);
      expect(selectedAnswers.contains('word1'), false);
      expect(notified, true);
    });

    test('should allow selection up to expected count', () {
      final result = manager.toggleTileSelection(
        word: 'word1',
        phase: GamePhase.play,
        currentMode: GameMode.classic,
        currentTrivia: testTrivia,
        selectedAnswers: selectedAnswers,
        state: gameState,
        expectedCorrectAnswers: 2,
        isDisposed: false,
        onFlipModeSelection: (_) {},
        onStateUpdate: (_) {},
        onPrecisionErrorUpdate: (_) {},
        onNotifyListeners: () {
          notified = true;
        },
        onSaveState: () {},
        hapticService: null,
      );

      expect(result.success, true);
      expect(selectedAnswers.contains('word1'), true);
      expect(notified, true);
    });

    test('should delegate to flip mode handler when in flip mode', () {
      bool flipModeCalled = false;
      String? flipModeWord;

      manager.toggleTileSelection(
        word: 'word1',
        phase: GamePhase.play,
        currentMode: GameMode.flip,
        currentTrivia: testTrivia,
        selectedAnswers: selectedAnswers,
        state: gameState,
        expectedCorrectAnswers: 2,
        isDisposed: false,
        onFlipModeSelection: (word) {
          flipModeCalled = true;
          flipModeWord = word;
        },
        onStateUpdate: (_) {},
        onPrecisionErrorUpdate: (_) {},
        onNotifyListeners: () {},
        onSaveState: () {},
        hapticService: null,
      );

      expect(flipModeCalled, true);
      expect(flipModeWord, 'word1');
    });

    test('should handle precision mode wrong answer', () {
      selectedAnswers.clear();

      final result = manager.toggleTileSelection(
        word: 'wrongword', // Wrong answer
        phase: GamePhase.play,
        currentMode: GameMode.precision,
        currentTrivia: testTrivia,
        selectedAnswers: selectedAnswers,
        state: gameState,
        expectedCorrectAnswers: 2,
        isDisposed: false,
        onFlipModeSelection: (_) {},
        onStateUpdate: (newState) {
          updatedState = newState;
        },
        onPrecisionErrorUpdate: (error) {
          precisionError = error;
        },
        onNotifyListeners: () {
          notified = true;
        },
        onSaveState: () {
          saved = true;
        },
        hapticService: HapticService(),
      );

      expect(result.success, false);
      expect(result.errorType, SelectionErrorType.precisionError);
      expect(updatedState?.lives, 2); // Lost one life
      expect(
        selectedAnswers.contains('wrongword'),
        false,
      ); // Wrong word not added
      expect(selectedAnswers.length, 0); // Selection cleared
      expect(precisionError, 'Wrong answer! Life lost.');
      expect(notified, true);
      expect(saved, true);
    });

    test('should set game over when lives reach zero in precision mode', () {
      final lowLivesState =
          GameState(score: 0, lives: 1, round: 1, isGameOver: false);

      manager.toggleTileSelection(
        word: 'wrongword',
        phase: GamePhase.play,
        currentMode: GameMode.precision,
        currentTrivia: testTrivia,
        selectedAnswers: selectedAnswers,
        state: lowLivesState,
        expectedCorrectAnswers: 2,
        isDisposed: false,
        onFlipModeSelection: (_) {},
        onStateUpdate: (newState) {
          updatedState = newState;
        },
        onPrecisionErrorUpdate: (_) {},
        onNotifyListeners: () {},
        onSaveState: () {},
        hapticService: HapticService(),
      );

      expect(updatedState?.lives, 0);
      expect(updatedState?.isGameOver, true);
    });

    test('should not add word beyond expected count', () {
      selectedAnswers.add('word1');
      selectedAnswers.add('word2');

      manager.toggleTileSelection(
        word: 'word3',
        phase: GamePhase.play,
        currentMode: GameMode.classic,
        currentTrivia: testTrivia,
        selectedAnswers: selectedAnswers,
        state: gameState,
        expectedCorrectAnswers: 2,
        isDisposed: false,
        onFlipModeSelection: (_) {},
        onStateUpdate: (_) {},
        onPrecisionErrorUpdate: (_) {},
        onNotifyListeners: () {
          notified = true;
        },
        onSaveState: () {},
        hapticService: null,
      );

      expect(selectedAnswers.length, 2);
      expect(selectedAnswers.contains('word3'), false);
      expect(notified, true);
    });
  });
}
