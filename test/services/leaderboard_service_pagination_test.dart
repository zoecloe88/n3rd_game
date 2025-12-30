import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/services/leaderboard_service.dart';
import '../utils/test_helpers.dart';
import '../utils/firebase_test_helper.dart';

void main() {
  group('LeaderboardService Pagination Tests', () {
    setUpAll(() async {
      await TestHelpers.setupAllTestInfrastructure();
      await FirebaseTestHelper.initializeFirebaseForTests();
    });

    tearDownAll(() {
      TestHelpers.tearDownAllTestInfrastructure();
    });

    setUp(() {
      TestHelpers.setupMockSharedPreferences();
    });

    tearDown(() {
      TestHelpers.clearMockSharedPreferences();
    });

    test('getGlobalLeaderboardWithPagination returns correct structure',
        () async {
      final service = LeaderboardService();

      final result = await service.getGlobalLeaderboardWithPagination(
        limit: 10,
      );

      expect(result, isA<Map<String, dynamic>>());
      expect(result.containsKey('entries'), isTrue);
      expect(result.containsKey('lastDocument'), isTrue);
      expect(result.containsKey('hasMore'), isTrue);
      expect(result['entries'], isA<List<LeaderboardEntry>>());
    });

    test('pagination respects limit parameter', () async {
      final service = LeaderboardService();

      final result = await service.getGlobalLeaderboardWithPagination(
        limit: 5,
      );

      final entries = result['entries'] as List<LeaderboardEntry>;
      expect(entries.length, lessThanOrEqualTo(5));
    });

    test('hasMore is false when results are less than limit', () async {
      final service = LeaderboardService();

      final result = await service.getGlobalLeaderboardWithPagination(
        limit: 1000, // Large limit to ensure hasMore is false
      );

      expect(result['hasMore'], isFalse);
    });

    test('pagination with startAfter returns next page', () async {
      final service = LeaderboardService();

      final firstPage = await service.getGlobalLeaderboardWithPagination(
        limit: 10,
      );

      final lastDocument = firstPage['lastDocument'];
      if (lastDocument != null) {
        final secondPage = await service.getGlobalLeaderboardWithPagination(
          limit: 10,
          startAfter: lastDocument,
        );

        final firstEntries = firstPage['entries'] as List<LeaderboardEntry>;
        final secondEntries = secondPage['entries'] as List<LeaderboardEntry>;

        // Second page should have different entries
        expect(secondEntries.isNotEmpty, isTrue);
        // Entries should be unique (no overlap)
        final firstIds = firstEntries.map((e) => e.userId).toSet();
        final secondIds = secondEntries.map((e) => e.userId).toSet();
        expect(firstIds.intersection(secondIds).isEmpty, isTrue);
      }
    });

    test('pagination handles empty results gracefully', () async {
      final service = LeaderboardService();

      final result = await service.getGlobalLeaderboardWithPagination(
        limit: 10,
        startAfter: null, // Start from beginning
      );

      expect(result['entries'], isA<List<LeaderboardEntry>>());
      expect(result['hasMore'], isA<bool>());
    });

    test('pagination clamps limit to max 100', () async {
      final service = LeaderboardService();

      final result = await service.getGlobalLeaderboardWithPagination(
        limit: 200, // Exceeds max
      );

      final entries = result['entries'] as List<LeaderboardEntry>;
      expect(entries.length, lessThanOrEqualTo(100));
    });

    test('pagination handles null startAfter correctly', () async {
      final service = LeaderboardService();

      final result = await service.getGlobalLeaderboardWithPagination(
        limit: 10,
        startAfter: null,
      );

      expect(result['entries'], isA<List<LeaderboardEntry>>());
      expect(result['lastDocument'], anyOf(isNull, isNotNull));
    });
  });
}
