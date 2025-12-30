import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:n3rd_game/screens/friends_more_view_model.dart';
import 'package:n3rd_game/services/friends_service.dart';
import 'package:n3rd_game/services/friend_score_service.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'friends_more_view_model_test.mocks.dart';

@GenerateMocks([FriendsService, FriendScoreService])
void main() {
  group('FriendsMoreViewModel', () {
    late FriendsMoreViewModel viewModel;
    late MockFriendsService mockFriendsService;
    late MockFriendScoreService mockFriendScoreService;

    setUp(() {
      mockFriendsService = MockFriendsService();
      mockFriendScoreService = MockFriendScoreService();
      viewModel = FriendsMoreViewModel(
        friendsService: mockFriendsService,
        friendScoreService: mockFriendScoreService,
      );
    });

    tearDown(() {
      viewModel.dispose();
    });

    group('searchUsers', () {
      test('returns empty list for empty query', () async {
        final results = await viewModel.searchUsers('');
        expect(results, isEmpty);
      });

      test('calls FriendsService.searchUsers', () async {
        when(mockFriendsService.searchUsers(any)).thenAnswer(
          (_) async => [
            {'userId': '1', 'email': 'test@example.com'},
          ],
        );

        final results = await viewModel.searchUsers('test');
        expect(results, isNotEmpty);
        verify(mockFriendsService.searchUsers('test')).called(1);
      });

      test('handles validation errors', () async {
        when(mockFriendsService.searchUsers(any))
            .thenThrow(ValidationException('Invalid query'));

        final results = await viewModel.searchUsers('test');
        expect(results, isEmpty);
        expect(viewModel.errorMessage, isNotNull);
      });
    });

    group('sendFriendRequest', () {
      test('returns true on success', () async {
        when(
          mockFriendsService.sendFriendRequest(
            any,
            friendEmail: anyNamed('friendEmail'),
            friendDisplayName: anyNamed('friendDisplayName'),
          ),
        ).thenAnswer((_) async => Future.value());

        final success = await viewModel.sendFriendRequest('user1');
        expect(success, true);
      });

      test('returns false on error', () async {
        when(
          mockFriendsService.sendFriendRequest(
            any,
            friendEmail: anyNamed('friendEmail'),
            friendDisplayName: anyNamed('friendDisplayName'),
          ),
        ).thenThrow(NetworkException('Network error'));

        final success = await viewModel.sendFriendRequest('user1');
        expect(success, false);
        expect(viewModel.errorMessage, isNotNull);
      });
    });

    group('friend scores', () {
      test('loads friend scores on initialization', () {
        // ViewModel should load scores in constructor
        verify(mockFriendScoreService.getFriendScores()).called(1);
      });

      test('refreshFriendScores invalidates cache and reloads', () async {
        // Reset mocks to clear previous calls from constructor
        reset(mockFriendScoreService);

        when(mockFriendScoreService.getFriendScores())
            .thenAnswer((_) async => []);
        when(mockFriendScoreService.getCurrentUserScore())
            .thenAnswer((_) async => 100);

        await viewModel.refreshFriendScores();
        verify(mockFriendScoreService.invalidateCache()).called(1);
        verify(mockFriendScoreService.getFriendScores()).called(1);
      });
    });
  });
}
