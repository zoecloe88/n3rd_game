import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:n3rd_game/models/game_state.dart';
import 'package:n3rd_game/models/trivia_item.dart';
import 'package:n3rd_game/models/game_mode_config.dart';
import 'package:n3rd_game/config/game_constants.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Extended game state data structure for persistence
/// Contains all game state beyond the core GameState
class ExtendedGameState {

  const ExtendedGameState({
    required this.revealAllUses,
    required this.clearUses,
    required this.skipUses,
    required this.streakShieldUses,
    required this.timeFreezeUses,
    required this.hintUses,
    required this.doubleScoreUses,
    this.competitiveChallengeId,
    this.competitiveChallengeStartTime,
    this.competitiveChallengePauseTime,
    this.competitiveChallengePausedDuration = 0,
    this.competitiveChallengeTargetRounds,
    this.competitiveChallengeScoreSubmitted = false,
    required this.currentMode,
    required this.streakMultiplier,
    required this.survivalPerfectCount,
    required this.isTimeFrozen,
    required this.hasDoubleScore,
    required this.hasStreakShield,
    this.playTimeAtFreeze,
    required this.sessionCorrectAnswers,
    required this.sessionWrongAnswers,
    required this.phase,
    this.currentTrivia,
    required this.shuffledWords,
    required this.selectedAnswers,
    required this.revealedWords,
    required this.memorizeTimeLeft,
    required this.playTimeLeft,
    this.timeAttackSecondsLeft,
    required this.currentTriviaPool,
    required this.flipModeSelectedOrder,
    required this.flipCurrentIndex,
    required this.flippedTiles,
    required this.hintedWords,
    required this.shuffleCount,
    required this.isShuffling,
    required this.shuffleDifficulty,
    this.gameStartTime,
  });

