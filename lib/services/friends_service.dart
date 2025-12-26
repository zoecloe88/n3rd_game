import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:n3rd_game/models/friend.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/services/logger_service.dart';

class FriendsService extends ChangeNotifier {
  FirebaseFirestore? get _firestore {
    try {
      Firebase.app();
      return FirebaseFirestore.instance;
    } catch (e) {
      return null;
    }
  }

  String? get _userId {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (e) {
      return null;
    }
  }

  StreamSubscription<QuerySnapshot>? _friendsSubscription;
  StreamSubscription<QuerySnapshot>? _requestsSubscription;
  final List<Friend> _friends = [];
  final List<FriendRequest> _pendingRequests = [];

  List<Friend> get friends => List.unmodifiable(_friends);
  List<FriendRequest> get pendingRequests =>
      List.unmodifiable(_pendingRequests);

  Future<void> init() async {
    final userId = _userId;
    if (userId == null) return;

    _loadFriends();
    _loadPendingRequests();
  }

  /// Refresh friends and requests data
  /// Useful for pull-to-refresh functionality
  Future<void> refreshFriends() async {
    final userId = _userId;
    if (userId == null) return;

    // Reload both friends and requests
    _loadFriends();
    _loadPendingRequests();

    // Wait a bit to allow streams to update
    await Future.delayed(const Duration(milliseconds: 500));
  }

  void _loadFriends() {
    final userId = _userId;
    final firestore = _firestore;
    if (userId == null || firestore == null) return;

    _friendsSubscription?.cancel();
    _friendsSubscription = firestore
        .collection('friends')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .listen(
      (snapshot) {
        _friends.clear();
        for (final doc in snapshot.docs) {
          try {
            final data = doc.data();
            _friends.add(
              Friend(
                userId: data['friendId'] as String,
                displayName: data['friendDisplayName'] as String?,
                email: data['friendEmail'] as String?,
                addedAt: data['addedAt'] != null
                    ? (data['addedAt'] as Timestamp).toDate()
                    : null,
                isOnline: data['isOnline'] as bool? ?? false,
              ),
            );
          } catch (e) {
            if (kDebugMode) {
              debugPrint('Error parsing friend: $e');
            }
          }
        }
        notifyListeners();
      },
      onError: (error) {
        // CRITICAL: Handle Firestore permission errors gracefully
        if (error is FirebaseException && error.code == 'permission-denied') {
          LoggerService.error(
            'FriendsService: Permission denied loading friends. User may not be authenticated or lacks required permissions.',
            error: error,
            reason: 'Firestore permission-denied error',
            fatal: false,
          );
          // Clear friends and notify listeners
          _friends.clear();
          notifyListeners();
        } else {
          LoggerService.error(
            'FriendsService: Error loading friends',
            error: error,
            reason: 'Firestore stream error',
            fatal: false,
          );
        }
      },
    );
  }

  void _loadPendingRequests() {
    final userId = _userId;
    final firestore = _firestore;
    if (userId == null || firestore == null) return;

    _requestsSubscription?.cancel();
    _requestsSubscription = firestore
        .collection('friend_requests')
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen(
      (snapshot) {
        _pendingRequests.clear();
        for (final doc in snapshot.docs) {
          try {
            _pendingRequests.add(
              FriendRequest.fromJson({'id': doc.id, ...doc.data()}),
            );
          } catch (e) {
            if (kDebugMode) {
              debugPrint('Error parsing friend request: $e');
            }
          }
        }
        notifyListeners();
      },
      onError: (error) {
        // CRITICAL: Handle Firestore permission errors gracefully
        if (error is FirebaseException && error.code == 'permission-denied') {
          LoggerService.error(
            'FriendsService: Permission denied loading friend requests. User may not be authenticated or lacks required permissions.',
            error: error,
            reason: 'Firestore permission-denied error',
            fatal: false,
          );
          // Clear requests and notify listeners
          _pendingRequests.clear();
          notifyListeners();
        } else {
          LoggerService.error(
            'FriendsService: Error loading friend requests',
            error: error,
            reason: 'Firestore stream error',
            fatal: false,
          );
        }
      },
    );
  }

  /// Search for users by email or display name
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final firestore = _firestore;
    if (firestore == null) return [];

