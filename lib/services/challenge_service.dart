import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:convert';
import 'package:n3rd_game/models/daily_challenge.dart';

class ChallengeService extends ChangeNotifier {
  static const String _storageKey = 'daily_challenges';
  List<DailyChallenge> _challenges = [];
  bool _firebaseAvailable = false;

  List<DailyChallenge> get challenges => _challenges;
  List<DailyChallenge> get todayChallenges => _challenges.where((c) {
    // Use UTC for consistency with leaderboard service
    final today = DateTime.now().toUtc();
    final challengeDate = c.date.toUtc();
    return challengeDate.year == today.year &&
        challengeDate.month == today.month &&
        challengeDate.day == today.day;
  }).toList();

  FirebaseFirestore? get _firestore {
    if (!_firebaseAvailable) return null;
    try {
      Firebase.app();
      return FirebaseFirestore.instance;
    } catch (e) {
      _firebaseAvailable = false;
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

  Future<void> init() async {
    try {
      Firebase.app();
      _firebaseAvailable = true;

      final userId = _userId;
      if (userId != null) {
        try {
          final doc = await _firestore!
              .collection('user_challenges')
              .doc(userId)
              .get();
          if (doc.exists && doc.data() != null) {
            final data = doc.data();
            if (data == null) return;
            _challenges =
                (data['challenges'] as List?)
                    ?.map(
                      (c) => DailyChallenge.fromJson(c as Map<String, dynamic>),
                    )
                    .toList() ??
                [];
            notifyListeners();
            await _saveLocal();
            return;
          }
        } catch (e) {
          debugPrint('Failed to load challenges from Firestore: $e');
        }
      }
    } catch (e) {
      _firebaseAvailable = false;
      debugPrint('Firebase not available for challenges: $e');
    }

    await _loadLocal();
    await _generateDailyChallenges();
  }

  Future<void> _loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        _challenges =
            (data['challenges'] as List?)
                ?.map((c) => DailyChallenge.fromJson(c as Map<String, dynamic>))
                .toList() ??
            [];
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to load challenges from local storage: $e');
    }
  }

