import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart'
    as firebase_crashlytics;
import 'dart:async';
import 'dart:convert';
import 'package:n3rd_game/services/achievement_service.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/config/app_config.dart';

/// Daily statistics for historical tracking
class DailyStats {
  final DateTime date;
  final int gamesPlayed;
  final int correctAnswers;
  final int wrongAnswers;
  final int score;
  final int highestScore;
  final Map<String, int> modePlayCounts;

  DailyStats({
    required this.date,
    this.gamesPlayed = 0,
    this.correctAnswers = 0,
    this.wrongAnswers = 0,
    this.score = 0,
    this.highestScore = 0,
    Map<String, int>? modePlayCounts,
  }) : modePlayCounts = modePlayCounts ?? {};

  double get accuracy => correctAnswers + wrongAnswers > 0
      ? (correctAnswers / (correctAnswers + wrongAnswers)) * 100
      : 0;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'gamesPlayed': gamesPlayed,
        'correctAnswers': correctAnswers,
        'wrongAnswers': wrongAnswers,
        'score': score,
        'highestScore': highestScore,
        'modePlayCounts': modePlayCounts,
      };

  factory DailyStats.fromJson(Map<String, dynamic> json) => DailyStats(
        date: () {
          try {
            return DateTime.parse(json['date'] as String);
          } catch (e) {
            // CRITICAL: Handle malformed date strings to prevent crashes
            // Use current date as fallback for required field
            LoggerService.warning(
              'Failed to parse DailyStats date: ${json['date']}, using current date as fallback',
              error: e,
            );
            return DateTime.now();
          }
        }(),
        gamesPlayed: json['gamesPlayed'] ?? 0,
        correctAnswers: json['correctAnswers'] ?? 0,
        wrongAnswers: json['wrongAnswers'] ?? 0,
        score: json['score'] ?? 0,
        highestScore: json['highestScore'] ?? 0,
        modePlayCounts: Map<String, int>.from(json['modePlayCounts'] ?? {}),
      );

  DailyStats copyWith({
    DateTime? date,
    int? gamesPlayed,
    int? correctAnswers,
    int? wrongAnswers,
    int? score,
    int? highestScore,
    Map<String, int>? modePlayCounts,
  }) {
    return DailyStats(
      date: date ?? this.date,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      wrongAnswers: wrongAnswers ?? this.wrongAnswers,
      score: score ?? this.score,
      highestScore: highestScore ?? this.highestScore,
      modePlayCounts: modePlayCounts ?? this.modePlayCounts,
    );
  }
}

class GameStats {
  final int totalGamesPlayed;
  final int totalCorrectAnswers;
  final int totalWrongAnswers;
  final int highestScore;
  final int totalTimeAttackScore;
  final Map<String, int> modePlayCounts;
  final List<DailyStats> dailyStats;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastPlayDate;

  GameStats({
    this.totalGamesPlayed = 0,
    this.totalCorrectAnswers = 0,
    this.totalWrongAnswers = 0,
    this.highestScore = 0,
    this.totalTimeAttackScore = 0,
    Map<String, int>? modePlayCounts,
    List<DailyStats>? dailyStats,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastPlayDate,
  })  : modePlayCounts = modePlayCounts ?? {},
        dailyStats = dailyStats ?? [];

  double get accuracy => totalCorrectAnswers + totalWrongAnswers > 0
      ? (totalCorrectAnswers / (totalCorrectAnswers + totalWrongAnswers)) * 100
      : 0;

  Map<String, dynamic> toJson() => {
        'totalGamesPlayed': totalGamesPlayed,
        'totalCorrectAnswers': totalCorrectAnswers,
        'totalWrongAnswers': totalWrongAnswers,
        'highestScore': highestScore,
        'totalTimeAttackScore': totalTimeAttackScore,
        'modePlayCounts': modePlayCounts,
        'dailyStats': dailyStats.map((ds) => ds.toJson()).toList(),
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'lastPlayDate': lastPlayDate?.toIso8601String(),
      };

  factory GameStats.fromJson(Map<String, dynamic> json) => GameStats(
        totalGamesPlayed: json['totalGamesPlayed'] ?? 0,
        totalCorrectAnswers: json['totalCorrectAnswers'] ?? 0,
        totalWrongAnswers: json['totalWrongAnswers'] ?? 0,
        highestScore: json['highestScore'] ?? 0,
        totalTimeAttackScore: json['totalTimeAttackScore'] ?? 0,
        modePlayCounts: Map<String, int>.from(json['modePlayCounts'] ?? {}),
        dailyStats: (json['dailyStats'] as List<dynamic>?)
                ?.map((ds) => DailyStats.fromJson(ds as Map<String, dynamic>))
                .toList() ??
            [],
        currentStreak: json['currentStreak'] ?? 0,
        longestStreak: json['longestStreak'] ?? 0,
        lastPlayDate: json['lastPlayDate'] != null
            ? () {
                try {
                  return DateTime.parse(json['lastPlayDate'] as String);
                } catch (e) {
                  // CRITICAL: Handle malformed date strings to prevent crashes
                  // Return null if parsing fails for optional field
                  LoggerService.warning(
                    'Failed to parse GameStats lastPlayDate: ${json['lastPlayDate']}',
                    error: e,
                  );
                  return null;
                }
              }()
            : null,
      );

