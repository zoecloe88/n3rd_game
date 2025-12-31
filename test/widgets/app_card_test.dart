import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/widgets/app_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppCard', () {
    testWidgets('displays child widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppCard(
              child: Text('Card content'),
            ),
          ),
        ),
      );

      expect(find.text('Card content'), findsOneWidget);
    });

    testWidgets('elevated variant creates elevated card', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard.elevated(
              child: const Text('Elevated card'),
            ),
          ),
        ),
      );

      expect(find.text('Elevated card'), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('outlined variant creates outlined card', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard.outlined(
              child: const Text('Outlined card'),
            ),
          ),
        ),
      );

      expect(find.text('Outlined card'), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('filled variant creates filled card', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard.filled(
              child: const Text('Filled card'),
            ),
          ),
        ),
      );

      expect(find.text('Filled card'), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('calls onTap when card is tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard(
              child: const Text('Tappable card'),
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tappable card'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('applies padding when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppCard(
              padding: EdgeInsets.all(16),
              child: Text('Padded card'),
            ),
          ),
        ),
      );

      expect(find.text('Padded card'), findsOneWidget);
    });

    testWidgets('applies margin when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppCard(
              margin: EdgeInsets.all(8),
              child: Text('Margined card'),
            ),
          ),
        ),
      );

      expect(find.text('Margined card'), findsOneWidget);
    });

    testWidgets('uses custom background color when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppCard(
              backgroundColor: Colors.blue,
              child: Text('Colored card'),
            ),
          ),
        ),
      );

      expect(find.text('Colored card'), findsOneWidget);
    });
  });
}
