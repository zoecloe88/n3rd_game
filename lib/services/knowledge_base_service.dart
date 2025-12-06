/// Service for managing knowledge base articles and searchable help content
class KnowledgeBaseService {
  /// Get all knowledge base articles
  static List<KnowledgeArticle> getAllArticles() {
    return [
      // Getting Started
      KnowledgeArticle(
        id: 'getting_started',
        title: 'Getting Started',
        category: 'Getting Started',
        content: '''
# Getting Started with N3RD Trivia

Welcome to N3RD Trivia! Here's everything you need to know to get started.

## First Steps
1. **Create an Account** - Sign up with your email to save your progress
2. **Choose Your Tier** - Start with Free (5 games/day) or upgrade for more
3. **Select a Game Mode** - Try Classic mode first, it's perfect for beginners
4. **Play Your First Round** - Memorize the words, then select the correct answers

## Understanding the Game
- **Memorize Phase**: Study the words (10 seconds in Classic mode)
- **Play Phase**: Select exactly 3 correct answers from 6 words shown (20 seconds in Classic mode)
- **Scoring**: 10 points per correct answer, +10 bonus for perfect round
- **Lives**: Start with 3 lives, lose 1 for each wrong answer

## Tips for Success
- Focus on getting all 3 correct for bonus points
- Use power-ups wisely (you start with 3 of each)
- Practice daily to improve your memory and speed
- Check your stats to track your progress
        ''',
        tags: ['beginner', 'tutorial', 'basics'],
      ),

      // Scoring System
      KnowledgeArticle(
        id: 'scoring_system',
        title: 'Understanding the Scoring System',
        category: 'Gameplay',
        content: '''
# Scoring System Explained

## Points Breakdown
- **Correct Answer**: 10 points each
- **Perfect Round** (3/3 correct): +10 bonus points
- **Wrong Answer**: -1 life (no points deducted)

## Example Scoring
- Round 1: 2 correct = 20 points
- Round 2: 3 correct = 30 points + 10 bonus = 40 points
- Round 3: 1 correct = 10 points
- **Total**: 70 points

## Perfect Streaks
Getting perfect rounds builds your streak:
- **3rd perfect streak**: Earn 1 life
- **6th perfect streak**: Earn 1 skip power-up
- **9th perfect streak**: Earn 1 clear power-up
- **12th perfect streak**: Earn 1 reveal power-up

## High Scores
- Track your highest score in Stats
- Compete on leaderboards (Premium feature)
- Daily challenges offer bonus points
        ''',
        tags: ['scoring', 'points', 'streaks', 'rewards'],
      ),

      // Power-Ups
      KnowledgeArticle(
        id: 'power_ups',
        title: 'Power-Ups Guide',
        category: 'Gameplay',
        content: '''
# Power-Ups Guide

## Standard Power-Ups (All Users)
You start each game with:
- **3x Reveal All**: Shows all correct answers
- **3x Clear**: Removes all selected answers
- **3x Skip**: Skips to next round (lose current round points)

## Premium Power-Ups (Premium Users Only)
- **Streak Shield**: Protects your perfect streak (1 wrong answer allowed)
- **Time Freeze**: Pauses the timer for 5 seconds
- **Hint**: Highlights one correct answer
- **Double Score**: Doubles points for current round

## Strategy Tips
- Save Reveal All for difficult rounds
- Use Clear if you're unsure about selections
- Skip only if you're completely stuck
- Premium power-ups are best used in Challenge mode

## Earning Power-Ups
- Start each game with 3 standard power-ups
- Earn additional power-ups through perfect streaks
- Premium users get access to advanced power-ups
        ''',
        tags: ['power-ups', 'strategy', 'premium'],
      ),

      // Game Modes
      KnowledgeArticle(
        id: 'game_modes',
        title: 'Game Modes Explained',
        category: 'Gameplay',
        content: '''
# All Game Modes

## Classic Mode
- **Memorize**: 10 seconds
- **Play**: 20 seconds
- **Best for**: Beginners, learning the game

## Classic II Mode
- **Memorize**: 5 seconds
- **Play**: 10 seconds
- **Best for**: Intermediate players, faster pace

## Speed Mode
- **Memorize**: 0 seconds (words shown with question)
- **Play**: 7 seconds
- **Best for**: Quick thinking, fast reactions

## Regular Mode
- **Memorize**: 0 seconds (words shown with question)
- **Play**: 15 seconds
- **Best for**: Balanced gameplay

## Shuffle Mode
- **Memorize**: 10 seconds
- **Play**: 20 seconds (tiles shuffle during play)
- **Best for**: Memory challenge, focus training

## Challenge Mode
- **Progressive difficulty**: Gets harder each round
- Round 1: 12s memorize, 18s play
- Round 2: 10s memorize, 15s play
- Round 3: 8s memorize, 12s play
- Round 4+: 6s memorize, 10s play
- **Best for**: Advanced players, high scores

## Time Attack Mode
- **Duration**: 60 seconds continuous
- **Goal**: Score as much as possible
- **Best for**: Speed runs, high score attempts

## Random Mode
- **Variety**: Different mode each round
- **Best for**: Surprise challenge, variety

## Flip Mode
- **Memorize**: 10 seconds (4s visible, then tiles flip face-down one by one over 6s)
- **Play**: 20 seconds (all tiles face-down, select 3 correct in order)
- **Reveal Settings**: Instant (flip on tap), Blind (reveal after 3 selections), or Random
- **Best for**: Memory challenge, spatial memory training
        ''',
        tags: ['modes', 'gameplay', 'difficulty'],
      ),

      // Subscription Tiers
      KnowledgeArticle(
        id: 'subscription_tiers',
        title: 'Subscription Tiers & Pricing',
        category: 'Account',
        content: '''
# Subscription Tiers

## Free Tier
- **Cost**: \$0
- **Features**:
  - Classic mode only
  - 5 games per day (resets at midnight UTC)
  - General trivia database only
  - No ads
  - No editions or online features

## Basic Tier
- **Cost**: \$2.99/month
- **Features**:
  - All game modes (except AI Mode)
  - Unlimited play
  - Regular trivia database only
  - No ads
  - Offline play
  - No editions or online features

## Premium Tier
- **Cost**: \$4.99/month
- **Features**:
  - Everything in Basic
  - AI Mode (adaptive difficulty)
  - All editions & categories (100+)
  - Online multiplayer
  - Global leaderboard
  - Voice input (speak answers)
  - Text-to-speech (hear questions)
  - Advanced power-ups
  - Early access to features
  - Priority support

## Game Limits
- Free tier: 5 games per day (resets at midnight UTC)
- Basic tier: Unlimited play
- Premium tier: Unlimited play

## Managing Subscriptions
- Go to Settings > Manage Subscriptions
- Restore purchases if needed
- Cancel anytime (access until end of billing period)
        ''',
        tags: ['subscription', 'pricing', 'tokens', 'premium'],
      ),

      // Troubleshooting
      KnowledgeArticle(
        id: 'troubleshooting',
        title: 'Common Issues & Solutions',
        category: 'Support',
        content: '''
# Troubleshooting Guide

## App Crashes or Freezes
1. Force close the app completely
2. Restart your device
3. Check for app updates
4. Clear app cache (Settings)
5. Reinstall if problem persists

## Login Issues
1. Check internet connection
2. Verify email and password
3. Try "Forgot Password"
4. Check if account is active
5. Sign out and sign back in

## Game Not Working
1. Check you have tokens (free tier) or active subscription
2. Verify internet connection
3. Restart the game
4. Check game mode availability for your tier

## Video/Background Issues
1. Wait a few seconds for videos to load
2. Check internet connection
3. Restart the app
4. Check available storage space

## Sound/Audio Issues
1. Check device volume
2. Turn off Do Not Disturb
3. Check app sound settings
4. Restart the app

## Performance Issues
1. Close other apps
2. Restart device
3. Check available storage (need 500MB+)
4. Clear app cache
5. Update device software

## Subscription Issues
1. Check subscription status in Settings
2. Verify payment was successful
3. Try "Restore Purchases"
4. Contact billing support with receipt
        ''',
        tags: ['troubleshooting', 'support', 'fixes'],
      ),

      // Features
      KnowledgeArticle(
        id: 'features',
        title: 'All Features',
        category: 'Features',
        content: '''
# Complete Feature List

## Game Features
- Multiple game modes (8 different modes)
- Power-ups and streak rewards
- Daily challenges
- Achievements system
- Stats tracking
- Word of the Day

## Learning Features
- Learning Mode (review missed questions)
- Word info lookup (tap info icon)
- Educational content
- Performance insights

## Social Features
- Connect with friends
- Direct messaging
- Multiplayer games (Premium)
- Global leaderboards (Premium)

## Premium Features
- Voice input (speak answers)
- Text-to-speech (hear questions)
- Advanced power-ups
- Online multiplayer
- Priority support

## Accessibility
- Screen reader support
- Voice input/output
- Customizable settings
- High contrast options
        ''',
        tags: ['features', 'premium', 'accessibility'],
      ),
    ];
  }

