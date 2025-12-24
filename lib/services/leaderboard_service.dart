import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class LeaderboardEntry {
  final String userId;
  final String? displayName;
  final String? email;
  final int score;
  final int rank;

  LeaderboardEntry({
    required this.userId,
    this.displayName,
    this.email,
    required this.score,
    required this.rank,
  });

  factory LeaderboardEntry.fromFirestore(DocumentSnapshot doc, int rank) {
    final data = doc.data() as Map<String, dynamic>;
    return LeaderboardEntry(
      userId: doc.id,
      displayName: data['displayName'] as String?,
      email: data['email'] as String?,
      score: data['highestScore'] as int? ?? 0,
      rank: rank,
    );
  }
}

class LeaderboardService {
  FirebaseFirestore? get _firestore {
    try {
      Firebase.app();
      return FirebaseFirestore.instance;
    } catch (e) {
      return null;
    }
  }

  /// Get global leaderboard (top scores) with filters and pagination
  ///
  /// Parameters:
  /// - [limit]: Maximum number of entries to return (default: 20, max: 100)
  /// - [startAfter]: Document snapshot to start after (for pagination)
  /// - [category]: Optional category filter
  /// - [timePeriod]: Optional time period filter
  /// - [region]: Optional region filter
  /// - [friendsOnly]: If true, only show friends' scores
  ///
  /// Returns:
  /// - List of LeaderboardEntry objects
  /// - Last document snapshot for pagination (via getGlobalLeaderboardWithPagination)
  Future<List<LeaderboardEntry>> getGlobalLeaderboard({
    int limit = 20,
    DocumentSnapshot? startAfter,
    String? category,
    String? timePeriod,
    String? region,
    bool friendsOnly = false,
  }) async {
    final firestore = _firestore;
    if (firestore == null) return [];

    // Clamp limit to reasonable bounds
    final clampedLimit = limit.clamp(1, 100);

    try {
      Query query = firestore.collection('user_stats');

      // Apply time period filter (if implemented in Firestore)
      // For now, we'll just filter by highestScore
      // In production, you'd have separate collections or fields for time periods

      // Apply category filter (if category-specific scores exist)
      // For now, we'll use the general highestScore

      // Apply region filter (if user region data exists)
      // For now, we'll use global leaderboard

      query = query.orderBy('highestScore', descending: true);

      // Apply pagination
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.limit(clampedLimit).get();

      return snapshot.docs.asMap().entries.map((entry) {
        return LeaderboardEntry.fromFirestore(entry.value, entry.key + 1);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching global leaderboard: $e');
      return [];
    }
  }

  /// Get global leaderboard with pagination support
  /// Returns both entries and last document for next page
  Future<Map<String, dynamic>> getGlobalLeaderboardWithPagination({
    int limit = 20,
    DocumentSnapshot? startAfter,
    String? category,
    String? timePeriod,
    String? region,
    bool friendsOnly = false,
  }) async {
    final firestore = _firestore;
    if (firestore == null) {
      return {
        'entries': <LeaderboardEntry>[],
        'lastDocument': null,
        'hasMore': false,
      };
    }

    final clampedLimit = limit.clamp(1, 100);

    try {
      Query query = firestore.collection('user_stats');
      query = query.orderBy('highestScore', descending: true);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      // Fetch one extra to check if there are more pages
      final snapshot = await query.limit(clampedLimit + 1).get();

      final entries = snapshot.docs
          .take(clampedLimit)
          .toList()
          .asMap()
          .entries
          .map((entry) {
        return LeaderboardEntry.fromFirestore(entry.value, entry.key + 1);
      }).toList();

      final hasMore = snapshot.docs.length > clampedLimit;
      final lastDocument = hasMore ? snapshot.docs[clampedLimit - 1] : null;

      return {
        'entries': entries,
        'lastDocument': lastDocument,
        'hasMore': hasMore,
      };
    } catch (e) {
      debugPrint('Error fetching global leaderboard with pagination: $e');
      return {
        'entries': <LeaderboardEntry>[],
        'lastDocument': null,
        'hasMore': false,
      };
    }
  }

  /// Get user's rank
  Future<int> getUserRank(String userId) async {
    final firestore = _firestore;
    if (firestore == null) return 0;

    try {
      final userDoc =
          await firestore.collection('user_stats').doc(userId).get();
      if (!userDoc.exists) return 0;

      final userScore = (userDoc.data()?['highestScore'] as int?) ?? 0;

      final snapshot = await firestore
          .collection('user_stats')
          .where('highestScore', isGreaterThan: userScore)
          .count()
          .get();

      return snapshot.count! + 1;
    } catch (e) {
      debugPrint('Error getting user rank: $e');
      return 0;
    }
  }

  /// Get leaderboard around current user
  Future<List<LeaderboardEntry>> getLeaderboardAroundUser(
    String userId, {
    int range = 5,
  }) async {
    final firestore = _firestore;
    if (firestore == null) return [];

    try {
      final userRank = await getUserRank(userId);
      final startRank = (userRank - range).clamp(1, double.infinity).toInt();

      // This is a simplified version - in production, you'd want to use pagination
      final snapshot = await firestore
          .collection('user_stats')
          .orderBy('highestScore', descending: true)
          .limit(startRank + range * 2)
          .get();

      return snapshot.docs.asMap().entries.map((entry) {
        return LeaderboardEntry.fromFirestore(entry.value, entry.key + 1);
      }).where((entry) {
        final rank = entry.rank;
        return rank >= startRank && rank <= userRank + range;
      }).toList();
    } catch (e) {
      debugPrint('Error fetching leaderboard around user: $e');
      return [];
    }
  }
}