  factory ExtendedGameState.fromJson(Map<String, dynamic> json) {
    return ExtendedGameState(
      revealAllUses: (json['revealAllUses'] as int? ?? 3).clamp(0, 999),
      clearUses: (json['clearUses'] as int? ?? 3).clamp(0, 999),
      skipUses: (json['skipUses'] as int? ?? 3).clamp(0, 999),
      streakShieldUses: (json['streakShieldUses'] as int? ?? 0).clamp(0, 999),
      timeFreezeUses: (json['timeFreezeUses'] as int? ?? 0).clamp(0, 999),
      hintUses: (json['hintUses'] as int? ?? 0).clamp(0, 999),
      doubleScoreUses: (json['doubleScoreUses'] as int? ?? 0).clamp(0, 999),
      competitiveChallengeId: json['competitiveChallengeId'] as String?,
      competitiveChallengeStartTime: json['competitiveChallengeStartTime'] !=
              null
          ? DateTime.tryParse(json['competitiveChallengeStartTime'] as String)
          : null,
      competitiveChallengePauseTime: json['competitiveChallengePauseTime'] !=
              null
          ? DateTime.tryParse(json['competitiveChallengePauseTime'] as String)
          : null,
      competitiveChallengePausedDuration:
          (json['competitiveChallengePausedDuration'] as int? ?? 0)
              .clamp(0, 86400),
      competitiveChallengeTargetRounds:
          json['competitiveChallengeTargetRounds'] as int?,
      competitiveChallengeScoreSubmitted:
          json['competitiveChallengeScoreSubmitted'] as bool? ?? false,
      currentMode: GameMode.values.firstWhere(
        (mode) => mode.name == (json['currentMode'] as String? ?? 'classic'),
        orElse: () => GameMode.classic,
      ),
      streakMultiplier: (json['streakMultiplier'] as int? ?? 1).clamp(1, 5),
      survivalPerfectCount:
          (json['survivalPerfectCount'] as int? ?? 0).clamp(0, 999),
      isTimeFrozen: json['isTimeFrozen'] as bool? ?? false,
      hasDoubleScore: json['hasDoubleScore'] as bool? ?? false,
      hasStreakShield: json['hasStreakShield'] as bool? ?? false,
      playTimeAtFreeze: json['playTimeAtFreeze'] as int?,
      sessionCorrectAnswers: (json['sessionCorrectAnswers'] as int? ?? 0)
          .clamp(0, GameConstants.maxSessionAnswers),
      sessionWrongAnswers: (json['sessionWrongAnswers'] as int? ?? 0)
          .clamp(0, GameConstants.maxSessionAnswers),
      phase: GamePhase.values.firstWhere(
        (phase) => phase.name == (json['phase'] as String? ?? 'memorize'),
        orElse: () => GamePhase.memorize,
      ),
      currentTrivia: json['currentTrivia'] != null
          ? TriviaItem.fromJson(json['currentTrivia'] as Map<String, dynamic>)
          : null,
      shuffledWords: List<String>.from(json['shuffledWords'] as List? ?? []),
      selectedAnswers:
          List<String>.from(json['selectedAnswers'] as List? ?? []),
      revealedWords: List<String>.from(json['revealedWords'] as List? ?? []),
      memorizeTimeLeft: json['memorizeTimeLeft'] as int? ?? 10,
      playTimeLeft: json['playTimeLeft'] as int? ?? 20,
      timeAttackSecondsLeft: json['timeAttackSecondsLeft'] as int?,
      currentTriviaPool: (json['currentTriviaPool'] as List?)
              ?.map((item) => TriviaItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      flipModeSelectedOrder:
          List<String>.from(json['flipModeSelectedOrder'] as List? ?? []),
      flipCurrentIndex: json['flipCurrentIndex'] as int? ?? 0,
      flippedTiles: List<bool>.from(json['flippedTiles'] as List? ?? []),
      hintedWords: List<String>.from(json['hintedWords'] as List? ?? []),
      shuffleCount: (json['shuffleCount'] as int? ?? 0)
          .clamp(0, GameConstants.maxShuffleCount),
      isShuffling: json['isShuffling'] as bool? ?? false,
      shuffleDifficulty: json['shuffleDifficulty'] as String? ?? 'medium',
      gameStartTime: json['gameStartTime'] != null
          ? DateTime.tryParse(json['gameStartTime'] as String)
          : null,
    );
  }
  // Power-up uses
  final int revealAllUses;
  final int clearUses;
  final int skipUses;
  final int streakShieldUses;
  final int timeFreezeUses;
  final int hintUses;
  final int doubleScoreUses;

  // Competitive challenge state
  final String? competitiveChallengeId;
  final DateTime? competitiveChallengeStartTime;
  final DateTime? competitiveChallengePauseTime;
  final int competitiveChallengePausedDuration;
  final int? competitiveChallengeTargetRounds;
  final bool competitiveChallengeScoreSubmitted;

  // Mode-specific state
  final GameMode currentMode;
  final int streakMultiplier;
  final int survivalPerfectCount;

  // Power-up active states
  final bool isTimeFrozen;
  final bool hasDoubleScore;
  final bool hasStreakShield;
  final int? playTimeAtFreeze;

  // Session stats
  final int sessionCorrectAnswers;
  final int sessionWrongAnswers;

  // Round-level state
  final GamePhase phase;
  final TriviaItem? currentTrivia;
  final List<String> shuffledWords;
  final List<String> selectedAnswers;
  final List<String> revealedWords;
  final int memorizeTimeLeft;
  final int playTimeLeft;
  final int? timeAttackSecondsLeft;
  final List<TriviaItem> currentTriviaPool;

  // Flip mode state
  final List<String> flipModeSelectedOrder;
  final int flipCurrentIndex;
  final List<bool> flippedTiles;
  final List<String> hintedWords;

  // Additional state
  final int shuffleCount;
  final bool isShuffling;
  final String shuffleDifficulty;

  // Marathon mode
  final DateTime? gameStartTime;

  Map<String, dynamic> toJson() => {
        'revealAllUses': revealAllUses,
        'clearUses': clearUses,
        'skipUses': skipUses,
        'streakShieldUses': streakShieldUses,
        'timeFreezeUses': timeFreezeUses,
        'hintUses': hintUses,
        'doubleScoreUses': doubleScoreUses,
        'competitiveChallengeId': competitiveChallengeId,
        'competitiveChallengeStartTime':
            competitiveChallengeStartTime?.toIso8601String(),
        'competitiveChallengePauseTime':
            competitiveChallengePauseTime?.toIso8601String(),
        'competitiveChallengePausedDuration':
            competitiveChallengePausedDuration,
        'competitiveChallengeTargetRounds': competitiveChallengeTargetRounds,
        'competitiveChallengeScoreSubmitted':
            competitiveChallengeScoreSubmitted,
        'currentMode': currentMode.name,
        'streakMultiplier': streakMultiplier,
        'survivalPerfectCount': survivalPerfectCount,
        'isTimeFrozen': isTimeFrozen,
        'hasDoubleScore': hasDoubleScore,
        'hasStreakShield': hasStreakShield,
        'playTimeAtFreeze': playTimeAtFreeze,
        'sessionCorrectAnswers': sessionCorrectAnswers,
        'sessionWrongAnswers': sessionWrongAnswers,
        'phase': phase.name,
        'currentTrivia': currentTrivia?.toJson(),
        'shuffledWords': shuffledWords,
        'selectedAnswers': selectedAnswers,
        'revealedWords': revealedWords,
        'memorizeTimeLeft': memorizeTimeLeft,
        'playTimeLeft': playTimeLeft,
        'timeAttackSecondsLeft': timeAttackSecondsLeft,
        'currentTriviaPool':
            currentTriviaPool.map((item) => item.toJson()).toList(),
        'flipModeSelectedOrder': flipModeSelectedOrder,
        'flipCurrentIndex': flipCurrentIndex,
        'flippedTiles': flippedTiles,
        'hintedWords': hintedWords,
        'shuffleCount': shuffleCount,
        'isShuffling': isShuffling,
        'shuffleDifficulty': shuffleDifficulty,
        'gameStartTime': gameStartTime?.toIso8601String(),
      };
}

/// Manages game state persistence to SharedPreferences
///
/// Handles saving and loading of both core game state and extended state
/// with proper error handling, retry logic, and validation.
class GamePersistenceManager {
  static const String _storageKeyGameState = 'game_state';
  static const String _storageKeyExtendedState = 'game_extended_state';

