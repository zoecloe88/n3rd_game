import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/widgets/upgrade_dialog.dart';
import 'package:n3rd_game/services/analytics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UpgradeDialog', () {
    late AnalyticsService analyticsService;

    setUp(() {
      analyticsService = AnalyticsService();
    });

    tearDown(() {
      analyticsService.dispose();
    });

    testWidgets('displays dialog with title and message', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AnalyticsService>.value(
              value: analyticsService,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const UpgradeDialog(
                        title: 'Upgrade Required',
                        message: 'Upgrade to premium for this feature',
                        targetTier: 'premium',
                        source: 'test',
                        features: ['Feature 1', 'Feature 2'],
                      ),
                    );
                  },
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pump();

      expect(find.text('Upgrade Required'), findsOneWidget);
      expect(find.text('Upgrade to premium for this feature'), findsOneWidget);
    });

    testWidgets('displays features list when provided', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AnalyticsService>.value(
              value: analyticsService,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const UpgradeDialog(
                        title: 'Upgrade',
                        message: 'Message',
                        targetTier: 'premium',
                        source: 'test',
                        features: ['Feature 1', 'Feature 2', 'Feature 3'],
                      ),
                    );
                  },
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pump();

      expect(find.text('Feature 1'), findsOneWidget);
      expect(find.text('Feature 2'), findsOneWidget);
      expect(find.text('Feature 3'), findsOneWidget);
    });
  });
}
