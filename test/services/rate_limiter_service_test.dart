import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/services/rate_limiter_service.dart';
import '../utils/test_helpers.dart';

void main() {
  TestHelpers.ensureInitialized();

  group('RateLimiterService', () {
    late RateLimiterService service;

    setUpAll(() {
      TestHelpers.setupMockSharedPreferences();
    });

    setUp(() {
      service = RateLimiterService();
    });

    tearDown(() {
      // RateLimiterService doesn't have dispose method
      // No cleanup needed
    });

    tearDownAll(() {
      TestHelpers.clearMockSharedPreferences();
    });

    test('allows first request', () async {
      final isAllowed = await service.isAllowed(
        'test_key',
        maxAttempts: 5,
        window: const Duration(seconds: 60),
      );
      expect(isAllowed, true);
    });

    test('respects max attempts', () async {
      const key = 'test_key';
      const maxAttempts = 3;
      const window = Duration(seconds: 60);

      // Reset first to ensure clean state
      await service.reset(key);

      // Make max attempts (should all be allowed)
      for (int i = 0; i < maxAttempts; i++) {
        final isAllowed = await service.isAllowed(
          key,
          maxAttempts: maxAttempts,
          window: window,
        );
        expect(isAllowed, true, reason: 'Attempt ${i + 1} should be allowed');
      }

      // Next attempt should be blocked (we've used all maxAttempts)
      final isBlocked = await service.isAllowed(
        key,
        maxAttempts: maxAttempts,
        window: window,
      );
      expect(isBlocked, false, reason: 'Should be blocked after maxAttempts');
    });

    test('different keys are independent', () async {
      const maxAttempts = 2;
      const window = Duration(seconds: 60);

      // Use up attempts for key1
      await service.isAllowed('key1', maxAttempts: maxAttempts, window: window);
      await service.isAllowed('key1', maxAttempts: maxAttempts, window: window);

      // key1 should be blocked
      expect(
        await service.isAllowed('key1', maxAttempts: maxAttempts, window: window),
        false,
      );

      // key2 should still be allowed
      expect(
        await service.isAllowed('key2', maxAttempts: maxAttempts, window: window),
        true,
      );
    });

    test('service can reset rate limits', () async {
      const key = 'test_reset';
      await service.isAllowed(key, maxAttempts: 2, window: const Duration(seconds: 60));
      await service.reset(key);
      // After reset, should be allowed again
      final isAllowed = await service.isAllowed(key, maxAttempts: 2, window: const Duration(seconds: 60));
      expect(isAllowed, true);
    });
  });
}

