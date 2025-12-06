import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for storing AI performance data for adaptive difficulty
class AIPerformanceData {
  final String userId;
  final double averageAccuracy;
  final double averageResponseTime; // in seconds
  final Map<String, double> categoryAccuracy; // category -> accuracy percentage
  final Map<String, int> categoryAttempts; // category -> number of attempts
  final int totalRounds;
  final int totalCorrect;
  final int totalWrong;
  final DateTime lastUpdated;
  final double currentDifficultyLevel; // 0.0 (easy) to 1.0 (hard)

  AIPerformanceData({
    required this.userId,
    required this.averageAccuracy,
    required this.averageResponseTime,
    required this.categoryAccuracy,
    required this.categoryAttempts,
    required this.totalRounds,
    required this.totalCorrect,
    required this.totalWrong,
    required this.lastUpdated,
    required this.currentDifficultyLevel,
  });

  /// Create from Firestore document
  factory AIPerformanceData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AIPerformanceData(
      userId: doc.id,
      averageAccuracy: (data['averageAccuracy'] ?? 0.0).toDouble(),
      averageResponseTime: (data['averageResponseTime'] ?? 10.0).toDouble(),
      categoryAccuracy: Map<String, double>.from(
        data['categoryAccuracy'] ?? {},
      ),
      categoryAttempts: Map<String, int>.from(data['categoryAttempts'] ?? {}),
      totalRounds: data['totalRounds'] ?? 0,
      totalCorrect: data['totalCorrect'] ?? 0,
      totalWrong: data['totalWrong'] ?? 0,
      lastUpdated:
          (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      currentDifficultyLevel: (data['currentDifficultyLevel'] ?? 0.5)
          .toDouble(),
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'averageAccuracy': averageAccuracy,
      'averageResponseTime': averageResponseTime,
      'categoryAccuracy': categoryAccuracy,
      'categoryAttempts': categoryAttempts,
      'totalRounds': totalRounds,
      'totalCorrect': totalCorrect,
      'totalWrong': totalWrong,
      'lastUpdated': Timestamp.now(),
      'currentDifficultyLevel': currentDifficultyLevel,
    };
  }

  /// Calculate overall accuracy
  double get overallAccuracy {
    if (totalRounds == 0) return 0.0;
    return (totalCorrect / (totalCorrect + totalWrong)) * 100.0;
  }

  /// Get weakest category (lowest accuracy)
  String? get weakestCategory {
    if (categoryAccuracy.isEmpty) return null;
    return categoryAccuracy.entries
        .reduce((a, b) => a.value < b.value ? a : b)
        .key;
  }

  /// Get strongest category (highest accuracy)
  String? get strongestCategory {
    if (categoryAccuracy.isEmpty) return null;
    return categoryAccuracy.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  AIPerformanceData copyWith({
    String? userId,
    double? averageAccuracy,
    double? averageResponseTime,
    Map<String, double>? categoryAccuracy,
    Map<String, int>? categoryAttempts,
    int? totalRounds,
    int? totalCorrect,
    int? totalWrong,
    DateTime? lastUpdated,
    double? currentDifficultyLevel,
  }) {
    return AIPerformanceData(
      userId: userId ?? this.userId,
      averageAccuracy: averageAccuracy ?? this.averageAccuracy,
      averageResponseTime: averageResponseTime ?? this.averageResponseTime,
      categoryAccuracy: categoryAccuracy ?? this.categoryAccuracy,
      categoryAttempts: categoryAttempts ?? this.categoryAttempts,
      totalRounds: totalRounds ?? this.totalRounds,
      totalCorrect: totalCorrect ?? this.totalCorrect,
      totalWrong: totalWrong ?? this.totalWrong,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      currentDifficultyLevel:
          currentDifficultyLevel ?? this.currentDifficultyLevel,
    );
  }
}