  SharedPreferences? _prefs;
  bool _isSaving = false;
  int _consecutiveSaveFailures = 0;
  int _consecutiveExtendedStateFailures = 0;
  bool _needsSaveFailureNotification = false;
  bool _needsExtendedStateFailureNotification = false;

  AnalyticsService? _analyticsService;

  /// Set analytics service for tracking
  void setAnalyticsService(AnalyticsService? service) {
    _analyticsService = service;
  }

  /// Get or initialize SharedPreferences
  Future<SharedPreferences> _getPrefs() async {
    if (_prefs != null) return _prefs!;
    try {
      _prefs = await SharedPreferences.getInstance();
      return _prefs!;
    } catch (e) {
      LoggerService.error(
        'GamePersistenceManager: Failed to initialize SharedPreferences',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
      rethrow;
    }
  }

  /// Save game state with retry logic
  ///
  /// Saves both core state and extended state with proper error handling.
  /// Core state save is critical; extended state save is best-effort.
  Future<void> saveState({
    required GameState coreState,
    ExtendedGameState? extendedState,
    VoidCallback? onNotifyListeners,
    bool Function()? isDisposed,
  }) async {
    // Prevent concurrent saves
    if (_isSaving) {
      LoggerService.debug('State save already in progress, skipping concurrent save');
      return;
    }

    _isSaving = true;
    final saveStartTime = DateTime.now();
    try {
      const maxRetries = 3;
      String? lastError;

      for (int attempt = 0; attempt < maxRetries; attempt++) {
        try {
          final prefs = await _getPrefs();

          // Prepare core state JSON
          final stateJson = jsonEncode({
            'score': coreState.score,
            'lives': coreState.lives,
            'round': coreState.round,
            'isGameOver': coreState.isGameOver,
            'perfectStreak': coreState.perfectStreak,
          });

          String? extendedStateJson;
          bool shouldClearExtendedState = false;

          // Prepare extended state if game is in progress
          if (!coreState.isGameOver && extendedState != null) {
            extendedStateJson = jsonEncode(extendedState.toJson());
          } else {
            shouldClearExtendedState = true;
          }

          // Save core state first (critical)
          await prefs.setString(_storageKeyGameState, stateJson);

          // Save extended state (best-effort)
          if (extendedStateJson != null) {
            try {
              await prefs.setString(
                  _storageKeyExtendedState, extendedStateJson,);
              _consecutiveExtendedStateFailures = 0;
              _needsExtendedStateFailureNotification = false;
            } catch (extendedStateError) {
              _consecutiveExtendedStateFailures++;
              if (kDebugMode) {
                debugPrint(
                  'Warning: Failed to save extended state (non-critical): $extendedStateError '
                  '($_consecutiveExtendedStateFailures consecutive failures)',
                );
              }

              if (_consecutiveExtendedStateFailures >=
                  GameConstants.maxConsecutiveSaveFailures) {
                if (kDebugMode) {
                  debugPrint(
                    '⚠️ CRITICAL: Persistent extended state save failures detected '
                    '($_consecutiveExtendedStateFailures consecutive failures). '
                    'Game progress may not be fully restored on resume.',
                  );
                }
                _needsExtendedStateFailureNotification = true;
                onNotifyListeners?.call();

                try {
                  if (_analyticsService != null) {
                    unawaited(
                      _analyticsService!.logError(
                        'persistent_extended_state_save_failure',
                        'Extended state save failed. Consecutive failures: $_consecutiveExtendedStateFailures. Error: $extendedStateError',
                      ),
                    );
                  }
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint(
                        'Failed to log extended state failure analytics: $e',);
                  }
                }
              } else {
                try {
                  if (_analyticsService != null) {
                    unawaited(
                      _analyticsService!.logError(
                        'extended_state_save_failure',
                        'Extended state save failed. Consecutive failures: $_consecutiveExtendedStateFailures. Error: $extendedStateError',
                      ),
                    );
                  }
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint(
                        'Failed to log extended state failure analytics: $e',);
                  }
                }
              }
            }
          } else if (shouldClearExtendedState) {
            try {
              await prefs.remove(_storageKeyExtendedState);
            } catch (removeError) {
              if (kDebugMode) {
                debugPrint(
                  'Warning: Failed to remove extended state (non-critical): $removeError',
                );
              }
            }
          }

          // Reset consecutive failure counter on success
          _consecutiveSaveFailures = 0;

          // Track performance metrics
          final saveDuration = DateTime.now().difference(saveStartTime);
          try {
            if (_analyticsService != null) {
              unawaited(
                _analyticsService!.logGameStateSave(
                  saveDuration,
                  success: true,
                  retryCount: attempt,
                ),
              );
            }
          } catch (e) {
            LoggerService.error('Failed to log save performance', error: e);
          }

          return; // Success
        } catch (e) {
          lastError = e.toString();
          if (kDebugMode) {
            debugPrint(
              'Failed to save game state (attempt ${attempt + 1}/$maxRetries): $e',
            );
          }

          // Retry with exponential backoff
          if (attempt < maxRetries - 1) {
            await Future.delayed(Duration(milliseconds: 100 * (1 << attempt)));
            continue;
          }
        }
      }

      // All retries failed
      _consecutiveSaveFailures++;

      if (_consecutiveSaveFailures >=
          GameConstants.maxConsecutiveSaveFailures) {
        if (kDebugMode) {
          debugPrint(
            '⚠️ CRITICAL: Persistent save failures detected ($_consecutiveSaveFailures consecutive failures). '
            'Game state may not be saved. User should be notified.',
          );
        }
        _needsSaveFailureNotification = true;
        onNotifyListeners?.call();

        try {
          if (_analyticsService != null) {
            unawaited(
              _analyticsService!.logError(
                'persistent_save_failure',
                'Core state save failed after $maxRetries attempts. Consecutive failures: $_consecutiveSaveFailures. Error: $lastError',
              ),
            );
          }
        } catch (e) {
          LoggerService.error('Failed to log save failure analytics', error: e);
        }
      } else {
        try {
          if (_analyticsService != null) {
            unawaited(
              _analyticsService!.logError(
                'save_failure',
                'Game state save failed (attempt $maxRetries/$maxRetries). Consecutive failures: $_consecutiveSaveFailures. Error: $lastError',
              ),
            );
          }
        } catch (e) {
          LoggerService.error('Failed to log save failure analytics', error: e);
        }
      }

      if (kDebugMode) {
        debugPrint(
          '⚠️ Warning: Failed to save game state after $maxRetries attempts. Last error: $lastError',
        );
        LoggerService.debug('   Game state may be lost if app crashes.');
      }

      try {
        await FirebaseCrashlytics.instance.recordError(
          Exception('Game state save failed: $lastError'),
          StackTrace.current,
          reason: 'Failed to save game state after $maxRetries retries',
          fatal: false,
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
              'Failed to log game state save failure to Crashlytics: $e',);
        }
      }

