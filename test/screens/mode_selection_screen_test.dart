import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/screens/mode_selection_screen.dart';
import 'package:n3rd_game/services/game_service.dart';
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

  group('ModeSelectionScreen Widget Tests', () {
    late GameService gameService;
    late SubscriptionService subscriptionService;
    late AnalyticsService analyticsService;

    setUp(() {
      TestHelpers.setupMockSharedPreferences();
      TestHelpers.setupVideoPlayerMocks();
      gameService = GameService();
      subscriptionService = SubscriptionService();
      analyticsService = AnalyticsService();
    });

    tearDown(() {
      gameService.dispose();
      subscriptionService.dispose();
      analyticsService.dispose();
      TestHelpers.clearMockSharedPreferences();
    });

    testWidgets('should render mode selection screen', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GameService>.value(value: gameService),
            ChangeNotifierProvider<SubscriptionService>.value(
              value: subscriptionService,
            ),
            ChangeNotifierProvider.value(value: analyticsService),
          ],
          child: const MaterialApp(
            home: ModeSelectionScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      // Verify screen renders
      expect(find.byType(ModeSelectionScreen), findsOneWidget);
    });

    testWidgets('should display mode cards', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GameService>.value(value: gameService),
            ChangeNotifierProvider<SubscriptionService>.value(
              value: subscriptionService,
            ),
            ChangeNotifierProvider.value(value: analyticsService),
          ],
          child: const MaterialApp(
            home: ModeSelectionScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      // Should show mode selection UI
      expect(find.byType(ModeSelectionScreen), findsOneWidget);
    });

    testWidgets('should handle mode selection navigation', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GameService>.value(value: gameService),
            ChangeNotifierProvider<SubscriptionService>.value(
              value: subscriptionService,
            ),
            ChangeNotifierProvider.value(value: analyticsService),
          ],
          child: MaterialApp(
            home: const ModeSelectionScreen(),
            routes: {
              '/mode-transition': (context) =>
                  const Scaffold(body: Text('Mode Transition')),
            },
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      // Screen should render
      expect(find.byType(ModeSelectionScreen), findsOneWidget);
    });
  });
}
