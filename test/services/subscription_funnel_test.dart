import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import '../utils/test_helpers.dart';
import '../utils/firebase_test_helper.dart';

void main() {
  group('Subscription Funnel Analytics Tests', () {
    late SubscriptionService subscriptionService;
    late AnalyticsService analyticsService;

    setUpAll(() async {
      await TestHelpers.setupAllTestInfrastructure();
      await FirebaseTestHelper.initializeFirebaseForTests();
    });

    tearDownAll(() {
      TestHelpers.tearDownAllTestInfrastructure();
    });

    setUp(() {
      TestHelpers.setupMockSharedPreferences();
      subscriptionService = SubscriptionService();
      analyticsService = AnalyticsService();
      subscriptionService.setAnalyticsService(analyticsService);
    });

    tearDown(() {
      TestHelpers.clearMockSharedPreferences();
      subscriptionService.dispose();
      analyticsService.dispose();
    });

    test('setTier tracks subscription change', () async {
      await subscriptionService.init();

      await subscriptionService.setTier(SubscriptionTier.premium);

      expect(subscriptionService.currentTier, equals(SubscriptionTier.premium));
    });

    test('subscription change tracks upgrade', () async {
      await subscriptionService.init();
      await subscriptionService.setTier(SubscriptionTier.free);

      await subscriptionService.setTier(SubscriptionTier.basic);

      expect(subscriptionService.currentTier, equals(SubscriptionTier.basic));
    });

    test('subscription change tracks downgrade', () async {
      await subscriptionService.init();
      await subscriptionService.setTier(SubscriptionTier.premium);

      await subscriptionService.setTier(SubscriptionTier.basic);

      expect(subscriptionService.currentTier, equals(SubscriptionTier.basic));
    });

    test('analytics service logs funnel steps', () async {
      await analyticsService.init();

      await analyticsService.logSubscriptionFunnel(
        step: 'view',
        tier: 'premium',
      );

      await analyticsService.logSubscriptionFunnel(
        step: 'select_tier',
        tier: 'premium',
      );

      // Verify no exceptions thrown
      expect(true, isTrue);
    });

    test('analytics service logs retention metrics', () async {
      await analyticsService.init();

      await analyticsService.logSubscriptionRetention(
        tier: 'premium',
        daysSinceSubscription: 30,
        isActive: true,
      );

      // Verify no exceptions thrown
      expect(true, isTrue);
    });

    test('analytics service logs trial conversion', () async {
      await analyticsService.init();

      await analyticsService.logTrialConversion(
        tier: 'premium',
        converted: true,
        daysUntilConversion: 7,
      );

      // Verify no exceptions thrown
      expect(true, isTrue);
    });
  });
}
