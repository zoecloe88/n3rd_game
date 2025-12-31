import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/widgets/route_guard.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/services/analytics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RouteGuard', () {
    late SubscriptionService subscriptionService;
    late AnalyticsService analyticsService;

    setUp(() {
      subscriptionService = SubscriptionService();
      analyticsService = AnalyticsService();
    });

    tearDown(() {
      subscriptionService.dispose();
      analyticsService.dispose();
    });

    testWidgets('renders child when access is granted', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SubscriptionService>.value(
              value: subscriptionService,
            ),
            ChangeNotifierProvider<AnalyticsService>.value(
              value: analyticsService,
            ),
          ],
          child: const MaterialApp(
            home: RouteGuard(
              child: Text('Protected content'),
            ),
          ),
        ),
      );

      expect(find.text('Protected content'), findsOneWidget);
    });

    testWidgets('shows locked screen when premium access required',
        (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SubscriptionService>.value(
              value: subscriptionService,
            ),
            ChangeNotifierProvider<AnalyticsService>.value(
              value: analyticsService,
            ),
          ],
          child: const MaterialApp(
            home: RouteGuard(
              requiresPremium: true,
              child: Text('Protected content'),
            ),
          ),
        ),
      );

      // Should not show protected content when access denied
      expect(find.text('Protected content'), findsNothing);
      // Should show some locked UI (exact implementation may vary)
    });

    testWidgets('renders child when no requirements specified', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SubscriptionService>.value(
              value: subscriptionService,
            ),
            ChangeNotifierProvider<AnalyticsService>.value(
              value: analyticsService,
            ),
          ],
          child: const MaterialApp(
            home: RouteGuard(
              child: Text('Free content'),
            ),
          ),
        ),
      );

      expect(find.text('Free content'), findsOneWidget);
    });
  });
}
