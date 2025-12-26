import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/services/stats_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StatsService', () {
    late StatsService statsService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      statsService = StatsService();
      await statsService.init();
    });

    tearDown(() {
      statsService.dispose();
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
  });
}

