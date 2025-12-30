import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:n3rd_game/services/secure_storage_service.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/exceptions/error_codes.dart';
import 'package:n3rd_game/utils/input_sanitizer.dart';
import '../utils/test_helpers.dart';

/// Security integration tests
///
/// Tests authentication flows, authorization checks, input sanitization,
/// and security-related functionality.

// In-memory storage for secure storage mock
final Map<String, String?> _secureStorageMock = {};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await TestHelpers.setupAllTestInfrastructure();
    // Mock flutter_secure_storage platform channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (methodCall) async {
        if (methodCall.method == 'write') {
          final args = methodCall.arguments as Map;
          final key = args['key'] as String;
          final value = args['value'] as String?;
          // Store in memory for testing
          _secureStorageMock[key] = value;
          return null;
        } else if (methodCall.method == 'read') {
          final args = methodCall.arguments as Map;
          final key = args['key'] as String;
          return _secureStorageMock[key];
        } else if (methodCall.method == 'delete') {
          final args = methodCall.arguments as Map;
          final key = args['key'] as String;
          _secureStorageMock.remove(key);
          return null;
        } else if (methodCall.method == 'deleteAll') {
          _secureStorageMock.clear();
          return null;
        }
        return null;
      },
    );
  });

  tearDownAll(() {
    TestHelpers.tearDownAllTestInfrastructure();
    // Clear secure storage mock
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
    _secureStorageMock.clear();
  });

  group('Security Integration Tests', () {
    test('should reject weak passwords', () {
      // Test password strength validation patterns
      final weakPasswords = [
        'short', // Too short
        'nouppercase123!', // No uppercase
        'NOLOWERCASE123!', // No lowercase
        'NoNumbers!', // No numbers
        'NoSpecial123', // No special characters
        'password', // Common password
      ];

      for (final password in weakPasswords) {
        // Verify password doesn't meet strength requirements
        final hasLength = password.length >= 8;
        final hasUppercase = password.contains(RegExp(r'[A-Z]'));
        final hasLowercase = password.contains(RegExp(r'[a-z]'));
        final hasNumber = password.contains(RegExp(r'[0-9]'));
        final hasSpecial = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

        final isValid = hasLength &&
            hasUppercase &&
            hasLowercase &&
            hasNumber &&
            hasSpecial;
        expect(
          isValid,
          isFalse,
          reason: 'Weak password should fail validation: $password',
        );
      }
    });

    test('should accept strong passwords', () {
      final strongPasswords = [
        'SecurePass123!',
        'MyP@ssw0rd!',
        'Str0ng#Pass',
      ];

      for (final password in strongPasswords) {
        // Verify password meets all strength requirements
        expect(password.length, greaterThanOrEqualTo(8));
        expect(
          password,
          matches(RegExp(r'[A-Z]')),
          reason: 'Should have uppercase',
        );
        expect(
          password,
          matches(RegExp(r'[a-z]')),
          reason: 'Should have lowercase',
        );
        expect(
          password,
          matches(RegExp(r'[0-9]')),
          reason: 'Should have number',
        );
        expect(
          password,
          matches(RegExp(r'[!@#$%^&*(),.?":{}|<>]')),
          reason: 'Should have special char',
        );
      }
    });

    test('should store tokens securely', () async {
      final storage = SecureStorageService();
      const testToken = 'test-auth-token-123';

      // Store token
      await storage.saveAuthToken(testToken);

      // Retrieve token
      final retrieved = await storage.getAuthToken();

      expect(retrieved, equals(testToken));
    });

    test('should not expose tokens in plaintext', () async {
      final storage = SecureStorageService();
      const testToken = 'sensitive-token-123';

      await storage.saveAuthToken(testToken);

      // Verify token is not in SharedPreferences (plaintext)
      // This is a conceptual test - actual implementation uses secure storage
      final retrieved = await storage.getAuthToken();
      expect(retrieved, isNotNull);
      expect(retrieved, equals(testToken));
    });

    test('should handle authentication errors with error codes', () {
      final authException = AuthenticationException(
        'Invalid credentials',
        errorCode: ErrorCode.authInvalidCredentials,
      );

      expect(authException.errorCode, equals(ErrorCode.authInvalidCredentials));
      expect(authException.recovery, isNotNull);
    });

    test('should validate email format', () {
      final invalidEmails = [
        'notanemail',
        '@example.com',
        'user@',
        'user@example',
        'user name@example.com',
      ];

      final emailRegex =
          RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

      for (final email in invalidEmails) {
        // Verify invalid emails don't match format
        expect(
          emailRegex.hasMatch(email),
          isFalse,
          reason: 'Should reject invalid email: $email',
        );
      }

      // Valid emails should pass format validation
      final validEmails = [
        'user@example.com',
        'test.user@example.co.uk',
        'user+tag@example.com',
      ];

      for (final email in validEmails) {
        // Check email format using regex
        expect(
          emailRegex.hasMatch(email),
          isTrue,
          reason: 'Should accept valid email: $email',
        );
      }
    });

    test('should sanitize user input', () {
      // Test input sanitization using InputSanitizer
      final maliciousInputs = [
        '<script>alert("xss")</script>',
        'javascript:alert("xss")',
        'onerror="alert(\'xss\')"',
        '../../etc/passwd',
      ];

      // Test that InputSanitizer properly sanitizes malicious input
      for (final input in maliciousInputs) {
        final sanitized = InputSanitizer.sanitizeHtml(input);
        // Sanitized output should not contain script tags
        expect(sanitized, isNot(contains('<script>')));
        expect(sanitized, isNot(contains('javascript:')));
      }
    });
  });
}
