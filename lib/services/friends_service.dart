import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:n3rd_game/models/friend.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/utils/list_helper.dart';
import 'package:n3rd_game/utils/firebase_helper.dart';
import 'package:n3rd_game/utils/firestore_error_handler.dart';

class FriendsService extends ChangeNotifier {
  FirebaseFirestore? get _firestore {
    if (!FirebaseHelper.isInitialized()) {
      return null;
    }
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      return null;
    }
  }

  String? get _userId {
    if (!FirebaseHelper.isInitialized()) {
      return null;
    }
    try {
      return FirebaseHelper.getCurrentUser()?.uid;
    } catch (e) {
      return null;
    }
  }

  StreamSubscription<QuerySnapshot>? _friendsSubscription;
  StreamSubscription<QuerySnapshot>? _requestsSubscription;
  final List<Friend> _friends = [];
  final List<FriendRequest> _pendingRequests = [];

  // Pagination state
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastFriendDocument;
  static const int _pageSize = 20;

  List<Friend> get friends => List.unmodifiable(_friends);
  List<FriendRequest> get pendingRequests =>
      List.unmodifiable(_pendingRequests);

  bool get isLoadingMoreFriends => _isLoadingMore;
  bool get hasMoreFriends => _hasMore;

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
    _lastFriendDocument = null;
    _hasMore = true;

    final Query query = firestore
        .collection('friends')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'accepted')
        .orderBy('addedAt', descending: true)
        .limit(_pageSize);

    _friendsSubscription = query.snapshots().listen(
      (snapshot) {
        _friends.clear();
        for (final doc in snapshot.docs) {
          try {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) continue;
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
            LoggerService.error('Error parsing friend', error: e);
          }
        }

        // Update pagination state
        if (snapshot.docs.isNotEmpty) {
          final lastDoc = ListHelper.safeLast(snapshot.docs);
          if (lastDoc != null) {
            _lastFriendDocument = lastDoc;
          }
          _hasMore = snapshot.docs.length >= _pageSize;
        } else {
          _hasMore = false;
        }

        notifyListeners();
      },
      onError: (error) {
        FirestoreErrorHandler.handleStreamError(
          error,
          'FriendsService',
          'loading friends',
          clearData: () {
            _friends.clear();
            _hasMore = false;
          },
          notifyListeners: notifyListeners,
        );
      },
    );
  }

  /// Load more friends using pagination
  Future<void> loadMoreFriends() async {
    if (_isLoadingMore || !_hasMore) return;

    final userId = _userId;
    final firestore = _firestore;
    if (userId == null || firestore == null || _lastFriendDocument == null) {
      _hasMore = false;
      return;
    }

    _isLoadingMore = true;
    notifyListeners();

    try {
      final Query query = firestore
          .collection('friends')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'accepted')
          .orderBy('addedAt', descending: true)
          .startAfterDocument(_lastFriendDocument!)
          .limit(_pageSize);

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        _hasMore = false;
      } else {
        for (final doc in snapshot.docs) {
          try {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) continue;
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
            LoggerService.error('Error parsing friend', error: e);
          }
        }

        final lastDoc = ListHelper.safeLast(snapshot.docs);
        if (lastDoc != null) {
          _lastFriendDocument = lastDoc;
        }
        _hasMore = snapshot.docs.length >= _pageSize;
      }
    } catch (e) {
      LoggerService.error(
        'FriendsService: Error loading more friends',
        error: e,
        reason: 'Pagination query error',
        fatal: false,
      );
      _hasMore = false;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
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
            LoggerService.error('Error parsing friend request', error: e);
          }
        }
        notifyListeners();
      },
      onError: (error) {
        FirestoreErrorHandler.handleStreamError(
          error,
          'FriendsService',
          'loading friend requests',
          clearData: () {
            _pendingRequests.clear();
          },
          notifyListeners: notifyListeners,
        );
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
      LoggerService.error('Error searching users', error: e);
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
  /// Uses smart algorithm: mutual friends, similar activity, leaderboard proximity
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

      final suggestions = <Map<String, dynamic>>[];
      final suggestionScores = <String, int>{};

      // 1. Get mutual friends (friends of friends)
      if (friendIds.length > 1) {
        final mutualFriendsQuery = await firestore
            .collection('friends')
            .where('userId', whereIn: friendIds.where((id) => id != userId).take(10).toList())
            .where('status', isEqualTo: 'accepted')
            .limit(50)
            .get();

        for (final doc in mutualFriendsQuery.docs) {
          final friendId = doc.data()['friendId'] as String;
          if (!friendIds.contains(friendId)) {
            final score = suggestionScores[friendId] ?? 0;
            suggestionScores[friendId] = score + 10; // High weight for mutual friends
          }
        }
      }

      // 2. Get users with similar leaderboard rank (within 50 ranks)
      try {
        final userProfile = await firestore.collection('user_profiles').doc(userId).get();
        if (userProfile.exists) {
          final userData = userProfile.data();
          final userScore = (userData?['totalScore'] as int?) ?? 0;
          
          // Get users with similar scores (within 20% range)
          final minScore = (userScore * 0.8).round();
          final maxScore = (userScore * 1.2).round();
          
          final similarScoreUsers = await firestore
              .collection('user_profiles')
              .where('totalScore', isGreaterThanOrEqualTo: minScore)
              .where('totalScore', isLessThanOrEqualTo: maxScore)
              .limit(30)
              .get();

          for (final doc in similarScoreUsers.docs) {
            if (!friendIds.contains(doc.id)) {
              final score = suggestionScores[doc.id] ?? 0;
              suggestionScores[doc.id] = score + 5; // Medium weight for similar activity
            }
          }
        }
      } catch (e) {
        LoggerService.warning('Error getting similar score users for suggestions', error: e);
      }

      // 3. Get users who play similar game modes (if game history exists)
      try {
        final userGameHistory = await firestore
            .collection('game_history')
            .where('userId', isEqualTo: userId)
            .orderBy('playedAt', descending: true)
            .limit(10)
            .get();

        if (userGameHistory.docs.isNotEmpty) {
          // Get most played game modes
          final modeCounts = <String, int>{};
          for (final doc in userGameHistory.docs) {
            final mode = doc.data()['gameMode'] as String?;
            if (mode != null) {
              modeCounts[mode] = (modeCounts[mode] ?? 0) + 1;
            }
          }

          if (modeCounts.isNotEmpty) {
            final topMode = modeCounts.entries
                .reduce((a, b) => a.value > b.value ? a : b)
                .key;

            // Find users who also play this mode
            final similarModeUsers = await firestore
                .collection('game_history')
                .where('gameMode', isEqualTo: topMode)
                .limit(20)
                .get();

            for (final doc in similarModeUsers.docs) {
              final otherUserId = doc.data()['userId'] as String?;
              if (otherUserId != null && !friendIds.contains(otherUserId)) {
                final score = suggestionScores[otherUserId] ?? 0;
                suggestionScores[otherUserId] = score + 3; // Lower weight for similar modes
              }
            }
          }
        }
      } catch (e) {
        LoggerService.warning('Error getting similar game mode users for suggestions', error: e);
      }

      // 4. Get user profiles for all suggested user IDs
      final suggestedUserIds = suggestionScores.keys.toList();
      if (suggestedUserIds.isNotEmpty) {
        // Sort by score (highest first)
        suggestedUserIds.sort((a, b) => (suggestionScores[b] ?? 0).compareTo(suggestionScores[a] ?? 0));
        
        // Get top 10
        final topUserIds = suggestedUserIds.take(10).toList();
        
        // Batch get user profiles
        for (final uid in topUserIds) {
          try {
            final userDoc = await firestore.collection('user_profiles').doc(uid).get();
            if (userDoc.exists) {
              final data = userDoc.data();
              suggestions.add({
                'userId': uid,
                'email': data?['email'],
                'displayName': data?['displayName'],
                'score': suggestionScores[uid] ?? 0,
              });
            }
          } catch (e) {
            LoggerService.warning('Error getting user profile for suggestion: $uid', error: e);
          }
        }
      }

      // 5. Fallback: If we don't have enough suggestions, add random users
      if (suggestions.length < 5) {
        final randomUsersSnapshot =
            await firestore.collection('user_profiles').limit(20).get();

        for (final doc in randomUsersSnapshot.docs) {
          if (suggestions.length >= 10) break;
          if (!friendIds.contains(doc.id) &&
              !suggestions.any((s) => s['userId'] == doc.id)) {
            final data = doc.data();
            suggestions.add({
              'userId': doc.id,
              'email': data['email'],
              'displayName': data['displayName'],
              'score': 1, // Low score for random users
            });
          }
        }
      }

      // Sort by score and return top 10
      suggestions.sort((a, b) => ((b['score'] as int?) ?? 0).compareTo((a['score'] as int?) ?? 0));
      return suggestions.take(10).toList();
    } catch (e) {
      LoggerService.error('Error getting friend suggestions', error: e);
      // Fallback to random users on error
      try {
        final friendsSnapshot = await firestore
            .collection('friends')
            .where('userId', isEqualTo: userId)
            .where('status', isEqualTo: 'accepted')
            .get();

        final friendIds = friendsSnapshot.docs
            .map((doc) => doc.data()['friendId'] as String)
            .toSet();
        friendIds.add(userId);

        final randomUsersSnapshot =
            await firestore.collection('user_profiles').limit(20).get();

        final fallbackSuggestions = <Map<String, dynamic>>[];
        for (final doc in randomUsersSnapshot.docs) {
          if (fallbackSuggestions.length >= 5) break;
          if (!friendIds.contains(doc.id)) {
            final data = doc.data();
            fallbackSuggestions.add({
              'userId': doc.id,
              'email': data['email'],
              'displayName': data['displayName'],
            });
          }
        }
        return fallbackSuggestions;
      } catch (fallbackError) {
        LoggerService.error('Error in fallback friend suggestions', error: fallbackError);
        return [];
      }
    }
  }

  /// Generate unique invite code for current user
  /// Creates or retrieves existing invite code from Firestore
  Future<String> generateInviteCode() async {
    final userId = _userId;
    final firestore = _firestore;
    if (userId == null || firestore == null) {
      throw AuthenticationException('User not authenticated');
    }

    try {
      // Check if user already has an invite code
      final inviteCodeDoc = await firestore
          .collection('user_invite_codes')
          .doc(userId)
          .get();

      if (inviteCodeDoc.exists) {
        final data = inviteCodeDoc.data();
        final code = data?['code'] as String?;
        final expiresAt = data?['expiresAt'] as Timestamp?;
        
        // Check if code is still valid (24 hours)
        if (code != null && expiresAt != null) {
          final expiresDate = expiresAt.toDate();
          if (expiresDate.isAfter(DateTime.now())) {
            return code;
          }
        }
      }

      // Generate new invite code (6 character alphanumeric)
      final random = DateTime.now().millisecondsSinceEpoch;
      final code = 'N3RD${random.toString().substring(random.toString().length - 6).toUpperCase()}';
      
      // Store invite code with 24 hour expiration
      await firestore.collection('user_invite_codes').doc(userId).set({
        'code': code,
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
      });

      return code;
    } catch (e) {
      LoggerService.error('Error generating invite code', error: e);
      // Fallback: use userId as code
      return userId.substring(0, userId.length > 8 ? 8 : userId.length).toUpperCase();
    }
  }

  /// Send invitation to a user via email/SMS/share link
  /// Creates an invitation record and uses share_plus to share the invite
  Future<void> sendInvitation(String? email) async {
    final userId = _userId;
    final firestore = _firestore;
    if (userId == null || firestore == null) {
      throw AuthenticationException('User not authenticated');
    }

    // Generate invite code
    final inviteCode = await generateInviteCode();

    // Create invitation record in Firestore (email optional for non-email methods)
    if (email != null && email.isNotEmpty) {
      await firestore.collection('invitations').add({
        'fromUserId': userId,
        'toEmail': email,
        'inviteCode': inviteCode,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Store invite code even without email
      await firestore.collection('invitations').add({
        'fromUserId': userId,
        'inviteCode': inviteCode,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
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
      LoggerService.error('Error getting contacts', error: e);
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
        final emails =
            contact.emails.map((e) => e.address.toLowerCase()).toList();
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
                  final doc = ListHelper.safeFirst(userQuery.docs);
                  if (doc == null) {
                    LoggerService.warning('User query returned empty docs list');
                    continue;
                  }
                  final userData = doc.data();
                  results.add({
                    'userId': doc.id,
                    'email': email.address,
                    'displayName': (userData['displayName'] as String?) ??
                        contact.displayName,
                    'contactName': contact.displayName,
                    'isContact': true,
                  });
                  break; // Found user, move to next contact
                }
              } catch (e) {
                // Continue to next email if search fails
                LoggerService.error('Error searching user by email', error: e);
              }
            }
          }
        }
      }

      return results;
    } catch (e) {
      LoggerService.error('Error searching contacts and users', error: e);
      // Fallback to regular user search
      return searchUsers(query);
    }
  }

  @override
  void dispose() {
    _friendsSubscription?.cancel();
    _requestsSubscription?.cancel();
    super.dispose();
  }
}
