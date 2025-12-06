import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('cloudFunctionUrl returns correct format', () {
      final url = AppConfig.cloudFunctionUrl;
      expect(url, contains('https://'));
      expect(url, contains('.cloudfunctions.net/'));
      expect(url, contains(AppConfig.cloudFunctionName));
    });

    test('getRetryDelay returns exponential backoff', () {
      expect(AppConfig.getRetryDelay(0), const Duration(seconds: 1));
      expect(AppConfig.getRetryDelay(1), const Duration(seconds: 2));
      expect(AppConfig.getRetryDelay(2), const Duration(seconds: 4));
      expect(AppConfig.getRetryDelay(3), const Duration(seconds: 8));
    });

    test('timeout constants are set correctly', () {
      expect(AppConfig.cloudFunctionTimeout, const Duration(seconds: 60));
      expect(AppConfig.dictionaryApiTimeout, const Duration(seconds: 15));
    });

    test('rate limiting constants are set correctly', () {
      expect(AppConfig.dailyGenerationLimit, 20);
      expect(AppConfig.maxRetries, 3);
    });

    test('input validation limits are set correctly', () {
      expect(AppConfig.minTopicLength, 2);
      expect(AppConfig.maxTopicLength, 100);
      expect(AppConfig.minTriviaCount, 1);
      expect(AppConfig.maxTriviaCount, 100);
    });

    test('cache settings are set correctly', () {
      expect(AppConfig.cacheMaxAge, const Duration(hours: 24));
    });

    test('network settings are set correctly', () {
      expect(AppConfig.enforceHttps, true);
    });
  });
}

