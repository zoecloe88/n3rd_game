import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/services/trivia/local_trivia_repository.dart';
import 'package:n3rd_game/models/trivia_item.dart';
import '../../utils/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await TestHelpers.setupAllTestInfrastructure();
  });

  tearDownAll(() {
    TestHelpers.tearDownAllTestInfrastructure();
  });

  group('LocalTriviaRepository', () {
    late LocalTriviaRepository repository;

    setUp(() {
      TestHelpers.setupMockSharedPreferences();
      repository = LocalTriviaRepository();
    });

    tearDown(() {
      TestHelpers.clearMockSharedPreferences();
    });

    test('saves local trivia successfully', () async {
      await repository.saveLocalTrivia(
        category: 'Test Category',
        question: 'Test Question',
        words: ['word1', 'word2', 'word3', 'word4', 'word5', 'word6'],
        correctAnswers: ['word1', 'word2', 'word3'],
      );

      final trivia = await repository.getLocalTrivia();
      expect(trivia.length, greaterThan(0));
      expect(trivia.first.category, 'Test Category');
      // Note: TriviaItem doesn't have a 'question' field - it uses 'category' for the question text
      // The repository stores both, but TriviaItem only exposes 'category'
    });

    test('retrieves local trivia', () async {
      await repository.saveLocalTrivia(
        category: 'Category 1',
        question: 'Question 1',
        words: ['w1', 'w2', 'w3', 'w4', 'w5', 'w6'],
        correctAnswers: ['w1', 'w2', 'w3'],
      );

      final trivia = await repository.getLocalTrivia();
      expect(trivia, isNotEmpty);
    });

    test('handles empty local trivia', () async {
      final trivia = await repository.getLocalTrivia();
      expect(trivia, isA<List<TriviaItem>>());
    });
  });
}
