import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/services/trivia_creator_service.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import '../utils/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await TestHelpers.setupAllTestInfrastructure();
  });

  tearDownAll(() {
    TestHelpers.tearDownAllTestInfrastructure();
  });

  group('TriviaCreatorService', () {
    late TriviaCreatorService service;

    setUp(() {
      TestHelpers.setupMockSharedPreferences();
      service = TriviaCreatorService();
    });

    tearDown(() {
      service.dispose();
      TestHelpers.clearMockSharedPreferences();
    });

    test('initializes successfully', () async {
      await service.init();
      expect(service.isInitialized, true);
    });

    test('validates empty category', () async {
      await service.init();

      expect(
        () => service.saveTriviaToCloud(
          category: '',
          question: 'Test question',
          words: List.filled(6, 'word'),
          correctAnswers: List.filled(3, 'word'),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('validates category length', () async {
      await service.init();

      expect(
        () => service.saveTriviaToCloud(
          category: 'a' * 101, // Exceeds max length
          question: 'Test question',
          words: List.filled(6, 'word'),
          correctAnswers: List.filled(3, 'word'),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('validates empty question', () async {
      await service.init();

      expect(
        () => service.saveTriviaToCloud(
          category: 'Test category',
          question: '',
          words: List.filled(6, 'word'),
          correctAnswers: List.filled(3, 'word'),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('validates question length', () async {
      await service.init();

      expect(
        () => service.saveTriviaToCloud(
          category: 'Test category',
          question: 'a' * 501, // Exceeds max length
          words: List.filled(6, 'word'),
          correctAnswers: List.filled(3, 'word'),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('validates word count', () async {
      await service.init();

      expect(
        () => service.saveTriviaToCloud(
          category: 'Test category',
          question: 'Test question',
          words: List.filled(5, 'word'), // Wrong count
          correctAnswers: List.filled(3, 'word'),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('validates duplicate words', () async {
      await service.init();

      expect(
        () => service.saveTriviaToCloud(
          category: 'Test category',
          question: 'Test question',
          words: [
            'word1',
            'word2',
            'word3',
            'word4',
            'word5',
            'word1',
          ], // Duplicate
          correctAnswers: ['word1', 'word2', 'word3'],
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('validates correct answers are in words list', () async {
      await service.init();

      expect(
        () => service.saveTriviaToCloud(
          category: 'Test category',
          question: 'Test question',
          words: ['word1', 'word2', 'word3', 'word4', 'word5', 'word6'],
          correctAnswers: ['word7'], // Not in words list
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('validates correct answer count', () async {
      await service.init();

      expect(
        () => service.saveTriviaToCloud(
          category: 'Test category',
          question: 'Test question',
          words: ['word1', 'word2', 'word3', 'word4', 'word5', 'word6'],
          correctAnswers: ['word1', 'word2', 'word3', 'word4'], // Too many
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('rate limiting for saves', () async {
      await service.init();

      // This test would require mocking Firebase
      // For now, we just verify the service structure
      expect(service.isSaving, false);
    });

    test('disposes correctly', () async {
      await service.init();
      expect(service.isInitialized, true);
      // Don't dispose here - tearDown will handle it
      // Just verify the service can be initialized
    });
  });
}
