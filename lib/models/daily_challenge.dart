class DailyChallenge {
  final String id;
  final String title;
  final String description;
  final ChallengeType type;
  final Map<String, dynamic> target;
  final DateTime date;
  final int rewardPoints;
  final bool isCompleted;
  final int progress;

  DailyChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.target,
    required this.date,
    this.rewardPoints = 100,
    this.isCompleted = false,
    this.progress = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type.toString(),
        'target': target,
        'date': date.toIso8601String(),
        'rewardPoints': rewardPoints,
        'isCompleted': isCompleted,
        'progress': progress,
      };

  factory DailyChallenge.fromJson(Map<String, dynamic> json) => DailyChallenge(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        type: ChallengeType.values.firstWhere(
          (e) => e.toString() == json['type'],
          orElse: () => ChallengeType.perfectScore,
        ),
        target: json['target'] as Map<String, dynamic>,
        date: DateTime.parse(json['date'] as String),
        rewardPoints: json['rewardPoints'] as int? ?? 100,
        isCompleted: json['isCompleted'] as bool? ?? false,
        progress: json['progress'] as int? ?? 0,
      );

  DailyChallenge copyWith({
    String? id,
    String? title,
    String? description,
    ChallengeType? type,
    Map<String, dynamic>? target,
    DateTime? date,
    int? rewardPoints,
    bool? isCompleted,
    int? progress,
  }) {
    return DailyChallenge(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      target: target ?? this.target,
      date: date ?? this.date,
      rewardPoints: rewardPoints ?? this.rewardPoints,
      isCompleted: isCompleted ?? this.isCompleted,
      progress: progress ?? this.progress,
    );
  }
}

enum ChallengeType {
  perfectScore, // Get X perfect scores
  streak, // Maintain X game streak
  category, // Play X games in specific category
  timeAttack, // Score X points in time attack
  accuracy, // Achieve X% accuracy
  gamesPlayed, // Play X games
  modeSpecific, // Play X games in specific mode
  dailyCompetitive, // Competitive daily challenge with leaderboard
}
