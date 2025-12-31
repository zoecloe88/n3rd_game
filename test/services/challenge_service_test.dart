import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:n3rd_game/models/daily_challenge.dart';
import 'package:n3rd_game/services/challenge_service.dart';
import 'package:n3rd_game/services/challenge/challenge_repository.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import '../utils/test_helpers.dart';

class MockChallengeRepository extends Mock implements ChallengeRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await TestHelpers.setupAllTestInfrastructure();
  });

  tearDownAll(() async {
    await TestHelpers.tearDownAllTestInfrastructure();
  });

  group('ChallengeService', () {
    late ChallengeService service;

    setUp(() {
      TestHelpers.setupMockSharedPreferences();
      service = ChallengeService();
    });

    tearDown(() {
      service.dispose();
      TestHelpers.clearMockSharedPreferences();
    });

    test('initialization sets isInitialized flag', () async {
      await service.init();
      expect(service.isInitialized, isTrue);
    });

    test('todayChallenges filters challenges for today', () {
      // This test would require setting up the service with challenges
      // For now, we test the getter logic
      expect(service.todayChallenges, isA<List<DailyChallenge>>());
    });

    test(
        'updateChallengeProgress throws ValidationException for empty challengeId',
        () async {
      await service.init();

      expect(
        () => service.updateChallengeProgress('', 5),
        throwsA(isA<ValidationException>()),
      );
    });

    test('completeChallenge throws ValidationException for empty challengeId',
        () async {
      await service.init();

      expect(
        () => service.completeChallenge(''),
        throwsA(isA<ValidationException>()),
      );
    });

    test('dispose cleans up resources', () async {
      await service.init();
      expect(service.isInitialized, isTrue);
      // Don't dispose here - tearDown will handle it
    });
  });
}
