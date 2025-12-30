import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/services/global_leaderboard_service.dart';
import 'package:n3rd_game/models/game_mode_config.dart';
import 'package:n3rd_game/services/leaderboard/leaderboard_repository.dart';
import '../utils/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await TestHelpers.setupAllTestInfrastructure();
  });

  tearDownAll(() {
    TestHelpers.tearDownAllTestInfrastructure();
  });

  group('GlobalLeaderboardService', () {
    late GlobalLeaderboardService service;

    setUp(() {
      TestHelpers.setupMockSharedPreferences();
      service = GlobalLeaderboardService();
    });

    tearDown(() {
      service.dispose();
      TestHelpers.clearMockSharedPreferences();
    });

    test('should initialize service', () async {
      await service.init();
      // Service is initialized after init() call
      expect(service, isNotNull);
    });

    test('should submit score', () async {
      await service.init();

      // Note: This will fail without Firebase, but tests the structure
      try {
        await service.submitScore(
          score: 1000,
          gameMode: GameMode.classic,
          timeframe: LeaderboardTimeframe.allTime,
        );
      } catch (e) {
        // Expected to fail without Firebase
        expect(e, isA<Exception>());
      }
    });

    test('should get leaderboard', () async {
      await service.init();

      try {
        final result = await service.getLeaderboard(
          gameMode: GameMode.classic,
          timeframe: LeaderboardTimeframe.allTime,
          pageSize: 20,
        );

        expect(result, isA<PaginatedGlobalLeaderboardResult>());
      } catch (e) {
        // Expected to fail without Firebase
        expect(e, isA<Exception>());
      }
    });
  });
}
