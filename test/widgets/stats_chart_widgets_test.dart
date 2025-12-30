import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/widgets/stats_chart_widgets.dart';
import 'package:n3rd_game/services/stats_service.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import '../utils/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await TestHelpers.setupAllTestInfrastructure();
  });

  tearDownAll(() {
    TestHelpers.tearDownAllTestInfrastructure();
  });

  group('ScoreTrendChart', () {
    late AnalyticsService analyticsService;

    setUp(() {
      TestHelpers.setupMockSharedPreferences();
      analyticsService = AnalyticsService();
    });

    tearDown(() {
      analyticsService.dispose();
      TestHelpers.clearMockSharedPreferences();
    });

    testWidgets('displays empty state when no data available', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: analyticsService),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ScoreTrendChart(
                dailyStats: [],
              ),
            ),
          ),
        ),
      );

      expect(find.text('No score data available'), findsOneWidget);
    });

    testWidgets('renders chart when data is provided', (tester) async {
      final stats = [
        DailyStats(
          date: DateTime.now(),
          score: 100,
        ),
        DailyStats(
          date: DateTime.now().add(const Duration(days: 1)),
          score: 150,
        ),
      ];

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: analyticsService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ScoreTrendChart(
                dailyStats: stats,
              ),
            ),
          ),
        ),
      );

      // Chart should render (exact widget tree may vary)
      expect(find.byType(ScoreTrendChart), findsOneWidget);
    });

    testWidgets('handles rendering errors gracefully', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: analyticsService),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ScoreTrendChart(
                dailyStats: [],
                daysToShow: -1, // Invalid value
              ),
            ),
          ),
        ),
      );

      // Should show empty state or error state
      expect(find.byType(ScoreTrendChart), findsOneWidget);
    });
  });

  group('AccuracyTrendChart', () {
    late AnalyticsService analyticsService;

    setUp(() {
      TestHelpers.setupMockSharedPreferences();
      analyticsService = AnalyticsService();
    });

    tearDown(() {
      analyticsService.dispose();
      TestHelpers.clearMockSharedPreferences();
    });

    testWidgets('displays empty state when no data available', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: analyticsService),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AccuracyTrendChart(
                dailyStats: [],
              ),
            ),
          ),
        ),
      );

      expect(find.text('No accuracy data available'), findsOneWidget);
    });

    testWidgets('renders chart when data is provided', (tester) async {
      final stats = [
        DailyStats(
          date: DateTime.now(),
          correctAnswers: 8,
          wrongAnswers: 2,
        ),
        DailyStats(
          date: DateTime.now().add(const Duration(days: 1)),
          correctAnswers: 9,
          wrongAnswers: 1,
        ),
      ];

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: analyticsService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AccuracyTrendChart(
                dailyStats: stats,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AccuracyTrendChart), findsOneWidget);
    });
  });
}
