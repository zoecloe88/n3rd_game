/// Service that provides quick tips about game mechanics, gems, points, and strategies
class QuickTipsService {
  /// Get all game gems (tips about scoring and points)
  static List<GameGem> getAllGems() {
    return [
      GameGem(
        title: 'Perfect Round Bonus',
        description:
            'Get all 3 correct answers in a round to earn a perfect streak!',
        category: 'scoring',
        points: '+10 bonus points',
      ),
      GameGem(
        title: 'Streak Rewards',
        description:
            '3rd perfect streak = 1 life, 6th = 1 skip, 9th = 1 clear, 12th = 1 reveal',
        category: 'rewards',
        points: 'Free power-ups',
      ),
      GameGem(
        title: 'Points System',
        description:
            'Each correct answer = 10 points. Perfect round = +10 bonus. Wrong answer = -1 life.',
        category: 'scoring',
        points: '10 points per answer',
      ),
      GameGem(
        title: 'Power-Ups',
        description:
            'You start with 3 Reveal All, 3 Clear, and 3 Skip. Use them wisely!',
        category: 'mechanics',
        points: '3 of each',
      ),
      GameGem(
        title: 'Premium Power-Ups',
        description:
            'Premium users get access to Streak Shield, Time Freeze, Hint, and Double Score!',
        category: 'premium',
        points: '4 extra types',
      ),
      GameGem(
        title: 'Time Attack Mode',
        description:
            'Score as much as possible in 60 seconds. Every correct answer counts!',
        category: 'modes',
        points: 'Unlimited rounds',
      ),
      GameGem(
        title: 'Challenge Mode',
        description:
            'Progressive difficulty - gets harder each round. Higher risk, higher reward!',
        category: 'modes',
        points: 'Bonus multipliers',
      ),
      GameGem(
        title: 'Shuffle Mode',
        description:
            'Tiles shuffle during play phase. Focus and memorize quickly!',
        category: 'modes',
        points: 'Memory challenge',
      ),
      GameGem(
        title: 'Speed Mode',
        description: 'Only 7 seconds to answer! Fast thinking required.',
        category: 'modes',
        points: '7s timer',
      ),
      GameGem(
        title: 'Classic Mode',
        description:
            '10 seconds to memorize, 20 seconds to play. Perfect for beginners!',
        category: 'modes',
        points: '30s total',
      ),
      GameGem(
        title: 'Double Tap to Reveal',
        description: 'Double tap any word tile to reveal it during play phase.',
        category: 'mechanics',
        points: 'Quick reveal',
      ),
      GameGem(
        title: 'Voice Input',
        description:
            'Premium users can speak their answers! Enable in game settings.',
        category: 'premium',
        points: 'Hands-free play',
      ),
      GameGem(
        title: 'Token System',
        description:
            'Free tier gets 5 games per day. The limit resets at midnight UTC.',
        category: 'subscription',
        points: '10/month',
      ),
      GameGem(
        title: 'Leaderboard',
        description:
            'Compete globally! Premium users get access to global leaderboards.',
        category: 'social',
        points: 'Global rankings',
      ),
      GameGem(
        title: 'Daily Challenges',
        description:
            'Complete daily challenges for bonus rewards and achievements!',
        category: 'rewards',
        points: 'Daily bonuses',
      ),
      GameGem(
        title: 'Learning Mode',
        description: 'Review missed questions and improve your knowledge base.',
        category: 'features',
        points: 'Study mode',
      ),
      GameGem(
        title: 'Stats Tracking',
        description:
            'Track your accuracy, streaks, and performance across all game modes.',
        category: 'features',
        points: 'Full analytics',
      ),
      GameGem(
        title: 'Word Info',
        description:
            'Tap the info icon on word tiles after a round to learn more!',
        category: 'features',
        points: 'Educational',
      ),
      GameGem(
        title: 'Perfect Round Strategy',
        description:
            'Focus on getting all 3 correct. The bonus points add up quickly!',
        category: 'strategy',
        points: 'Pro tip',
      ),
      GameGem(
        title: 'Time Management',
        description: 'Don\'t rush! Take time to think, but watch the timer.',
        category: 'strategy',
        points: 'Balance speed & accuracy',
      ),
    ];
  }

  /// Get gems by category
  static List<GameGem> getGemsByCategory(String category) {
    return getAllGems().where((gem) => gem.category == category).toList();
  }

  /// Get random gem
  static GameGem getRandomGem() {
    final gems = getAllGems();
    return gems[DateTime.now().millisecondsSinceEpoch % gems.length];
  }

  /// Get gems for specific game mode
  static List<GameGem> getGemsForMode(String mode) {
    return getAllGems()
        .where(
          (gem) =>
              gem.category == 'modes' ||
              gem.title.toLowerCase().contains(mode.toLowerCase()) ||
              gem.description.toLowerCase().contains(mode.toLowerCase()),
        )
        .toList();
  }
}

/// Model for game gems (tips)
class GameGem {
  final String title;
  final String description;
  final String category;
  final String points;

  GameGem({
    required this.title,
    required this.description,
    required this.category,
    required this.points,
  });
}
