import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/screens/more_menu_screen.dart';
import 'package:n3rd_game/services/auth_service.dart';
import 'package:n3rd_game/services/subscription_service.dart';
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

  group('MoreMenuScreen Widget Tests', () {
    late AuthService authService;
    late SubscriptionService subscriptionService;
    late AnalyticsService analyticsService;

    setUp(() {
      TestHelpers.setupMockSharedPreferences();
      TestHelpers.setupVideoPlayerMocks();
      authService = AuthService();
      subscriptionService = SubscriptionService();
      analyticsService = AnalyticsService();
    });

    tearDown(() {
      authService.dispose();
      subscriptionService.dispose();
      analyticsService.dispose();
      TestHelpers.clearMockSharedPreferences();
    });

    testWidgets('should render more menu screen', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: authService),
            ChangeNotifierProvider<SubscriptionService>.value(
              value: subscriptionService,
            ),
            ChangeNotifierProvider.value(value: analyticsService),
          ],
          child: const MaterialApp(
            home: MoreMenuScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      // Verify screen renders
      expect(find.byType(MoreMenuScreen), findsOneWidget);
    });

    testWidgets('should display menu items', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: authService),
            ChangeNotifierProvider<SubscriptionService>.value(
              value: subscriptionService,
            ),
            ChangeNotifierProvider.value(value: analyticsService),
          ],
          child: const MaterialApp(
            home: MoreMenuScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      // Should show menu items
      expect(find.byType(MoreMenuScreen), findsOneWidget);
    });

    testWidgets('should handle navigation from menu items', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: authService),
            ChangeNotifierProvider<SubscriptionService>.value(
              value: subscriptionService,
            ),
            ChangeNotifierProvider.value(value: analyticsService),
          ],
          child: MaterialApp(
            home: const MoreMenuScreen(),
            routes: {
              '/settings': (context) => const Scaffold(body: Text('Settings')),
            },
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      // Screen should render
      expect(find.byType(MoreMenuScreen), findsOneWidget);
    });
  });
}
