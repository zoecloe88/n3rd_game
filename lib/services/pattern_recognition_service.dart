import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';

/// Pattern recognition service for analyzing user gameplay patterns
/// Identifies learning patterns, knowledge gaps, and performance trends
class PatternRecognitionService extends ChangeNotifier {
  FirebaseFirestore? _firestore;
  FirebaseAuth? _auth;

  /// Get Firestore instance if Firebase is available
  FirebaseFirestore? get _firestoreInstance {
    if (_firestore != null) return _firestore;
    try {
      Firebase.app(); // Check if Firebase is initialized
      _firestore = FirebaseFirestore.instance;
      return _firestore;
    } catch (e) {
      LoggerService.debug('Firebase not available for PatternRecognitionService', error: e);
      return null;
    }
  }

  /// Get Auth instance if Firebase is available
  FirebaseAuth? get _authInstance {
    if (_auth != null) return _auth;
    try {
      Firebase.app(); // Check if Firebase is initialized
      _auth = FirebaseAuth.instance;
      return _auth;
    } catch (e) {
      LoggerService.debug('Firebase not available for PatternRecognitionService', error: e);
      return null;
    }
  }

  String? get _userId => _authInstance?.currentUser?.uid;

  /// Analyze user gameplay patterns
  Future<GameplayPatterns> analyzePatterns() async {
    if (_userId == null) {
      throw Exception('User must be authenticated');
    }

    try {
      // Get game history from Firestore
      final gameHistory = await _getGameHistory();

      if (gameHistory.isEmpty) {
        return GameplayPatterns.empty();
      }

      // Analyze response times
      final responseTimePattern = _analyzeResponseTimes(gameHistory);

      // Analyze accuracy by category
      final accuracyByCategory = _analyzeAccuracyByCategory(gameHistory);

      // Analyze difficulty progression
      final difficultyProgression = _analyzeDifficultyProgression(gameHistory);

      // Identify knowledge gaps
      final knowledgeGaps = _identifyKnowledgeGaps(gameHistory);

      // Analyze performance trends
      final performanceTrends = _analyzePerformanceTrends(gameHistory);

      // Generate personalized recommendations
      final recommendations = _generateRecommendations(
        responseTimePattern,
        accuracyByCategory,
        difficultyProgression,
        knowledgeGaps,
        performanceTrends,
      );

      return GameplayPatterns(
        responseTimePattern: responseTimePattern,
        accuracyByCategory: accuracyByCategory,
        difficultyProgression: difficultyProgression,
        knowledgeGaps: knowledgeGaps,
        performanceTrends: performanceTrends,
        recommendations: recommendations,
      );
    } catch (e) {
      LoggerService.error('Error analyzing gameplay patterns', error: e);
      rethrow;
    }
  }

  /// Get game history from Firestore
  Future<List<Map<String, dynamic>>> _getGameHistory() async {
    if (_userId == null) return [];

    try {
      final firestore = _firestoreInstance;
      if (firestore == null) {
        throw NetworkException('Firebase not available');
      }
      final snapshot = await firestore
          .collection('user_game_history')
          .doc(_userId)
          .collection('games')
          .orderBy('timestamp', descending: true)
          .limit(100) // Analyze last 100 games
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      LoggerService.warning('Error fetching game history', error: e);
      return [];
    }
  }

