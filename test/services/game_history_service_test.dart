import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/services/game_history_service.dart';
import 'package:n3rd_game/models/game_history_entry.dart';
import 'package:n3rd_game/models/game_mode_config.dart';
import '../utils/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await TestHelpers.setupAllTestInfrastructure();
  });

  tearDownAll(() async {
    await TestHelpers.tearDownAllTestInfrastructure();
  });

  group('GameHistoryService', () {
    late GameHistoryService service;

    setUp(() async {
      TestHelpers.setupMockSharedPreferences();
      service = GameHistoryService();
      await service.init();
    });

    tearDown(() {
      service.dispose();
      TestHelpers.clearMockSharedPreferences();
    });

    test('should initialize with default state', () {
      expect(service.isInitialized, isTrue);
      expect(service.cachedGames, isEmpty);
    });

    test('should validate gameId format', () async {
      // Valid gameId
      final validGame = GameHistoryEntry(
        gameId: 'game_123-abc',
        completedAt: DateTime.now(),
        mode: GameMode.classic,
        score: 100,
        rounds: 1,
        correctAnswers: 5,
        wrongAnswers: 0,
        durationSeconds: 60,
        accuracy: 1.0,
      );

      // This should not throw
      await service.recordGame(validGame);

      // Invalid gameId (empty)
      final invalidGame = GameHistoryEntry(
        gameId: '',
        completedAt: DateTime.now(),
        mode: GameMode.classic,
        score: 100,
        rounds: 1,
        correctAnswers: 5,
        wrongAnswers: 0,
        durationSeconds: 60,
        accuracy: 1.0,
      );

      // Should not record invalid game
      await service.recordGame(invalidGame);
      expect(service.cachedGames.length, 1); // Only valid game recorded
    });

    test('should enforce rate limiting', () async {
      // Record multiple games rapidly
      for (int i = 0; i < 15; i++) {
        final testGame = GameHistoryEntry(
          gameId: 'test_game_$i',
          completedAt: DateTime.now(),
          mode: GameMode.classic,
          score: 100,
          rounds: 1,
          correctAnswers: 5,
          wrongAnswers: 0,
          durationSeconds: 60,
          accuracy: 1.0,
        );
        await service.recordGame(testGame);
      }

      // Should have rate limited some calls
      // Exact count depends on timing, but should be <= 10
      expect(service.cachedGames.length, lessThanOrEqualTo(10));
    });

    test('should filter games by mode', () async {
      // Add games with different modes
      final classicGame = GameHistoryEntry(
        gameId: 'classic_1',
        completedAt: DateTime.now(),
        mode: GameMode.classic,
        score: 100,
        rounds: 1,
        correctAnswers: 5,
        wrongAnswers: 0,
        durationSeconds: 60,
        accuracy: 1.0,
      );

      final speedGame = GameHistoryEntry(
        gameId: 'speed_1',
        completedAt: DateTime.now(),
        mode: GameMode.speed,
        score: 200,
        rounds: 1,
        correctAnswers: 5,
        wrongAnswers: 0,
        durationSeconds: 60,
        accuracy: 1.0,
      );

      await service.recordGame(classicGame);
      await service.recordGame(speedGame);

      final classicGames = await service.getGameHistory(
        limit: 10,
        mode: GameMode.classic,
      );

      expect(classicGames.length, 1);
      expect(classicGames.first.mode, GameMode.classic);
    });

    test('should filter games by score range', () async {
      final lowScoreGame = GameHistoryEntry(
        gameId: 'low_1',
        completedAt: DateTime.now(),
        mode: GameMode.classic,
        score: 50,
        rounds: 1,
        correctAnswers: 3,
        wrongAnswers: 2,
        durationSeconds: 60,
        accuracy: 0.6,
      );

      final highScoreGame = GameHistoryEntry(
        gameId: 'high_1',
        completedAt: DateTime.now(),
        mode: GameMode.classic,
        score: 200,
        rounds: 1,
        correctAnswers: 5,
        wrongAnswers: 0,
        durationSeconds: 60,
        accuracy: 1.0,
      );

      await service.recordGame(lowScoreGame);
      await service.recordGame(highScoreGame);

      final highScoreGames = await service.getGameHistory(
        limit: 10,
        minScore: 100,
      );

      expect(highScoreGames.length, 1);
      expect(highScoreGames.first.score, greaterThanOrEqualTo(100));
    });

    test('should calculate statistics', () async {
      // Add multiple games
      for (int i = 0; i < 5; i++) {
        final game = GameHistoryEntry(
          gameId: 'stats_game_$i',
          completedAt: DateTime.now(),
          mode: GameMode.classic,
          score: 100 * (i + 1),
          rounds: i + 1,
          correctAnswers: 5,
          wrongAnswers: 0,
          durationSeconds: 60,
          accuracy: 0.8 + (i * 0.05),
        );
        await service.recordGame(game);
      }

      final stats = await service.getStatistics();

      expect(stats['totalGames'], 5);
      expect(stats['totalScore'], 1500); // 100 + 200 + 300 + 400 + 500
      expect(stats['averageScore'], 300.0);
      expect(stats['highestScore'], 500);
    });

    test('should handle empty statistics', () async {
      final stats = await service.getStatistics();

      expect(stats['totalGames'], 0);
      expect(stats['totalScore'], 0);
      expect(stats['averageScore'], 0.0);
      expect(stats['highestScore'], 0);
    });

    test('should cache games locally', () async {
      final game = GameHistoryEntry(
        gameId: 'cache_test',
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
      expect(service.cachedGames.first.gameId, 'cache_test');
    });

    test('should limit cache size', () async {
      // Add more games than max cache size
      for (int i = 0; i < 150; i++) {
        final game = GameHistoryEntry(
          gameId: 'cache_limit_$i',
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
      }

      // Cache should be limited
      expect(service.cachedGames.length, lessThanOrEqualTo(100));
    });
  });
}
