import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Service for managing user satisfaction surveys and feedback
class UserSurveyService {
  FirebaseFirestore? _firestore;

  /// Get Firestore instance if Firebase is available
  FirebaseFirestore? get _firestoreInstance {
    if (_firestore != null) return _firestore;
    try {
      Firebase.app(); // Check if Firebase is initialized
      _firestore = FirebaseFirestore.instance;
      return _firestore;
    } catch (e) {
      LoggerService.debug('Firebase not available for UserSurveyService', error: e);
      return null;
    }
  }

  /// Get Auth instance if Firebase is available
  FirebaseAuth? get _authInstance {
    try {
      Firebase.app(); // Check if Firebase is initialized
      return FirebaseAuth.instance;
    } catch (e) {
      LoggerService.debug('Firebase not available for UserSurveyService', error: e);
      return null;
    }
  }

  /// Submit a user satisfaction survey
  Future<void> submitSurvey({
    required String surveyType, // 'post_game', 'feature', 'general'
    required int rating, // 1-5 stars
    String? comment,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final auth = _authInstance;
      final user = auth?.currentUser;
      final userId = user?.uid ?? 'anonymous';

      final firestore = _firestoreInstance;
      if (firestore == null) {
        throw NetworkException('Firebase not available');
      }
      await firestore.collection('surveys').add({
        'userId': userId,
        'userEmail': user?.email,
        'surveyType': surveyType,
        'rating': rating,
        'comment': comment,
        'additionalData': additionalData ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'appVersion': '1.0.0',
      });

      LoggerService.info('Survey submitted successfully');
    } catch (e) {
      LoggerService.error('Error submitting survey', error: e);
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
      final firestore = _firestoreInstance;
      if (firestore == null) {
        throw NetworkException('Firebase not available');
      }
      Query query = firestore.collection('surveys');

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
      LoggerService.error('Error getting survey analytics', error: e);
      return SurveyAnalytics.empty();
    }
  }

  /// Check if user should be shown a survey
  Future<bool> shouldShowSurvey({
    required String surveyType,
    int daysSinceLastSurvey = 7,
  }) async {
    try {
      final auth = _authInstance;
      final user = auth?.currentUser;
      if (user == null) return false;

      final firestore = _firestoreInstance;
      if (firestore == null) {
        return false;
      }
      final lastSurvey = await firestore
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
      final lastSurveyDate =
          (lastSurveyData['createdAt'] as Timestamp?)?.toDate();
      if (lastSurveyDate == null) return true;

      final daysSince = DateTime.now().difference(lastSurveyDate).inDays;
      return daysSince >= daysSinceLastSurvey;
    } catch (e) {
      LoggerService.error('Error checking if should show survey', error: e);
      return false; // Don't show if error
    }
  }
}

/// Survey Analytics model
class SurveyAnalytics {

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
  final int totalSurveys;
  final double averageRating;
  final int rating1;
  final int rating2;
  final int rating3;
  final int rating4;
  final int rating5;
  final int withComments;
}
