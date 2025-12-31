import 'dart:async' show TimeoutException;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Trending challenge model
class TrendingChallenge {

  TrendingChallenge({
    required this.id,
    required this.name,
    required this.description,
    required this.participantCount,
    required this.createdAt,
    this.category,
  });

  factory TrendingChallenge.fromJson(Map<String, dynamic> json) {
    return TrendingChallenge(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      participantCount: json['participantCount'] as int? ?? 0,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      category: json['category'] as String?,
    );
  }
  final String id;
  final String name;
  final String description;
  final int participantCount;
  final DateTime createdAt;
  final String? category;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'participantCount': participantCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'category': category,
    };
  }
}

/// Recommended player model
class RecommendedPlayer {

  RecommendedPlayer({
    required this.userId,
    this.displayName,
    this.email,
    this.avatarUrl,
    this.highestScore,
    this.commonInterest,
    this.isFriend = false,
    this.mutualFriends,
  });

  factory RecommendedPlayer.fromJson(Map<String, dynamic> json) {
    return RecommendedPlayer(
      userId: json['userId'] as String,
      displayName: json['displayName'] as String?,
      email: json['email'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      highestScore: json['highestScore'] as int?,
      commonInterest: json['commonInterest'] as String?,
      isFriend: json['isFriend'] as bool? ?? false,
      mutualFriends: json['mutualFriends'] as int?,
    );
  }
  final String userId;
  final String? displayName;
  final String? email;
  final String? avatarUrl;
  final int? highestScore;
  final String? commonInterest;
  final bool isFriend;
  final int? mutualFriends;
}

/// Service for social discovery features
class SocialDiscoveryService extends ChangeNotifier {
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

  final List<TrendingChallenge> _trendingChallenges = [];
  final List<RecommendedPlayer> _recommendedPlayers = [];
  bool _isLoading = false;

  List<TrendingChallenge> get trendingChallenges =>
      List.unmodifiable(_trendingChallenges);
  List<RecommendedPlayer> get recommendedPlayers =>
      List.unmodifiable(_recommendedPlayers);
  bool get isLoading => _isLoading;

  /// Initialize and load discovery data
  Future<void> init() async {
    final userId = _userId;
    if (userId == null) return;

    await loadTrendingChallenges();
    await loadRecommendedPlayers();
  }

  /// Load trending challenges
  Future<void> loadTrendingChallenges() async {
    final firestore = _firestore;
    if (firestore == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Query daily challenges with most participants
      final challengesSnapshot = await firestore
          .collection('daily_challenges')
          .where('date',
              isGreaterThanOrEqualTo:
                  DateTime.now().subtract(const Duration(days: 7)),)
          .orderBy('date', descending: true)
          .limit(10)
          .get()
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException(
              'Firestore operation timed out: daily_challenges',);
        },
      );

      final challengesList = <TrendingChallenge>[];

      for (final doc in challengesSnapshot.docs) {
        final data = doc.data();

        // Get participant count from leaderboard entries
        final participantCount = await _getChallengeParticipantCount(doc.id);

        challengesList.add(
          TrendingChallenge(
            id: doc.id,
            name: data['name'] as String? ?? 'Daily Challenge',
            description: data['description'] as String? ?? '',
            participantCount: participantCount,
            createdAt: (data['date'] as Timestamp).toDate(),
            category: data['category'] as String?,
          ),
        );
      }

      // Sort by participant count (trending)
      challengesList
          .sort((a, b) => b.participantCount.compareTo(a.participantCount));

