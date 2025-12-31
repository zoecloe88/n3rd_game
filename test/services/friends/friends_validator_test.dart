import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/services/friends/friends_validator.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/exceptions/error_codes.dart';

void main() {
  group('FriendsValidator', () {
    group('validateEmail', () {
      test('validates correct email addresses', () {
        expect(
          FriendsValidator.validateEmail('user@example.com'),
          'user@example.com',
        );
        expect(
          FriendsValidator.validateEmail('test.user@domain.co.uk'),
          'test.user@domain.co.uk',
        );
      });

      test('normalizes email to lowercase', () {
        expect(
          FriendsValidator.validateEmail('USER@EXAMPLE.COM'),
          'user@example.com',
        );
      });

      test('trims whitespace', () {
        expect(
          FriendsValidator.validateEmail('  user@example.com  '),
          'user@example.com',
        );
      });

      test('throws ValidationException for empty email', () {
        expect(
          () => FriendsValidator.validateEmail(''),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.errorCode,
              'errorCode',
              ErrorCode.validationEmptyField,
            ),
          ),
        );
      });

      test('throws ValidationException for invalid email format', () {
        expect(
          () => FriendsValidator.validateEmail('invalid'),
          throwsA(isA<ValidationException>()),
        );
        expect(
          () => FriendsValidator.validateEmail('@example.com'),
          throwsA(isA<ValidationException>()),
        );
        expect(
          () => FriendsValidator.validateEmail('user@'),
          throwsA(isA<ValidationException>()),
        );
      });

      test('throws ValidationException for email too short', () {
        expect(
          () => FriendsValidator.validateEmail('a@b.c'),
          throwsA(isA<ValidationException>()),
        );
      });
    });

    group('validatePhone', () {
      test('validates correct phone numbers', () {
        expect(
          FriendsValidator.validatePhone('1234567890'),
          '1234567890',
        );
        expect(
          FriendsValidator.validatePhone('(123) 456-7890'),
          '1234567890',
        );
        expect(
          FriendsValidator.validatePhone('123-456-7890'),
          '1234567890',
        );
      });

      test('normalizes phone numbers', () {
        expect(
          FriendsValidator.validatePhone('(123) 456-7890'),
          '1234567890',
        );
        expect(
          FriendsValidator.validatePhone('123 456 7890'),
          '1234567890',
        );
      });

      test('throws ValidationException for empty phone', () {
        expect(
          () => FriendsValidator.validatePhone(''),
          throwsA(isA<ValidationException>()),
        );
      });

      test('throws ValidationException for phone with non-digits', () {
        expect(
          () => FriendsValidator.validatePhone('123-abc-7890'),
          throwsA(isA<ValidationException>()),
        );
      });

      test('throws ValidationException for phone too short', () {
        expect(
          () => FriendsValidator.validatePhone('123'),
          throwsA(isA<ValidationException>()),
        );
      });
    });

    group('validateUserId', () {
      test('validates correct user IDs', () {
        expect(
          () => FriendsValidator.validateUserId('1234567890'),
          returnsNormally,
        );
        expect(
          () => FriendsValidator.validateUserId('a' * 50),
          returnsNormally,
        );
      });

      test('throws ValidationException for empty user ID', () {
        expect(
          () => FriendsValidator.validateUserId(''),
          throwsA(isA<ValidationException>()),
        );
      });

      test('throws ValidationException for user ID too short', () {
        expect(
          () => FriendsValidator.validateUserId('123'),
          throwsA(isA<ValidationException>()),
        );
      });
    });

    group('validateReportReason', () {
      test('validates correct report reasons', () {
        expect(
          FriendsValidator.validateReportReason('This is a valid reason'),
          'This is a valid reason',
        );
      });

      test('throws ValidationException for empty reason', () {
        expect(
          () => FriendsValidator.validateReportReason(''),
          throwsA(isA<ValidationException>()),
        );
      });

      test('throws ValidationException for reason too short', () {
        expect(
          () => FriendsValidator.validateReportReason('short'),
          throwsA(isA<ValidationException>()),
        );
      });

      test('throws ValidationException for reason too long', () {
        expect(
          () => FriendsValidator.validateReportReason('a' * 501),
          throwsA(isA<ValidationException>()),
        );
      });
    });

    group('validateDisplayName', () {
      test('validates correct display names', () {
        expect(
          FriendsValidator.validateDisplayName('John Doe'),
          'John Doe',
        );
      });

      test('throws ValidationException for empty display name', () {
        expect(
          () => FriendsValidator.validateDisplayName(''),
          throwsA(isA<ValidationException>()),
        );
      });
    });

    group('validateSearchQuery', () {
      test('validates correct search queries', () {
        expect(
          FriendsValidator.validateSearchQuery('test query'),
          'test query',
        );
      });

      test('throws ValidationException for empty query', () {
        expect(
          () => FriendsValidator.validateSearchQuery(''),
          throwsA(isA<ValidationException>()),
        );
      });

      test('throws ValidationException for query too long', () {
        expect(
          () => FriendsValidator.validateSearchQuery('a' * 101),
          throwsA(isA<ValidationException>()),
        );
      });
    });

    group('validateDifferentUsers', () {
      test('allows different user IDs', () {
        expect(
          () => FriendsValidator.validateDifferentUsers('user1', 'user2'),
          returnsNormally,
        );
      });

      test('throws ValidationException for same user IDs', () {
        expect(
          () => FriendsValidator.validateDifferentUsers('user1', 'user1'),
          throwsA(isA<ValidationException>()),
        );
      });
    });
  });
}
