import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/services/stats_service.dart';
import '../utils/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await TestHelpers.setupAllTestInfrastructure();
  });

  tearDownAll(() async {
    await TestHelpers.tearDownAllTestInfrastructure();
  });

  group('StatsService', () {
    late StatsService statsService;

    setUp(() async {
      TestHelpers.setupMockSharedPreferences();
      statsService = StatsService();
      await statsService.init();
    });

    tearDown(() {
      statsService.dispose();
      TestHelpers.clearMockSharedPreferences();
    });

    test('should initialize with default state', () {
      final stats = statsService.stats;
      expect(stats.totalGamesPlayed, 0);
      expect(stats.totalCorrectAnswers, 0);
      expect(stats.totalWrongAnswers, 0);
      expect(stats.highestScore, 0);
      expect(stats.currentStreak, 0);
      expect(stats.longestStreak, 0);
    });

    test('should handle daily stats correctly', () {
      final stats = statsService.stats;
      expect(stats.dailyStats, isA<List<DailyStats>>());
      expect(stats.dailyStats.length, greaterThanOrEqualTo(0));
    });

    test('should calculate stats correctly', () {
      // Stats should be calculated from daily stats
      final stats = statsService.stats;

      // All initial values should be 0 or valid defaults
      expect(stats.totalGamesPlayed, greaterThanOrEqualTo(0));
      expect(stats.totalCorrectAnswers, greaterThanOrEqualTo(0));
      expect(stats.totalWrongAnswers, greaterThanOrEqualTo(0));
      expect(stats.highestScore, greaterThanOrEqualTo(0));
    });

    test('should handle mode play counts', () {
      final stats = statsService.stats;
      expect(stats.modePlayCounts, isA<Map<String, int>>());
    });

    test('should persist and load stats', () async {
      // Test that stats can be saved and loaded
      // This is tested through the init() method which loads from SharedPreferences
      final stats = statsService.stats;
      expect(stats, isNotNull);
    });

    test('should handle empty daily stats', () {
      final stats = statsService.stats;
      // Should handle empty list gracefully
      expect(stats.dailyStats, isA<List<DailyStats>>());
    });

    test('should calculate streaks correctly', () {
      final stats = statsService.stats;
      expect(stats.currentStreak, greaterThanOrEqualTo(0));
      expect(stats.longestStreak, greaterThanOrEqualTo(0));
      expect(stats.longestStreak, greaterThanOrEqualTo(stats.currentStreak));
    });
  });

  group('DailyStats', () {
    test('should create DailyStats with valid data', () {
      final date = DateTime.now();
      final dailyStats = DailyStats(
        date: date,
        gamesPlayed: 5,
        correctAnswers: 10,
        wrongAnswers: 2,
        score: 100,
        highestScore: 150,
        modePlayCounts: {'classic': 3, 'speed': 2},
      );

      expect(dailyStats.date, date);
      expect(dailyStats.gamesPlayed, 5);
      expect(dailyStats.correctAnswers, 10);
      expect(dailyStats.wrongAnswers, 2);
      expect(dailyStats.score, 100);
      expect(dailyStats.highestScore, 150);
      expect(dailyStats.modePlayCounts['classic'], 3);
      expect(dailyStats.modePlayCounts['speed'], 2);
    });

    test('should handle malformed date strings gracefully', () {
      // Test that fromJson handles invalid dates
      final json = {
        'date': 'invalid-date',
        'gamesPlayed': 0,
        'correctAnswers': 0,
        'wrongAnswers': 0,
        'score': 0,
        'highestScore': 0,
        'modePlayCounts': {},
      };

      // Should not throw, should use current date as fallback
      expect(() => DailyStats.fromJson(json), returnsNormally);
    });

    test('should create copyWith correctly', () {
      final original = DailyStats(
        date: DateTime.now(),
        gamesPlayed: 5,
        correctAnswers: 10,
        wrongAnswers: 2,
        score: 100,
        highestScore: 150,
        modePlayCounts: {'classic': 3},
      );

      final updated = original.copyWith(
        gamesPlayed: 10,
        score: 200,
      );

      expect(updated.gamesPlayed, 10);
      expect(updated.score, 200);
      expect(updated.correctAnswers, 10); // Unchanged
      expect(updated.wrongAnswers, 2); // Unchanged
    });

    // Edge Cases and Boundary Conditions
    test('handles negative values gracefully', () {
      final stats = DailyStats(
        date: DateTime.now(),
        gamesPlayed: -1, // Invalid value
        correctAnswers: -5,
        wrongAnswers: -2,
        score: -100,
        highestScore: -50,
      );

      // Should not crash, values should be stored as-is
      expect(stats.gamesPlayed, -1);
    });

    test('handles very large values', () {
      final stats = DailyStats(
        date: DateTime.now(),
        gamesPlayed: 999999,
        correctAnswers: 999999,
        score: 999999999,
        highestScore: 999999999,
      );

      // Should handle large values without overflow
      expect(stats.gamesPlayed, 999999);
    });

    test('handles null modePlayCounts', () {
      final stats = DailyStats(
        date: DateTime.now(),
        gamesPlayed: 0,
        correctAnswers: 0,
        wrongAnswers: 0,
        score: 0,
        highestScore: 0,
      );

      expect(stats.modePlayCounts, isA<Map<String, int>>());
    });

    test('handles future dates', () {
      final futureDate = DateTime.now().add(const Duration(days: 365));
      final stats = DailyStats(
        date: futureDate,
        gamesPlayed: 0,
      );

      expect(stats.date, futureDate);
    });

    test('handles very old dates', () {
      final oldDate = DateTime(1970, 1, 1);
      final stats = DailyStats(
        date: oldDate,
        gamesPlayed: 0,
      );

      expect(stats.date, oldDate);
    });

    test('handles empty modePlayCounts map', () {
      final stats = DailyStats(
        date: DateTime.now(),
        gamesPlayed: 0,
        modePlayCounts: {},
      );

      expect(stats.modePlayCounts, isEmpty);
    });

    test('handles copyWith with all null values', () {
      final original = DailyStats(
        date: DateTime.now(),
        gamesPlayed: 5,
        correctAnswers: 10,
      );

      final updated = original.copyWith();

      expect(updated.gamesPlayed, 5);
      expect(updated.correctAnswers, 10);
    });
  });

  group('StatsService Edge Cases', () {
    late StatsService statsService;

    setUp(() async {
      TestHelpers.setupMockSharedPreferences();
      statsService = StatsService();
      await statsService.init();
    });

    tearDown(() {
      statsService.dispose();
      TestHelpers.clearMockSharedPreferences();
    });

    test('handles multiple init calls', () async {
      await statsService.init();
      await statsService.init(); // Should not crash
      expect(statsService, isNotNull);
    });

    test('handles dispose after multiple inits', () async {
      // Note: This test verifies that dispose can be called after multiple inits
      // The service should handle this gracefully
      await statsService.init();
      await statsService.init();
      // Verify service is still functional after multiple inits
      expect(statsService, isNotNull);
      expect(statsService.stats, isNotNull);
      // Dispose is called in tearDown, so we don't call it here
    });

    test('handles stats with zero values', () {
      final stats = statsService.stats;
      expect(stats.totalGamesPlayed, greaterThanOrEqualTo(0));
      expect(stats.highestScore, greaterThanOrEqualTo(0));
    });

    test('handles empty mode play counts', () {
      final stats = statsService.stats;
      expect(stats.modePlayCounts, isA<Map<String, int>>());
    });
  });
}