  Future<void> _saveLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {'challenges': _challenges.map((c) => c.toJson()).toList()};
      await prefs.setString(_storageKey, jsonEncode(data));
    } catch (e) {
      debugPrint('Failed to save challenges to local storage: $e');
    }
  }

  Future<void> _saveToFirestore() async {
    if (!_firebaseAvailable) return;
    final userId = _userId;
    if (userId == null) return;

    try {
      await _firestore!.collection('user_challenges').doc(userId).set({
        'challenges': _challenges.map((c) => c.toJson()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true,),);
    } catch (e) {
      debugPrint('Failed to save challenges to Firestore: $e');
    }
  }

  /// Generate daily challenges for today
  Future<void> _generateDailyChallenges() async {
    // Use UTC for consistency with leaderboard service
    final today = DateTime.now().toUtc();
    final todayChallenges = _challenges.where((c) {
      final challengeDate = c.date.toUtc();
      return challengeDate.year == today.year &&
          challengeDate.month == today.month &&
          challengeDate.day == today.day;
    }).toList();

    // If we already have challenges for today, don't regenerate
    if (todayChallenges.isNotEmpty) {
      return;
    }

    // Generate 3-5 random challenges for today + 1 competitive challenge
    final random = Random();
    final challengeCount = 3 + random.nextInt(3); // 3-5 challenges
    final newChallenges = <DailyChallenge>[];

    // Add one competitive challenge first
    newChallenges.add(_generateDailyCompetitiveChallenge(today));

    // Generate regular challenges (exclude competitive from random pool)
    for (int i = 0; i < challengeCount; i++) {
      final challenge = _generateRandomChallenge(today);
      newChallenges.add(challenge);
    }

    _challenges.addAll(newChallenges);
    notifyListeners();
    await _saveLocal();
    await _saveToFirestore();
  }

  /// Generate daily competitive challenge (one per day)
  DailyChallenge _generateDailyCompetitiveChallenge(DateTime date) {
    final random = Random();
    final modes = ['Blitz', 'Speed', 'Classic', 'Streak', 'Shuffle'];
    final mode = modes[random.nextInt(modes.length)];
    final rounds = 5 + random.nextInt(3); // 5-7 rounds

    return DailyChallenge(
      id: '${date.millisecondsSinceEpoch}_competitive',
      title: 'Daily Challenge: $mode Mode',
      description:
          'Compete in $mode Mode - $rounds rounds. Top 5 players on leaderboard!',
      type: ChallengeType.dailyCompetitive,
      target: {'mode': mode, 'rounds': rounds},
      date: date,
      rewardPoints: 300, // Higher reward for competitive
    );
  }

  DailyChallenge _generateRandomChallenge(DateTime date) {
    final random = Random();
    // Exclude competitive from random pool
    final types = ChallengeType.values
        .where((t) => t != ChallengeType.dailyCompetitive)
        .toList();
    final type = types[random.nextInt(types.length)];

    switch (type) {
      case ChallengeType.perfectScore:
        return DailyChallenge(
          id: '${date.millisecondsSinceEpoch}_perfect',
          title: 'Perfect Performance',
          description:
              'Get ${2 + random.nextInt(3)} perfect scores (3/3 correct)',
          type: type,
          target: {'count': 2 + random.nextInt(3)},
          date: date,
          rewardPoints: 150,
        );
      case ChallengeType.streak:
        return DailyChallenge(
          id: '${date.millisecondsSinceEpoch}_streak',
          title: 'Streak Master',
          description:
              'Maintain a ${3 + random.nextInt(3)} game winning streak',
          type: type,
          target: {'streak': 3 + random.nextInt(3)},
          date: date,
          rewardPoints: 200,
        );
      case ChallengeType.gamesPlayed:
        return DailyChallenge(
          id: '${date.millisecondsSinceEpoch}_games',
          title: 'Daily Grind',
          description: 'Play ${5 + random.nextInt(6)} games today',
          type: type,
          target: {'count': 5 + random.nextInt(6)},
          date: date,
          rewardPoints: 100,
        );
      case ChallengeType.accuracy:
        return DailyChallenge(
          id: '${date.millisecondsSinceEpoch}_accuracy',
          title: 'Precision Expert',
          description:
              'Achieve ${70 + random.nextInt(21)}% accuracy in 5 games',
          type: type,
          target: {'accuracy': 70 + random.nextInt(21), 'games': 5},
          date: date,
          rewardPoints: 180,
        );
      case ChallengeType.timeAttack:
        return DailyChallenge(
          id: '${date.millisecondsSinceEpoch}_timeattack',
          title: 'Time Warrior',
          description:
              'Score ${100 + random.nextInt(100)} points in Time Attack mode',
          type: type,
          target: {'score': 100 + random.nextInt(100)},
          date: date,
          rewardPoints: 250,
        );
      case ChallengeType.category:
        final categories = [
          'History',
          'Science',
          'Geography',
          'Sports',
          'Entertainment',
        ];
        final category = categories[random.nextInt(categories.length)];
        return DailyChallenge(
          id: '${date.millisecondsSinceEpoch}_category',
          title: 'Category Specialist',
          description: 'Play 3 games in $category category',
          type: type,
          target: {'category': category, 'count': 3},
          date: date,
          rewardPoints: 120,
        );
      case ChallengeType.modeSpecific:
        final modes = ['Classic', 'Speed', 'Shuffle', 'Challenge'];
        final mode = modes[random.nextInt(modes.length)];
        return DailyChallenge(
          id: '${date.millisecondsSinceEpoch}_mode',
          title: 'Mode Master',
          description: 'Play 2 games in $mode mode',
          type: type,
          target: {'mode': mode, 'count': 2},
          date: date,
          rewardPoints: 130,
        );
      case ChallengeType.dailyCompetitive:
        // This should not be called in random generation
        // Competitive challenges are generated separately
        return _generateDailyCompetitiveChallenge(date);
    }
  }

  /// Update challenge progress
  Future<void> updateChallengeProgress(String challengeId, int progress) async {
    final index = _challenges.indexWhere((c) => c.id == challengeId);
    if (index != -1) {
      final challenge = _challenges[index];
      final newProgress = challenge.progress + progress;
      final targetValue =
          challenge.target['count'] ??
          challenge.target['streak'] ??
          challenge.target['score'] ??
          1;
      final isCompleted = newProgress >= targetValue;

      _challenges[index] = challenge.copyWith(
        progress: newProgress,
        isCompleted: isCompleted,
      );

      notifyListeners();
      await _saveLocal();
      await _saveToFirestore();
    }
  }

  /// Mark challenge as completed
  Future<void> completeChallenge(String challengeId) async {
    final index = _challenges.indexWhere((c) => c.id == challengeId);
    if (index != -1) {
      _challenges[index] = _challenges[index].copyWith(isCompleted: true);
      notifyListeners();
      await _saveLocal();
      await _saveToFirestore();
    }
  }
}
