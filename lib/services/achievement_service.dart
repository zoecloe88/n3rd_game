import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:n3rd_game/models/achievement.dart';
import 'package:n3rd_game/services/stats_service.dart';

class AchievementService {
  static final List<Achievement> _allAchievements = [
    Achievement(
      id: 'first_game',
      title: 'First Steps',
      description: 'Play your first game',
      icon: '🎮',
      type: AchievementType.gamesPlayed,
      targetValue: 1,
    ),
    Achievement(
      id: 'perfect_score',
      title: 'Perfect!',
      description: 'Get a perfect score (3/3 correct)',
      icon: '⭐',
      type: AchievementType.perfectScore,
      targetValue: 1,
    ),
    Achievement(
      id: 'games_10',
      title: 'Getting Started',
      description: 'Play 10 games',
      icon: '🏁',
      type: AchievementType.gamesPlayed,
      targetValue: 10,
    ),
    Achievement(
      id: 'games_100',
      title: 'Centurion',
      description: 'Play 100 games',
      icon: '💯',
      type: AchievementType.gamesPlayed,
      targetValue: 100,
    ),
    Achievement(
      id: 'high_score_100',
      title: 'Century Club',
      description: 'Score 100 points in a single game',
      icon: '🎯',
      type: AchievementType.highScore,
      targetValue: 100,
    ),
    Achievement(
      id: 'correct_100',
      title: 'Knowledge Seeker',
      description: 'Answer 100 questions correctly',
      icon: '🧠',
      type: AchievementType.correctAnswers,
      targetValue: 100,
    ),
    Achievement(
      id: 'time_attack_master',
      title: 'Time Master',
      description: 'Play 10 Time Attack games',
      icon: '⏱️',
      type: AchievementType.timeAttack,
      targetValue: 10,
    ),
    Achievement(
      id: 'multiplayer_win',
      title: 'Champion',
      description: 'Win a multiplayer match',
      icon: '🏆',
      type: AchievementType.multiplayerWins,
      targetValue: 1,
    ),
  ];

  FirebaseFirestore? get _firestore {
    try {
      Firebase.app();
      return FirebaseFirestore.instance;
    } catch (e) {
      return null;
    }
  }

  String? get _userId {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (e) {
      return null;
    }
  }

  /// Get all available achievements
  List<Achievement> getAllAchievements() => _allAchievements;

  /// Get user's achievements
  Future<Map<String, UserAchievement>> getUserAchievements() async {
    final firestore = _firestore;
    final userId = _userId;
    if (firestore == null || userId == null) return {};

    try {
      final doc = await firestore
          .collection('user_achievements')
          .doc(userId)
          .get();
      if (!doc.exists) return {};

      final data = doc.data() as Map<String, dynamic>;
      final achievements = <String, UserAchievement>{};

      data.forEach((key, value) {
        achievements[key] = UserAchievement.fromJson(
          value as Map<String, dynamic>,
        );
      });

      return achievements;
    } catch (e) {
      debugPrint('Error fetching user achievements: $e');
      return {};
    }
  }

  /// Check and update achievements based on stats
  Future<List<Achievement>> checkAchievements(GameStats stats) async {
    final firestore = _firestore;
    final userId = _userId;
    if (firestore == null || userId == null) return [];

    final unlocked = <Achievement>[];
    final userAchievements = await getUserAchievements();

    for (final achievement in _allAchievements) {
      final userAchievement = userAchievements[achievement.id];
      if (userAchievement?.unlocked == true) continue;

      int progress = 0;
      bool shouldUnlock = false;

      switch (achievement.type) {
        case AchievementType.gamesPlayed:
          progress = stats.totalGamesPlayed;
          shouldUnlock = progress >= achievement.targetValue;
          break;
        case AchievementType.perfectScore:
          // This would need to be tracked separately
          break;
        case AchievementType.highScore:
          progress = stats.highestScore;
          shouldUnlock = progress >= achievement.targetValue;
          break;
        case AchievementType.correctAnswers:
          progress = stats.totalCorrectAnswers;
          shouldUnlock = progress >= achievement.targetValue;
          break;
        case AchievementType.timeAttack:
          progress = stats.modePlayCounts['Time Attack'] ?? 0;
          shouldUnlock = progress >= achievement.targetValue;
          break;
        case AchievementType.multiplayerWins:
          // This would need to be tracked separately
          break;
      }

      if (shouldUnlock) {
        await _unlockAchievement(achievement, userId, firestore);
        unlocked.add(achievement);
      } else {
        // Update progress
        await _updateAchievementProgress(
          achievement.id,
          progress,
          userId,
          firestore,
        );
      }
    }

    return unlocked;
  }

  Future<void> _unlockAchievement(
    Achievement achievement,
    String userId,
    FirebaseFirestore firestore,
  ) async {
    try {
      final userAchievement = UserAchievement(
        achievementId: achievement.id,
        unlockedAt: DateTime.now(),
        progress: achievement.targetValue,
        unlocked: true,
      );

      await firestore.collection('user_achievements').doc(userId).set({
        achievement.id: userAchievement.toJson(),
      }, SetOptions(merge: true,),);

      // Note: Notification will be sent via Cloud Functions or client-side notification
      debugPrint('Achievement unlocked: ${achievement.title}');
    } catch (e) {
      debugPrint('Error unlocking achievement: $e');
    }
  }

  Future<void> _updateAchievementProgress(
    String achievementId,
    int progress,
    String userId,
    FirebaseFirestore firestore,
  ) async {
    try {
      await firestore.collection('user_achievements').doc(userId).set({
        achievementId: {
          'achievementId': achievementId,
          'progress': progress,
          'unlocked': false,
        },
      }, SetOptions(merge: true,),);
    } catch (e) {
      debugPrint('Error updating achievement progress: $e');
    }
  }
}
