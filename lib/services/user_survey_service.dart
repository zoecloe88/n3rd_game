import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service for managing user satisfaction surveys and feedback
class UserSurveyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Submit a user satisfaction survey
  Future<void> submitSurvey({
    required String surveyType, // 'post_game', 'feature', 'general'
    required int rating, // 1-5 stars
    String? comment,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? 'anonymous';

      await _firestore.collection('surveys').add({
        'userId': userId,
        'userEmail': user?.email,
        'surveyType': surveyType,
        'rating': rating,
        'comment': comment,
        'additionalData': additionalData ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'appVersion': '1.0.0',
      });

      debugPrint('Survey submitted successfully');
    } catch (e) {
      debugPrint('Error submitting survey: $e');
      rethrow;
    }
  }

  /// Submit post-game survey
  Future<void> submitPostGameSurvey({
    required int rating,
    String? comment,
    int? score,
    String? gameMode,
    int? roundsPlayed,
    double? accuracy,
  }) async {
    await submitSurvey(
      surveyType: 'post_game',
      rating: rating,
      comment: comment,
      additionalData: {
        'score': score,
        'gameMode': gameMode,
        'roundsPlayed': roundsPlayed,
        'accuracy': accuracy,
      },
    );
  }

  /// Submit feature request survey
  Future<void> submitFeatureSurvey({
    required String featureName,
    required int rating, // How much they want it (1-5)
    String? comment,
    bool? wouldUse,
  }) async {
    await submitSurvey(
      surveyType: 'feature',
      rating: rating,
      comment: comment,
      additionalData: {'featureName': featureName, 'wouldUse': wouldUse},
    );
  }

  /// Get survey analytics
  Future<SurveyAnalytics> getSurveyAnalytics({
    String? surveyType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore.collection('surveys');

      if (surveyType != null) {
        query = query.where('surveyType', isEqualTo: surveyType);
      }
      if (startDate != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: startDate);
      }
      if (endDate != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: endDate);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        return SurveyAnalytics.empty();
      }

      final int totalSurveys = snapshot.docs.length;
      double totalRating = 0;
      int rating1 = 0, rating2 = 0, rating3 = 0, rating4 = 0, rating5 = 0;
      int withComments = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        final rating = data['rating'] ?? 0;
        totalRating += rating;

        switch (rating) {
          case 1:
            rating1++;
            break;
          case 2:
            rating2++;
            break;
          case 3:
            rating3++;
            break;
          case 4:
            rating4++;
            break;
          case 5:
            rating5++;
            break;
        }

        if (data['comment'] != null && (data['comment'] as String).isNotEmpty) {
          withComments++;
        }
      }

      return SurveyAnalytics(
        totalSurveys: totalSurveys,
        averageRating: totalRating / totalSurveys,
        rating1: rating1,
        rating2: rating2,
        rating3: rating3,
        rating4: rating4,
        rating5: rating5,
        withComments: withComments,
      );
    } catch (e) {
      debugPrint('Error getting survey analytics: $e');
      return SurveyAnalytics.empty();
    }
  }

  /// Check if user should be shown a survey
  Future<bool> shouldShowSurvey({
    required String surveyType,
    int daysSinceLastSurvey = 7,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final lastSurvey = await _firestore
          .collection('surveys')
          .where('userId', isEqualTo: user.uid)
          .where('surveyType', isEqualTo: surveyType)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (lastSurvey.docs.isEmpty) return true;

      final lastSurveyData =
          lastSurvey.docs.first.data() as Map<String, dynamic>?;
      if (lastSurveyData == null) return true;
      final lastSurveyDate = (lastSurveyData['createdAt'] as Timestamp?)
          ?.toDate();
      if (lastSurveyDate == null) return true;

      final daysSince = DateTime.now().difference(lastSurveyDate).inDays;
      return daysSince >= daysSinceLastSurvey;
    } catch (e) {
      debugPrint('Error checking if should show survey: $e');
      return false; // Don't show if error
    }
  }
}

/// Survey Analytics model
class SurveyAnalytics {
  final int totalSurveys;
  final double averageRating;
  final int rating1;
  final int rating2;
  final int rating3;
  final int rating4;
  final int rating5;
  final int withComments;

  SurveyAnalytics({
    required this.totalSurveys,
    required this.averageRating,
    required this.rating1,
    required this.rating2,
    required this.rating3,
    required this.rating4,
    required this.rating5,
    required this.withComments,
  });

  factory SurveyAnalytics.empty() {
    return SurveyAnalytics(
      totalSurveys: 0,
      averageRating: 0.0,
      rating1: 0,
      rating2: 0,
      rating3: 0,
      rating4: 0,
      rating5: 0,
      withComments: 0,
    );
  }
}
