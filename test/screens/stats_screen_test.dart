import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/screens/stats_screen.dart';
import 'package:n3rd_game/services/stats_service.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import '../utils/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await TestHelpers.setupAllTestInfrastructure();
  });

  tearDownAll(() async {
    await TestHelpers.tearDownAllTestInfrastructure();
  });

  group('StatsScreen Widget Tests', () {
    late StatsService statsService;
    late SubscriptionService subscriptionService;
    late AnalyticsService analyticsService;

    setUp(() {
      TestHelpers.setupMockSharedPreferences();
      statsService = StatsService();
      subscriptionService = SubscriptionService();
      analyticsService = AnalyticsService();
    });

    tearDown(() {
      statsService.dispose();
      subscriptionService.dispose();
      analyticsService.dispose();
      TestHelpers.clearMockSharedPreferences();
    });

    testWidgets('should render stats screen', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<StatsService>.value(value: statsService),
            ChangeNotifierProvider<SubscriptionService>.value(
              value: subscriptionService,
            ),
            ChangeNotifierProvider.value(value: analyticsService),
          ],
          child: const MaterialApp(
            home: StatsScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      // Verify screen renders
      expect(find.byType(StatsScreen), findsOneWidget);
    });

    testWidgets('should display stats data', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<StatsService>.value(value: statsService),
            ChangeNotifierProvider<SubscriptionService>.value(
              value: subscriptionService,
            ),
            ChangeNotifierProvider.value(value: analyticsService),
          ],
          child: const MaterialApp(
            home: StatsScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      // Should show stats cards
      expect(find.text('Personal Stats'), findsOneWidget);
    });

    testWidgets('should show back button', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<StatsService>.value(value: statsService),
            ChangeNotifierProvider<SubscriptionService>.value(
              value: subscriptionService,
            ),
            ChangeNotifierProvider.value(value: analyticsService),
          ],
          child: const MaterialApp(
            home: StatsScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      // Should show back button
      expect(find.byIcon(Icons.arrow_back), findsWidgets);
    });
  });
}