  /// Analyze response times
  ResponseTimePattern _analyzeResponseTimes(
      List<Map<String, dynamic>> history,) {
    if (history.isEmpty) {
      return ResponseTimePattern(
        averageResponseTime: 0,
        fastestResponseTime: 0,
        slowestResponseTime: 0,
        trend: PerformanceTrend.stable,
      );
    }

    final responseTimes = <int>[];
    for (final game in history) {
      final times = game['responseTimes'] as List<dynamic>?;
      if (times != null) {
        responseTimes.addAll(times.map((t) => t as int));
      }
    }

    if (responseTimes.isEmpty) {
      return ResponseTimePattern(
        averageResponseTime: 0,
        fastestResponseTime: 0,
        slowestResponseTime: 0,
        trend: PerformanceTrend.stable,
      );
    }

    responseTimes.sort();
    final average =
        responseTimes.reduce((a, b) => a + b) / responseTimes.length;
    final fastest = responseTimes.first;
    final slowest = responseTimes.last;

    // Determine trend (compare recent vs older games)
    final recentGames = history.take(20).toList();
    final olderGames = history.skip(20).take(20).toList();

    PerformanceTrend trend = PerformanceTrend.stable;
    if (recentGames.isNotEmpty && olderGames.isNotEmpty) {
      final recentAvg = _calculateAverageResponseTime(recentGames);
      final olderAvg = _calculateAverageResponseTime(olderGames);

      if (recentAvg < olderAvg * 0.9) {
        trend = PerformanceTrend.improving;
      } else if (recentAvg > olderAvg * 1.1) {
        trend = PerformanceTrend.declining;
      }
    }

    return ResponseTimePattern(
      averageResponseTime: average.round(),
      fastestResponseTime: fastest,
      slowestResponseTime: slowest,
      trend: trend,
    );
  }

  int _calculateAverageResponseTime(List<Map<String, dynamic>> games) {
    final times = <int>[];
    for (final game in games) {
      final responseTimes = game['responseTimes'] as List<dynamic>?;
      if (responseTimes != null) {
        times.addAll(responseTimes.map((t) => t as int));
      }
    }
    if (times.isEmpty) return 0;
    return (times.reduce((a, b) => a + b) / times.length).round();
  }

  /// Analyze accuracy by category
  Map<String, CategoryAccuracy> _analyzeAccuracyByCategory(
    List<Map<String, dynamic>> history,
  ) {
    final categoryStats = <String, List<bool>>{};

    for (final game in history) {
      final questions = game['questions'] as List<dynamic>?;
      if (questions == null) continue;

      for (final question in questions) {
        final category = question['category'] as String? ?? 'Unknown';
        final isCorrect = question['isCorrect'] as bool? ?? false;

        categoryStats.putIfAbsent(category, () => []).add(isCorrect);
      }
    }

    return categoryStats.map((category, results) {
      final correct = results.where((r) => r).length;
      final total = results.length;
      final accuracy = total > 0 ? (correct / total) * 100 : 0.0;

      return MapEntry(
        category,
        CategoryAccuracy(
          category: category,
          accuracy: accuracy,
          totalQuestions: total,
          correctAnswers: correct,
        ),
      );
    });
  }

  /// Analyze difficulty progression
  DifficultyProgression _analyzeDifficultyProgression(
    List<Map<String, dynamic>> history,
  ) {
    if (history.isEmpty) {
      return DifficultyProgression(
        currentLevel: 'easy',
        progressionRate: 0.0,
        trend: PerformanceTrend.stable,
      );
    }

    final difficulties = history.map((game) {
      return game['difficulty'] as String? ?? 'easy';
    }).toList();

    final recentDifficulties = difficulties.take(10).toList();
    final olderDifficulties = difficulties.skip(10).take(10).toList();

    final recentAvg = _calculateDifficultyAverage(recentDifficulties);
    final olderAvg = _calculateDifficultyAverage(olderDifficulties);

    final progressionRate =
        olderAvg > 0 ? ((recentAvg - olderAvg) / olderAvg) * 100 : 0.0;

    PerformanceTrend trend = PerformanceTrend.stable;
    if (progressionRate > 10) {
      trend = PerformanceTrend.improving;
    } else if (progressionRate < -10) {
      trend = PerformanceTrend.declining;
    }

    return DifficultyProgression(
      currentLevel:
          recentDifficulties.isNotEmpty ? recentDifficulties.last : 'easy',
      progressionRate: progressionRate,
      trend: trend,
    );
  }

