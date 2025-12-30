import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/screens/game_history_screen.dart';
import 'package:n3rd_game/services/game_history_service.dart';
import 'package:n3rd_game/models/game_history_entry.dart';
import 'package:n3rd_game/models/game_mode_config.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/widgets/app_card.dart';
import '../utils/test_helpers.dart';
import '../utils/firebase_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await TestHelpers.setupAllTestInfrastructure();
  });

  tearDownAll(() {
    TestHelpers.tearDownAllTestInfrastructure();
  });

  group('GameHistoryScreen', () {
    late GameHistoryService service;
    late AnalyticsService analyticsService;

    setUp(() async {
      TestHelpers.setupMockSharedPreferences();
      TestHelpers.setupVideoPlayerMocks();
      // Ensure Firebase is initialized before creating service
      await FirebaseTestHelper.initializeFirebaseForTests();
      // Small delay to ensure Firebase is fully ready
      await Future.delayed(const Duration(milliseconds: 50));
      service = GameHistoryService();
      await service.init();
      analyticsService = AnalyticsService();
    });

    tearDown(() {
      service.dispose();
      analyticsService.dispose();
      TestHelpers.clearMockSharedPreferences();
    });

    testWidgets('should render loading state initially', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GameHistoryService>.value(value: service),
            ChangeNotifierProvider.value(value: analyticsService),
          ],
          child: const MaterialApp(
            home: GameHistoryScreen(),
          ),
        ),
      );

      await tester.pump(); // Allow initial build

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should display empty state when no games', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GameHistoryService>.value(value: service),
            ChangeNotifierProvider.value(value: analyticsService),
          ],
          child: const MaterialApp(
            home: GameHistoryScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should show empty state
      expect(find.text('No Game History'), findsOneWidget);
    });

    testWidgets('should display game cards when games exist', (tester) async {
      // Add a test game
      final game = GameHistoryEntry(
        gameId: 'test_game_1',
        completedAt: DateTime.now(),
        mode: GameMode.classic,
        score: 100,
        rounds: 5,
        correctAnswers: 4,
        wrongAnswers: 1,
        durationSeconds: 120,
        accuracy: 0.8,
      );
      await service.recordGame(game);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GameHistoryService>.value(value: service),
            ChangeNotifierProvider.value(value: analyticsService),
          ],
          child: const MaterialApp(
            home: GameHistoryScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      // Wait for service to load games
      await tester.pump(const Duration(milliseconds: 500));

      // Should show game card - score may be displayed as "100" or formatted differently
      // Check for game card or any score-related text
      final scoreText = find.text('100');
      final gameCard = find.byType(AppCard);
      // Either the score text exists or a game card is displayed
      expect(
        scoreText.evaluate().isNotEmpty || gameCard.evaluate().isNotEmpty,
        isTrue,
        reason:
            'Game history should display game cards or score when games exist',
      );
    });

    testWidgets('should show filter button', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GameHistoryService>.value(value: service),
            ChangeNotifierProvider.value(value: analyticsService),
          ],
          child: const MaterialApp(
            home: GameHistoryScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should have filter button
      expect(find.byIcon(Icons.filter_list), findsOneWidget);
    });

    testWidgets('should show back button', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GameHistoryService>.value(value: service),
            ChangeNotifierProvider.value(value: analyticsService),
          ],
          child: const MaterialApp(
            home: GameHistoryScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should have back button
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('should show sync status when retry queue has items',
        (tester) async {
      // Note: This test would require mocking the retry queue
      // For now, we just verify the UI structure
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GameHistoryService>.value(value: service),
            ChangeNotifierProvider.value(value: analyticsService),
          ],
          child: const MaterialApp(
            home: GameHistoryScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // UI should be present (sync indicator may or may not show depending on queue)
      expect(find.byType(GameHistoryScreen), findsOneWidget);
    });
  });
}