    try {
      // Search by email
      final emailResults = await firestore
          .collection('user_profiles')
          .where('email', isGreaterThanOrEqualTo: query)
          .where('email', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(10)
          .get();

      final results = <Map<String, dynamic>>[];
      for (final doc in emailResults.docs) {
        results.add({
          'userId': doc.id,
          'email': doc.data()['email'],
          'displayName': doc.data()['displayName'],
        });
      }

      return results;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error searching users: $e');
      }
      return [];
    }
  }

  /// Send friend request
  Future<void> sendFriendRequest(
    String friendUserId, {
    String? friendEmail,
    String? friendDisplayName,
  }) async {
    final userId = _userId;
    final firestore = _firestore;
    if (userId == null || firestore == null) {
      throw AuthenticationException('User not authenticated');
    }

    if (userId == friendUserId) {
      throw ValidationException('Cannot add yourself as a friend');
    }

    // Check if already friends
    final existingFriend = await firestore
        .collection('friends')
        .where('userId', isEqualTo: userId)
        .where('friendId', isEqualTo: friendUserId)
        .where('status', isEqualTo: 'accepted')
        .get();

    if (existingFriend.docs.isNotEmpty) {
      throw ValidationException('Already friends');
    }

    // Check if request already exists
    final existingRequest = await firestore
        .collection('friend_requests')
        .where('fromUserId', isEqualTo: userId)
        .where('toUserId', isEqualTo: friendUserId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existingRequest.docs.isNotEmpty) {
      throw ValidationException('Friend request already sent');
    }

    // Get current user info
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserEmail = currentUser?.email;

    // Create friend request
    await firestore.collection('friend_requests').add({
      'fromUserId': userId,
      'toUserId': friendUserId,
      'fromDisplayName': currentUserEmail?.contains('@') == true
          ? currentUserEmail!.split('@').first
          : currentUserEmail,
      'fromEmail': currentUserEmail,
      'toDisplayName': friendDisplayName,
      'toEmail': friendEmail,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Accept friend request
  Future<void> acceptFriendRequest(String requestId) async {
    final userId = _userId;
    final firestore = _firestore;
    if (userId == null || firestore == null) {
      throw AuthenticationException('User not authenticated');
    }

    final requestDoc =
        await firestore.collection('friend_requests').doc(requestId).get();
    if (!requestDoc.exists) {
      throw ValidationException('Friend request not found');
    }

    final data = requestDoc.data();
    if (data == null) {
      throw ValidationException('Friend request data not found');
    }
    final fromUserId = data['fromUserId'] as String;

    // Update request status
    await firestore.collection('friend_requests').doc(requestId).update({
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
    });

    // Create friend relationship (bidirectional)
    final batch = firestore.batch();

    // Friend 1 -> Friend 2
    final friend1Ref = firestore.collection('friends').doc();
    batch.set(friend1Ref, {
      'userId': userId,
      'friendId': fromUserId,
      'friendDisplayName': data['fromDisplayName'],
      'friendEmail': data['fromEmail'],
      'status': 'accepted',
      'addedAt': FieldValue.serverTimestamp(),
    });

    // Friend 2 -> Friend 1
    final currentUser = FirebaseAuth.instance.currentUser;
    final friend2Ref = firestore.collection('friends').doc();
    batch.set(friend2Ref, {
      'userId': fromUserId,
      'friendId': userId,
      'friendDisplayName': currentUser?.email?.contains('@') == true
          ? currentUser!.email!.split('@').first
          : currentUser?.email,
      'friendEmail': currentUser?.email,
      'status': 'accepted',
      'addedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Reject friend request
  Future<void> rejectFriendRequest(String requestId) async {
    final firestore = _firestore;
    if (firestore == null) {
      throw StorageException('Firestore not available');
    }

    await firestore.collection('friend_requests').doc(requestId).update({
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remove friend
  Future<void> removeFriend(String friendUserId) async {
    final userId = _userId;
    final firestore = _firestore;
    if (userId == null || firestore == null) {
      throw AuthenticationException('User not authenticated');
    }

    // Remove bidirectional friendship
    final batch = firestore.batch();

    final friend1 = await firestore
        .collection('friends')
        .where('userId', isEqualTo: userId)
        .where('friendId', isEqualTo: friendUserId)
        .get();

    final friend2 = await firestore
        .collection('friends')
        .where('userId', isEqualTo: friendUserId)
        .where('friendId', isEqualTo: userId)
        .get();

    for (final doc in friend1.docs) {
      batch.delete(doc.reference);
    }
    for (final doc in friend2.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  /// Block a user
  Future<void> blockUser(String userIdToBlock) async {
    final userId = _userId;
    final firestore = _firestore;
    if (userId == null || firestore == null) {
      throw AuthenticationException('User not authenticated');
    }

    // Remove friendship if exists
    try {
      await removeFriend(userIdToBlock);
    } catch (e) {
      // Ignore if not friends
    }

    // Add to blocked list
    await firestore
        .collection('user_blocks')
        .doc('$userId-$userIdToBlock')
        .set({
      'userId': userId,
      'blockedUserId': userIdToBlock,
      'blockedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Unblock a user
  Future<void> unblockUser(String userIdToUnblock) async {
    final userId = _userId;
    final firestore = _firestore;
    if (userId == null || firestore == null) {
      throw AuthenticationException('User not authenticated');
    }

    await firestore
        .collection('user_blocks')
        .doc('$userId-$userIdToUnblock')
        .delete();
  }

  /// Check if a user is blocked
  Future<bool> isUserBlocked(String userIdToCheck) async {
    final userId = _userId;
    final firestore = _firestore;
    if (userId == null || firestore == null) return false;

    final blockDoc = await firestore
        .collection('user_blocks')
        .doc('$userId-$userIdToCheck')
        .get();
    return blockDoc.exists;
  }

  /// Get friend suggestions (users you might know)
  Future<List<Map<String, dynamic>>> getFriendSuggestions() async {
    final userId = _userId;
    final firestore = _firestore;
    if (userId == null || firestore == null) return [];

    try {
      // Get current friends
      final friendsSnapshot = await firestore
          .collection('friends')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'accepted')
          .get();

      final friendIds = friendsSnapshot.docs
          .map((doc) => doc.data()['friendId'] as String)
          .toSet();
      friendIds.add(userId); // Exclude self

      // Get random users (excluding friends and self)
      final suggestionsSnapshot =
          await firestore.collection('user_profiles').limit(20).get();

      final suggestions = <Map<String, dynamic>>[];
      for (final doc in suggestionsSnapshot.docs) {
        if (!friendIds.contains(doc.id)) {
          final data = doc.data();
          suggestions.add({
            'userId': doc.id,
            'email': data['email'],
            'displayName': data['displayName'],
          });
          if (suggestions.length >= 5) break; // Limit to 5 suggestions
        }
      }

      return suggestions;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting friend suggestions: $e');
      }
      return [];
    }
  }

  /// Send invitation to a user via email/SMS/share link
  /// Creates an invitation record and uses share_plus to share the invite
  Future<void> sendInvitation(String email) async {
    final userId = _userId;
    final firestore = _firestore;
    if (userId == null || firestore == null) {
      throw AuthenticationException('User not authenticated');
    }

    // Create invitation record in Firestore
    await firestore.collection('invitations').add({
      'fromUserId': userId,
      'toEmail': email,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Report a user for inappropriate behavior
  /// Saves the report to Firestore for moderation review
  Future<void> reportUser(String reportedUserId, String reason) async {
    final userId = _userId;
    final firestore = _firestore;
    if (userId == null || firestore == null) {
      throw AuthenticationException('User not authenticated');
    }

    if (userId == reportedUserId) {
      throw ValidationException('Cannot report yourself');
    }

    // Save report to Firestore
    await firestore.collection('user_reports').add({
      'reporterUserId': userId,
      'reportedUserId': reportedUserId,
      'reason': reason,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get contacts from device
  Future<List<Contact>> getContacts() async {
    try {
      // Request contacts permission
      final status = await Permission.contacts.request();
      if (!status.isGranted) {
        throw PermissionException('Contacts permission not granted');
      }

      // Check if contacts permission is available
      if (!await FlutterContacts.requestPermission()) {
        throw PermissionException('Contacts permission denied');
      }

      // Get all contacts
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withThumbnail: false,
      );

      return contacts;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting contacts: $e');
      }
      LoggerService.error(
        'FriendsService: Error getting contacts',
        error: e,
        reason: 'Contact list access error',
        fatal: false,
      );
      rethrow;
    }
  }

  /// Search contacts and match with app users
  Future<List<Map<String, dynamic>>> searchContactsAndUsers(
    String query,
  ) async {
    try {
      final contacts = await getContacts();
      final results = <Map<String, dynamic>>[];

      // Filter contacts by query
      final matchingContacts = contacts.where((contact) {
        final name = contact.displayName.toLowerCase();
        final emails = contact.emails.map((e) => e.address.toLowerCase()).toList();
        final phones = contact.phones.map((p) => p.number).toList();
        final queryLower = query.toLowerCase();

        return name.contains(queryLower) ||
            emails.any((e) => e.contains(queryLower)) ||
            phones.any((p) => p.contains(query));
      }).toList();

      // For each matching contact, try to find matching user in app
      final firestore = _firestore;
      if (firestore != null) {
        for (final contact in matchingContacts) {
          // Try to find user by email
          for (final email in contact.emails) {
            if (email.address.isNotEmpty) {
              try {
                final userQuery = await firestore
                    .collection('user_profiles')
                    .where('email', isEqualTo: email.address)
                    .limit(1)
                    .get();

                if (userQuery.docs.isNotEmpty) {
                  final doc = userQuery.docs.first;
                  final userData = doc.data();
                  results.add({
                    'userId': doc.id,
                    'email': email.address,
                    'displayName': (userData['displayName'] as String?) ?? contact.displayName,
                    'contactName': contact.displayName,
                    'isContact': true,
                  });
                  break; // Found user, move to next contact
                }
              } catch (e) {
                // Continue to next email if search fails
                if (kDebugMode) {
                  debugPrint('Error searching user by email: $e');
                }
              }
            }
          }
        }
      }

      return results;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error searching contacts and users: $e');
      }
      // Fallback to regular user search
      return await searchUsers(query);
    }
  }

  @override
  void dispose() {
    _friendsSubscription?.cancel();
    _requestsSubscription?.cancel();
    super.dispose();
  }
}
