import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/services/game/game_competitive_challenge_manager.dart';
import 'package:n3rd_game/models/game_state.dart';
import 'package:n3rd_game/services/daily_challenge_leaderboard_service.dart';

void main() {
  group('GameCompetitiveChallengeManager', () {
    late GameCompetitiveChallengeManager manager;

    setUp(() {
      manager = GameCompetitiveChallengeManager();
    });

    tearDown(() {
      // Manager doesn't require disposal, but keeping structure consistent
    });

    test('should initialize with default values', () {
      expect(manager.competitiveChallengeId, isNull);
      expect(manager.competitiveChallengeStartTime, isNull);
      expect(manager.competitiveChallengePauseTime, isNull);
      expect(manager.competitiveChallengePausedDuration, 0);
      expect(manager.competitiveChallengeTargetRounds, isNull);
      expect(manager.competitiveChallengeScoreSubmitted, false);
    });

    test('should set competitive challenge with valid parameters', () {
      bool sessionStatsReset = false;
      bool gameStartTimeReset = false;
      bool listenersNotified = false;

      manager.setCompetitiveChallenge(
        'challenge123',
        targetRounds: 5,
        onResetSessionStats: () {
          sessionStatsReset = true;
        },
        onResetGameStartTime: () {
          gameStartTimeReset = true;
        },
        onNotifyListeners: () {
          listenersNotified = true;
        },
      );

      expect(manager.competitiveChallengeId, 'challenge123');
      expect(manager.competitiveChallengeTargetRounds, 5);
      expect(manager.competitiveChallengeStartTime, isNotNull);
      expect(manager.competitiveChallengePauseTime, isNull);
      expect(manager.competitiveChallengePausedDuration, 0);
      expect(sessionStatsReset, true);
      expect(gameStartTimeReset, true);
      expect(listenersNotified, true);
    });

    test('should not set challenge with empty challenge ID', () {
      manager.setCompetitiveChallenge('');

      expect(manager.competitiveChallengeId, isNull);
    });

    test('should not set challenge with invalid target rounds', () {
      manager.setCompetitiveChallenge('challenge123', targetRounds: 0);
      expect(manager.competitiveChallengeId, isNull);

      manager.setCompetitiveChallenge('challenge123', targetRounds: 101);
      expect(manager.competitiveChallengeId, isNull);
    });

    test('should not set new challenge if submission is in progress', () {
      manager.competitiveChallengeScoreSubmitted = true;

      manager.setCompetitiveChallenge('newchallenge');

      expect(manager.competitiveChallengeId, isNull);
    });

    test('should reset competitive challenge state', () {
      manager.competitiveChallengeId = 'challenge123';
      manager.competitiveChallengeStartTime = DateTime.now();
      manager.competitiveChallengePausedDuration = 10;
      manager.competitiveChallengeScoreSubmitted = true;

      manager.reset();

      expect(manager.competitiveChallengeId, isNull);
      expect(manager.competitiveChallengeStartTime, isNull);
      expect(manager.competitiveChallengePauseTime, isNull);
      expect(manager.competitiveChallengePausedDuration, 0);
      expect(manager.competitiveChallengeTargetRounds, isNull);
      expect(manager.competitiveChallengeScoreSubmitted, false);
    });

    test('should handle submission when no active challenge', () async {
      final leaderboardService = DailyChallengeLeaderboardService();
      final state =
          GameState(score: 100, lives: 3, round: 1, isGameOver: false);

      final response = await manager.submitCompetitiveChallengeScore(
        state: state,
        sessionCorrectAnswers: 5,
        sessionWrongAnswers: 2,
        isLoadingState: false,
        leaderboardService: leaderboardService,
        onSaveState: () {},
      );

      expect(response.isSuccess, false);
      expect(response.result, SubmissionResult.unknownError);
    });

    test('should handle submission when state is loading', () async {
      manager.competitiveChallengeId = 'challenge123';
      manager.competitiveChallengeStartTime = DateTime.now();
      final leaderboardService = DailyChallengeLeaderboardService();
      final state =
          GameState(score: 100, lives: 3, round: 1, isGameOver: false);

      final response = await manager.submitCompetitiveChallengeScore(
        state: state,
        sessionCorrectAnswers: 5,
        sessionWrongAnswers: 2,
        isLoadingState: true, // Loading state
        leaderboardService: leaderboardService,
        onSaveState: () {},
      );

      expect(response.isSuccess, false);
      expect(response.result, SubmissionResult.unknownError);
    });

    test('should prevent duplicate submissions', () async {
      manager.competitiveChallengeId = 'challenge123';
      manager.competitiveChallengeStartTime = DateTime.now();
      manager.competitiveChallengeScoreSubmitted = true; // Already submitted
      final leaderboardService = DailyChallengeLeaderboardService();
      final state =
          GameState(score: 100, lives: 3, round: 1, isGameOver: false);

      final response = await manager.submitCompetitiveChallengeScore(
        state: state,
        sessionCorrectAnswers: 5,
        sessionWrongAnswers: 2,
        isLoadingState: false,
        leaderboardService: leaderboardService,
        onSaveState: () {},
      );

      expect(response.isSuccess, false);
      expect(response.result, SubmissionResult.unknownError);
    });
  });
}
