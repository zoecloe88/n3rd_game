import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:n3rd_game/models/daily_challenge.dart';
import 'package:n3rd_game/services/challenge/firestore_challenge_repository.dart';
import 'package:n3rd_game/services/challenge/local_challenge_repository.dart';
import '../../utils/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await TestHelpers.setupAllTestInfrastructure();
  });

  tearDownAll(() {
    TestHelpers.tearDownAllTestInfrastructure();
  });

  group('FirestoreChallengeRepository', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FirestoreChallengeRepository repository;

    setUp(() {
      TestHelpers.setupMockSharedPreferences();
      fakeFirestore = FakeFirebaseFirestore();
      repository = FirestoreChallengeRepository(fakeFirestore);
    });

    tearDown(() {
      TestHelpers.clearMockSharedPreferences();
    });

    test('loadChallenges returns empty list when document does not exist',
        () async {
      final result = await repository.loadChallenges('testUserId');

      expect(result, isEmpty);
    });

    test('loadChallenges returns challenges when document exists', () async {
      final challenge = DailyChallenge(
        id: 'test_id',
        title: 'Test Challenge',
        description: 'Test Description',
        type: ChallengeType.perfectScore,
        target: {'count': 5},
        date: DateTime.now(),
      );

      // Set up fake Firestore data
      await fakeFirestore.collection('user_challenges').doc('testUserId').set({
        'challenges': [challenge.toJson()],
      });

      final result = await repository.loadChallenges('testUserId');

      expect(result.length, 1);
      expect(result.first.id, 'test_id');
    });
  });

  group('LocalChallengeRepository', () {
    late LocalChallengeRepository repository;

    setUp(() {
      TestHelpers.setupMockSharedPreferences();
      repository = LocalChallengeRepository();
    });

    tearDown(() {
      TestHelpers.clearMockSharedPreferences();
    });

    test('loadChallenges returns empty list when no data exists', () async {
      final result = await repository.loadChallenges('testUserId');

      expect(result, isEmpty);
    });

    test('saveChallenges and loadChallenges work together', () async {
      final challenge = DailyChallenge(
        id: 'test_id',
        title: 'Test Challenge',
        description: 'Test Description',
        type: ChallengeType.perfectScore,
        target: {'count': 5},
        date: DateTime.now(),
      );

      await repository.saveChallenges(
        userId: 'testUserId',
        challenges: [challenge],
      );

      final result = await repository.loadChallenges('testUserId');

      expect(result.length, 1);
      expect(result.first.id, 'test_id');
    });

    test('updateChallenge updates existing challenge', () async {
      final challenge = DailyChallenge(
        id: 'test_id',
        title: 'Test Challenge',
        description: 'Test Description',
        type: ChallengeType.perfectScore,
        target: {'count': 5},
        date: DateTime.now(),
      );

      await repository.saveChallenges(
        userId: 'testUserId',
        challenges: [challenge],
      );

      final updatedChallenge = challenge.copyWith(progress: 3);
      await repository.updateChallenge(
        userId: 'testUserId',
        challenge: updatedChallenge,
      );

      final result = await repository.loadChallenges('testUserId');

      expect(result.length, 1);
      expect(result.first.progress, 3);
    });
  });
}
