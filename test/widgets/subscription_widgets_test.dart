import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/widgets/subscription_tier_indicator.dart';
import 'package:n3rd_game/widgets/subscription_badge.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/services/analytics_service.dart';

void main() {
  group('SubscriptionTierIndicator', () {
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

    testWidgets('renders tier indicator', (tester) async {
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
            home: Scaffold(
              body: SubscriptionTierIndicator(),
            ),
          ),
        ),
      );

      expect(find.byType(SubscriptionTierIndicator), findsOneWidget);
    });

    testWidgets('renders compact variant', (tester) async {
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
            home: Scaffold(
              body: SubscriptionTierIndicator(
                compact: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(SubscriptionTierIndicator), findsOneWidget);
    });

    testWidgets('hides icon when showIcon is false', (tester) async {
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
            home: Scaffold(
              body: SubscriptionTierIndicator(
                showIcon: false,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(SubscriptionTierIndicator), findsOneWidget);
    });
  });

  group('SubscriptionBadge', () {
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

    testWidgets('renders subscription badge', (tester) async {
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
            home: Scaffold(
              body: SubscriptionBadge(),
            ),
          ),
        ),
      );

      expect(find.byType(SubscriptionBadge), findsOneWidget);
    });

    testWidgets('hides upgrade button when showUpgradeButton is false',
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
            home: Scaffold(
              body: SubscriptionBadge(
                showUpgradeButton: false,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(SubscriptionBadge), findsOneWidget);
    });
  });
}
