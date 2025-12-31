import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/services/friends/friends_repository.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';

/// Local storage implementation of FriendsRepository using SharedPreferences
class LocalFriendsRepository implements FriendsRepository {
  static const String _storageKeyFriends = 'friends_cache';
  static const String _storageKeySearchResults = 'friends_search_cache';
  static const String _storageKeySuggestions = 'friends_suggestions_cache';
  static const String _storageKeyBlocks = 'friends_blocks_cache';

  @override
  bool get isAvailable => true; // SharedPreferences is always available

  @override
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKeySearchResults);
      if (jsonString != null) {
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        final results =
            (data['results'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        // Filter by query (case-insensitive)
        final queryLower = query.toLowerCase();
        return results.where((user) {
          final email = (user['email'] as String? ?? '').toLowerCase();
          final displayName =
              (user['displayName'] as String? ?? '').toLowerCase();
          return email.contains(queryLower) || displayName.contains(queryLower);
        }).toList();
      }
      return [];
    } catch (e, stack) {
      LoggerService.error(
        'Failed to search users from local storage',
        error: e,
        stack: stack,
      );
      return [];
    }
  }

  /// Cache search results locally
  Future<void> cacheSearchResults(List<Map<String, dynamic>> results) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'results': results,
        'cachedAt': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_storageKeySearchResults, jsonEncode(data));
    } catch (e) {
      LoggerService.error(
        'Failed to cache search results',
        error: e,
      );
    }
  }

  @override
  Future<void> sendFriendRequest({
    required String fromUserId,
    required String toUserId,
    String? fromDisplayName,
    String? fromEmail,
    String? toDisplayName,
    String? toEmail,
  }) async {
    // Local repository doesn't support sending requests
    // This should be handled by Firestore repository
    throw StorageException(
      'Friend requests must be sent through online storage',
      recoverySuggestion:
          'Please check your internet connection and try again.',
    );
  }

  @override
  Future<void> acceptFriendRequest({
    required String requestId,
    required String userId,
    required String fromUserId,
    String? fromDisplayName,
    String? fromEmail,
  }) async {
    // Local repository doesn't support accepting requests
    throw StorageException(
      'Friend requests must be accepted through online storage',
      recoverySuggestion:
          'Please check your internet connection and try again.',
    );
  }

  @override
  Future<void> rejectFriendRequest(String requestId) async {
    // Local repository doesn't support rejecting requests
    throw StorageException(
      'Friend requests must be rejected through online storage',
      recoverySuggestion:
          'Please check your internet connection and try again.',
    );
  }

  @override
  Future<void> removeFriend({
    required String userId,
    required String friendUserId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKeyFriends);
      if (jsonString != null) {
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        final friends =
            (data['friends'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        friends.removeWhere(
          (friend) =>
              friend['userId'] == userId && friend['friendId'] == friendUserId,
        );
        friends.removeWhere(
          (friend) =>
              friend['userId'] == friendUserId && friend['friendId'] == userId,
        );
        await prefs.setString(
          _storageKeyFriends,
          jsonEncode({
            'friends': friends,
            'updatedAt': DateTime.now().toIso8601String(),
          }),
        );
      }
    } catch (e, stack) {
      LoggerService.error(
        'Failed to remove friend from local storage',
        error: e,
        stack: stack,
      );
      throw StorageException(
        'Failed to remove friend locally: $e',
        recoverySuggestion: 'Please try again later.',
      );
    }
  }

  @override
  Future<void> blockUser({
    required String userId,
    required String blockedUserId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKeyBlocks);
      final blocks = <Map<String, dynamic>>[];
      if (jsonString != null) {
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        blocks.addAll(
            (data['blocks'] as List?)?.cast<Map<String, dynamic>>() ?? [],);
      }
      blocks.add({
        'userId': userId,
        'blockedUserId': blockedUserId,
        'blockedAt': DateTime.now().toIso8601String(),
      });
      await prefs.setString(
        _storageKeyBlocks,
        jsonEncode({
          'blocks': blocks,
          'updatedAt': DateTime.now().toIso8601String(),
        }),
      );
    } catch (e, stack) {
      LoggerService.error(
        'Failed to block user in local storage',
        error: e,
        stack: stack,
      );
      throw StorageException(
        'Failed to block user locally: $e',
        recoverySuggestion: 'Please try again later.',
      );
    }
  }

  @override
  Future<void> unblockUser({
    required String userId,
    required String unblockedUserId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKeyBlocks);
      if (jsonString != null) {
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        final blocks =
            (data['blocks'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        blocks.removeWhere(
          (block) =>
              block['userId'] == userId &&
              block['blockedUserId'] == unblockedUserId,
        );
        await prefs.setString(
          _storageKeyBlocks,
          jsonEncode({
            'blocks': blocks,
            'updatedAt': DateTime.now().toIso8601String(),
          }),
        );
      }
    } catch (e, stack) {
      LoggerService.error(
        'Failed to unblock user from local storage',
        error: e,
        stack: stack,
      );
      throw StorageException(
        'Failed to unblock user locally: $e',
        recoverySuggestion: 'Please try again later.',
      );
    }
  }

  @override
  Future<bool> isUserBlocked({
    required String userId,
    required String userIdToCheck,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKeyBlocks);
      if (jsonString != null) {
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        final blocks =
            (data['blocks'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        return blocks.any(
          (block) =>
              block['userId'] == userId &&
              block['blockedUserId'] == userIdToCheck,
        );
      }
      return false;
    } catch (e) {
      LoggerService.error(
        'Failed to check if user is blocked in local storage',
        error: e,
      );
      return false;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getFriendSuggestions({
    required String userId,
    required Set<String> excludeUserIds,
    int limit = 5,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKeySuggestions);
      if (jsonString != null) {
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        final suggestions =
            (data['suggestions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        // Filter out excluded users
        return suggestions
            .where(
                (suggestion) => !excludeUserIds.contains(suggestion['userId']),)
            .take(limit)
            .toList();
      }
      return [];
    } catch (e) {
      LoggerService.error(
        'Failed to get friend suggestions from local storage',
        error: e,
      );
      return [];
    }
  }

  /// Cache friend suggestions locally
  Future<void> cacheFriendSuggestions(
      List<Map<String, dynamic>> suggestions,) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'suggestions': suggestions,
        'cachedAt': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_storageKeySuggestions, jsonEncode(data));
    } catch (e) {
      LoggerService.error(
        'Failed to cache friend suggestions',
        error: e,
      );
    }
  }

  @override
  Future<void> sendInvitation({
    required String fromUserId,
    required String toEmail,
  }) async {
    // Local repository doesn't support sending invitations
    throw StorageException(
      'Invitations must be sent through online storage',
      recoverySuggestion:
          'Please check your internet connection and try again.',
    );
  }

  @override
  Future<void> reportUser({
    required String reporterUserId,
    required String reportedUserId,
    required String reason,
  }) async {
    // Local repository doesn't support reporting users
    throw StorageException(
      'User reports must be submitted through online storage',
      recoverySuggestion:
          'Please check your internet connection and try again.',
    );
  }
}
