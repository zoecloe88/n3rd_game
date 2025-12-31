import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/widgets/performance_chart_widget.dart';
import 'package:n3rd_game/models/performance_metric.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PerformanceChartWidget', () {
    testWidgets('renders widget when data is provided', (tester) async {
      final metrics = [
        PerformanceMetric(
          date: DateTime.now(),
          gamesPlayed: 5,
          hourOfDay: 10,
          score: 100,
          accuracy: 0.8,
        ),
        PerformanceMetric(
          date: DateTime.now().add(const Duration(days: 1)),
          gamesPlayed: 6,
          hourOfDay: 14,
          score: 150,
          accuracy: 0.9,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PerformanceChartWidget(
              metrics: metrics,
              title: 'Performance Chart',
            ),
          ),
        ),
      );

      expect(find.byType(PerformanceChartWidget), findsOneWidget);
    });

    testWidgets('handles empty data gracefully', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PerformanceChartWidget(
              metrics: [],
              title: 'Performance Chart',
            ),
          ),
        ),
      );

      expect(find.byType(PerformanceChartWidget), findsOneWidget);
      expect(find.text('No data available'), findsOneWidget);
    });
  });
}
