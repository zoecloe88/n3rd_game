import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/widgets/heat_map_widget.dart';
import 'package:n3rd_game/models/performance_metric.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HeatMapWidget', () {
    testWidgets('renders widget when data is provided', (tester) async {
      final data = [
        TimeOfDayPerformance(
          hour: 10,
          totalGames: 5,
          averageScore: 100,
          averageAccuracy: 0.8,
        ),
        TimeOfDayPerformance(
          hour: 14,
          totalGames: 3,
          averageScore: 150,
          averageAccuracy: 0.9,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HeatMapWidget(
              timeOfDayData: data,
            ),
          ),
        ),
      );

      expect(find.byType(HeatMapWidget), findsOneWidget);
    });

    testWidgets('handles empty data gracefully', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HeatMapWidget(
              timeOfDayData: [],
            ),
          ),
        ),
      );

      expect(find.byType(HeatMapWidget), findsOneWidget);
      expect(find.text('No time-of-day data available'), findsOneWidget);
    });
  });
}