  double _calculateDifficultyAverage(List<String> difficulties) {
    final difficultyValues = {
      'easy': 1,
      'medium': 2,
      'hard': 3,
      'insane': 4,
    };

    if (difficulties.isEmpty) return 0;

    final sum = difficulties
        .map((d) => difficultyValues[d] ?? 1)
        .reduce((a, b) => a + b);

    return sum / difficulties.length;
  }

  /// Identify knowledge gaps
  List<KnowledgeGap> _identifyKnowledgeGaps(
    List<Map<String, dynamic>> history,
  ) {
    final categoryAccuracy = _analyzeAccuracyByCategory(history);
    final gaps = <KnowledgeGap>[];

    for (final entry in categoryAccuracy.entries) {
      if (entry.value.accuracy < 50.0 && entry.value.totalQuestions >= 5) {
        gaps.add(
          KnowledgeGap(
            category: entry.key,
            accuracy: entry.value.accuracy,
            recommendation:
                'Focus on ${entry.key} to improve your overall performance.',
          ),
        );
      }
    }

    // Sort by accuracy (lowest first)
    gaps.sort((a, b) => a.accuracy.compareTo(b.accuracy));

    return gaps.take(5).toList(); // Top 5 knowledge gaps
  }

  /// Analyze performance trends
  PerformanceTrends _analyzePerformanceTrends(
    List<Map<String, dynamic>> history,
  ) {
    if (history.length < 10) {
      return PerformanceTrends(
        overallTrend: PerformanceTrend.stable,
        scoreTrend: PerformanceTrend.stable,
        accuracyTrend: PerformanceTrend.stable,
      );
    }

    final recentGames = history.take(10).toList();
    final olderGames = history.skip(10).take(10).toList();

    // Score trend
    final recentScores =
        recentGames.map((g) => g['score'] as int? ?? 0).toList();
    final olderScores = olderGames.map((g) => g['score'] as int? ?? 0).toList();

    final recentAvgScore = recentScores.isEmpty
        ? 0
        : recentScores.reduce((a, b) => a + b) / recentScores.length;
    final olderAvgScore = olderScores.isEmpty
        ? 0
        : olderScores.reduce((a, b) => a + b) / olderScores.length;

    final scoreTrend =
        _determineTrend(recentAvgScore.toDouble(), olderAvgScore.toDouble());

    // Accuracy trend
    final recentAccuracy = _calculateAverageAccuracy(recentGames);
    final olderAccuracy = _calculateAverageAccuracy(olderGames);
    final accuracyTrend = _determineTrend(recentAccuracy, olderAccuracy);

    // Overall trend (average of score and accuracy)
    final overallTrend = _determineTrend(
      (recentAvgScore + recentAccuracy) / 2,
      (olderAvgScore + olderAccuracy) / 2,
    );

    return PerformanceTrends(
      overallTrend: overallTrend,
      scoreTrend: scoreTrend,
      accuracyTrend: accuracyTrend,
    );
  }

  double _calculateAverageAccuracy(List<Map<String, dynamic>> games) {
    int correct = 0;
    int total = 0;

    for (final game in games) {
      final questions = game['questions'] as List<dynamic>?;
      if (questions == null) continue;

      for (final question in questions) {
        total++;
        if (question['isCorrect'] as bool? ?? false) {
          correct++;
        }
      }
    }

    return total > 0 ? (correct / total) * 100 : 0.0;
  }

  PerformanceTrend _determineTrend(double recent, double older) {
    if (older == 0) return PerformanceTrend.stable;

    final change = ((recent - older) / older) * 100;

    if (change > 10) {
      return PerformanceTrend.improving;
    } else if (change < -10) {
      return PerformanceTrend.declining;
    }

    return PerformanceTrend.stable;
  }

