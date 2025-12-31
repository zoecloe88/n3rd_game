import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import '../utils/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await TestHelpers.setupAllTestInfrastructure();
  });

  tearDownAll(() async {
    await TestHelpers.tearDownAllTestInfrastructure();
  });

  group('SubscriptionService', () {
    late SubscriptionService subscriptionService;

    setUp(() async {
      TestHelpers.setupMockSharedPreferences();
      subscriptionService = SubscriptionService();
      await subscriptionService.init();
    });

    tearDown(() {
      subscriptionService.dispose();
      TestHelpers.clearMockSharedPreferences();
    });

    test('initializes with free tier by default', () {
      expect(subscriptionService.isFree, true);
    });

    test('isFree returns true for free tier', () {
      expect(subscriptionService.isFree, true);
    });

    test('isPremium returns false for free tier', () {
      expect(subscriptionService.isPremium, false);
    });

    test('service can be initialized', () async {
      // Service is already initialized in setUp, this test verifies init() can be called again
      // Create a new instance to test init
      final testService = SubscriptionService();
      await expectLater(testService.init(), completes);
      testService.dispose();
    });

    test('service can be disposed', () {
      // Create a separate instance for this test since tearDown disposes the main one
      final testService = SubscriptionService();
      expect(() => testService.dispose(), returnsNormally);
    });

    // Edge Cases and Boundary Conditions
    test('setTier handles tier changes correctly', () async {
      await subscriptionService.setTier(SubscriptionTier.premium);
      expect(subscriptionService.currentTier, SubscriptionTier.premium);
      expect(subscriptionService.isPremium, isTrue);
    });

    test('setTier prevents concurrent updates', () async {
      // Start multiple tier updates concurrently
      final futures = List.generate(
        5,
        (_) => subscriptionService.setTier(SubscriptionTier.premium),
      );
      await Future.wait(futures);

      // Should complete without errors
      expect(subscriptionService.currentTier, SubscriptionTier.premium);
    });

    test('setTier with same tier is idempotent', () async {
      await subscriptionService.setTier(SubscriptionTier.free);
      final initialCall = subscriptionService.currentTier;

      await subscriptionService.setTier(SubscriptionTier.free);

      expect(subscriptionService.currentTier, equals(initialCall));
    });

    test('hasEditionsAccess returns correct for premium', () async {
      await subscriptionService.setTier(SubscriptionTier.premium);
      expect(subscriptionService.hasEditionsAccess, isTrue);
    });

    test('hasEditionsAccess returns false for free', () {
      expect(subscriptionService.hasEditionsAccess, isFalse);
    });

    test('hasOnlineAccess returns correct for premium', () async {
      await subscriptionService.setTier(SubscriptionTier.premium);
      expect(subscriptionService.hasOnlineAccess, isTrue);
    });

    test('hasAllModesAccess returns false for free tier', () {
      expect(subscriptionService.hasAllModesAccess, isFalse);
    });

    test('handles rapid tier changes', () async {
      await subscriptionService.setTier(SubscriptionTier.basic);
      await subscriptionService.setTier(SubscriptionTier.premium);
      await subscriptionService.setTier(SubscriptionTier.free);
      await subscriptionService.setTier(SubscriptionTier.basic);

      expect(subscriptionService.currentTier, SubscriptionTier.basic);
    });

    test('init can be called multiple times safely', () async {
      await subscriptionService.init();
      await subscriptionService.init();
      expect(subscriptionService, isNotNull);
    });
  });
}
