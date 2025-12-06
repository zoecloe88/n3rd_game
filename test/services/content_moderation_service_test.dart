import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/services/content_moderation_service.dart';

void main() {
  group('ContentModerationService', () {
    final service = ContentModerationService();

    test('should detect profanity in content', () {
      expect(service.containsProfanity('This is a test'), false);
      expect(service.containsProfanity('This is a damn test'), true);
      expect(service.containsProfanity('This is a DAMN test'), true); // Case insensitive
    });

    test('should sanitize profanity', () {
      final sanitized = service.sanitize('This is a damn test');
      expect(sanitized.contains('damn'), false);
      expect(sanitized.contains('****'), true); // Should be replaced with asterisks
    });

    test('should validate content length', () {
      expect(service.validateContent(''), isNotNull); // Empty should fail
      expect(service.validateContent('ab'), isNotNull); // Too short
      expect(service.validateContent('abc'), isNull); // Valid minimum
      expect(service.validateContent('a' * 501), isNotNull); // Too long
    });

    test('should detect spam patterns', () {
      // Excessive repetition
      expect(service.validateContent('aaaaaa'), isNotNull);
      expect(service.validateContent('test test test'), isNotNull);
      
      // Normal content
      expect(service.validateContent('This is a normal message'), isNull);
    });

    test('should validate trivia content', () {
      final validTrivia = service.validateTriviaContent(
        category: 'Science: Chemistry',
        question: 'What is the chemical symbol for water?',
        words: ['H2O', 'CO2', 'NaCl', 'O2', 'H2SO4', 'CH4'],
        correctAnswers: ['H2O', 'CO2', 'NaCl'],
      );
      expect(validTrivia, isNull); // Should be valid
    });

    test('should reject invalid trivia content', () {
      // Wrong number of words
      final invalid1 = service.validateTriviaContent(
        category: 'Science',
        question: 'What is water?',
        words: ['H2O', 'CO2'], // Only 2 words, should be 6
        correctAnswers: ['H2O'],
      );
      expect(invalid1, isNotNull);
      
      // Answer not in words list
      final invalid2 = service.validateTriviaContent(
        category: 'Science',
        question: 'What is water?',
        words: ['H2O', 'CO2', 'NaCl', 'O2', 'H2SO4', 'CH4'],
        correctAnswers: ['H2O', 'Invalid'], // 'Invalid' not in words
      );
      expect(invalid2, isNotNull);
    });

    test('should detect script injection attempts', () {
      // Test script injection detection via validateContent
      final scriptContent = '<script>alert("xss")</script>';
      expect(service.validateContent(scriptContent), isNotNull);
      
      // Test javascript: protocol
      final jsContent = 'javascript:alert("xss")';
      expect(service.validateContent(jsContent), isNotNull);
    });

    test('should detect suspicious URLs', () {
      // Test URL detection via validateContent
      final urlContent = 'Check out https://example.com';
      expect(service.validateContent(urlContent), isNotNull);
      
      // Normal content without URLs should pass
      expect(service.validateContent('This is normal text'), isNull);
    });
  });
}