  /// Generate personalized recommendations
  List<String> _generateRecommendations(
    ResponseTimePattern responseTimePattern,
    Map<String, CategoryAccuracy> accuracyByCategory,
    DifficultyProgression difficultyProgression,
    List<KnowledgeGap> knowledgeGaps,
    PerformanceTrends performanceTrends,
  ) {
    final recommendations = <String>[];

    // Response time recommendations
    if (responseTimePattern.averageResponseTime > 10000) {
      recommendations.add(
        'Your response time is slower than average. Try practicing with Time Attack mode to improve speed.',
      );
    }

    // Knowledge gap recommendations
    if (knowledgeGaps.isNotEmpty) {
      final topGap = knowledgeGaps.first;
      recommendations.add(topGap.recommendation);
    }

    // Difficulty progression recommendations
    if (difficultyProgression.trend == PerformanceTrend.declining) {
      recommendations.add(
        'Your performance has declined recently. Consider practicing at a lower difficulty to rebuild confidence.',
      );
    } else if (difficultyProgression.trend == PerformanceTrend.improving) {
      recommendations.add(
        'Great progress! You\'re ready to try harder difficulties. Challenge yourself!',
      );
    }

    // Performance trend recommendations
    if (performanceTrends.overallTrend == PerformanceTrend.improving) {
      recommendations.add(
        'You\'re on a roll! Keep up the great work and maintain your current practice routine.',
      );
    }

    return recommendations.take(3).toList(); // Limit to 3 recommendations
  }
}

/// Gameplay patterns analysis result
class GameplayPatterns {

  GameplayPatterns({
    required this.responseTimePattern,
    required this.accuracyByCategory,
    required this.difficultyProgression,
    required this.knowledgeGaps,
    required this.performanceTrends,
    required this.recommendations,
  });

  factory GameplayPatterns.empty() {
    return GameplayPatterns(
      responseTimePattern: ResponseTimePattern(
        averageResponseTime: 0,
        fastestResponseTime: 0,
        slowestResponseTime: 0,
        trend: PerformanceTrend.stable,
      ),
      accuracyByCategory: {},
      difficultyProgression: DifficultyProgression(
        currentLevel: 'easy',
        progressionRate: 0.0,
        trend: PerformanceTrend.stable,
      ),
      knowledgeGaps: [],
      performanceTrends: PerformanceTrends(
        overallTrend: PerformanceTrend.stable,
        scoreTrend: PerformanceTrend.stable,
        accuracyTrend: PerformanceTrend.stable,
      ),
      recommendations: [],
    );
  }
  final ResponseTimePattern responseTimePattern;
  final Map<String, CategoryAccuracy> accuracyByCategory;
  final DifficultyProgression difficultyProgression;
  final List<KnowledgeGap> knowledgeGaps;
  final PerformanceTrends performanceTrends;
  final List<String> recommendations;
}

/// Response time pattern
class ResponseTimePattern {

  ResponseTimePattern({
    required this.averageResponseTime,
    required this.fastestResponseTime,
    required this.slowestResponseTime,
    required this.trend,
  });
  final int averageResponseTime;
  final int fastestResponseTime;
  final int slowestResponseTime;
  final PerformanceTrend trend;
}

/// Category accuracy
class CategoryAccuracy {

  CategoryAccuracy({
    required this.category,
    required this.accuracy,
    required this.totalQuestions,
    required this.correctAnswers,
  });
  final String category;
  final double accuracy;
  final int totalQuestions;
  final int correctAnswers;
}

/// Difficulty progression
class DifficultyProgression {

  DifficultyProgression({
    required this.currentLevel,
    required this.progressionRate,
    required this.trend,
  });
  final String currentLevel;
  final double progressionRate;
  final PerformanceTrend trend;
}

/// Knowledge gap
class KnowledgeGap {

  KnowledgeGap({
    required this.category,
    required this.accuracy,
    required this.recommendation,
  });
  final String category;
  final double accuracy;
  final String recommendation;
}

/// Performance trends
class PerformanceTrends {

  PerformanceTrends({
    required this.overallTrend,
    required this.scoreTrend,
    required this.accuracyTrend,
  });
  final PerformanceTrend overallTrend;
  final PerformanceTrend scoreTrend;
  final PerformanceTrend accuracyTrend;
}

/// Performance trend enum
enum PerformanceTrend {
  improving,
  stable,
  declining,
}
