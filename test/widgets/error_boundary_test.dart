import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/widgets/error_boundary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ErrorBoundary', () {
    testWidgets('renders child widget when no error occurs', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ErrorBoundary(
            child: Scaffold(
              body: Text('Test content'),
            ),
          ),
        ),
      );

      expect(find.text('Test content'), findsOneWidget);
    });

    testWidgets('wraps child widget correctly', (tester) async {
      const testWidget = Text('Child widget');
      await tester.pumpWidget(
        const MaterialApp(
          home: ErrorBoundary(
            child: Scaffold(
              body: testWidget,
            ),
          ),
        ),
      );

      expect(find.text('Child widget'), findsOneWidget);
    });

    testWidgets('multiple instances can coexist', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ErrorBoundary(
            child: ErrorBoundary(
              child: Scaffold(
                body: Text('Nested boundary'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Nested boundary'), findsOneWidget);
    });
  });
}
