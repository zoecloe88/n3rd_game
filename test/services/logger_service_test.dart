import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/services/logger_service.dart';

void main() {
  group('LoggerService', () {
    test('can log debug messages', () {
      expect(() => LoggerService.debug('Test debug message'), returnsNormally);
    });

    test('can log info messages', () {
      expect(() => LoggerService.info('Test info message'), returnsNormally);
    });

    test('can log warning messages', () {
      expect(() => LoggerService.warning('Test warning message'), returnsNormally);
    });

    test('can log error messages', () {
      expect(() => LoggerService.error('Test error message'), returnsNormally);
    });

    test('can log errors with exception', () {
      expect(
        () => LoggerService.error(
          'Test error',
          error: Exception('Test exception'),
        ),
        returnsNormally,
      );
    });

    test('can log errors with stack trace', () {
      expect(
        () => LoggerService.error(
          'Test error',
          error: Exception('Test exception'),
          stack: StackTrace.current,
        ),
        returnsNormally,
      );
    });
  });
}








