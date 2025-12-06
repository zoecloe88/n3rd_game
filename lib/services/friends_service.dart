import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:n3rd_game/models/friend.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';

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
        .listen((snapshot) {
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
        });
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
        .listen((snapshot) {
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
        });
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
      'fromDisplayName': currentUserEmail?.split('@').first,
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

    final requestDoc = await firestore
        .collection('friend_requests')
        .doc(requestId)
        .get();
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
      'friendDisplayName': currentUser?.email?.split('@').first,
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

  @override
  void dispose() {
    _friendsSubscription?.cancel();
    _requestsSubscription?.cancel();
    super.dispose();
  }
}