  /// Search articles by query
  static List<KnowledgeArticle> searchArticles(String query) {
    if (query.isEmpty) return getAllArticles();

    final lowerQuery = query.toLowerCase();
    return getAllArticles().where((article) {
      return article.title.toLowerCase().contains(lowerQuery) ||
          article.content.toLowerCase().contains(lowerQuery) ||
          article.category.toLowerCase().contains(lowerQuery) ||
          article.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  /// Get articles by category
  static List<KnowledgeArticle> getArticlesByCategory(String category) {
    return getAllArticles()
        .where((article) => article.category == category)
        .toList();
  }

  /// Get article by ID
  static KnowledgeArticle? getArticleById(String id) {
    try {
      return getAllArticles().firstWhere((article) => article.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get related articles
  static List<KnowledgeArticle> getRelatedArticles(
    String articleId, {
    int limit = 3,
  }) {
    final article = getArticleById(articleId);
    if (article == null) return [];

    return getAllArticles()
        .where(
          (a) =>
              a.id != articleId &&
              (a.category == article.category ||
                  a.tags.any((tag) => article.tags.contains(tag))),
        )
        .take(limit)
        .toList();
  }
}

/// Knowledge Article model
class KnowledgeArticle {
  final String id;
  final String title;
  final String category;
  final String content;
  final List<String> tags;

  KnowledgeArticle({
    required this.id,
    required this.title,
    required this.category,
    required this.content,
    required this.tags,
  });
}
