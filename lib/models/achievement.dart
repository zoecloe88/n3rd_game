class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final AchievementType type;
  final int targetValue;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.type,
    required this.targetValue,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'icon': icon,
        'type': type.toString(),
        'targetValue': targetValue,
      };

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        icon: json['icon'] as String,
        type: AchievementType.values.firstWhere(
          (e) => e.toString() == json['type'],
          orElse: () => AchievementType.gamesPlayed,
        ),
        targetValue: json['targetValue'] as int,
      );
}

enum AchievementType {
  gamesPlayed,
  perfectScore,
  highScore,
  correctAnswers,
  timeAttack,
  multiplayerWins,
}

class UserAchievement {
  final String achievementId;
  final DateTime unlockedAt;
  final int progress;
  final bool unlocked;

  UserAchievement({
    required this.achievementId,
    required this.unlockedAt,
    required this.progress,
    required this.unlocked,
  });

  Map<String, dynamic> toJson() => {
        'achievementId': achievementId,
        'unlockedAt': unlockedAt.toIso8601String(),
        'progress': progress,
        'unlocked': unlocked,
      };

  factory UserAchievement.fromJson(Map<String, dynamic> json) =>
      UserAchievement(
        achievementId: json['achievementId'] as String,
        unlockedAt: DateTime.parse(json['unlockedAt'] as String),
        progress: json['progress'] as int,
        unlocked: json['unlocked'] as bool,
      );
}
