import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/services/trivia_creator_service.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import '../utils/test_helpers.dart';
import '../utils/firebase_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TriviaCreator Integration Tests', () {
    late TriviaCreatorService service;

    setUpAll(() async {
      await TestHelpers.setupAllTestInfrastructure();
      await FirebaseTestHelper.initializeFirebaseForTests();
    });

    tearDownAll(() {
      TestHelpers.tearDownAllTestInfrastructure();
    });

    setUp(() async {
      // Ensure Firebase is initialized before creating service
      await FirebaseTestHelper.initializeFirebaseForTests();
      // Verify Firebase is actually initialized
      if (!FirebaseTestHelper.isFirebaseInitialized()) {
        // If initialization failed, try again with a longer delay
        await Future.delayed(const Duration(milliseconds: 100));
        await FirebaseTestHelper.initializeFirebaseForTests();
      }
      // Small delay to ensure Firebase is fully ready
      await Future.delayed(const Duration(milliseconds: 50));
      try {
        service = TriviaCreatorService();
        await service.init();
      } catch (e) {
        // If service creation fails due to Firebase, skip the test
        // This allows the test framework to report the issue
        throw Exception('Failed to create TriviaCreatorService: $e');
      }
    });

    tearDown(() {
      service.dispose();
    });

    test('full flow: validate -> save locally', () async {
      await service.init();

      // Save locally
      await service.saveTriviaLocally(
        category: 'Test Category',
        question: 'Test Question with enough length',
        words: ['word1', 'word2', 'word3', 'word4', 'word5', 'word6'],
        correctAnswers: ['word1', 'word2', 'word3'],
      );

      // Verify no errors
      expect(service.isSaving, false);
    });

    test('handles validation errors', () async {
      await service.init();

      expect(
        () => service.saveTriviaLocally(
          category: '',
          question: 'Test',
          words: ['word1'],
          correctAnswers: ['word1'],
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
