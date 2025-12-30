import 'dart:async' show TimeoutException, StreamSubscription;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Newsfeed activity types
enum NewsfeedActivityType {
  achievement,
  challengeCompleted,
  highScore,
  friendRequest,
  friendAccepted,
  gameCompleted,
  multiplayerGameStarted,
  multiplayerGameCompleted,
  roomCreated,
  friendInvitedToGame,
}

/// Newsfeed activity model
class NewsfeedActivity {

  NewsfeedActivity({
    required this.id,
    required this.type,
    required this.userId,
    this.userDisplayName,
    this.userEmail,
    this.userAvatarUrl,
    this.metadata,
    required this.timestamp,
    this.isRead = false,
  });

  factory NewsfeedActivity.fromJson(Map<String, dynamic> json) {
    return NewsfeedActivity(
      id: json['id'] as String,
      type: NewsfeedActivityType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NewsfeedActivityType.gameCompleted,
      ),
      userId: json['userId'] as String,
      userDisplayName: json['userDisplayName'] as String?,
      userEmail: json['userEmail'] as String?,
      userAvatarUrl: json['userAvatarUrl'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      timestamp: (json['timestamp'] as Timestamp).toDate(),
      isRead: json['isRead'] as bool? ?? false,
    );
  }
  final String id;
  final NewsfeedActivityType type;
  final String userId;
  final String? userDisplayName;
  final String? userEmail;
  final String? userAvatarUrl;
  final Map<String, dynamic>? metadata; // Activity-specific data
  final DateTime timestamp;
  final bool isRead;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'userId': userId,
      'userDisplayName': userDisplayName,
      'userEmail': userEmail,
      'userAvatarUrl': userAvatarUrl,
      'metadata': metadata,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
    };
  }
}

/// Service for aggregating and managing newsfeed activities
class NewsfeedService extends ChangeNotifier {
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

  StreamSubscription<QuerySnapshot>? _newsfeedSubscription;
  final List<NewsfeedActivity> _activities = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  static const int _pageSize = 20;
  DateTime? _oldestTimestamp; // For pagination

  List<NewsfeedActivity> get activities => List.unmodifiable(_activities);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  int get unreadCount => _activities.where((a) => !a.isRead).length;

  /// Initialize newsfeed service
  Future<void> init() async {
    final userId = _userId;
    if (userId == null) return;

    await _loadNewsfeed();
  }