      // Track performance metrics even on failure
      final saveDuration = DateTime.now().difference(saveStartTime);
      try {
        if (_analyticsService != null) {
          unawaited(
            _analyticsService!.logGameStateSave(
              saveDuration,
              success: false,
              retryCount: maxRetries,
            ),
          );
        }
      } catch (e) {
        LoggerService.error('Failed to log save failure performance', error: e);
      }
    } finally {
      _isSaving = false;
    }
  }

  /// Load game state from SharedPreferences
  ///
  /// Returns a map with 'coreState' and 'extendedState' keys.
  /// Returns null if no saved state exists.
  Future<Map<String, dynamic>?> loadState() async {
    try {
      final prefs = await _getPrefs();
      final stateJson = prefs.getString(_storageKeyGameState);

      if (stateJson == null) return null;

      final stateMap = jsonDecode(stateJson) as Map<String, dynamic>;

      // Validate and sanitize core state
      final loadedScore = (stateMap['score'] as int? ?? 0)
          .clamp(0, GameConstants.maxLoadedScore);
      final loadedLives =
          (stateMap['lives'] as int? ?? 3).clamp(0, GameConstants.maxLives);
      final loadedRound = (stateMap['round'] as int? ?? 1)
          .clamp(1, GameConstants.maxRoundCount);
      final loadedPerfectStreak = (stateMap['perfectStreak'] as int? ?? 0)
          .clamp(0, GameConstants.maxPerfectStreak);
      final loadedIsGameOver = stateMap['isGameOver'] as bool? ?? false;

      // Enforce consistency: if lives <= 0, game must be over
      final isGameOver = loadedIsGameOver || loadedLives <= 0;

      final coreState = GameState(
        score: loadedScore,
        lives: loadedLives,
        round: loadedRound,
        isGameOver: isGameOver,
        perfectStreak: loadedPerfectStreak,
      );

      // Load extended state if game is in progress
      ExtendedGameState? extendedState;
      if (!isGameOver) {
        final extendedStateJson = prefs.getString(_storageKeyExtendedState);
        if (extendedStateJson != null) {
          try {
            final extendedStateMap =
                jsonDecode(extendedStateJson) as Map<String, dynamic>;
            extendedState = ExtendedGameState.fromJson(extendedStateMap);
          } catch (e) {
            LoggerService.error('Failed to load extended game state', error: e);
            // Continue with core state only
          }
        }
      }

      return {
        'coreState': coreState,
        'extendedState': extendedState,
      };
    } catch (e) {
      LoggerService.error('Failed to load game state', error: e);
      return null;
    }
  }

  /// Clear all saved game state
  Future<void> clearState() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_storageKeyGameState);
      await prefs.remove(_storageKeyExtendedState);
      _consecutiveSaveFailures = 0;
      _consecutiveExtendedStateFailures = 0;
      _needsSaveFailureNotification = false;
      _needsExtendedStateFailureNotification = false;
    } catch (e) {
      LoggerService.error('Failed to clear game state', error: e);
    }
  }

  /// Check if save failure notification is needed
  bool get needsSaveFailureNotification => _needsSaveFailureNotification;

  /// Check if extended state failure notification is needed
  bool get needsExtendedStateFailureNotification =>
      _needsExtendedStateFailureNotification;

  /// Reset notification flags
  void resetNotificationFlags() {
    _needsSaveFailureNotification = false;
    _needsExtendedStateFailureNotification = false;
  }
}

