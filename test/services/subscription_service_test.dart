import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/services/subscription_service.dart';

void main() {
  group('SubscriptionService', () {
    late SubscriptionService subscriptionService;

    setUp(() async {
      subscriptionService = SubscriptionService();
      await subscriptionService.init();
    });

    tearDown(() {
      subscriptionService.dispose();
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
      expect(() => subscriptionService.init(), returnsNormally);
    });

    test('service can be disposed', () {
      expect(() => subscriptionService.dispose(), returnsNormally);
    });
  });
}

