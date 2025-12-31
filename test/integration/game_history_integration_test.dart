import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/services/game_history_service.dart';
import 'package:n3rd_game/models/game_history_entry.dart';
import 'package:n3rd_game/models/game_mode_config.dart';
import '../utils/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await TestHelpers.setupAllTestInfrastructure();
    // Firebase is already initialized by setupAllTestInfrastructure()
  });

  tearDownAll(() async {
    await TestHelpers.tearDownAllTestInfrastructure();
  });

  group('Game History Integration Tests', () {
    late GameHistoryService service;

    setUp(() async {
      TestHelpers.setupMockSharedPreferences();
      // Firebase is already initialized by setUpAll()
      try {
        service = GameHistoryService();
        await service.init();
      } catch (e) {
        // If service creation fails due to Firebase, skip the test
        // This allows the test framework to report the issue
        throw Exception('Failed to create GameHistoryService: $e');
      }
    });

    tearDown(() {
      service.dispose();
      TestHelpers.clearMockSharedPreferences();
    });

    test('full flow: record -> retrieve -> filter', () async {
      // Record multiple games
      final games = [
        GameHistoryEntry(
          gameId: 'integration_1',
          completedAt: DateTime.now().subtract(const Duration(days: 1)),
          mode: GameMode.classic,
          score: 100,
          rounds: 5,
          correctAnswers: 4,
          wrongAnswers: 1,
          durationSeconds: 120,
          accuracy: 0.8,
        ),
        GameHistoryEntry(
          gameId: 'integration_2',
          completedAt: DateTime.now(),
          mode: GameMode.speed,
          score: 200,
          rounds: 3,
          correctAnswers: 3,
          wrongAnswers: 0,
          durationSeconds: 90,
          accuracy: 0.9,
        ),
        GameHistoryEntry(
          gameId: 'integration_3',
          completedAt: DateTime.now(),
          mode: GameMode.classic,
          score: 150,
          rounds: 4,
          correctAnswers: 4,
          wrongAnswers: 0,
          durationSeconds: 100,
          accuracy: 0.85,
        ),
      ];

      for (final game in games) {
        await service.recordGame(game);
      }

      // Retrieve all games
      final allGames = await service.getGameHistory(limit: 10);
      expect(allGames.length, greaterThanOrEqualTo(3));

      // Filter by mode
      final classicGames = await service.getGameHistory(
        limit: 10,
        mode: GameMode.classic,
      );
      expect(classicGames.length, 2);

      // Filter by score
      final highScoreGames = await service.getGameHistory(
        limit: 10,
        minScore: 150,
      );
      expect(highScoreGames.length, 2);
    });

    test('statistics accuracy', () async {
      // Record games with known values
      final games = [
        GameHistoryEntry(
          gameId: 'stats_1',
          completedAt: DateTime.now(),
          mode: GameMode.classic,
          score: 100,
          rounds: 5,
          correctAnswers: 4,
          wrongAnswers: 1,
          durationSeconds: 120,
          accuracy: 0.8,
        ),
        GameHistoryEntry(
          gameId: 'stats_2',
          completedAt: DateTime.now(),
          mode: GameMode.classic,
          score: 200,
          rounds: 3,
          correctAnswers: 3,
          wrongAnswers: 0,
          durationSeconds: 90,
          accuracy: 0.9,
        ),
        GameHistoryEntry(
          gameId: 'stats_3',
          completedAt: DateTime.now(),
          mode: GameMode.speed,
          score: 150,
          rounds: 4,
          correctAnswers: 4,
          wrongAnswers: 0,
          durationSeconds: 100,
          accuracy: 0.85,
        ),
      ];

      for (final game in games) {
        await service.recordGame(game);
      }

      final stats = await service.getStatistics();

      expect(stats['totalGames'], 3);
      expect(stats['totalScore'], 450); // 100 + 200 + 150
      expect(stats['averageScore'], 150.0);
      expect(stats['highestScore'], 200);
      expect(stats['totalRounds'], 12); // 5 + 3 + 4
      expect(stats['averageAccuracy'], closeTo(0.85, 0.01));

      final modeBreakdown = stats['modeBreakdown'] as Map<String, int>;
      expect(modeBreakdown['classic'], 2);
      expect(modeBreakdown['speed'], 1);
    });

    test('cache persistence', () async {
      // Record a game
      final game = GameHistoryEntry(
        gameId: 'cache_persist',
        completedAt: DateTime.now(),
        mode: GameMode.classic,
        score: 100,
        rounds: 1,
        correctAnswers: 5,
        wrongAnswers: 0,
        durationSeconds: 60,
        accuracy: 1.0,
      );

      await service.recordGame(game);
      expect(service.cachedGames.length, 1);

      // Dispose and recreate service
      service.dispose();
      service = GameHistoryService();
      await service.init();

      // Cache should be loaded
      expect(service.cachedGames.length, 1);
      expect(service.cachedGames.first.gameId, 'cache_persist');
    });
  });
}