  GameStats copyWith({
    int? totalGamesPlayed,
    int? totalCorrectAnswers,
    int? totalWrongAnswers,
    int? highestScore,
    int? totalTimeAttackScore,
    Map<String, int>? modePlayCounts,
    List<DailyStats>? dailyStats,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastPlayDate,
  }) {
    return GameStats(
      totalGamesPlayed: totalGamesPlayed ?? this.totalGamesPlayed,
      totalCorrectAnswers: totalCorrectAnswers ?? this.totalCorrectAnswers,
      totalWrongAnswers: totalWrongAnswers ?? this.totalWrongAnswers,
      highestScore: highestScore ?? this.highestScore,
      totalTimeAttackScore: totalTimeAttackScore ?? this.totalTimeAttackScore,
      modePlayCounts: modePlayCounts ?? this.modePlayCounts,
      dailyStats: dailyStats ?? this.dailyStats,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastPlayDate: lastPlayDate ?? this.lastPlayDate,
    );
  }
}

class StatsService extends ChangeNotifier {
  static const String _storageKey = 'game_stats';
  GameStats _stats = GameStats();
  bool _firebaseAvailable = false;
  bool _isSaving = false; // Mutex to prevent concurrent saves
  bool _isRecordingGameEnd = false; // Mutex to prevent concurrent recordGameEnd calls
  bool _isInitialized = false;
  bool _isInitializing = false; // Mutex to prevent concurrent initialization

  GameStats get stats => _stats;
  bool get isInitialized => _isInitialized;

  // Get Firestore instance if Firebase is available
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

  // Get current user ID for Firestore
  String? get _userId {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (e) {
      return null;
    }
  }