      _trendingChallenges.clear();
      _trendingChallenges.addAll(challengesList.take(5));
    } on TimeoutException catch (e) {
      LoggerService.error(
        'Firestore operation timed out: trending challenges',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
    } catch (e, stackTrace) {
      LoggerService.error(
        'Failed to load trending challenges',
        error: e,
        stack: stackTrace,
        fatal: false,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get participant count for a challenge
  Future<int> _getChallengeParticipantCount(String challengeId) async {
    final firestore = _firestore;
    if (firestore == null) return 0;

    try {
      final snapshot = await firestore
          .collection('challenge_leaderboard')
          .where('challengeId', isEqualTo: challengeId)
          .count()
          .get()
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException(
              'Firestore operation timed out: challenge_leaderboard count',);
        },
      );

      return snapshot.count ?? 0;
    } on TimeoutException catch (e) {
      LoggerService.error(
        'Firestore operation timed out: challenge participant count',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
      return 0;
    } catch (e, stackTrace) {
      LoggerService.error(
        'Failed to get challenge participant count',
        error: e,
        stack: stackTrace,
        fatal: false,
      );
      return 0;
    }
  }

  /// Load recommended players
  Future<void> loadRecommendedPlayers() async {
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
          .toSet();

      // Get user's stats for matching
      final userStatsDoc =
          await firestore.collection('user_stats').doc(userId).get().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Firestore operation timed out: user_stats');
        },
      );

      final userStats = userStatsDoc.data();
      final userHighestScore = userStats?['highestScore'] as int? ?? 0;
      final userCategories =
          userStats?['modePlayCounts'] as Map<String, dynamic>?;

      // Get players with similar scores (within range)
      final scoreRange = (userHighestScore * 0.5).round().clamp(100, 10000);
      final minScore = (userHighestScore - scoreRange).clamp(0, 999999);
      final maxScore = userHighestScore + scoreRange;

      // Query users with similar scores
      final playersSnapshot = await firestore
          .collection('user_stats')
          .where('highestScore', isGreaterThanOrEqualTo: minScore)
          .where('highestScore', isLessThanOrEqualTo: maxScore)
          .limit(20)
          .get()
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException(
              'Firestore operation timed out: user_stats query',);
        },
      );

      final recommendedList = <RecommendedPlayer>[];

      for (final doc in playersSnapshot.docs) {
        final playerId = doc.id;
        if (playerId == userId || friendIds.contains(playerId)) {
          continue; // Skip self and existing friends
        }

        final data = doc.data();
        final playerHighestScore = data['highestScore'] as int? ?? 0;

        // Get user profile
        final userDoc =
            await firestore.collection('users').doc(playerId).get().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('Firestore operation timed out: users');
          },
        );
        final userData = userDoc.data();

        // Calculate mutual friends
        final mutualFriends = await _getMutualFriendsCount(userId, playerId);

        // Find common interests (categories)
        String? commonInterest;
        if (userCategories != null && userData != null) {
          final playerCategories =
              data['modePlayCounts'] as Map<String, dynamic>?;
          if (playerCategories != null) {
            final common = userCategories.keys
                .toSet()
                .intersection(playerCategories.keys.toSet());
            if (common.isNotEmpty) {
              commonInterest = common.first;
            }
          }
        }

        recommendedList.add(
          RecommendedPlayer(
            userId: playerId,
            displayName: userData?['displayName'] as String?,
            email: userData?['email'] as String?,
            avatarUrl: userData?['avatarUrl'] as String?,
            highestScore: playerHighestScore,
            commonInterest: commonInterest,
            mutualFriends: mutualFriends > 0 ? mutualFriends : null,
          ),
        );
      }

      // Sort by mutual friends and common interests
      recommendedList.sort((a, b) {
        if (a.mutualFriends != null && b.mutualFriends == null) return -1;
        if (a.mutualFriends == null && b.mutualFriends != null) return 1;
        if (a.mutualFriends != null && b.mutualFriends != null) {
          return b.mutualFriends!.compareTo(a.mutualFriends!);
        }
        return 0;
      });

      _recommendedPlayers.clear();
      _recommendedPlayers.addAll(recommendedList.take(10));
    } on TimeoutException catch (e) {
      LoggerService.error(
        'Firestore operation timed out: recommended players',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
    } catch (e, stackTrace) {
      LoggerService.error(
        'Failed to load recommended players',
        error: e,
        stack: stackTrace,
        fatal: false,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get mutual friends count between two users
  Future<int> _getMutualFriendsCount(String userId1, String userId2) async {
    final firestore = _firestore;
    if (firestore == null) return 0;

    try {
      // Get user1's friends
      final friends1Snapshot = await firestore
          .collection('friends')
          .where('userId', isEqualTo: userId1)
          .where('status', isEqualTo: 'accepted')
          .get()
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException(
              'Firestore operation timed out: friends user1',);
        },
      );

      final friends1 = friends1Snapshot.docs
          .map((doc) => doc.data()['friendId'] as String)
          .toSet();

      // Get user2's friends
      final friends2Snapshot = await firestore
          .collection('friends')
          .where('userId', isEqualTo: userId2)
          .where('status', isEqualTo: 'accepted')
          .get()
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException(
              'Firestore operation timed out: friends user2',);
        },
      );

      final friends2 = friends2Snapshot.docs
          .map((doc) => doc.data()['friendId'] as String)
          .toSet();

      // Count mutual friends
      return friends1.intersection(friends2).length;
    } on TimeoutException catch (e) {
      LoggerService.error(
        'Firestore operation timed out: mutual friends count',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
      return 0;
    } catch (e, stackTrace) {
      LoggerService.error(
        'Failed to get mutual friends count',
        error: e,
        stack: stackTrace,
        fatal: false,
      );
      return 0;
    }
  }

  /// Search for players
  Future<List<RecommendedPlayer>> searchPlayers(String query) async {
    final firestore = _firestore;
    if (firestore == null || query.isEmpty) return [];

    try {
      // Search by email (if query contains @)
      if (query.contains('@')) {
        final usersSnapshot = await firestore
            .collection('users')
            .where('email', isEqualTo: query.toLowerCase())
            .limit(5)
            .get()
            .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException(
                'Firestore operation timed out: search players by email',);
          },
        );

        return usersSnapshot.docs.map((doc) {
          final data = doc.data();
          return RecommendedPlayer(
            userId: doc.id,
            displayName: data['displayName'] as String?,
            email: data['email'] as String?,
            avatarUrl: data['avatarUrl'] as String?,
          );
        }).toList();
      }

      // Search by display name (prefix match)
      final usersSnapshot = await firestore
          .collection('users')
          .where('displayName', isGreaterThanOrEqualTo: query)
          .where('displayName', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(10)
          .get()
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException(
              'Firestore operation timed out: search players by name',);
        },
      );

      return usersSnapshot.docs.map((doc) {
        final data = doc.data();
        return RecommendedPlayer(
          userId: doc.id,
          displayName: data['displayName'] as String?,
          email: data['email'] as String?,
          avatarUrl: data['avatarUrl'] as String?,
        );
      }).toList();
    } on TimeoutException catch (e) {
      LoggerService.error(
        'Firestore operation timed out: search players',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
      return [];
    } catch (e, stackTrace) {
      LoggerService.error(
        'Failed to search players',
        error: e,
        stack: stackTrace,
        fatal: false,
      );
      return [];
    }
  }

  /// Refresh discovery data
  Future<void> refresh() async {
    await Future.wait([
      loadTrendingChallenges(),
      loadRecommendedPlayers(),
    ]);
  }
}
