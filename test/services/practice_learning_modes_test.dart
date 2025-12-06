import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/services/game_service.dart';

void main() {
  group('Practice & Learning Modes', () {
    test('Practice mode should have relaxed timing configuration', () {
      final practiceConfig = ModeConfig.getConfig(GameMode.practice);
      expect(practiceConfig.memorizeTime, 15);
      expect(practiceConfig.playTime, 30);
      // Practice mode should have more time than classic mode
      final classicConfig = ModeConfig.getConfig(GameMode.classic);
      expect(practiceConfig.memorizeTime > classicConfig.memorizeTime, true);
      expect(practiceConfig.playTime > classicConfig.playTime, true);
    });

    test('Learning mode should have extended timing configuration', () {
      final learningConfig = ModeConfig.getConfig(GameMode.learning);
      expect(learningConfig.memorizeTime, 15);
      expect(learningConfig.playTime, 30);
      // Learning mode should have more time than classic mode
      final classicConfig = ModeConfig.getConfig(GameMode.classic);
      expect(learningConfig.memorizeTime > classicConfig.memorizeTime, true);
      expect(learningConfig.playTime > classicConfig.playTime, true);
    });

    test('Practice and Learning modes should be in GameMode enum', () {
      expect(GameMode.values.contains(GameMode.practice), true);
      expect(GameMode.values.contains(GameMode.learning), true);
    });

    test('ModeConfig should handle all 18 game modes including Practice and Learning', () {
      // Verify all modes have valid configurations
      for (final mode in GameMode.values) {
        final config = ModeConfig.getConfig(mode);
        expect(config.memorizeTime >= 0, true, reason: 'Mode: $mode');
        expect(config.playTime > 0, true, reason: 'Mode: $mode');
      }
      
      // Verify we have 18 modes total
      expect(GameMode.values.length, 18);
    });

    test('Practice mode name should be correct', () {
      // Verify the enum value exists
      expect(GameMode.practice.name, 'practice');
    });

    test('Learning mode name should be correct', () {
      expect(GameMode.learning.name, 'learning');
    });
  });
}

