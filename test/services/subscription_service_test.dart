import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:n3rd_game/services/subscription_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SubscriptionService', () {
    late SubscriptionService subscriptionService;

    setUp(() async {
      // Mock SharedPreferences for testing
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/shared_preferences'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'getAll') {
            return <String, dynamic>{}; // Return empty map
          }
          return null;
        },
      );

      subscriptionService = SubscriptionService();
      await subscriptionService.init();
    });

    tearDown(() {
      subscriptionService.dispose();
      // Clear mock handler
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/shared_preferences'),
        null,
      );
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
  });
}

