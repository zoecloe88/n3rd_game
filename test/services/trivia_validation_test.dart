import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/services/game_service.dart';
import 'package:n3rd_game/models/trivia_item.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('Trivia Validation Tests - Exactly 6 Words', () {
    late GameService gameService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      gameService = GameService();
    });

    tearDown(() {
      gameService.dispose();
    });

    test('Valid trivia items contain exactly 6 words and 3 correct answers', () {
      // Create a valid trivia item with exactly 6 words
      final validTrivia = TriviaItem(
        category: 'Test Category',
        words: ['Word1', 'Word2', 'Word3', 'Word4', 'Word5', 'Word6'],
        correctAnswers: ['Word1', 'Word2', 'Word3'],
        theme: 'test',
      );
      
      expect(validTrivia.words.length, equals(6));
      expect(validTrivia.correctAnswers.length, equals(3));
      final correctSet = validTrivia.correctAnswers.toSet();
      final wordSet = validTrivia.words.toSet();
      expect(wordSet.containsAll(correctSet), isTrue,
        reason: 'All correct answers must appear in the words list',);
    });

    test('GameService throws GameException for trivia with wrong word count', () {
      // Create invalid trivia items
      final invalidTrivia5 = TriviaItem(
        category: 'Test',
        words: ['W1', 'W2', 'W3', 'W4', 'W5'],
        correctAnswers: ['W1', 'W2', 'W3'],
        theme: 'test',
      );
      
      final invalidTrivia7 = TriviaItem(
        category: 'Test',
        words: ['W1', 'W2', 'W3', 'W4', 'W5', 'W6', 'W7'],
        correctAnswers: ['W1', 'W2', 'W3'],
        theme: 'test',
      );
      
      // GameService should reject trivia items that don't have exactly 6 words
      // This is tested when starting a new round
      final triviaPool = [invalidTrivia5, invalidTrivia7];
      
      expect(() => gameService.startNewRound(triviaPool),
        throwsA(isA<GameException>()),
        reason: 'GameService should throw GameException for trivia items without exactly 6 words',);
    });

  });
}

