import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/services/game/game_mode_specific_manager.dart';
import 'package:n3rd_game/models/game_mode_config.dart';
import 'package:n3rd_game/models/game_state.dart';

void main() {
  group('GameModeSpecificManager', () {
    late GameModeSpecificManager manager;

    setUp(() {
      manager = GameModeSpecificManager();
    });

    tearDown(() {
      // Manager doesn't require disposal, but keeping structure consistent
    });

    test('initializes with default values', () {
      expect(manager.streakMultiplier, equals(1));
      expect(manager.survivalPerfectCount, equals(0));
      expect(manager.precisionError, isNull);
    });

    test('handlePerfectRound increments streak multiplier in streak mode', () {
      final state = GameState(
        score: 0,
        lives: 3,
        round: 1,
        isGameOver: false,
      );
      final updatedState = manager.handlePerfectRound(
        currentMode: GameMode.streak,
        currentState: state,
      );

      expect(manager.streakMultiplier, equals(2));
      expect(updatedState, isNull);
    });

    test('handlePerfectRound caps streak multiplier at 5', () {
      final state = GameState(
        score: 0,
        lives: 3,
        round: 1,
        isGameOver: false,
      );
      // Set multiplier to 5
      for (var i = 0; i < 5; i++) {
        manager.handlePerfectRound(
          currentMode: GameMode.streak,
          currentState: state,
        );
      }

      expect(manager.streakMultiplier, equals(5));

      // One more perfect round shouldn't increase it
      manager.handlePerfectRound(
        currentMode: GameMode.streak,
        currentState: state,
      );

      expect(manager.streakMultiplier, equals(5));
    });

    test('handlePerfectRound increments survival perfect count', () {
      final state = GameState(
        score: 0,
        lives: 3,
        round: 1,
        isGameOver: false,
      );
      manager.handlePerfectRound(
        currentMode: GameMode.survival,
        currentState: state,
      );

      expect(manager.survivalPerfectCount, equals(1));
    });

    test(
        'handlePerfectRound grants life every 3 perfect rounds in survival mode',
        () {
      final state = GameState(
        score: 0,
        lives: 3,
        round: 1,
        isGameOver: false,
      );

      // First two perfect rounds
      manager.handlePerfectRound(
        currentMode: GameMode.survival,
        currentState: state,
      );
      manager.handlePerfectRound(
        currentMode: GameMode.survival,
        currentState: state,
      );

      expect(manager.survivalPerfectCount, equals(2));

      // Third perfect round should grant a life
      final updatedState = manager.handlePerfectRound(
        currentMode: GameMode.survival,
        currentState: state,
      );

      expect(manager.survivalPerfectCount, equals(0)); // Reset after granting
      expect(updatedState, isNotNull);
      expect(updatedState!.lives, equals(state.lives + 1));
    });

    test('handlePerfectRound does not grant life if already at max lives', () {
      final state = GameState(
        score: 0,
        lives: 5,
        round: 1,
        isGameOver: false,
      );

      // Set perfect count to 2
      manager.handlePerfectRound(
        currentMode: GameMode.survival,
        currentState: state,
      );
      manager.handlePerfectRound(
        currentMode: GameMode.survival,
        currentState: state,
      );

      expect(manager.survivalPerfectCount, equals(2));

      // Third perfect round shouldn't grant life if already at max, and count stays at 3
      final updatedState = manager.handlePerfectRound(
        currentMode: GameMode.survival,
        currentState: state,
      );

      expect(updatedState, isNull); // No state update (already at max lives)
      expect(
        manager.survivalPerfectCount,
        equals(3),
      ); // Count stays at 3 (not reset because no life granted)
    });

    test('handleNonPerfectRound resets streak multiplier', () {
      final state = GameState(
        score: 0,
        lives: 3,
        round: 1,
        isGameOver: false,
      );
      // Increment multiplier
      manager.handlePerfectRound(
        currentMode: GameMode.streak,
        currentState: state,
      );
      expect(manager.streakMultiplier, equals(2));

      // Non-perfect round should reset
      manager.handleNonPerfectRound(currentMode: GameMode.streak);
      expect(manager.streakMultiplier, equals(1));
    });

    test('handleNonPerfectRound resets survival perfect count', () {
      final state = GameState(
        score: 0,
        lives: 3,
        round: 1,
        isGameOver: false,
      );
      // Increment perfect count
      manager.handlePerfectRound(
        currentMode: GameMode.survival,
        currentState: state,
      );
      expect(manager.survivalPerfectCount, equals(1));

      // Non-perfect round should reset
      manager.handleNonPerfectRound(currentMode: GameMode.survival);
      expect(manager.survivalPerfectCount, equals(0));
    });

    test('getScoringMultiplier returns 1.0 for non-streak modes', () {
      final multiplier =
          manager.getScoringMultiplier(currentMode: GameMode.classic);
      expect(multiplier, equals(1.0));
    });

    test('getScoringMultiplier returns streak multiplier for streak mode', () {
      final state = GameState(
        score: 0,
        lives: 3,
        round: 1,
        isGameOver: false,
      );
      manager.handlePerfectRound(
        currentMode: GameMode.streak,
        currentState: state,
      );

      final multiplier =
          manager.getScoringMultiplier(currentMode: GameMode.streak);
      expect(multiplier, equals(2.0));
    });

    test('applyModeScoring applies streak multiplier', () {
      final state = GameState(
        score: 0,
        lives: 3,
        round: 1,
        isGameOver: false,
      );
      manager.handlePerfectRound(
        currentMode: GameMode.streak,
        currentState: state,
      );

      final adjustedPoints = manager.applyModeScoring(
        points: 100,
        currentMode: GameMode.streak,
      );

      expect(adjustedPoints, equals(200));
    });

    test('applyModeScoring does not modify points for non-streak modes', () {
      final adjustedPoints = manager.applyModeScoring(
        points: 100,
        currentMode: GameMode.classic,
      );

      expect(adjustedPoints, equals(100));
    });

    test('setPrecisionError and clearPrecisionError work correctly', () {
      expect(manager.precisionError, isNull);

      manager.setPrecisionError('Test error');
      expect(manager.precisionError, equals('Test error'));

      manager.clearPrecisionError();
      expect(manager.precisionError, isNull);
    });

    test('reset resets all state', () {
      final state = GameState(
        score: 0,
        lives: 3,
        round: 1,
        isGameOver: false,
      );
      // Set some state
      manager.handlePerfectRound(
        currentMode: GameMode.streak,
        currentState: state,
      );
      manager.setPrecisionError('Error');

      manager.reset(currentMode: GameMode.classic);

      expect(manager.streakMultiplier, equals(1));
      expect(manager.survivalPerfectCount, equals(0));
      expect(manager.precisionError, isNull);
    });

    test('resetForNewRound clears precision error', () {
      manager.setPrecisionError('Error');
      manager.resetForNewRound();
      expect(manager.precisionError, isNull);
    });

    test('getStateForPersistence returns correct state', () {
      final state = GameState(
        score: 0,
        lives: 3,
        round: 1,
        isGameOver: false,
      );
      manager.handlePerfectRound(
        currentMode: GameMode.streak,
        currentState: state,
      );
      manager.handlePerfectRound(
        currentMode: GameMode.survival,
        currentState: state,
      );

      final stateMap = manager.getStateForPersistence();

      expect(stateMap['streakMultiplier'], equals(2));
      expect(stateMap['survivalPerfectCount'], equals(1));
    });

    test('restoreState restores streak state correctly when in streak mode',
        () {
      final stateMap = {
        'streakMultiplier': 3,
        'survivalPerfectCount': 2,
      };

      manager.restoreState(
        extendedStateMap: stateMap,
        currentMode: GameMode.streak,
      );

      expect(
        manager.streakMultiplier,
        equals(3),
      ); // Restored because in streak mode
      expect(
        manager.survivalPerfectCount,
        equals(0),
      ); // Reset because not in survival mode
    });

    test('restoreState restores survival state correctly when in survival mode',
        () {
      final stateMap = {
        'streakMultiplier': 3,
        'survivalPerfectCount': 2,
      };

      manager.restoreState(
        extendedStateMap: stateMap,
        currentMode: GameMode.survival,
      );

      expect(
        manager.streakMultiplier,
        equals(1),
      ); // Reset because not in streak mode
      expect(
        manager.survivalPerfectCount,
        equals(2),
      ); // Restored because in survival mode
    });

    test('restoreState resets multiplier if not in streak mode', () {
      final extendedStateMap = {
        'streakMultiplier': 3,
        'survivalPerfectCount': 2,
      };

      manager.restoreState(
        extendedStateMap: extendedStateMap,
        currentMode: GameMode.classic,
      );

      expect(manager.streakMultiplier, equals(1)); // Reset for non-streak mode
      expect(
        manager.survivalPerfectCount,
        equals(0),
      ); // Reset for non-survival mode
    });
  });
}
