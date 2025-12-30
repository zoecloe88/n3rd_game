import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/widgets/error_recovery_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ErrorRecoveryWidget', () {
    testWidgets('displays error message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorRecoveryWidget(
              message: 'Test error message',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Test error message'), findsOneWidget);
    });

    testWidgets('displays title when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorRecoveryWidget(
              title: 'Error Title',
              message: 'Test error message',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Error Title'), findsOneWidget);
      expect(find.text('Test error message'), findsOneWidget);
    });

    testWidgets('shows retry button when onRetry provided', (tester) async {
      bool retryCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorRecoveryWidget(
              message: 'Test error',
              onRetry: () {
                retryCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(retryCalled, true);
    });

    testWidgets('hides retry button when showRetryButton is false',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorRecoveryWidget(
              message: 'Test error',
              onRetry: () {},
              showRetryButton: false,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Retry'), findsNothing);
    });
  });
}
