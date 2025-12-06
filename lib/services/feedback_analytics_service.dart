import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service for analyzing feedback data and generating insights
class FeedbackAnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get feedback analytics summary
  Future<FeedbackAnalytics> getAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore.collection('feedback');

      if (startDate != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: startDate);
      }
      if (endDate != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: endDate);
      }

      final snapshot = await query.get();

      final int totalFeedback = snapshot.docs.length;
      int bugs = 0;
      int features = 0;
      int errors = 0;
      int questions = 0;
      int highPriority = 0;
      int mediumPriority = 0;
      int lowPriority = 0;
      int resolved = 0;
      int newStatus = 0;
      int inProgress = 0;

      final categoryCounts = <String, int>{};
      final commonIssues = <String, int>{};

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        // Count by type
        final type = data['type'] ?? 'unknown';
        switch (type) {
          case 'bug':
            bugs++;
            break;
          case 'feature':
            features++;
            break;
          case 'error':
            errors++;
            break;
          case 'question':
            questions++;
            break;
        }

        // Count by priority
        final priority = data['priority'] ?? 'low';
        switch (priority) {
          case 'high':
            highPriority++;
            break;
          case 'medium':
            mediumPriority++;
            break;
          case 'low':
            lowPriority++;
            break;
        }

        // Count by status
        final status = data['status'] ?? 'new';
        switch (status) {
          case 'resolved':
            resolved++;
            break;
          case 'new':
            newStatus++;
            break;
          case 'in_progress':
            inProgress++;
            break;
        }

        // Category counts
        final category = data['category'] ?? 'general';
        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;

        // Common issues (from message keywords)
        final message = (data['message'] ?? '').toString().toLowerCase();
        _extractCommonIssues(message, commonIssues);
      }

      return FeedbackAnalytics(
        totalFeedback: totalFeedback,
        bugs: bugs,
        features: features,
        errors: errors,
        questions: questions,
        highPriority: highPriority,
        mediumPriority: mediumPriority,
        lowPriority: lowPriority,
        resolved: resolved,
        newStatus: newStatus,
        inProgress: inProgress,
        categoryCounts: categoryCounts,
        commonIssues: commonIssues,
      );
    } catch (e) {
      debugPrint('Error getting feedback analytics: $e');
      return FeedbackAnalytics.empty();
    }
  }

  /// Extract common issues from message text
  void _extractCommonIssues(String message, Map<String, int> commonIssues) {
    final keywords = [
      'crash',
      'freeze',
      'slow',
      'lag',
      'login',
      'password',
      'subscription',
      'payment',
      'video',
      'sound',
      'audio',
      'game',
      'tile',
      'round',
      'score',
      'points',
      'token',
    ];

    for (final keyword in keywords) {
      if (message.contains(keyword)) {
        commonIssues[keyword] = (commonIssues[keyword] ?? 0) + 1;
      }
    }
  }

  /// Get feedback trends over time
  Future<List<FeedbackTrend>> getTrends({int days = 30}) async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: days));

      final snapshot = await _firestore
          .collection('feedback')
          .where('createdAt', isGreaterThanOrEqualTo: startDate)
          .where('createdAt', isLessThanOrEqualTo: endDate)
          .get();

      final trends = <String, FeedbackTrend>{};

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        final createdAt =
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final dateKey =
            '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';

        if (!trends.containsKey(dateKey)) {
          trends[dateKey] = FeedbackTrend(
            date: dateKey,
            count: 0,
            bugs: 0,
            features: 0,
            errors: 0,
          );
        }

        final trend = trends[dateKey]!;
        trends[dateKey] = FeedbackTrend(
          date: dateKey,
          count: trend.count + 1,
          bugs: trend.bugs + (data['type'] == 'bug' ? 1 : 0),
          features: trend.features + (data['type'] == 'feature' ? 1 : 0),
          errors: trend.errors + (data['type'] == 'error' ? 1 : 0),
        );
      }

      return trends.values.toList()..sort((a, b) => a.date.compareTo(b.date));
    } catch (e) {
      debugPrint('Error getting feedback trends: $e');
      return [];
    }
  }
}

/// Feedback Analytics model
class FeedbackAnalytics {
  final int totalFeedback;
  final int bugs;
  final int features;
  final int errors;
  final int questions;
  final int highPriority;
  final int mediumPriority;
  final int lowPriority;
  final int resolved;
  final int newStatus;
  final int inProgress;
  final Map<String, int> categoryCounts;
  final Map<String, int> commonIssues;

  FeedbackAnalytics({
    required this.totalFeedback,
    required this.bugs,
    required this.features,
    required this.errors,
    required this.questions,
    required this.highPriority,
    required this.mediumPriority,
    required this.lowPriority,
    required this.resolved,
    required this.newStatus,
    required this.inProgress,
    required this.categoryCounts,
    required this.commonIssues,
  });

  factory FeedbackAnalytics.empty() {
    return FeedbackAnalytics(
      totalFeedback: 0,
      bugs: 0,
      features: 0,
      errors: 0,
      questions: 0,
      highPriority: 0,
      mediumPriority: 0,
      lowPriority: 0,
      resolved: 0,
      newStatus: 0,
      inProgress: 0,
      categoryCounts: {},
      commonIssues: {},
    );
  }
}

/// Feedback Trend model
class FeedbackTrend {
  final String date;
  final int count;
  final int bugs;
  final int features;
  final int errors;

  FeedbackTrend({
    required this.date,
    required this.count,
    required this.bugs,
    required this.features,
    required this.errors,
  });
}
