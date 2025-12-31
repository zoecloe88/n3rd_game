class PerformanceMetric { // 0-23 for time-of-day analysis

  PerformanceMetric({
    required this.date,
    required this.score,
    required this.accuracy,
    required this.gamesPlayed,
    this.category,
    required this.hourOfDay,
  });

  factory PerformanceMetric.fromJson(Map<String, dynamic> json) =>
      PerformanceMetric(
        date: DateTime.parse(json['date'] as String),
        score: (json['score'] as num).toDouble(),
        accuracy: (json['accuracy'] as num).toDouble(),
        gamesPlayed: json['gamesPlayed'] as int,
        category: json['category'] as String?,
        hourOfDay: json['hourOfDay'] as int,
      );
  final DateTime date;
  final double score;
  final double accuracy;
  final int gamesPlayed;
  final String? category;
  final int hourOfDay;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'score': score,
        'accuracy': accuracy,
        'gamesPlayed': gamesPlayed,
        'category': category,
        'hourOfDay': hourOfDay,
      };
}

class CategoryPerformance {

  CategoryPerformance({
    required this.category,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.accuracy,
    required this.averageScore,
  });
  final String category;
  final int totalQuestions;
  final int correctAnswers;
  final double accuracy;
  final double averageScore;
}

class TimeOfDayPerformance {

  TimeOfDayPerformance({
    required this.hour,
    required this.averageScore,
    required this.averageAccuracy,
    required this.totalGames,
  });
  final int hour; // 0-23
  final double averageScore;
  final double averageAccuracy;
  final int totalGames;
}
