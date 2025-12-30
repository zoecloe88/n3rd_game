import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/services/auth_service.dart';
import 'package:n3rd_game/services/game_service.dart';
import 'package:n3rd_game/services/learning_service.dart';
import 'package:n3rd_game/services/game_history_service.dart';
import 'package:n3rd_game/services/challenge_service.dart';
import 'package:n3rd_game/services/daily_challenge_leaderboard_service.dart';
import 'package:n3rd_game/services/trivia_creator_service.dart';
import 'package:n3rd_game/services/friends_service.dart';
import 'package:n3rd_game/services/ai_edition_service.dart';
// Note: TriviaGeneratorService is a large file (15,491 lines) but is needed
// as a type parameter for ChangeNotifierProvider<TriviaGeneratorService>.
// Deferred import is not feasible here as types must be available at compile time.
// This file is only loaded when tests actually use TestWidgetBuilder, not during
// test discovery, so the impact is minimal.
import 'package:n3rd_game/services/trivia_generator_service.dart';

/// Standardized widget test builder for consistent test setup
///
/// This helper provides common provider setups to reduce boilerplate
/// and ensure all required providers are available in tests.
class TestWidgetBuilder {
  /// Build a MaterialApp with standard providers for widget tests
  ///
  /// Includes commonly needed providers:
  /// - AnalyticsService (ChangeNotifierProvider)
  /// - SubscriptionService (optional)
  /// - AuthService (optional)
  /// - Other services as needed
  static Widget buildWithProviders({
    required Widget child,
    AnalyticsService? analyticsService,
    SubscriptionService? subscriptionService,
    AuthService? authService,
    GameService? gameService,
    LearningService? learningService,
    GameHistoryService? gameHistoryService,
    ChallengeService? challengeService,
    DailyChallengeLeaderboardService? dailyChallengeLeaderboardService,
    TriviaCreatorService? triviaCreatorService,
    FriendsService? friendsService,
    AIEditionService? aiEditionService,
    TriviaGeneratorService? triviaGeneratorService,
    List<Widget>? additionalProviders,
  }) {
    final providers = <Widget>[];

    // Always include AnalyticsService (required by VideoBackgroundWidget and others)
    providers.add(
      ChangeNotifierProvider<AnalyticsService>.value(
        value: analyticsService ?? AnalyticsService(),
      ),
    );

    // Add optional providers if provided
    if (subscriptionService != null) {
      providers.add(
        ChangeNotifierProvider<SubscriptionService>.value(
          value: subscriptionService,
        ),
      );
    }

    if (authService != null) {
      providers.add(
        ChangeNotifierProvider<AuthService>.value(
          value: authService,
        ),
      );
    }

    if (gameService != null) {
      providers.add(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
        ),
      );
    }

    if (learningService != null) {
      providers.add(
        ChangeNotifierProvider<LearningService>.value(
          value: learningService,
        ),
      );
    }

    if (gameHistoryService != null) {
      providers.add(
        ChangeNotifierProvider<GameHistoryService>.value(
          value: gameHistoryService,
        ),
      );
    }

    if (challengeService != null) {
      providers.add(
        ChangeNotifierProvider<ChallengeService>.value(
          value: challengeService,
        ),
      );
    }

    if (dailyChallengeLeaderboardService != null) {
      providers.add(
        Provider<DailyChallengeLeaderboardService>.value(
          value: dailyChallengeLeaderboardService,
        ),
      );
    }

    if (triviaCreatorService != null) {
      providers.add(
        ChangeNotifierProvider<TriviaCreatorService>.value(
          value: triviaCreatorService,
        ),
      );
    }

    if (friendsService != null) {
      providers.add(
        ChangeNotifierProvider<FriendsService>.value(
          value: friendsService,
        ),
      );
    }

    if (aiEditionService != null) {
      providers.add(
        ChangeNotifierProvider<AIEditionService>.value(
          value: aiEditionService,
        ),
      );
    }

    if (triviaGeneratorService != null) {
      providers.add(
        ChangeNotifierProvider<TriviaGeneratorService>.value(
          value: triviaGeneratorService,
        ),
      );
    }

    // Add any additional providers
    if (additionalProviders != null) {
      providers.addAll(additionalProviders);
    }

    return MultiProvider(
      providers: providers.cast(),
      child: MaterialApp(
        home: child,
      ),
    );
  }

  /// Build a MaterialApp with minimal providers (just AnalyticsService)
  ///
  /// Use this for simple widget tests that only need AnalyticsService
  static Widget buildMinimal({
    required Widget child,
    AnalyticsService? analyticsService,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AnalyticsService>.value(
          value: analyticsService ?? AnalyticsService(),
        ),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }
}
