import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/widgets/standardized_loading_widget.dart';

void main() {
  group('StandardizedLoadingWidget', () {
    testWidgets('displays loading indicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StandardizedLoadingWidget(),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays message when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StandardizedLoadingWidget(
              message: 'Loading...',
            ),
          ),
        ),
      );

      expect(find.text('Loading...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('uses custom color when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StandardizedLoadingWidget(
              color: Colors.red,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('uses custom size when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StandardizedLoadingWidget(
              size: 64.0,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}

