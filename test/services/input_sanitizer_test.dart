import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/utils/input_sanitizer.dart';

void main() {
  group('InputSanitizer', () {
    test('sanitizeText removes control characters', () {
      expect(InputSanitizer.sanitizeText('hello\x00world'), 'helloworld');
      expect(InputSanitizer.sanitizeText('hello\nworld'), 'hello\nworld');
      expect(InputSanitizer.sanitizeText('hello\tworld'), 'hello\tworld');
    });

    test('sanitizeHtml removes script tags', () {
      final input = '<div>Hello</div><script>alert("xss")</script>';
      final result = InputSanitizer.sanitizeHtml(input);
      expect(result, contains('Hello'));
      expect(result, isNot(contains('script')));
      expect(result, isNot(contains('alert')));
    });

    test('sanitizeHtml removes event handlers', () {
      final input = '<div onclick="alert(\'xss\')">Click me</div>';
      final result = InputSanitizer.sanitizeHtml(input);
      expect(result, isNot(contains('onclick')));
    });

    test('escapeHtml escapes special characters', () {
      expect(InputSanitizer.escapeHtml('<div>'), '&lt;div&gt;');
      expect(InputSanitizer.escapeHtml('"hello"'), '&quot;hello&quot;');
      expect(InputSanitizer.escapeHtml("'test'"), '&#x27;test&#x27;');
    });

    test('sanitizeEmail validates and sanitizes emails', () {
      expect(InputSanitizer.sanitizeEmail('test@example.com'), 'test@example.com');
      expect(InputSanitizer.sanitizeEmail('  TEST@EXAMPLE.COM  '), 'test@example.com');
      expect(InputSanitizer.sanitizeEmail('invalid'), null);
      expect(InputSanitizer.sanitizeEmail(''), null);
    });

    test('sanitizeUrl validates URLs', () {
      // HTTPS URLs should always be allowed
      expect(InputSanitizer.sanitizeUrl('https://example.com'), 'https://example.com');
      
      // HTTP URLs should be rejected when AppConfig.enforceHttps is true
      // (AppConfig.enforceHttps is true by default for security)
      expect(InputSanitizer.sanitizeUrl('http://example.com'), null);
      
      // Invalid URLs should be rejected
      expect(InputSanitizer.sanitizeUrl('javascript:alert(1)'), null);
      expect(InputSanitizer.sanitizeUrl('invalid'), null);
    });

    test('sanitizeFileName removes dangerous characters', () {
      expect(InputSanitizer.sanitizeFileName('file<>name'), 'file__name');
      expect(InputSanitizer.sanitizeFileName('file/name'), 'file_name');
      expect(InputSanitizer.sanitizeFileName('file\\name'), 'file_name');
    });

    test('sanitizeForJson escapes JSON special characters', () {
      expect(InputSanitizer.sanitizeForJson('hello"world'), 'hello\\"world');
      expect(InputSanitizer.sanitizeForJson('hello\nworld'), 'hello\\nworld');
    });
  });
}

