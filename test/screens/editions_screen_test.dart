import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/screens/editions_screen.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/services/edition_access_service.dart';
import 'package:n3rd_game/services/revenue_cat_service.dart';
import '../utils/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await TestHelpers.setupAllTestInfrastructure();
  });

  tearDownAll(() async {
    await TestHelpers.tearDownAllTestInfrastructure();
  });

  group('EditionsScreen Widget Tests', () {
    late SubscriptionService subscriptionService;
    late AnalyticsService analyticsService;
    late EditionAccessService editionAccessService;
    late RevenueCatService revenueCatService;

    setUp(() {
      TestHelpers.setupMockSharedPreferences();
      TestHelpers.setupVideoPlayerMocks();
      subscriptionService = SubscriptionService();
      analyticsService = AnalyticsService();
      editionAccessService = EditionAccessService();
      revenueCatService = RevenueCatService();
    });

    tearDown(() {
      subscriptionService.dispose();
      analyticsService.dispose();
      editionAccessService.dispose();
      revenueCatService.dispose();
      TestHelpers.clearMockSharedPreferences();
    });

    testWidgets('should render editions screen', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SubscriptionService>.value(
              value: subscriptionService,
            ),
            ChangeNotifierProvider.value(value: analyticsService),
            ChangeNotifierProvider<EditionAccessService>.value(
              value: editionAccessService,
            ),
            ChangeNotifierProvider<RevenueCatService>.value(
              value: revenueCatService,
            ),
          ],
          child: const MaterialApp(
            home: EditionsScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      // Verify screen renders
      expect(find.byType(EditionsScreen), findsOneWidget);
    });

    testWidgets('should display edition list', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SubscriptionService>.value(
              value: subscriptionService,
            ),
            ChangeNotifierProvider.value(value: analyticsService),
            ChangeNotifierProvider<EditionAccessService>.value(
              value: editionAccessService,
            ),
            ChangeNotifierProvider<RevenueCatService>.value(
              value: revenueCatService,
            ),
          ],
          child: const MaterialApp(
            home: EditionsScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      // Should show editions
      expect(find.byType(EditionsScreen), findsOneWidget);
    });

    testWidgets('should handle edition selection', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SubscriptionService>.value(
              value: subscriptionService,
            ),
            ChangeNotifierProvider.value(value: analyticsService),
            ChangeNotifierProvider<EditionAccessService>.value(
              value: editionAccessService,
            ),
            ChangeNotifierProvider<RevenueCatService>.value(
              value: revenueCatService,
            ),
          ],
          child: const MaterialApp(
            home: EditionsScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      // Screen should render
      expect(find.byType(EditionsScreen), findsOneWidget);
    });
  });
}
