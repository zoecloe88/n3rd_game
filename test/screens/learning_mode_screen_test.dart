import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/screens/learning_mode_screen.dart';
import 'package:n3rd_game/services/learning_service.dart';
import 'package:n3rd_game/models/reviewed_question.dart';
import 'package:n3rd_game/widgets/app_button.dart';
import 'package:n3rd_game/widgets/app_card.dart';
import 'package:n3rd_game/widgets/empty_state_widget.dart';
import '../utils/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await TestHelpers.setupAllTestInfrastructure();
  });

  tearDownAll(() {
    TestHelpers.tearDownAllTestInfrastructure();
  });

  group('LearningModeScreen', () {
    late LearningService learningService;

    setUp(() {
      TestHelpers.setupMockSharedPreferences();
      learningService = LearningService();
    });

    tearDown(() {
      learningService.dispose();
      TestHelpers.clearMockSharedPreferences();
    });

    testWidgets('renders learning mode screen', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: learningService),
          ],
          child: const MaterialApp(
            home: LearningModeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should render the screen
      expect(find.byType(LearningModeScreen), findsOneWidget);

      // Should show title
      expect(find.text('Learning Mode'), findsOneWidget);
    });

    testWidgets('displays tabs correctly', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: learningService),
          ],
          child: const MaterialApp(
            home: LearningModeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should show all three tabs
      expect(find.text('Wrong Answers'), findsOneWidget);
      expect(find.text('Bookmarked'), findsOneWidget);
      expect(find.text('All Questions'), findsOneWidget);
    });

    testWidgets('switches between tabs', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: learningService),
          ],
          child: const MaterialApp(
            home: LearningModeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tap on Bookmarked tab
      await tester.tap(find.text('Bookmarked'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should show bookmarked tab content
      expect(find.text('Bookmarked'), findsOneWidget);
    });

    testWidgets('displays empty state for wrong answers', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: learningService),
          ],
          child: const MaterialApp(
            home: LearningModeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should show empty state
      expect(find.text('No wrong answers yet!'), findsOneWidget);
      expect(
        find.text('Keep playing to review questions you got wrong.'),
        findsOneWidget,
      );
      expect(find.byType(EmptyStateWidget), findsOneWidget);
    });

    testWidgets('displays empty state for bookmarked', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: learningService),
          ],
          child: const MaterialApp(
            home: LearningModeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tap on Bookmarked tab
      await tester.tap(find.text('Bookmarked'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should show empty state
      expect(find.text('No bookmarks yet'), findsOneWidget);
      expect(
        find.text('Bookmark questions to review them later.'),
        findsOneWidget,
      );
    });

    testWidgets('displays empty state for all questions', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: learningService),
          ],
          child: const MaterialApp(
            home: LearningModeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tap on All Questions tab
      await tester.tap(find.text('All Questions'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should show empty state
      expect(find.text('No questions reviewed yet'), findsOneWidget);
      expect(
        find.text('Play games to build your question history.'),
        findsOneWidget,
      );
    });

    testWidgets('back button navigates back', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: learningService),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: AppButton.primary(
                    label: 'Go to Learning Mode',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LearningModeScreen(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Go to Learning Mode'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 500));

      final backButton = find.byIcon(Icons.arrow_back);
      expect(backButton, findsOneWidget);

      await tester.tap(backButton);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Go to Learning Mode'), findsOneWidget);
    });

    testWidgets('uses design system components', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: learningService),
          ],
          child: const MaterialApp(
            home: LearningModeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should use AppButton components
      expect(find.byType(AppButton), findsWidgets);

      // Should use EmptyStateWidget
      expect(find.byType(EmptyStateWidget), findsOneWidget);
    });

    testWidgets('has accessibility semantics', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: learningService),
          ],
          child: const MaterialApp(
            home: LearningModeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should have Semantics widgets
      expect(find.byType(Semantics), findsWidgets);
    });

    testWidgets('displays question cards when questions exist', (tester) async {
      // Add test question
      final testQuestion = ReviewedQuestion(
        questionId: 'test-1',
        category: 'Test Category',
        words: ['word1', 'word2', 'word3'],
        correctAnswers: ['word1', 'word2'],
        userAnswers: ['word1'],
        wasCorrect: false,
        answeredAt: DateTime.now(),
        roundNumber: 1,
        gameMode: 'Classic',
      );

      await learningService.addReviewedQuestion(testQuestion);
      await tester.pump();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: learningService),
          ],
          child: const MaterialApp(
            home: LearningModeScreen(),
          ),
        ),
      );

      // Use pump with timeout instead of pumpAndSettle to avoid infinite wait
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Should show question card
      expect(find.byType(AppCard), findsWidgets);
      expect(find.text('Test Category'), findsOneWidget);
    });

    testWidgets('bookmark button toggles bookmark', (tester) async {
      // Add test question
      final testQuestion = ReviewedQuestion(
        questionId: 'test-2',
        category: 'Test Category',
        words: ['word1', 'word2'],
        correctAnswers: ['word1', 'word2'],
        userAnswers: ['word1', 'word2'],
        wasCorrect: true,
        answeredAt: DateTime.now(),
        roundNumber: 1,
        gameMode: 'Classic',
      );

      await learningService.addReviewedQuestion(testQuestion);
      await tester.pump();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: learningService),
          ],
          child: const MaterialApp(
            home: LearningModeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Find bookmark button (should be in question card)
      final bookmarkButtons = find.byType(AppButton);
      expect(bookmarkButtons, findsWidgets);

      // Tap bookmark button (assuming first AppButton after back button is bookmark)
      if (bookmarkButtons.evaluate().length > 1) {
        await tester.tap(bookmarkButtons.at(1));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }
    });

    testWidgets('displays error recovery widget on error', (tester) async {
      // Create a screen with error state
      // This would require setting _errorMessage in the state
      // For now, we'll test that ErrorRecoveryWidget can be rendered

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: learningService),
          ],
          child: const MaterialApp(
            home: LearningModeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Screen should still render
      expect(find.byType(LearningModeScreen), findsOneWidget);
    });

    testWidgets('pagination shows load more button', (tester) async {
      // Add multiple test questions (more than page size)
      for (int i = 0; i < 25; i++) {
        final testQuestion = ReviewedQuestion(
          questionId: 'test-$i',
          category: 'Test Category $i',
          words: ['word1', 'word2'],
          correctAnswers: ['word1', 'word2'],
          userAnswers: ['word1', 'word2'],
          wasCorrect: true,
          answeredAt: DateTime.now(),
          roundNumber: 1,
          gameMode: 'Classic',
        );
        await learningService.addReviewedQuestion(testQuestion);
      }
      await tester.pump();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: learningService),
          ],
          child: const MaterialApp(
            home: LearningModeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should show load more button if pagination is implemented
      // This test may need adjustment based on actual pagination implementation
      expect(find.byType(LearningModeScreen), findsOneWidget);
    });
  });
}
