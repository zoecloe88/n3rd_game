import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/utils/trivia_validator.dart';
import 'package:n3rd_game/models/trivia_item.dart';
import 'package:n3rd_game/models/difficulty_level.dart';

void main() {
  group('TriviaValidator', () {
    test('should validate correct trivia item', () {
      // Arrange
      final item = TriviaItem(
        category: 'Science: What is the chemical symbol for water?',
        words: ['H2O', 'CO2', 'NaCl', 'O2', 'H2SO4', 'CH4'],
        correctAnswers: ['H2O', 'CO2', 'NaCl'],
      );

      // Act
      final result = TriviaValidator.validateTriviaItem(item);

      // Assert
      expect(result, isNull);
    });

    test('should reject trivia item with empty category', () {
      // Arrange
      final item = TriviaItem(
        category: '',
        words: ['word1', 'word2', 'word3', 'word4', 'word5', 'word6'],
        correctAnswers: ['word1', 'word2', 'word3'],
      );

      // Act
      final result = TriviaValidator.validateTriviaItem(item);

      // Assert
      expect(result, isNotNull);
      expect(result, contains('Category cannot be empty'));
    });

    test('should reject trivia item with wrong number of words', () {
      // Arrange
      final item = TriviaItem(
        category: 'Science',
        words: ['word1', 'word2', 'word3'], // Only 3 words, should be 6
        correctAnswers: ['word1', 'word2', 'word3'],
      );

      // Act
      final result = TriviaValidator.validateTriviaItem(item);

      // Assert
      expect(result, isNotNull);
      expect(result, contains('exactly 6 words'));
    });

    test('should reject trivia item with wrong number of correct answers', () {
      // Arrange
      final item = TriviaItem(
        category: 'Science',
        words: ['word1', 'word2', 'word3', 'word4', 'word5', 'word6'],
        correctAnswers: ['word1', 'word2'], // Only 2, should be 3
      );

      // Act
      final result = TriviaValidator.validateTriviaItem(item);

      // Assert
      expect(result, isNotNull);
      expect(result, contains('exactly 3 correct answers'));
    });

    test('should reject trivia item with duplicate words', () {
      // Arrange
      final item = TriviaItem(
        category: 'Science',
        words: ['word1', 'word2', 'word3', 'word1', 'word5', 'word6'], // word1 duplicated
        correctAnswers: ['word1', 'word2', 'word3'],
      );

      // Act
      final result = TriviaValidator.validateTriviaItem(item);

      // Assert
      expect(result, isNotNull);
      expect(result, contains('Duplicate words'));
    });

    test('should reject trivia item with correct answer not in words', () {
      // Arrange
      final item = TriviaItem(
        category: 'Science',
        words: ['word1', 'word2', 'word3', 'word4', 'word5', 'word6'],
        correctAnswers: ['word1', 'word2', 'invalid'], // 'invalid' not in words
      );

      // Act
      final result = TriviaValidator.validateTriviaItem(item);

      // Assert
      expect(result, isNotNull);
      expect(result, contains('not found in words list'));
    });

    test('should check trivia quality and return warnings', () {
      // Arrange
      final item = TriviaItem(
        category: 'Short', // Very short category
        words: ['word1', 'word2', 'word3', 'word4', 'word5', 'word6'],
        correctAnswers: ['word1', 'word2', 'word3'],
      );

      // Act
      final warnings = TriviaValidator.checkTriviaQuality(item);

      // Assert
      expect(warnings, isNotEmpty);
      expect(warnings.any((w) => w.contains('short')), true);
    });
  });

  group('Content Freshness Metrics', () {
    test('should calculate freshness metrics correctly', () {
      final items = [
        TriviaItem(
          category: 'Science',
          words: ['H2O', 'CO2', 'NaCl', 'O2', 'H2SO4', 'CH4'],
          correctAnswers: ['H2O', 'CO2', 'NaCl'],
        ),
        TriviaItem(
          category: 'Geography',
          words: ['Paris', 'London', 'Berlin', 'Madrid', 'Rome', 'Vienna'],
          correctAnswers: ['Paris', 'London', 'Berlin'],
        ),
        TriviaItem(
          category: 'History',
          words: ['WWI', 'WWII', 'Cold War', 'Vietnam', 'Korea', 'Gulf'],
          correctAnswers: ['WWI', 'WWII', 'Cold War'],
        ),
      ];

      final metrics = TriviaValidator.getContentFreshnessMetrics(items);

      expect(metrics['totalItems'], 3);
      expect(metrics['uniqueCategories'], 3);
      expect(metrics['categoryDistribution'], isA<Map<String, int>>());
      expect(metrics['difficultyDistribution'], isA<Map<String, int>>());
      expect(metrics['timestamp'], isA<String>());
    });

    test('should handle empty list', () {
      final metrics = TriviaValidator.getContentFreshnessMetrics([]);

      expect(metrics['totalItems'], 0);
      expect(metrics['uniqueCategories'], 0);
      expect(metrics['averageCategoryLength'], 0.0);
    });
  });

  group('Difficulty Distribution', () {
    test('should detect balanced distribution', () {
      final items = [
        TriviaItem(
          category: 'Easy 1',
          words: ['a', 'b', 'c', 'd', 'e', 'f'],
          correctAnswers: ['a', 'b', 'c'],
          difficulty: DifficultyLevel.easy,
        ),
        TriviaItem(
          category: 'Medium 1',
          words: ['a', 'b', 'c', 'd', 'e', 'f'],
          correctAnswers: ['a', 'b', 'c'],
          difficulty: DifficultyLevel.medium,
        ),
        TriviaItem(
          category: 'Hard 1',
          words: ['a', 'b', 'c', 'd', 'e', 'f'],
          correctAnswers: ['a', 'b', 'c'],
          difficulty: DifficultyLevel.hard,
        ),
      ];

      final warnings = TriviaValidator.checkDifficultyDistribution(items);
      expect(warnings, isEmpty);
    });

    test('should detect unbalanced distribution', () {
      final items = List.generate(
        10,
        (i) => TriviaItem(
          category: 'Easy $i',
          words: ['a', 'b', 'c', 'd', 'e', 'f'],
          correctAnswers: ['a', 'b', 'c'],
        ),
      )..add(
          TriviaItem(
            category: 'Medium 1',
            words: ['a', 'b', 'c', 'd', 'e', 'f'],
            correctAnswers: ['a', 'b', 'c'],
          ),
        );

      final warnings = TriviaValidator.checkDifficultyDistribution(items);
      expect(warnings, isNotEmpty);
      expect(
        warnings.any((w) => w.contains('overrepresented')),
        true,
      );
    });

    test('should handle empty list', () {
      final warnings = TriviaValidator.checkDifficultyDistribution([]);
      expect(warnings, isNotEmpty);
      expect(warnings.first, contains('Empty trivia list'));
    });
  });
}


