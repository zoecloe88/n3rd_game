/// Abstract repository interface for friend operations
///
/// Provides a clean abstraction layer for friend-related data operations,
/// allowing for easier testing and potential future storage backends.
///
/// **Implementations:**
/// - `FirestoreFriendsRepository`: Cloud storage using Firestore
/// - `LocalFriendsRepository`: Local storage using SharedPreferences for offline support
///
/// **Usage:**
/// ```dart
/// final repository = FirestoreFriendsRepository(FirebaseFirestore.instance);
/// final results = await repository.searchUsers('user@example.com');
/// ```
abstract class FriendsRepository {
  /// Search for users by email or display name
  Future<List<Map<String, dynamic>>> searchUsers(String query);

  /// Send a friend request
  Future<void> sendFriendRequest({
    required String fromUserId,
    required String toUserId,
    String? fromDisplayName,
    String? fromEmail,
    String? toDisplayName,
    String? toEmail,
  });

  /// Accept a friend request
  Future<void> acceptFriendRequest({
    required String requestId,
    required String userId,
    required String fromUserId,
    String? fromDisplayName,
    String? fromEmail,
  });

  /// Reject a friend request
  Future<void> rejectFriendRequest(String requestId);

  /// Remove a friend (bidirectional)
  Future<void> removeFriend({
    required String userId,
    required String friendUserId,
  });

  /// Block a user
  Future<void> blockUser({
    required String userId,
    required String blockedUserId,
  });

  /// Unblock a user
  Future<void> unblockUser({
    required String userId,
    required String unblockedUserId,
  });

  /// Check if a user is blocked
  Future<bool> isUserBlocked({
    required String userId,
    required String userIdToCheck,
  });

  /// Get friend suggestions (users you might know)
  Future<List<Map<String, dynamic>>> getFriendSuggestions({
    required String userId,
    required Set<String> excludeUserIds,
    int limit = 5,
  });

  /// Send an invitation
  Future<void> sendInvitation({
    required String fromUserId,
    required String toEmail,
  });

  /// Report a user
  Future<void> reportUser({
    required String reporterUserId,
    required String reportedUserId,
    required String reason,
  });

  /// Check if repository is available (e.g., Firebase initialized)
  bool get isAvailable;
}
