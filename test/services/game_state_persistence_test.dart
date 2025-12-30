import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/models/game_state.dart';
import '../utils/test_helpers.dart';

void main() {
  setUpAll(() async {
    await TestHelpers.setupAllTestInfrastructure();
  });

  tearDownAll(() {
    TestHelpers.tearDownAllTestInfrastructure();
  });

  group('GameState Persistence', () {
    late SharedPreferences prefs;

    setUp(() async {
      TestHelpers.setupMockSharedPreferences();
      prefs = await SharedPreferences.getInstance();
    });

    tearDown(() async {
      await prefs.clear();
      TestHelpers.clearMockSharedPreferences();
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

    // Edge Cases and Boundary Conditions
    test('handles negative score values', () {
      final state = GameState(
        score: -100,
        round: 1,
        lives: 3,
        isGameOver: false,
      );

      expect(state.score, -100); // Should not crash
    });

    test('handles zero score', () {
      final state = GameState(
        score: 0,
        round: 1,
        lives: 3,
        isGameOver: false,
      );

      expect(state.score, 0);
    });

    test('handles very large score values', () {
      final state = GameState(
        score: 999999999,
        round: 1,
        lives: 3,
        isGameOver: false,
      );

      expect(state.score, 999999999);
    });

    test('handles zero lives', () {
      final state = GameState(
        score: 100,
        round: 1,
        lives: 0,
        isGameOver: false,
      );

      expect(state.lives, 0);
    });

    test('handles negative lives', () {
      final state = GameState(
        score: 100,
        round: 1,
        lives: -1,
        isGameOver: false,
      );

      expect(state.lives, -1); // Should not crash
    });

    test('handles zero round', () {
      final state = GameState(
        score: 100,
        round: 0,
        lives: 3,
        isGameOver: false,
      );

      expect(state.round, 0);
    });

    test('handles very high round numbers', () {
      final state = GameState(
        score: 100,
        round: 999999,
        lives: 3,
        isGameOver: false,
      );

      expect(state.round, 999999);
    });

    test('copyWith preserves all fields when none specified', () {
      final original = GameState(
        score: 1000,
        round: 5,
        lives: 3,
        isGameOver: false,
      );

      final copy = original.copyWith();

      expect(copy.score, original.score);
      expect(copy.round, original.round);
      expect(copy.lives, original.lives);
      expect(copy.isGameOver, original.isGameOver);
    });

    test('copyWith handles partial updates', () {
      final original = GameState(
        score: 1000,
        round: 5,
        lives: 3,
        isGameOver: false,
      );

      final updated = original.copyWith(score: 2000);

      expect(updated.score, 2000);
      expect(updated.round, 5); // Unchanged
      expect(updated.lives, 3); // Unchanged
    });

    test('isPerfectRound handles boundary cases', () {
      final state0Correct = GameState(
        score: 100,
        round: 1,
        lives: 3,
        isGameOver: false,
        correctCount: 0,
      );

      final state3Correct = GameState(
        score: 100,
        round: 1,
        lives: 3,
        isGameOver: false,
        correctCount: 3,
      );

      expect(state0Correct.isPerfectRound(), false);
      expect(state3Correct.isPerfectRound(), true);
    });
  });
}
