import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/services/game/game_powerup_manager.dart';

void main() {
  group('GamePowerupManager', () {
    late GamePowerupManager manager;

    setUp(() {
      manager = GamePowerupManager();
    });

    tearDown(() {
      // Manager doesn't require disposal, but keeping structure consistent
    });

    test('should initialize with default power-up uses', () {
      expect(manager.revealAllUses, 3);
      expect(manager.clearUses, 3);
      expect(manager.skipUses, 3);
      expect(manager.streakShieldUses, 0);
      expect(manager.timeFreezeUses, 0);
      expect(manager.hintUses, 0);
      expect(manager.doubleScoreUses, 0);
    });

    test('should track power-up uses', () {
      manager.revealAllUses = 5;
      expect(manager.revealAllUses, 5);

      manager.clearUses = 2;
      expect(manager.clearUses, 2);
    });

    test('should track active power-up states', () {
      expect(manager.isTimeFrozen, false);
      expect(manager.hasDoubleScore, false);
      expect(manager.hasStreakShield, false);

      manager.isTimeFrozen = true;
      expect(manager.isTimeFrozen, true);

      manager.hasDoubleScore = true;
      expect(manager.hasDoubleScore, true);
    });

    test('should track hinted words', () {
      expect(manager.getHintedWords(), isEmpty);

      manager.hintedWords.add('word1');
      manager.hintedWords.add('word2');
      expect(manager.getHintedWords().length, 2);
      expect(manager.getHintedWords().contains('word1'), true);
    });

    test('should clear hinted words', () {
      manager.hintedWords.add('word1');
      manager.hintedWords.clear();
      expect(manager.getHintedWords(), isEmpty);
    });

    test('should track play time at freeze', () {
      expect(manager.playTimeAtFreeze, isNull);

      manager.playTimeAtFreeze = 10;
      expect(manager.playTimeAtFreeze, 10);
    });

    test('should award streak reward', () {
      int livesAdded = 0;
      manager.awardStreakReward(
        streak: 3, // 3rd perfect streak should add a life
        currentLives: 2,
        onAddLife: (lives) {
          livesAdded = lives;
        },
      );
      // 3rd perfect streak should add 1 life
      expect(livesAdded, 1);
      // hasStreakShield should remain false (not set by awardStreakReward)
      expect(manager.hasStreakShield, false);
    });

    test('should consume streak shield', () {
      manager.hasStreakShield = true;
      manager.consumeStreakShield();
      expect(manager.hasStreakShield, false);
    });

    test('should consume double score', () {
      manager.hasDoubleScore = true;
      manager.consumeDoubleScore();
      expect(manager.hasDoubleScore, false);
    });
  });
}
