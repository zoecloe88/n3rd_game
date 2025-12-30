import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:n3rd_game/services/friends/friends_repository.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';

/// Firestore implementation of FriendsRepository
class FirestoreFriendsRepository implements FriendsRepository {

  FirestoreFriendsRepository(this._firestore);
  final FirebaseFirestore _firestore;
  static const Duration _timeout = Duration(seconds: 10);

  @override
  bool get isAvailable {
    try {
      Firebase.app();
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (!isAvailable) {
      throw NetworkException(
        'Firebase is not available',
        recoverySuggestion:
            'Please check your internet connection and try again.',
      );
    }

    try {
      // Search by email
      final emailResults = await _firestore
          .collection('user_profiles')
          .where('email', isGreaterThanOrEqualTo: query)
          .where('email', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(10)
          .get()
          .timeout(_timeout);

      final results = <Map<String, dynamic>>[];
      for (final doc in emailResults.docs) {
        final data = doc.data();
        results.add({
          'userId': doc.id,
          'email': data['email'],
          'displayName': data['displayName'],
        });
      }

      return results;
    } on TimeoutException {
      LoggerService.error(
        'Firestore search timeout for users',
      );
      throw NetworkException(
        'Request timed out while searching users',
        recoverySuggestion: 'Please check your connection and try again.',
      );
    } on FirebaseException catch (e) {
      LoggerService.error(
        'Firestore error searching users',
        error: e,
      );
      if (e.code == 'permission-denied') {
        throw PermissionException(
          'Permission denied searching users',
          recoverySuggestion:
              'Please check your account permissions and try again.',
        );
      } else if (e.code == 'unavailable') {
        throw NetworkException(
          'Search service is currently unavailable',
          recoverySuggestion:
              'Please check your connection and try again later.',
        );
      }
      throw NetworkException(
        'Failed to search users: ${e.message}',
        recoverySuggestion: 'Please try again later.',
      );
    } catch (e, stack) {
      LoggerService.error(
        'Unexpected error searching users',
        error: e,
        stack: stack,
      );
      throw NetworkException(
        'Failed to search users',
        recoverySuggestion: 'An unexpected error occurred. Please try again.',
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
    if (!isAvailable) {
      throw NetworkException(
        'Firebase is not available',
        recoverySuggestion:
            'Please check your internet connection and try again.',
      );
    }

    if (fromUserId == toUserId) {
      throw ValidationException(
        'Cannot add yourself as a friend',
        recoverySuggestion: 'Please search for a different user.',
      );
    }

    try {
      // Check if already friends
      final existingFriend = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: fromUserId)
          .where('friendId', isEqualTo: toUserId)
          .where('status', isEqualTo: 'accepted')
          .get()
          .timeout(_timeout);

      if (existingFriend.docs.isNotEmpty) {
        throw ValidationException(
          'Already friends',
          recoverySuggestion: 'This user is already your friend.',
        );
      }

      // Check if request already exists
      final existingRequest = await _firestore
          .collection('friend_requests')
          .where('fromUserId', isEqualTo: fromUserId)
          .where('toUserId', isEqualTo: toUserId)
          .where('status', isEqualTo: 'pending')
          .get()
          .timeout(_timeout);

      if (existingRequest.docs.isNotEmpty) {
        throw ValidationException(
          'Friend request already sent',
          recoverySuggestion:
              'You have already sent a friend request to this user.',
        );
      }

      // Create friend request
      await _firestore.collection('friend_requests').add({
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'fromDisplayName': fromDisplayName,
        'fromEmail': fromEmail,
        'toDisplayName': toDisplayName,
        'toEmail': toEmail,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      }).timeout(_timeout);
    } on TimeoutException {
      LoggerService.error(
        'Firestore send friend request timeout',
      );
      throw NetworkException(
        'Request timed out while sending friend request',
        recoverySuggestion: 'Please check your connection and try again.',
      );
    } on FirebaseException catch (e) {
      LoggerService.error(
        'Firebase error sending friend request',
        error: e,
      );
      if (e.code == 'permission-denied') {
        throw PermissionException(
          'Permission denied sending friend request',
          recoverySuggestion:
              'Please check your account permissions and try again.',
        );
      } else if (e.code == 'unavailable') {
        throw NetworkException(
          'Friend service is currently unavailable',
          recoverySuggestion:
              'Please check your connection and try again later.',
        );
      }
      throw NetworkException(
        'Failed to send friend request: ${e.message}',
        recoverySuggestion: 'Please try again later.',
      );
    } catch (e, stack) {
      if (e is ValidationException) rethrow;
      LoggerService.error(
        'Unexpected error sending friend request',
        error: e,
        stack: stack,
      );
      throw NetworkException(
        'Failed to send friend request',
        recoverySuggestion: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  @override
  Future<void> acceptFriendRequest({
    required String requestId,
    required String userId,
    required String fromUserId,
    String? fromDisplayName,
    String? fromEmail,
  }) async {
    if (!isAvailable) {
      throw NetworkException(
        'Firebase is not available',
        recoverySuggestion:
            'Please check your internet connection and try again.',
      );
    }

    try {
      final requestDoc = await _firestore
          .collection('friend_requests')
          .doc(requestId)
          .get()
          .timeout(_timeout);

      if (!requestDoc.exists) {
        throw ValidationException(
          'Friend request not found',
          recoverySuggestion: 'This friend request may have been cancelled.',
        );
      }

      final data = requestDoc.data();
      if (data == null) {
        throw ValidationException(
          'Friend request data not found',
          recoverySuggestion: 'Please try again.',
        );
      }

      // Update request status
      await _firestore.collection('friend_requests').doc(requestId).update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      }).timeout(_timeout);

      // Create friend relationship (bidirectional)
      final batch = _firestore.batch();

      // Friend 1 -> Friend 2
      final friend1Ref = _firestore.collection('friends').doc();
      batch.set(friend1Ref, {
        'userId': userId,
        'friendId': fromUserId,
        'friendDisplayName': fromDisplayName ?? data['fromDisplayName'],
        'friendEmail': fromEmail ?? data['fromEmail'],
        'status': 'accepted',
        'addedAt': FieldValue.serverTimestamp(),
      });

      // Friend 2 -> Friend 1
      final friend2Ref = _firestore.collection('friends').doc();
      batch.set(friend2Ref, {
        'userId': fromUserId,
        'friendId': userId,
        'friendDisplayName': data['toDisplayName'],
        'friendEmail': data['toEmail'],
        'status': 'accepted',
        'addedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit().timeout(_timeout);
    } on TimeoutException {
      LoggerService.error(
        'Firestore accept friend request timeout',
      );
      throw NetworkException(
        'Request timed out while accepting friend request',
        recoverySuggestion: 'Please check your connection and try again.',
      );
    } on FirebaseException catch (e) {
      LoggerService.error(
        'Firebase error accepting friend request',
        error: e,
      );
      if (e.code == 'permission-denied') {
        throw PermissionException(
          'Permission denied accepting friend request',
          recoverySuggestion:
              'Please check your account permissions and try again.',
        );
      }
      throw NetworkException(
        'Failed to accept friend request: ${e.message}',
        recoverySuggestion: 'Please try again later.',
      );
    } catch (e, stack) {
      if (e is ValidationException) rethrow;
      LoggerService.error(
        'Unexpected error accepting friend request',
        error: e,
        stack: stack,
      );
      throw NetworkException(
        'Failed to accept friend request',
        recoverySuggestion: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  @override
  Future<void> rejectFriendRequest(String requestId) async {
    if (!isAvailable) {
      throw NetworkException(
        'Firebase is not available',
        recoverySuggestion:
            'Please check your internet connection and try again.',
      );
    }

    try {
      await _firestore.collection('friend_requests').doc(requestId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      }).timeout(_timeout);
    } on TimeoutException {
      LoggerService.error(
        'Firestore reject friend request timeout',
      );
      throw NetworkException(
        'Request timed out while rejecting friend request',
        recoverySuggestion: 'Please check your connection and try again.',
      );
    } on FirebaseException catch (e) {
      LoggerService.error(
        'Firebase error rejecting friend request',
        error: e,
      );
      throw StorageException(
        'Failed to reject friend request: ${e.message}',
        recoverySuggestion: 'Please try again later.',
      );
    } catch (e, stack) {
      LoggerService.error(
        'Unexpected error rejecting friend request',
        error: e,
        stack: stack,
      );
      throw StorageException(
        'Failed to reject friend request',
        recoverySuggestion: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  @override
  Future<void> removeFriend({
    required String userId,
    required String friendUserId,
  }) async {
    if (!isAvailable) {
      throw NetworkException(
        'Firebase is not available',
        recoverySuggestion:
            'Please check your internet connection and try again.',
      );
    }

    try {
      // Remove bidirectional friendship
      final batch = _firestore.batch();

      final friend1 = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: userId)
          .where('friendId', isEqualTo: friendUserId)
          .get()
          .timeout(_timeout);

      final friend2 = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: friendUserId)
          .where('friendId', isEqualTo: userId)
          .get()
          .timeout(_timeout);

      for (final doc in friend1.docs) {
        batch.delete(doc.reference);
      }
      for (final doc in friend2.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit().timeout(_timeout);
    } on TimeoutException {
      LoggerService.error(
        'Firestore remove friend timeout',
      );
      throw NetworkException(
        'Request timed out while removing friend',
        recoverySuggestion: 'Please check your connection and try again.',
      );
    } on FirebaseException catch (e) {
      LoggerService.error(
        'Firebase error removing friend',
        error: e,
      );
      throw StorageException(
        'Failed to remove friend: ${e.message}',
        recoverySuggestion: 'Please try again later.',
      );
    } catch (e, stack) {
      LoggerService.error(
        'Unexpected error removing friend',
        error: e,
        stack: stack,
      );
      throw StorageException(
        'Failed to remove friend',
        recoverySuggestion: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  @override
  Future<void> blockUser({
    required String userId,
    required String blockedUserId,
  }) async {
    if (!isAvailable) {
      throw NetworkException(
        'Firebase is not available',
        recoverySuggestion:
            'Please check your internet connection and try again.',
      );
    }

    try {
      // Add to blocked list
      await _firestore
          .collection('user_blocks')
          .doc('$userId-$blockedUserId')
          .set({
        'userId': userId,
        'blockedUserId': blockedUserId,
        'blockedAt': FieldValue.serverTimestamp(),
      }).timeout(_timeout);
    } on TimeoutException {
      LoggerService.error(
        'Firestore block user timeout',
      );
      throw NetworkException(
        'Request timed out while blocking user',
        recoverySuggestion: 'Please check your connection and try again.',
      );
    } on FirebaseException catch (e) {
      LoggerService.error(
        'Firebase error blocking user',
        error: e,
      );
      throw StorageException(
        'Failed to block user: ${e.message}',
        recoverySuggestion: 'Please try again later.',
      );
    } catch (e, stack) {
      LoggerService.error(
        'Unexpected error blocking user',
        error: e,
        stack: stack,
      );
      throw StorageException(
        'Failed to block user',
        recoverySuggestion: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  @override
  Future<void> unblockUser({
    required String userId,
    required String unblockedUserId,
  }) async {
    if (!isAvailable) {
      throw NetworkException(
        'Firebase is not available',
        recoverySuggestion:
            'Please check your internet connection and try again.',
      );
    }

    try {
      await _firestore
          .collection('user_blocks')
          .doc('$userId-$unblockedUserId')
          .delete()
          .timeout(_timeout);
    } on TimeoutException {
      LoggerService.error(
        'Firestore unblock user timeout',
      );
      throw NetworkException(
        'Request timed out while unblocking user',
        recoverySuggestion: 'Please check your connection and try again.',
      );
    } on FirebaseException catch (e) {
      LoggerService.error(
        'Firebase error unblocking user',
        error: e,
      );
      throw StorageException(
        'Failed to unblock user: ${e.message}',
        recoverySuggestion: 'Please try again later.',
      );
    } catch (e, stack) {
      LoggerService.error(
        'Unexpected error unblocking user',
        error: e,
        stack: stack,
      );
      throw StorageException(
        'Failed to unblock user',
        recoverySuggestion: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  @override
  Future<bool> isUserBlocked({
    required String userId,
    required String userIdToCheck,
  }) async {
    if (!isAvailable) {
      return false;
    }

    try {
      final blockDoc = await _firestore
          .collection('user_blocks')
          .doc('$userId-$userIdToCheck')
          .get()
          .timeout(_timeout);
      return blockDoc.exists;
    } on TimeoutException {
      LoggerService.error(
        'Firestore check blocked user timeout',
      );
      return false; // Default to not blocked on timeout
    } catch (e) {
      LoggerService.error(
        'Error checking if user is blocked',
        error: e,
      );
      return false; // Default to not blocked on error
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getFriendSuggestions({
    required String userId,
    required Set<String> excludeUserIds,
    int limit = 5,
  }) async {
    if (!isAvailable) {
      return [];
    }

    try {
      // Get random users (excluding friends and self)
      final suggestionsSnapshot = await _firestore
          .collection('user_profiles')
          .limit(20)
          .get()
          .timeout(_timeout);

      final suggestions = <Map<String, dynamic>>[];
      for (final doc in suggestionsSnapshot.docs) {
        if (!excludeUserIds.contains(doc.id)) {
          final data = doc.data();
          suggestions.add({
            'userId': doc.id,
            'email': data['email'],
            'displayName': data['displayName'],
          });
          if (suggestions.length >= limit) break;
        }
      }

      return suggestions;
    } on TimeoutException {
      LoggerService.error(
        'Firestore get friend suggestions timeout',
      );
      return [];
    } catch (e) {
      LoggerService.error(
        'Error getting friend suggestions',
        error: e,
      );
      return [];
    }
  }

  @override
  Future<void> sendInvitation({
    required String fromUserId,
    required String toEmail,
  }) async {
    if (!isAvailable) {
      throw NetworkException(
        'Firebase is not available',
        recoverySuggestion:
            'Please check your internet connection and try again.',
      );
    }

    try {
      // Create invitation record in Firestore
      await _firestore.collection('invitations').add({
        'fromUserId': fromUserId,
        'toEmail': toEmail,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      }).timeout(_timeout);
    } on TimeoutException {
      LoggerService.error(
        'Firestore send invitation timeout',
      );
      throw NetworkException(
        'Request timed out while sending invitation',
        recoverySuggestion: 'Please check your connection and try again.',
      );
    } on FirebaseException catch (e) {
      LoggerService.error(
        'Firebase error sending invitation',
        error: e,
      );
      throw StorageException(
        'Failed to send invitation: ${e.message}',
        recoverySuggestion: 'Please try again later.',
      );
    } catch (e, stack) {
      LoggerService.error(
        'Unexpected error sending invitation',
        error: e,
        stack: stack,
      );
      throw StorageException(
        'Failed to send invitation',
        recoverySuggestion: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  @override
  Future<void> reportUser({
    required String reporterUserId,
    required String reportedUserId,
    required String reason,
  }) async {
    if (!isAvailable) {
      throw NetworkException(
        'Firebase is not available',
        recoverySuggestion:
            'Please check your internet connection and try again.',
      );
    }

    if (reporterUserId == reportedUserId) {
      throw ValidationException(
        'Cannot report yourself',
        recoverySuggestion: 'You cannot report your own account.',
      );
    }

    try {
      // Save report to Firestore
      await _firestore.collection('user_reports').add({
        'reporterUserId': reporterUserId,
        'reportedUserId': reportedUserId,
        'reason': reason,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      }).timeout(_timeout);
    } on TimeoutException {
      LoggerService.error(
        'Firestore report user timeout',
      );
      throw NetworkException(
        'Request timed out while reporting user',
        recoverySuggestion: 'Please check your connection and try again.',
      );
    } on FirebaseException catch (e) {
      LoggerService.error(
        'Firebase error reporting user',
        error: e,
      );
      throw StorageException(
        'Failed to report user: ${e.message}',
        recoverySuggestion: 'Please try again later.',
      );
    } catch (e, stack) {
      if (e is ValidationException) rethrow;
      LoggerService.error(
        'Unexpected error reporting user',
        error: e,
        stack: stack,
      );
      throw StorageException(
        'Failed to report user',
        recoverySuggestion: 'An unexpected error occurred. Please try again.',
      );
    }
  }
}
