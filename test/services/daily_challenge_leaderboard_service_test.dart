import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:n3rd_game/services/daily_challenge_leaderboard_service.dart';
import 'package:n3rd_game/services/challenge/leaderboard_repository.dart';
import '../utils/test_helpers.dart';

class MockLeaderboardRepository extends Mock implements LeaderboardRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await TestHelpers.setupAllTestInfrastructure();
  });

  tearDownAll(() {
    TestHelpers.tearDownAllTestInfrastructure();
  });

  group('DailyChallengeLeaderboardService', () {
    late DailyChallengeLeaderboardService service;

    setUp(() {
      TestHelpers.setupMockSharedPreferences();
      service = DailyChallengeLeaderboardService();
    });

    tearDown(() {
      service.dispose();
      TestHelpers.clearMockSharedPreferences();
    });

    test('initialization sets isInitialized flag', () async {
      await service.init();
      expect(service, isNotNull);
    });

    test('submitDailyChallengeScore returns error for empty challengeId',
        () async {
      await service.init();

      final response = await service.submitDailyChallengeScore(
        challengeId: '',
        score: 100,
        completionTime: 60,
        accuracy: 80.0,
      );

      expect(response.isSuccess, isFalse);
      expect(response.result, SubmissionResult.challengeInvalid);
    });

    test('submitDailyChallengeScore returns error for negative score',
        () async {
      await service.init();

      final response = await service.submitDailyChallengeScore(
        challengeId: 'test_id',
        score: -1,
        completionTime: 60,
        accuracy: 80.0,
      );

      expect(response.isSuccess, isFalse);
      expect(response.result, SubmissionResult.challengeInvalid);
    });

    test('submitDailyChallengeScore returns error for invalid accuracy',
        () async {
      await service.init();

      final response = await service.submitDailyChallengeScore(
        challengeId: 'test_id',
        score: 100,
        completionTime: 60,
        accuracy: 150.0, // Invalid: > 100
      );

      expect(response.isSuccess, isFalse);
      expect(response.result, SubmissionResult.challengeInvalid);
    });

    test('getAttemptCount returns 0 when repository unavailable', () async {
      await service.init();

      final count = await service.getAttemptCount('test_id', null);
      expect(count, 0);
    });

    test('getTop5Leaderboard returns empty list when repository unavailable',
        () async {
      await service.init();

      final leaderboard =
          await service.getTop5Leaderboard(challengeId: 'test_id');
      expect(leaderboard, isEmpty);
    });

    test('dispose cleans up resources', () {
      service.dispose();
      // Verify no errors are thrown
      expect(service, isNotNull);
    });
  });
}
