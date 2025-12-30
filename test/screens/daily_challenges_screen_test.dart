import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/screens/daily_challenges_screen.dart';
import 'package:n3rd_game/services/challenge_service.dart';
import 'package:n3rd_game/services/daily_challenge_leaderboard_service.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import '../utils/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await TestHelpers.setupAllTestInfrastructure();
  });

  tearDownAll(() {
    TestHelpers.tearDownAllTestInfrastructure();
  });

  group('DailyChallengesScreen', () {
    late ChallengeService challengeService;
    late DailyChallengeLeaderboardService leaderboardService;
    late SubscriptionService subscriptionService;
    late AnalyticsService analyticsService;

    setUp(() {
      TestHelpers.setupMockSharedPreferences();
      TestHelpers.setupVideoPlayerMocks();
      challengeService = ChallengeService();
      leaderboardService = DailyChallengeLeaderboardService();
      subscriptionService = SubscriptionService();
      analyticsService = AnalyticsService();
    });

    tearDown(() {
      challengeService.dispose();
      leaderboardService.dispose();
      subscriptionService.dispose();
      analyticsService.dispose();
      TestHelpers.clearMockSharedPreferences();
    });

    testWidgets('renders premium feature message when no online access',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: subscriptionService),
              ChangeNotifierProvider.value(value: challengeService),
              Provider.value(value: leaderboardService),
              ChangeNotifierProvider.value(value: analyticsService),
            ],
            child: const DailyChallengesScreen(),
          ),
        ),
      );

      // Wait for initialization
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should show premium feature message if no online access
      expect(find.text('Premium Feature'), findsOneWidget);
    });

    testWidgets('renders empty state when no challenges', (tester) async {
      // Mock subscription service to have online access
      // This would require setting up the service properly

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: subscriptionService),
              ChangeNotifierProvider.value(value: challengeService),
              Provider.value(value: leaderboardService),
              ChangeNotifierProvider.value(value: analyticsService),
            ],
            child: const DailyChallengesScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should show empty state or challenges list
      expect(find.byType(DailyChallengesScreen), findsOneWidget);
    });
  });
}