  Future<void> init() async {
    if (_isInitialized || _isInitializing) return;

    _isInitializing = true;

    try {
      // Try to initialize Firebase
      try {
        Firebase.app();
        _firebaseAvailable = true;

      // Try to load from Firestore if user is logged in (with timeout)
      final userId = _userId;
      if (userId != null) {
        try {
          const timeoutDuration = Duration(seconds: 10);
          final doc = await _firestore!
              .collection('user_stats')
              .doc(userId)
              .get()
              .timeout(
            timeoutDuration,
            onTimeout: () {
              throw TimeoutException(
                'Firestore load timeout after ${timeoutDuration.inSeconds}s',
              );
            },
          );
          if (doc.exists && doc.data() != null) {
            final data = doc.data();
            if (data != null) {
              _stats = GameStats.fromJson(data);
            }
            notifyListeners();
            // Also save to local storage as backup
            await _saveLocal();
            return;
          }
        } catch (e) {
          LoggerService.error('Failed to load stats from Firestore', error: e);
          // Fall through to local storage
        }
      }
    } catch (e) {
      _firebaseAvailable = false;
      LoggerService.warning('Firebase not available for stats', error: e);
    }

      // Fallback to local storage
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_storageKey);
      if (json != null) {
        _stats = GameStats.fromJson(jsonDecode(json));
        notifyListeners();
      }

      _isInitialized = true;
      LoggerService.info('StatsService initialized');
    } catch (e, stackTrace) {
      LoggerService.error(
        'Error initializing StatsService',
        error: e,
        stack: stackTrace,
      );
      _isInitialized = false;
    } finally {
      _isInitializing = false;
    }
  }

  /// Normalize date to UTC and strip time component for consistent comparison
  DateTime _normalizeDate(DateTime date) {
    final utc = date.toUtc();
    return DateTime(utc.year, utc.month, utc.day);
  }

  Future<void> recordGameEnd({
    required int score,
    required int correctAnswers,
    required int wrongAnswers,
    required String mode,
  }) async {
    // Mutex to prevent concurrent calls
    if (_isRecordingGameEnd) {
      LoggerService.warning('recordGameEnd already in progress, skipping duplicate call');
      return;
    }
    _isRecordingGameEnd = true;

    try {
      // Validate input
      if (score < 0) {
        LoggerService.warning('Invalid score: $score');
        _isRecordingGameEnd = false;
        return;
      }
      if (correctAnswers < 0 || wrongAnswers < 0) {
        LoggerService.warning('Invalid answer counts');
        _isRecordingGameEnd = false;
        return;
      }
      if (mode.isEmpty) {
        LoggerService.warning('Invalid mode: empty string');
        _isRecordingGameEnd = false;
        return;
      }

      final newModePlayCounts = Map<String, int>.from(_stats.modePlayCounts);
      newModePlayCounts[mode] = (newModePlayCounts[mode] ?? 0) + 1;

      // Calculate streak with timezone-safe date normalization
      final today = _normalizeDate(DateTime.now());
      final lastPlayKey = _stats.lastPlayDate != null
          ? _normalizeDate(_stats.lastPlayDate!)
          : null;

      int newCurrentStreak = _stats.currentStreak;
      int newLongestStreak = _stats.longestStreak;

      if (lastPlayKey == null) {
        // First play
        newCurrentStreak = 1;
        newLongestStreak = 1;
      } else {
        final daysDiff = today.difference(lastPlayKey).inDays;
        if (daysDiff == 0) {
          // Same day - maintain streak
          newCurrentStreak = _stats.currentStreak;
        } else if (daysDiff == 1) {
          // Consecutive day - increment streak
          newCurrentStreak = _stats.currentStreak + 1;
          if (newCurrentStreak > newLongestStreak) {
            newLongestStreak = newCurrentStreak;
          }
        } else {
          // Streak broken
          newCurrentStreak = 1;
        }
      }

      // Record daily stats with timezone-safe date comparison
      final dailyStatsList = List<DailyStats>.from(_stats.dailyStats);
      final todayIndex = dailyStatsList.indexWhere(
        (ds) => _normalizeDate(ds.date) == today,
      );

      if (todayIndex >= 0) {
        // Update existing day
        final existing = dailyStatsList[todayIndex];
        dailyStatsList[todayIndex] = existing.copyWith(
          gamesPlayed: existing.gamesPlayed + 1,
          correctAnswers: existing.correctAnswers + correctAnswers,
          wrongAnswers: existing.wrongAnswers + wrongAnswers,
          score: existing.score + score,
          highestScore:
              score > existing.highestScore ? score : existing.highestScore,
          modePlayCounts: {
            ...existing.modePlayCounts,
            mode: (existing.modePlayCounts[mode] ?? 0) + 1,
          },
        );
      } else {
        // Add new day
        dailyStatsList.add(
          DailyStats(
            date: DateTime.now().toUtc(), // Store actual UTC timestamp
            gamesPlayed: 1,
            correctAnswers: correctAnswers,
            wrongAnswers: wrongAnswers,
            score: score,
            highestScore: score,
            modePlayCounts: {mode: 1},
          ),
        );
      }

      // Cleanup old daily stats (keep only last N days)
      _cleanupOldDailyStats(dailyStatsList);

      _stats = _stats.copyWith(
        totalGamesPlayed: _stats.totalGamesPlayed + 1,
        totalCorrectAnswers: _stats.totalCorrectAnswers + correctAnswers,
        totalWrongAnswers: _stats.totalWrongAnswers + wrongAnswers,
        highestScore: score > _stats.highestScore ? score : _stats.highestScore,
        modePlayCounts: newModePlayCounts,
        dailyStats: dailyStatsList,
        currentStreak: newCurrentStreak.clamp(0, AppConfig.maxStreakDisplay),
        longestStreak: newLongestStreak.clamp(0, AppConfig.maxStreakDisplay),
        lastPlayDate: DateTime.now().toUtc(), // Store actual UTC timestamp
      );

      // Use Firestore transaction for atomic update
      final userId = _userId;
      final firestore = _firestore;
      if (userId != null && firestore != null) {
        try {
          await firestore.runTransaction((transaction) async {
            final docRef = firestore.collection('user_stats').doc(userId);
            final doc = await transaction.get(docRef);
            
            if (doc.exists) {
              final existingData = doc.data()!;
              final existingStats = GameStats.fromJson(existingData);
              
              // Calculate new values
              final updatedStats = existingStats.copyWith(
                totalGamesPlayed: existingStats.totalGamesPlayed + 1,
                totalCorrectAnswers: existingStats.totalCorrectAnswers + correctAnswers,
                totalWrongAnswers: existingStats.totalWrongAnswers + wrongAnswers,
                highestScore: score > existingStats.highestScore ? score : existingStats.highestScore,
                modePlayCounts: newModePlayCounts,
                dailyStats: dailyStatsList,
                currentStreak: newCurrentStreak.clamp(0, AppConfig.maxStreakDisplay),
                longestStreak: newLongestStreak.clamp(0, AppConfig.maxStreakDisplay),
                lastPlayDate: DateTime.now().toUtc(),
              );
              
              transaction.set(docRef, updatedStats.toJson(), SetOptions(merge: true));
            } else {
              // Create new document
              transaction.set(docRef, _stats.toJson());
            }
          });
        } catch (e) {
          LoggerService.error('Failed to save stats with transaction, falling back to local save', error: e);
          // Fall through to local save
        }
      }

      await _save();
      notifyListeners();

      // Check achievements
      try {
        final achievementService = AchievementService();
        final unlocked = await achievementService.checkAchievements(_stats);
        if (unlocked.isNotEmpty) {
          LoggerService.info('Unlocked ${unlocked.length} achievement(s)');
        }
      } catch (e) {
        LoggerService.error('Error checking achievements', error: e);
      }
    } finally {
      _isRecordingGameEnd = false;
    }
  }

  Future<void> recordTimeAttackScore(int score) async {
    _stats = _stats.copyWith(
      totalTimeAttackScore: _stats.totalTimeAttackScore + score,
      highestScore: score > _stats.highestScore ? score : _stats.highestScore,
    );

    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    // Prevent concurrent saves with mutex
    if (_isSaving) {
      if (kDebugMode) {
        LoggerService.debug(
          'Stats save already in progress, skipping concurrent save',
        );
      }
      return;
    }

    _isSaving = true;
    try {
      // Save to local storage first (always) - this ensures data is never lost
      await _saveLocal();

      // Try to save to Firestore if available (with retry logic)
      if (_firebaseAvailable) {
        final userId = _userId;
        final firestore = _firestore;
        if (userId != null && firestore != null) {
          const maxRetries = 3;
          const timeoutDuration = Duration(seconds: 10);

          for (int attempt = 1; attempt <= maxRetries; attempt++) {
            try {
              await firestore
                  .collection('user_stats')
                  .doc(userId)
                  .set(_stats.toJson(), SetOptions(merge: true))
                  .timeout(
                timeoutDuration,
                onTimeout: () {
                  throw TimeoutException(
                    'Firestore save timeout after ${timeoutDuration.inSeconds}s',
                  );
                },
              );

              if (attempt > 1) {
                LoggerService.info(
                  'Stats saved to Firestore on attempt $attempt',
                );
              } else {
                LoggerService.info('Stats saved to Firestore');
              }
              break; // Success - exit retry loop
            } catch (e) {
              final isLastAttempt = attempt == maxRetries;
              if (isLastAttempt) {
                // Log final failure - stats are already saved locally
                LoggerService.error(
                  'Failed to save stats to Firestore after $maxRetries attempts',
                  error: e,
                );
                // Log to Crashlytics for production monitoring
                try {
                  await firebase_crashlytics.FirebaseCrashlytics.instance
                      .recordError(
                    e,
                    StackTrace.current,
                    reason:
                        'Stats Firestore save failed after $maxRetries retries',
                    fatal: false,
                  );
                } catch (crashlyticsError) {
                  // Ignore Crashlytics errors - not critical
                  LoggerService.warning(
                    'Failed to log to Crashlytics',
                    error: crashlyticsError,
                  );
                }
              } else {
                // Wait before retry (exponential backoff)
                final delayMs = 500 * attempt; // 500ms, 1000ms, 1500ms
                LoggerService.warning(
                  'Stats Firestore save failed (attempt $attempt/$maxRetries): $e. Retrying in ${delayMs}ms...',
                  error: e,
                );
                await Future.delayed(Duration(milliseconds: delayMs));
              }
            }
          }
        }
      }
    } finally {
      _isSaving = false;
    }
  }

  /// Cleanup old daily stats to prevent unbounded growth
  /// Keeps only the last N days as configured in AppConfig
  void _cleanupOldDailyStats(List<DailyStats> dailyStatsList) {
    if (dailyStatsList.length <= AppConfig.maxDailyStatsDays) return;

    // Sort by date (oldest first)
    dailyStatsList.sort((a, b) => a.date.compareTo(b.date));

    // Calculate cutoff date
    final cutoff = DateTime.now().toUtc().subtract(
          const Duration(days: AppConfig.maxDailyStatsDays),
        );
    final cutoffNormalized = _normalizeDate(cutoff);

    // Remove stats older than cutoff
    dailyStatsList.removeWhere(
      (ds) => _normalizeDate(ds.date).isBefore(cutoffNormalized),
    );
  }

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_stats.toJson()));
  }

  Future<void> reset() async {
    _stats = GameStats();
    await _save();
    notifyListeners();

    // Check achievements
    try {
      final achievementService = AchievementService();
      final unlocked = await achievementService.checkAchievements(_stats);
      if (unlocked.isNotEmpty) {
        LoggerService.info('Unlocked ${unlocked.length} achievement(s)');
      }
    } catch (e) {
      LoggerService.error('Error checking achievements', error: e);
    }
  }
}
