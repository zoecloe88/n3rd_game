import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/services/trivia_generator_service.dart';
import 'package:n3rd_game/models/trivia_item.dart';
import 'package:n3rd_game/models/difficulty_level.dart';

void main() {
  group('TriviaGeneratorService', () {
    late TriviaGeneratorService triviaService;

    setUp(() {
      triviaService = TriviaGeneratorService();
    });

    tearDown(() {
      triviaService.dispose();
    });

    test('can generate trivia item', () {
      final item = TriviaItem(
        category: 'Test Category',
        words: ['word1', 'word2', 'word3', 'word4', 'word5', 'word6'],
        correctAnswers: ['word1', 'word2', 'word3'],
        difficulty: DifficultyLevel.medium,
      );

      expect(item.category, 'Test Category');
      expect(item.words.length, 6);
      expect(item.correctAnswers.length, 3);
    });

    test('trivia item can be created with minimum required fields', () {
      final item = TriviaItem(
        category: 'Test Category',
        words: ['word1'],
        correctAnswers: ['word1'],
      );
      expect(item.category, 'Test Category');
      expect(item.words.isNotEmpty, true);
      expect(item.correctAnswers.isNotEmpty, true);
    });

    test('trivia item supports optional difficulty', () {
      final item = TriviaItem(
        category: 'Test',
        words: ['word1', 'word2'],
        correctAnswers: ['word1'],
        difficulty: DifficultyLevel.hard,
      );
      expect(item.difficulty, DifficultyLevel.hard);
    });

    test('trivia item supports optional theme', () {
      final item = TriviaItem(
        category: 'Test',
        words: ['word1', 'word2'],
        correctAnswers: ['word1'],
        theme: 'science',
      );
      expect(item.theme, 'science');
    });
  });
}

