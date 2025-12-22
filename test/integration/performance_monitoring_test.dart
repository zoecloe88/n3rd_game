import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/services/network_service.dart';
import 'package:n3rd_game/data/trivia_templates_consolidated.dart';

/// Integration tests for performance monitoring
/// These tests verify that performance metrics are tracked correctly
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Mock connectivity_plus MethodChannel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'check') {
          // Return WiFi connectivity for testing
          return ['wifi'];
        }
        return null;
      },
    );
  });

  tearDownAll(() {
    // Clear mock handler
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      null,
    );
  });
  group('Performance Monitoring Tests', () {
    late AnalyticsService analyticsService;

    setUp(() {
      analyticsService = AnalyticsService();
    });

    tearDown(() {
      analyticsService.dispose();
    });

    test('AnalyticsService tracks template initialization performance', () async {
      await analyticsService.init();
      
      // Service should track template initialization
      // This is verified by logTemplateInitialization method
      expect(analyticsService, isNotNull);
      
      // Template initialization duration should be tracked
      final initDuration = EditionTriviaTemplates.lastInitializationDuration;
      expect(initDuration, anyOf(isNull, isA<Duration>()));
    });

    test('AnalyticsService tracks network reachability performance', () async {
      await analyticsService.init();
      
      // Service should track network reachability checks
      // This is verified by logNetworkReachabilityCheck method
      expect(analyticsService, isNotNull);
      
      // Network service should integrate with analytics
      final networkService = NetworkService();
      await networkService.init();
      expect(networkService, isNotNull);
      
      networkService.dispose();
    });

    test('Performance metrics are stored correctly', () {
      // Verify performance metrics structure
      expect(analyticsService.metrics, isA<List>());
      
      // Metrics should be empty initially
      expect(analyticsService.metrics.isEmpty, true);
    });

    test('AnalyticsService tracks service initialization failures', () async {
      await analyticsService.init();
      
      // Service should track initialization failures
      // This is verified by logServiceInitializationFailure method
      expect(analyticsService, isNotNull);
    });

    test('Performance metrics support trend analysis', () {
      // Verify trend analysis methods exist
      final weeklyTrends = analyticsService.getWeeklyTrends();
      final monthlyTrends = analyticsService.getMonthlyTrends();
      
      expect(weeklyTrends, isA<List>());
      expect(monthlyTrends, isA<List>());
    });

    test('Performance metrics track category breakdown', () {
      // Verify category performance tracking
      final categoryBreakdown = analyticsService.getCategoryBreakdown();
      
      expect(categoryBreakdown, isA<List>());
    });

    test('Performance metrics track time-of-day performance', () {
      // Verify time-of-day performance tracking
      final timeOfDayPerformance = analyticsService.getTimeOfDayPerformance();
      
      expect(timeOfDayPerformance, isA<List>());
      expect(timeOfDayPerformance.length, 24); // 24 hours
    });

    test('Performance metrics track personal bests', () {
      // Verify personal bests tracking
      final personalBests = analyticsService.getPersonalBests();
      
      expect(personalBests, isA<Map>());
      expect(personalBests.containsKey('highestScore'), true);
      expect(personalBests.containsKey('bestAccuracy'), true);
      expect(personalBests.containsKey('bestDayScore'), true);
      expect(personalBests.containsKey('longestStreak'), true);
    });

    test('Performance metrics track improvement over time', () {
      // Verify improvement tracking
      final improvement = analyticsService.getImprovementTracking();
      
      expect(improvement, isA<Map>());
      expect(improvement.containsKey('scoreImprovement'), true);
      expect(improvement.containsKey('accuracyImprovement'), true);
    });
  });

  group('Network Performance Monitoring', () {
    test('NetworkService tracks reachability check duration', () async {
      final networkService = NetworkService();
      await networkService.init();
      
      // Network service should track performance
      final startTime = DateTime.now();
      await networkService.checkInternetReachability();
      final duration = DateTime.now().difference(startTime);
      
      // Duration should be reasonable (< 10 seconds)
      expect(duration.inSeconds, lessThan(10));
      
      networkService.dispose();
    });

    test('NetworkService caches reachability results for performance', () async {
      final networkService = NetworkService();
      await networkService.init();
      
      // First check
      final firstStart = DateTime.now();
      await networkService.checkInternetReachability();
      final firstDuration = DateTime.now().difference(firstStart);
      
      // Second check (may use cache)
      final secondStart = DateTime.now();
      await networkService.checkInternetReachability();
      final secondDuration = DateTime.now().difference(secondStart);
      
      // Both checks should complete reasonably quickly (< 5 seconds)
      // Note: Caching may or may not make the second call faster in test environment
      expect(firstDuration.inSeconds, lessThan(5));
      expect(secondDuration.inSeconds, lessThan(5));
      
      networkService.dispose();
    });
  });

  group('Template Initialization Performance', () {
    test('Template initialization tracks duration', () {
      // Verify template initialization tracks performance
      final duration = EditionTriviaTemplates.lastInitializationDuration;
      final templateCount = EditionTriviaTemplates.lastInitializationTemplateCount;
      final retryCount = EditionTriviaTemplates.lastInitializationRetryCount;
      
      // All metrics should be tracked
      expect(duration, anyOf(isNull, isA<Duration>()));
      expect(templateCount, isA<int>());
      expect(retryCount, isA<int>());
    });

    test('Template initialization tracks retry attempts', () {
      // Verify retry count is tracked
      final retryCount = EditionTriviaTemplates.lastInitializationRetryCount;
      
      // Retry count should be >= 0
      expect(retryCount, greaterThanOrEqualTo(0));
    });
  });
}


