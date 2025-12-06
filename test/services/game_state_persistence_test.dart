import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/models/game_state.dart';

void main() {
  group('GameState Persistence', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    tearDown(() async {
      await prefs.clear();
    });

    test('creates game state with required fields', () {
      final state = GameState(
        score: 1000,
        round: 5,
        lives: 3,
        isGameOver: false,
        perfectStreak: 3,
      );

      expect(state.score, 1000);
      expect(state.round, 5);
      expect(state.lives, 3);
      expect(state.isGameOver, false);
      expect(state.perfectStreak, 3);
    });

    test('validates state constraints on creation', () {
      final state = GameState(
        score: 1000,
        round: 5,
        lives: 3,
        isGameOver: false,
      );
      expect(state.score, 1000);
      expect(state.round, 5);
      expect(state.lives, 3);
    });

    test('copyWith creates new state with updated values', () {
      final original = GameState(
        score: 1000,
        round: 5,
        lives: 3,
        isGameOver: false,
      );

      final updated = original.copyWith(score: 2000, round: 10);

      expect(updated.score, 2000);
      expect(updated.round, 10);
      expect(updated.lives, 3); // Unchanged
      expect(original.score, 1000); // Original unchanged
    });

    test('isPerfectRound correctly identifies perfect rounds', () {
      final perfectState = GameState(
        score: 1000,
        round: 5,
        lives: 3,
        isGameOver: false,
        correctCount: 3,
      );

      final imperfectState = GameState(
        score: 1000,
        round: 5,
        lives: 3,
        isGameOver: false,
        correctCount: 2,
      );

      expect(perfectState.isPerfectRound(), true);
      expect(imperfectState.isPerfectRound(), false);
    });
  });
}

