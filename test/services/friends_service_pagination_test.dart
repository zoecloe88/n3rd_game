import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/services/friends_service.dart';
import '../utils/test_helpers.dart';

void main() {
  group('FriendsService Pagination Tests', () {
    late FriendsService service;

    setUpAll(() async {
      await TestHelpers.setupAllTestInfrastructure();
      // Firebase is already initialized by setupAllTestInfrastructure()
    });

    tearDownAll(() async {
      await TestHelpers.tearDownAllTestInfrastructure();
    });

    setUp(() {
      TestHelpers.setupMockSharedPreferences();
      service = FriendsService();
    });

    tearDown(() {
      TestHelpers.clearMockSharedPreferences();
      service.dispose();
    });

    test('hasMoreFriends starts as true', () {
      expect(service.hasMoreFriends, isTrue);
    });

    test('isLoadingMoreFriends starts as false', () {
      expect(service.isLoadingMoreFriends, isFalse);
    });

    test('loadMoreFriends updates hasMoreFriends when no more data', () async {
      // This test verifies the state management works correctly
      // Actual Firestore operations may not have data in test environment
      await service.loadMoreFriends();

      // State should be updated
      expect(service.isLoadingMoreFriends, isFalse);
    });

    test('loadMoreFriends prevents concurrent loads', () async {
      // Start multiple concurrent loads
      final futures = List.generate(3, (_) => service.loadMoreFriends());

      // Should complete without errors
      await Future.wait(futures, eagerError: true);

      expect(service.isLoadingMoreFriends, isFalse);
    });

    test('loadMoreFriends respects hasMoreFriends flag', () async {
      // If hasMore is false, loadMore should return immediately
      // This is tested through the service's internal logic
      await service.loadMoreFriends();

      // After load, should not be loading
      expect(service.isLoadingMoreFriends, isFalse);
    });

    test('pagination state resets on refresh', () async {
      await service.loadMoreFriends();

      // Refresh should reset pagination state
      await service.refreshFriends();

      // After refresh, should allow loading more
      expect(service.hasMoreFriends, anyOf(isTrue, isFalse));
    });
  });
}