  /// Load newsfeed activities from Firestore
  Future<void> _loadNewsfeed() async {
    final userId = _userId;
    final firestore = _firestore;
    if (userId == null || firestore == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Get user's friends list
      final friendsSnapshot = await firestore
          .collection('friends')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'accepted')
          .get()
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Firestore operation timed out: friends');
        },
      );

      final friendIds = friendsSnapshot.docs
          .map((doc) => doc.data()['friendId'] as String)
          .toList();

      if (friendIds.isEmpty) {
        _activities.clear();
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Fetch recent activities from friends
      // Query newsfeed collection (if it exists) or aggregate from other collections
      final activitiesList = <NewsfeedActivity>[];

      // 1. Fetch achievements from friends (last 7 days)
      await _fetchFriendAchievements(friendIds, activitiesList);

      // 2. Fetch challenge completions from friends (last 7 days)
      await _fetchFriendChallengeCompletions(friendIds, activitiesList);

      // 3. Fetch high scores from friends (last 7 days)
      await _fetchFriendHighScores(friendIds, activitiesList);

      // 4. Fetch friend requests/accepted
      await _fetchFriendRequests(userId, activitiesList);

      // 5. Fetch multiplayer activities from friends
      await _fetchMultiplayerActivities(friendIds, activitiesList);

      // Sort by timestamp (newest first)
      activitiesList.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Pagination: Limit to page size
      final limitedActivities = activitiesList.take(_pageSize).toList();

      _activities.clear();
      _activities.addAll(limitedActivities);

      // Update pagination state
      if (limitedActivities.length < _pageSize) {
        _hasMore = false;
      } else {
        _hasMore = true;
        _oldestTimestamp = limitedActivities.last.timestamp;
      }
    } on TimeoutException catch (e) {
      LoggerService.error(
        'Firestore operation timed out: newsfeed',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
    } catch (e, stackTrace) {
      LoggerService.error(
        'Failed to load newsfeed',
        error: e,
        stack: stackTrace,
        fatal: false,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch friend achievements
  Future<void> _fetchFriendAchievements(
    List<String> friendIds,
    List<NewsfeedActivity> activitiesList, {
    DateTime? beforeDate,
  }) async {
    final firestore = _firestore;
    if (firestore == null || friendIds.isEmpty) return;

    try {
      Query query = firestore
          .collection('user_achievements')
          .where('userId',
              whereIn: friendIds.take(30).toList(),) // Firestore limit
          .where('unlockedAt',
              isGreaterThan: Timestamp.fromDate(
                  DateTime.now().subtract(const Duration(days: 30)),),)
          .orderBy('unlockedAt', descending: true)
          .limit(20);

      if (beforeDate != null) {
        query = query.where('unlockedAt',
            isLessThan: Timestamp.fromDate(beforeDate),);
      }

      final achievementsSnapshot = await query.get().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException(
              'Firestore operation timed out: user_achievements',);
        },
      );

      for (final doc in achievementsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final friendId = data['userId'] as String?;
        if (friendId == null) continue;

        // Get friend info
        final friendInfo = await _getFriendInfo(friendId);

        activitiesList.add(
          NewsfeedActivity(
            id: doc.id,
            type: NewsfeedActivityType.achievement,
            userId: friendId,
            userDisplayName: friendInfo['displayName'] as String?,
            userEmail: friendInfo['email'] as String?,
            metadata: {
              'achievementId': data['achievementId'] as String?,
              'achievementName': data['achievementName'] as String?,
              'achievementDescription':
                  data['achievementDescription'] as String?,
            },
            timestamp: (data['unlockedAt'] as Timestamp).toDate(),
          ),
        );
      }
    } on TimeoutException catch (e) {
      LoggerService.error(
        'Firestore operation timed out: friend achievements',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
    } catch (e, stackTrace) {
      LoggerService.error(
        'Failed to fetch friend achievements',
        error: e,
        stack: stackTrace,
        fatal: false,
      );
    }
  }

  /// Fetch friend challenge completions
  Future<void> _fetchFriendChallengeCompletions(
    List<String> friendIds,
    List<NewsfeedActivity> activitiesList, {
    DateTime? beforeDate,
  }) async {
    final firestore = _firestore;
    if (firestore == null || friendIds.isEmpty) return;

    try {
      final cutoffDate =
          beforeDate ?? DateTime.now().subtract(const Duration(days: 7));
      final maxDate = beforeDate ?? DateTime.now();

      // Query challenge_completions collection (if it exists)
      // Or check user_challenges collection
      final challengesSnapshot = await firestore
          .collection('user_challenges')
          .where(FieldPath.documentId, whereIn: friendIds.take(30).toList())
          .get()
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException(
              'Firestore operation timed out: user_challenges',);
        },
      );

      for (final doc in challengesSnapshot.docs) {
        final data = doc.data();
        final challenges = data['challenges'] as List?;
        if (challenges == null) continue;

        final friendId = doc.id;
        final friendInfo = await _getFriendInfo(friendId);

        // Process recent challenge completions
        for (final challengeData in challenges) {
          final challengeMap = challengeData as Map<String, dynamic>;
          final completedAt = challengeMap['completedAt'];
          if (completedAt == null) continue;

          final completedDate = (completedAt as Timestamp).toDate();
          if (completedDate.isBefore(cutoffDate)) continue;
          if (beforeDate != null && completedDate.isAfter(maxDate)) continue;

          activitiesList.add(
            NewsfeedActivity(
              id: '${doc.id}_${challengeMap['id']}',
              type: NewsfeedActivityType.challengeCompleted,
              userId: friendId,
              userDisplayName: friendInfo['displayName'] as String?,
              userEmail: friendInfo['email'] as String?,
              metadata: {
                'challengeId': challengeMap['id'],
                'challengeName': challengeMap['name'],
                'score': challengeMap['score'],
              },
              timestamp: completedDate,
            ),
          );
        }
      }
    } on TimeoutException catch (e) {
      LoggerService.error(
        'Firestore operation timed out: challenge completions',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
    } catch (e, stackTrace) {
      LoggerService.error(
        'Failed to fetch challenge completions',
        error: e,
        stack: stackTrace,
        fatal: false,
      );
    }
  }

  /// Fetch friend high scores
  Future<void> _fetchFriendHighScores(
    List<String> friendIds,
    List<NewsfeedActivity> activitiesList, {
    DateTime? beforeDate,
  }) async {
    final firestore = _firestore;
    if (firestore == null || friendIds.isEmpty) return;

    try {
      final cutoffDate =
          beforeDate ?? DateTime.now().subtract(const Duration(days: 7));
      final maxDate = beforeDate ?? DateTime.now();

      // Query game_history or stats for high scores
      final statsSnapshot = await firestore
          .collection('user_stats')
          .where(FieldPath.documentId, whereIn: friendIds.take(30).toList())
          .get()
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Firestore operation timed out: user_stats');
        },
      );

      for (final doc in statsSnapshot.docs) {
        final data = doc.data();
        final friendId = doc.id;
        final lastPlayDate = data['lastPlayDate'];

        if (lastPlayDate == null) continue;
        final lastPlay = (lastPlayDate as Timestamp).toDate();
        if (lastPlay.isBefore(cutoffDate)) continue;
        if (beforeDate != null && lastPlay.isAfter(maxDate)) continue;

        final highestScore = data['highestScore'] as int? ?? 0;
        if (highestScore == 0) continue;

        final friendInfo = await _getFriendInfo(friendId);

        activitiesList.add(
          NewsfeedActivity(
            id: '${doc.id}_highscore',
            type: NewsfeedActivityType.highScore,
            userId: friendId,
            userDisplayName: friendInfo['displayName'] as String?,
            userEmail: friendInfo['email'] as String?,
            metadata: {
              'score': highestScore,
              'mode': data['highestScoreMode'] as String?,
            },
            timestamp: lastPlay,
          ),
        );
      }
    } on TimeoutException catch (e) {
      LoggerService.error(
        'Firestore operation timed out: friend high scores',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
    } catch (e, stackTrace) {
      LoggerService.error(
        'Failed to fetch high scores',
        error: e,
        stack: stackTrace,
        fatal: false,
      );
    }
  }

  /// Fetch friend requests and acceptances
  Future<void> _fetchFriendRequests(
    String userId,
    List<NewsfeedActivity> activitiesList,
  ) async {
    final firestore = _firestore;
    if (firestore == null) return;

    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 3));

      // Fetch recent friend requests
      final requestsSnapshot = await firestore
          .collection('friends')
          .where('toUserId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(cutoffDate))
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get()
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException(
              'Firestore operation timed out: friend requests',);
        },
      );

      for (final doc in requestsSnapshot.docs) {
        final data = doc.data();
        final fromUserId = data['userId'] as String;
        final friendInfo = await _getFriendInfo(fromUserId);

        activitiesList.add(
          NewsfeedActivity(
            id: doc.id,
            type: NewsfeedActivityType.friendRequest,
            userId: fromUserId,
            userDisplayName: friendInfo['displayName'] as String?,
            userEmail: friendInfo['email'] as String?,
            timestamp: (data['createdAt'] as Timestamp).toDate(),
          ),
        );
      }

      // Fetch recent friend acceptances
      final acceptancesSnapshot = await firestore
          .collection('friends')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'accepted')
          .where('updatedAt', isGreaterThan: Timestamp.fromDate(cutoffDate))
          .orderBy('updatedAt', descending: true)
          .limit(10)
          .get()
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException(
              'Firestore operation timed out: friend acceptances',);
        },
      );

      for (final doc in acceptancesSnapshot.docs) {
        final data = doc.data();
        final friendId = data['friendId'] as String;
        final friendInfo = await _getFriendInfo(friendId);

        activitiesList.add(
          NewsfeedActivity(
            id: '${doc.id}_accepted',
            type: NewsfeedActivityType.friendAccepted,
            userId: friendId,
            userDisplayName: friendInfo['displayName'] as String?,
            userEmail: friendInfo['email'] as String?,
            timestamp: (data['updatedAt'] as Timestamp).toDate(),
          ),
        );
      }
    } on TimeoutException catch (e) {
      LoggerService.error(
        'Firestore operation timed out: friend requests/acceptances',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
    } catch (e, stackTrace) {
      LoggerService.error(
        'Failed to fetch friend requests',
        error: e,
        stack: stackTrace,
        fatal: false,
      );
    }
  }

  /// Fetch multiplayer activities from friends
  Future<void> _fetchMultiplayerActivities(
    List<String> friendIds,
    List<NewsfeedActivity> activitiesList, {
    DateTime? beforeDate,
  }) async {
    final firestore = _firestore;
    if (firestore == null || friendIds.isEmpty) return;

    try {
      final cutoffDate =
          beforeDate ?? DateTime.now().subtract(const Duration(days: 7));
      final maxDate = beforeDate ?? DateTime.now();

      // Fetch multiplayer activities from newsfeed_activities collection
      final Query query = firestore
          .collection('newsfeed_activities')
          .where('userId',
              whereIn: friendIds.length > 10
                  ? friendIds.take(10).toList()
                  : friendIds,)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(cutoffDate))
          .where('timestamp', isLessThan: Timestamp.fromDate(maxDate))
          .orderBy('timestamp', descending: true)
          .limit(20);

      final snapshot = await query.get().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException(
              'Firestore operation timed out: multiplayer activities',);
        },
      );

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final typeString = data['type'] as String?;
        final activityType = NewsfeedActivityType.values.firstWhere(
          (e) => e.name == (typeString ?? ''),
          orElse: () => NewsfeedActivityType.gameCompleted,
        );

        // Only include multiplayer activity types
        if (activityType == NewsfeedActivityType.multiplayerGameStarted ||
            activityType == NewsfeedActivityType.multiplayerGameCompleted ||
            activityType == NewsfeedActivityType.roomCreated ||
            activityType == NewsfeedActivityType.friendInvitedToGame) {
          activitiesList.add(
            NewsfeedActivity(
              id: doc.id,
              type: activityType,
              userId: data['userId'] as String? ?? '',
              userDisplayName: data['userDisplayName'] as String?,
              userEmail: data['userEmail'] as String?,
              userAvatarUrl: data['userAvatarUrl'] as String?,
              metadata: data['metadata'] as Map<String, dynamic>?,
              timestamp: data['timestamp'] != null
                  ? (data['timestamp'] as Timestamp).toDate()
                  : DateTime.now(),
              isRead: data['isRead'] as bool? ?? false,
            ),
          );
        }
      }
    } on TimeoutException catch (e) {
      LoggerService.error(
        'Firestore operation timed out: multiplayer activities',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
    } catch (e, stackTrace) {
      LoggerService.error(
        'Failed to fetch multiplayer activities',
        error: e,
        stack: stackTrace,
        fatal: false,
      );
    }
  }

  /// Get friend info from Firestore
  Future<Map<String, dynamic>> _getFriendInfo(String friendId) async {
    final firestore = _firestore;
    if (firestore == null) {
      return {};
    }

    try {
      final userDoc =
          await firestore.collection('users').doc(friendId).get().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Firestore operation timed out: friend info');
        },
      );
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        return {
          'displayName': data['displayName'] as String?,
          'email': data['email'] as String?,
          'avatarUrl': data['avatarUrl'] as String?,
        };
      }
    } on TimeoutException catch (e) {
      LoggerService.error(
        'Firestore operation timed out: friend info',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
    } catch (e, stackTrace) {
      LoggerService.error(
        'Failed to get friend info',
        error: e,
        stack: stackTrace,
        fatal: false,
      );
    }

    return {};
  }

  /// Refresh newsfeed (reset pagination)
  Future<void> refresh() async {
    _hasMore = true;
    _oldestTimestamp = null;
    await _loadNewsfeed();
  }

  /// Load more activities (pagination)
  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final userId = _userId;
      final firestore = _firestore;
      if (userId == null || firestore == null) {
        _isLoadingMore = false;
        _hasMore = false;
        notifyListeners();
        return;
      }

      // Get user's friends list (cached from previous load)
      final friendsSnapshot = await firestore
          .collection('friends')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'accepted')
          .get()
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Firestore operation timed out: friends');
        },
      );

      final friendIds = friendsSnapshot.docs
          .map((doc) => doc.data()['friendId'] as String)
          .toList();

      if (friendIds.isEmpty) {
        _hasMore = false;
        _isLoadingMore = false;
        notifyListeners();
        return;
      }

      final activitiesList = <NewsfeedActivity>[];

      // Fetch more activities (older than _oldestTimestamp)
      await _fetchFriendAchievements(friendIds, activitiesList,
          beforeDate: _oldestTimestamp,);
      await _fetchFriendChallengeCompletions(friendIds, activitiesList,
          beforeDate: _oldestTimestamp,);
      await _fetchFriendHighScores(friendIds, activitiesList,
          beforeDate: _oldestTimestamp,);
      await _fetchMultiplayerActivities(friendIds, activitiesList,
          beforeDate: _oldestTimestamp,);

      // Sort by timestamp (newest first)
      activitiesList.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Add to existing activities
      final limitedActivities = activitiesList.take(_pageSize).toList();
      _activities.addAll(limitedActivities);

      // Update pagination state
      if (limitedActivities.length < _pageSize) {
        _hasMore = false;
      } else {
        _hasMore = true;
        _oldestTimestamp = limitedActivities.last.timestamp;
      }
    } on TimeoutException catch (e) {
      LoggerService.error(
        'Firestore operation timed out: newsfeed loadMore',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
      _hasMore = false;
    } catch (e, stackTrace) {
      LoggerService.error(
        'Failed to load more newsfeed',
        error: e,
        stack: stackTrace,
        fatal: false,
      );
      _hasMore = false;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Mark activity as read
  Future<void> markAsRead(String activityId) async {
    final index = _activities.indexWhere((a) => a.id == activityId);
    if (index != -1) {
      _activities[index] = NewsfeedActivity(
        id: _activities[index].id,
        type: _activities[index].type,
        userId: _activities[index].userId,
        userDisplayName: _activities[index].userDisplayName,
        userEmail: _activities[index].userEmail,
        userAvatarUrl: _activities[index].userAvatarUrl,
        metadata: _activities[index].metadata,
        timestamp: _activities[index].timestamp,
        isRead: true,
      );
      notifyListeners();
    }
  }

  /// Mark all activities as read
  Future<void> markAllAsRead() async {
    for (int i = 0; i < _activities.length; i++) {
      if (!_activities[i].isRead) {
        _activities[i] = NewsfeedActivity(
          id: _activities[i].id,
          type: _activities[i].type,
          userId: _activities[i].userId,
          userDisplayName: _activities[i].userDisplayName,
          userEmail: _activities[i].userEmail,
          userAvatarUrl: _activities[i].userAvatarUrl,
          metadata: _activities[i].metadata,
          timestamp: _activities[i].timestamp,
          isRead: true,
        );
      }
    }
    notifyListeners();
  }

  /// Log multiplayer activity to newsfeed
  Future<void> logMultiplayerActivity({
    required NewsfeedActivityType activityType,
    required Map<String, dynamic> metadata,
  }) async {
    final userId = _userId;
    final firestore = _firestore;
    if (userId == null || firestore == null) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Create activity document
      await firestore.collection('newsfeed_activities').add({
        'type': activityType.name,
        'userId': userId,
        'userDisplayName': user.displayName,
        'userEmail': user.email,
        'userAvatarUrl': user.photoURL,
        'metadata': metadata,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (e) {
      LoggerService.error('Failed to log multiplayer activity', error: e);
    }
  }

  @override
  void dispose() {
    _newsfeedSubscription?.cancel();
    super.dispose();
  }
}
