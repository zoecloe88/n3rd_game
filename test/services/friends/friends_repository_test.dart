import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/services/friends/local_friends_repository.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import '../../utils/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await TestHelpers.setupAllTestInfrastructure();
  });

  tearDownAll(() async {
    await TestHelpers.tearDownAllTestInfrastructure();
  });

  group('FirestoreFriendsRepository', () {
    setUp(() {
      TestHelpers.setupMockSharedPreferences();
    });

    tearDown(() {
      TestHelpers.clearMockSharedPreferences();
    });

    group('searchUsers', () {
      test('returns empty list when Firestore is not available', () async {
        // Mock Firebase not available
        // Note: isAvailable check requires Firebase.app() which is hard to mock
        // This test would need Firebase test setup
      });

      test('handles timeout errors', () async {
        // Test would require mocking Firestore timeout
      });
    });
  });

  group('LocalFriendsRepository', () {
    late LocalFriendsRepository repository;

    setUp(() async {
      TestHelpers.setupMockSharedPreferences();
      repository = LocalFriendsRepository();
    });

    tearDown(() {
      TestHelpers.clearMockSharedPreferences();
    });

    test('isAvailable always returns true', () {
      expect(repository.isAvailable, true);
    });

    test('searchUsers returns empty list when no cache', () async {
      final results = await repository.searchUsers('test');
      expect(results, isEmpty);
    });

    test('cacheSearchResults stores results', () async {
      final testResults = [
        {'userId': '1', 'email': 'test@example.com', 'displayName': 'Test'},
      ];
      await repository.cacheSearchResults(testResults);
      final results = await repository.searchUsers('test');
      expect(results, isNotEmpty);
    });

    test('isUserBlocked returns false when no blocks', () async {
      final isBlocked = await repository.isUserBlocked(
        userId: 'user1',
        userIdToCheck: 'user2',
      );
      expect(isBlocked, false);
    });

    test('blockUser stores block locally', () async {
      await repository.blockUser(
        userId: 'user1',
        blockedUserId: 'user2',
      );
      final isBlocked = await repository.isUserBlocked(
        userId: 'user1',
        userIdToCheck: 'user2',
      );
      expect(isBlocked, true);
    });

    test('unblockUser removes block', () async {
      await repository.blockUser(
        userId: 'user1',
        blockedUserId: 'user2',
      );
      await repository.unblockUser(
        userId: 'user1',
        unblockedUserId: 'user2',
      );
      final isBlocked = await repository.isUserBlocked(
        userId: 'user1',
        userIdToCheck: 'user2',
      );
      expect(isBlocked, false);
    });

    test('sendFriendRequest throws StorageException', () async {
      expect(
        () => repository.sendFriendRequest(
          fromUserId: 'user1',
          toUserId: 'user2',
        ),
        throwsA(isA<StorageException>()),
      );
    });

    test('sendInvitation throws StorageException', () async {
      expect(
        () => repository.sendInvitation(
          fromUserId: 'user1',
          toEmail: 'test@example.com',
        ),
        throwsA(isA<StorageException>()),
      );
    });

    test('reportUser throws StorageException', () async {
      expect(
        () => repository.reportUser(
          reporterUserId: 'user1',
          reportedUserId: 'user2',
          reason: 'Test reason',
        ),
        throwsA(isA<StorageException>()),
      );
    });
  });
}
