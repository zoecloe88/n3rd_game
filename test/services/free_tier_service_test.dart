import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/services/free_tier_service.dart';
import '../utils/test_helpers.dart';

void main() {
  TestHelpers.ensureInitialized();

  group('FreeTierService', () {
    late FreeTierService service;

    setUpAll(() {
      TestHelpers.setupMockSharedPreferences();
    });

    setUp(() async {
      // Clear SharedPreferences mock data before each test to prevent state pollution
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      service = FreeTierService();
    });

    tearDown(() {
      service.dispose();
    });

    tearDownAll(() {
      TestHelpers.clearMockSharedPreferences();
    });

    test('initializes correctly', () {
      expect(service, isNotNull);
    });

    test('has maxGamesPerDay getter', () {
      expect(service.maxGamesPerDay, 5);
    });

    test('gamesStartedToday starts at 0', () async {
      await service.init();
      expect(service.gamesStartedToday, 0);
    });

    test('can record game start', () async {
      await service.init();
      final result = await service.recordGameStart();
      expect(result, true);
      expect(service.gamesStartedToday, 1);
    });

    test('can check if daily limit reached', () async {
      await service.init();
      // Start 5 games (the limit)
      for (int i = 0; i < service.maxGamesPerDay; i++) {
        await service.recordGameStart();
      }
      expect(service.hasGamesRemaining, false);
    });

    test('hasGamesRemaining returns correct value', () async {
      await service.init();
      await service.recordGameStart();
      expect(service.hasGamesRemaining, true);
      
      // Fill up to limit
      for (int i = 1; i < service.maxGamesPerDay; i++) {
        await service.recordGameStart();
      }
      expect(service.hasGamesRemaining, false);
    });

    test('service can be disposed', () {
      // Create a new service instance for this test since tearDown will dispose the main one
      final testService = FreeTierService();
      expect(() => testService.dispose(), returnsNormally);
    });
  });
}

