import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/services/animation_randomizer_service.dart';

void main() {
  group('AnimationRandomizerService', () {
    late AnimationRandomizerService service;

    setUp(() {
      service = AnimationRandomizerService();
      service.clearCache();
    });

    tearDown(() {
      service.clearCache();
      service.dispose();
    });

    test('initializes correctly', () async {
      expect(service.isInitialized, false);
      await service.init();
      expect(service.isInitialized, true);
    });

    test('returns empty list for non-existent category', () async {
      await service.init();
      final animations = await service.getAllAnimations('non_existent');
      expect(animations, isEmpty);
    });

    test('handles empty category gracefully', () async {
      await service.init();
      final animations = await service.getAllAnimations('');
      expect(animations, isEmpty);
    });

    test('getRandomAnimation returns null for empty category', () async {
      await service.init();
      final animation = await service.getRandomAnimation('');
      expect(animation, isNull);
    });

    test('getAnimationPath validates empty inputs', () async {
      await service.init();
      final path1 = await service.getAnimationPath('', 'test.mp4');
      final path2 = await service.getAnimationPath('category', '');
      expect(path1, isNull);
      expect(path2, isNull);
    });

    test('clearCache works correctly', () async {
      await service.init();
      service.clearCache();
      expect(service.isInitialized, true); // init state preserved
    });

    test('dispose clears cache', () {
      service.clearCache();
      service.dispose();
      // After dispose, cache should be cleared
      expect(service.isInitialized, false);
    });
  });
}

