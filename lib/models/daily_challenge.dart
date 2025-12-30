/// Model representing a daily challenge
///
/// Daily challenges are tasks that users can complete to earn rewards.
/// Challenges can be regular (progress-based) or competitive (leaderboard-based).
///
/// Example:
/// ```dart
/// final challenge = DailyChallenge(
///   id: 'challenge_123',
///   title: 'Perfect Performance',
///   description: 'Get 3 perfect scores',
///   type: ChallengeType.perfectScore,
///   target: {'count': 3},
///   date: DateTime.now(),
///   rewardPoints: 150,
/// );
/// ```
class DailyChallenge {

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
  /// Unique identifier for the challenge
  final String id;

  /// Display title of the challenge
  final String title;

  /// Description explaining what the challenge requires
  final String description;

  /// Type of challenge (determines how progress is tracked)
  final ChallengeType type;

  /// Target values for the challenge (varies by type)
  /// - perfectScore: {'count': int}
  /// - streak: {'streak': int}
  /// - gamesPlayed: {'count': int}
  /// - accuracy: {'accuracy': int, 'games': int}
  /// - timeAttack: {'score': int}
  /// - category: {'category': String, 'count': int}
  /// - modeSpecific: {'mode': String, 'count': int}
  /// - dailyCompetitive: {'mode': String, 'rounds': int}
  final Map<String, dynamic> target;

  /// Date the challenge is for (UTC)
  final DateTime date;

  /// Reward points awarded upon completion
  final int rewardPoints;

  /// Whether the challenge has been completed
  final bool isCompleted;

  /// Current progress toward the target
  final int progress;

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

/// Types of daily challenges
///
/// Each type has different target requirements and progress tracking:
/// - [perfectScore]: Get X perfect scores (3/3 correct)
/// - [streak]: Maintain X game winning streak
/// - [category]: Play X games in a specific category
/// - [timeAttack]: Score X points in Time Attack mode
/// - [accuracy]: Achieve X% accuracy in Y games
/// - [gamesPlayed]: Play X games total
/// - [modeSpecific]: Play X games in a specific mode
/// - [dailyCompetitive]: Competitive challenge with leaderboard (one per day)
enum ChallengeType {
  /// Get X perfect scores (3/3 correct answers)
  perfectScore,

  /// Maintain X game winning streak
  streak,

  /// Play X games in specific category
  category,

  /// Score X points in Time Attack mode
  timeAttack,

  /// Achieve X% accuracy in Y games
  accuracy,

  /// Play X games total
  gamesPlayed,

  /// Play X games in specific mode
  modeSpecific,

  /// Competitive daily challenge with leaderboard (one per day)
  dailyCompetitive,
}
