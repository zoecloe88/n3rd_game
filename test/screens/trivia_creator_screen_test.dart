import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/screens/trivia_creator_screen.dart';
import 'package:n3rd_game/services/trivia_creator_service.dart';
import 'package:n3rd_game/services/friends_service.dart';
import 'package:n3rd_game/services/ai_edition_service.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import '../utils/test_helpers.dart';
import '../utils/firebase_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await TestHelpers.setupAllTestInfrastructure();
    await FirebaseTestHelper.initializeFirebaseForTests();
  });

  tearDownAll(() {
    TestHelpers.tearDownAllTestInfrastructure();
  });

  group('TriviaCreatorScreen', () {
    late TriviaCreatorService triviaCreatorService;
    late FriendsService friendsService;
    late AIEditionService aiEditionService;
    late AnalyticsService analyticsService;

    setUp(() {
      TestHelpers.setupMockSharedPreferences();
      triviaCreatorService = TriviaCreatorService()..init();
      friendsService = FriendsService();
      aiEditionService = AIEditionService();
      analyticsService = AnalyticsService();
    });

    tearDown(() {
      triviaCreatorService.dispose();
      friendsService.dispose();
      aiEditionService.dispose();
      analyticsService.dispose();
      TestHelpers.clearMockSharedPreferences();
    });

    testWidgets('renders correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: triviaCreatorService),
              ChangeNotifierProvider.value(value: friendsService),
              ChangeNotifierProvider.value(value: aiEditionService),
              ChangeNotifierProvider.value(value: analyticsService),
            ],
            child: const TriviaCreatorScreen(),
          ),
        ),
      );

      expect(find.text('Create Trivia'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Question/Statement'), findsOneWidget);
    });

    testWidgets('shows all form fields', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: triviaCreatorService),
              ChangeNotifierProvider.value(value: friendsService),
              ChangeNotifierProvider.value(value: aiEditionService),
              ChangeNotifierProvider.value(value: analyticsService),
            ],
            child: const TriviaCreatorScreen(),
          ),
        ),
      );

      expect(find.text('Words (6 total)'), findsOneWidget);
      expect(find.text('Correct Answers (3)'), findsOneWidget);
      expect(find.text('Save Locally'), findsOneWidget);
      expect(find.text('Save to Cloud'), findsOneWidget);
      expect(find.text('Send to Friend'), findsOneWidget);
      expect(find.text('AI Assist'), findsOneWidget);
    });
  });
}
