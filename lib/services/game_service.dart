import 'dart:async' show Timer, Future, unawaited;
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/models/game_state.dart';
import 'package:n3rd_game/models/trivia_item.dart';
import 'package:n3rd_game/models/difficulty_level.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/config/app_config.dart';
import 'package:n3rd_game/config/game_constants.dart';
import 'package:n3rd_game/services/trivia_generator_service.dart';
import 'package:n3rd_game/services/trivia_personalization_service.dart';
import 'package:n3rd_game/services/trivia_gamification_service.dart';
import 'package:n3rd_game/services/analytics_service.dart'; // Added for analytics tracking
import 'package:n3rd_game/services/haptic_service.dart';
import 'package:n3rd_game/services/daily_challenge_leaderboard_service.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

// GameMode enum
enum GameMode {
  classic, // 10s memorize, 20s play
  classicII, // 5s memorize, 10s play
  speed, // 0s memorize (shown together), 7s play
  regular, // 0s memorize (shown together), 15s play
  shuffle, // 10s memorize, tiles shuffle, 20s play
  random, // Random mode each round
  timeAttack, // 60s continuous play
  challenge, // Progressive difficulty - gets harder each round
  streak, // Score multiplier increases with perfect rounds
  blitz, // Ultra-fast: 3s memorize, 5s play
  marathon, // Infinite rounds, progressive difficulty
  perfect, // Must get all correct answers, wrong = game over
  survival, // Start with 1 life, gain lives every 3 perfect rounds
  precision, // Wrong selection = lose life immediately
  ai, // AI-powered adaptive mode (Premium only)
  flip, // Flip Mode: 10s study (4s visible, 6s flipping), 20s play (face-down, correct order)
  practice, // Practice mode - no scoring, unlimited hints (Premium only)
  learning, // Learning mode - review missed questions (Premium only)
}

// ModeConfig class
class ModeConfig {
  final int memorizeTime;
  final int playTime;
  final bool showWordsWithQuestion;
  final bool enableShuffle;
  final bool enableFlip; // Enable flip mode mechanics
  final int flipStartTime; // When tiles start flipping (4 seconds)
  final int flipDuration; // How long flipping takes (6 seconds)

  ModeConfig({
    required this.memorizeTime,
    required this.playTime,
    this.showWordsWithQuestion = false,
    this.enableShuffle = false,
    this.enableFlip = false,
    this.flipStartTime = 4,
    this.flipDuration = 6,
  });

  static ModeConfig getConfig(GameMode mode, {int round = 1}) {
    switch (mode) {
      case GameMode.classic:
        return ModeConfig(memorizeTime: 10, playTime: 20);
      case GameMode.classicII:
        return ModeConfig(memorizeTime: 5, playTime: 10);
      case GameMode.speed:
        return ModeConfig(
          memorizeTime: 0,
          playTime: 7,
          showWordsWithQuestion: true,
        );
      case GameMode.regular:
        return ModeConfig(
          memorizeTime: 0,
          playTime: 15,
          showWordsWithQuestion: true,
        );
      case GameMode.shuffle:
        return ModeConfig(memorizeTime: 10, playTime: 20, enableShuffle: true);
      case GameMode.random:
        return ModeConfig(memorizeTime: 10, playTime: 20);
      case GameMode.timeAttack:
        return ModeConfig(memorizeTime: 10, playTime: 20);
      case GameMode.challenge:
        // Progressive difficulty: each round gets harder
        // Round 1: 12s memorize, 18s play
        // Round 2: 10s memorize, 15s play
        // Round 3: 8s memorize, 12s play
        // Round 4+: 6s memorize, 10s play
        final memorizeTime = round == 1
            ? 12
            : round == 2
            ? 10
            : round == 3
            ? 8
            : 6;
        final playTime = round == 1
            ? 18
            : round == 2
            ? 15
            : round == 3
            ? 12
            : 10;
        return ModeConfig(memorizeTime: memorizeTime, playTime: playTime);
      case GameMode.streak:
        return ModeConfig(memorizeTime: 10, playTime: 20);
      case GameMode.blitz:
        return ModeConfig(memorizeTime: 3, playTime: 5);
      case GameMode.marathon:
        // Progressive difficulty based on round
        if (round <= 5) {
          return ModeConfig(memorizeTime: 10, playTime: 20);
        } else if (round <= 10) {
          return ModeConfig(memorizeTime: 8, playTime: 15);
        } else if (round <= 15) {
          return ModeConfig(memorizeTime: 6, playTime: 12);
        } else {
          return ModeConfig(memorizeTime: 5, playTime: 10);
        }
      case GameMode.perfect:
        return ModeConfig(memorizeTime: 10, playTime: 20);
      case GameMode.survival:
        return ModeConfig(memorizeTime: 10, playTime: 20);
      case GameMode.precision:
        return ModeConfig(memorizeTime: 10, playTime: 20);
      case GameMode.ai:
        // AI mode timing is determined dynamically by AIModeService
        // Default values here, will be overridden
        return ModeConfig(memorizeTime: 10, playTime: 20);
      case GameMode.flip:
        return ModeConfig(
          memorizeTime: 10,
          playTime: 20,
          enableFlip: true,
          flipStartTime: 4,
          flipDuration: 6,
        );
      case GameMode.practice:
        // Practice mode: relaxed timing, no scoring
        return ModeConfig(memorizeTime: 15, playTime: 30);
      case GameMode.learning:
        // Learning mode: review mode with extended time
        return ModeConfig(memorizeTime: 15, playTime: 30);
    }
  }
}

enum GamePhase { memorize, play, result }

class GameService extends ChangeNotifier {
  // Public getters for UI
  bool get isShuffling => _isShuffling;
  int get shuffleCount => _shuffleCount;

  // Disposal flag to prevent notifyListeners() after dispose
  bool _disposed = false;
  bool _isLoadingState = false; // Mutex to prevent concurrent loadState calls

  // Safe wrapper for notifyListeners() that checks disposal state
  // Prevents race conditions where timer callbacks try to notify after dispose
  void _safeNotifyListeners() {
    if (!_disposed && hasListeners) {
      notifyListeners();
    }
  }

  // Constructor - initialize flip reveal mode on startup
  GameService() {
    // Load flip reveal mode setting asynchronously (non-blocking)
    // Note: This is fire-and-forget - defaults to 'instant' mode if not yet loaded
    // The setting will be properly loaded before first use via loadState() or when setFlipRevealMode() is called
    _loadFlipRevealMode().catchError((e) {
      LoggerService.debug(
        'Failed to load flip reveal mode in constructor',
        error: e,
      );
      // Continue with default 'instant' mode - safe fallback
    });
  }

  // Add startTimeAttack stub
  void startTimeAttack(List<TriviaItem> triviaPool) {
    // Reset state for time attack
    _state = GameState(score: 0, lives: 3, round: 1, isGameOver: false);
    _timeAttackSecondsLeft = 60;

    // Clear recent trivia tracking for new game
    _recentTriviaCategories.clear();

    // Reset session stats for new game (consistent with resetGame and setCompetitiveChallenge)
    _sessionCorrectAnswers = 0;
    _sessionWrongAnswers = 0;

    // Store trivia pool for nextRound calls
    _currentTriviaPool = triviaPool;

    // Start time attack timer
    _timeAttackTimer?.cancel();
    _timeAttackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }
      if (_timeAttackSecondsLeft != null && _timeAttackSecondsLeft! > 0) {
        // CRITICAL: Clamp time attack seconds to prevent negative values (defensive programming)
        _timeAttackSecondsLeft = (_timeAttackSecondsLeft! - 1).clamp(0, GameConstants.maxTimeSeconds);
        _safeNotifyListeners();
      } else {
        timer.cancel();
        if (!_disposed) {
          // CRITICAL: Check if submission is in progress before ending game
          // This prevents race condition where timer expires during answer submission
          // If submission is active, let it complete before ending the game
          if (!_isSubmitting) {
            _setGameOver();
            _safeNotifyListeners();
          } else {
            // Submission in progress - schedule game over after submission completes
            // The submission logic will handle game over state properly
            LoggerService.debug(
              'Time attack timer expired during submission - will end game after submission completes',
            );
          }
        }
      }
    });

    // Start first round with error handling
    try {
      startNewRound(triviaPool, mode: GameMode.timeAttack);
    } on GameException catch (e) {
      // Stop the timer if round start fails
      _timeAttackTimer?.cancel();
      _timeAttackSecondsLeft = null;
      _state = _state.copyWith(isGameOver: true);
      _safeNotifyListeners();

      LoggerService.error(
        'GameService: Failed to start time attack round',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
      rethrow; // Re-throw so caller can handle
    } catch (e, stackTrace) {
      // Handle unexpected errors
      _timeAttackTimer?.cancel();
      _timeAttackSecondsLeft = null;
      _state = _state.copyWith(isGameOver: true);
      _safeNotifyListeners();

      LoggerService.error(
        'GameService: Unexpected error starting time attack round',
        error: e,
        stack: stackTrace,
        fatal: false,
      );
      rethrow;
    }
  }

  // Update startNewRound to accept difficulty
  Timer? _timeAttackTimer;
  Timer? _timeFreezeTimer; // Store time freeze timer for proper cleanup
  Timer? _flipInitialTimer; // Timer for initial flip delay
  Timer? _flipPeriodicTimer; // Timer for periodic tile flipping
  Future<void>?
  _pendingNextRoundDelay; // Track pending nextRound auto-advance to prevent leaks and race conditions
  String shuffleDifficulty = 'medium';

  GameMode _currentMode = GameMode.classic;
  int? _timeAttackSecondsLeft;
  int _shuffleCount = 0;
  bool _isShuffling = false;
  Timer? _shuffleTimer;

  void _startShuffleSequence() {
    // Cancel any existing shuffle timer to prevent leaks
    _shuffleTimer?.cancel();
    _shuffleTimer = null;

    _isShuffling = true;
    _shuffleCount = 0;

    // Determine shuffle speed based on difficulty (using AppConfig constants)
    int shuffleInterval;
    switch (shuffleDifficulty) {
      case 'easy':
        shuffleInterval = AppConfig.shuffleIntervalEasy;
        break;
      case 'medium':
        shuffleInterval = AppConfig.shuffleIntervalMedium;
        break;
      case 'hard':
        shuffleInterval = AppConfig.shuffleIntervalHard;
        break;
      case 'insane':
        shuffleInterval = AppConfig.shuffleIntervalInsane;
        break;
      default: // fallback to medium
        shuffleInterval = AppConfig.shuffleIntervalMedium;
    }

    _shuffleTimer = Timer.periodic(Duration(milliseconds: shuffleInterval), (
      timer,
    ) {
      if (_disposed) {
        timer.cancel();
        return;
      }
      if (_phase == GamePhase.play && _shuffledWords.isNotEmpty) {
        _shuffledWords.shuffle(_random);
        // CRITICAL: Filter empty/whitespace strings from list FIRST to maintain size consistency
        // This prevents index mismatches between _shuffledWords list and _shuffledWordsMap
        // Empty strings shouldn't exist, but if they do, filtering prevents flip mode failures
        _shuffledWords = _shuffledWords
            .where((word) => word.trim().isNotEmpty)
            .toList();

        // CRITICAL: Rebuild shuffledWordsMap after filtering to keep indices in sync with Flip Mode
        // Flip Mode uses this map for O(1) lookups (line 2396), so it must match the shuffled order exactly
        // Both list and map now have the same length, ensuring index consistency
        // CRITICAL: Handle duplicate words by keeping the last occurrence index (defensive programming)
        // Duplicates shouldn't exist, but if they do, this ensures consistent behavior
        _shuffledWordsMap = {};
        for (int i = 0; i < _shuffledWords.length; i++) {
          _shuffledWordsMap[_shuffledWords[i]] = i; // Last occurrence wins if duplicates exist
        }
        // CRITICAL: Clamp shuffle count to prevent integer overflow (defensive programming)
        _shuffleCount = (_shuffleCount + 1).clamp(0, GameConstants.maxShuffleCount);
        _safeNotifyListeners();
      } else {
        timer.cancel();
        _isShuffling = false;
      }
    });
  }

  void _startFlipSequence() {
    // CRITICAL: Validate _shuffledWords is populated before starting flip sequence
    // This prevents desync between flip animation and actual tile count
    if (_shuffledWords.isEmpty && (_currentTrivia?.words.isEmpty ?? true)) {
      LoggerService.warning('Cannot start flip sequence - no words available');
      return;
    }

    // Cancel any existing flip timers
    _flipInitialTimer?.cancel();
    _flipPeriodicTimer?.cancel();
    _flipInitialTimer = null;
    _flipPeriodicTimer = null;

    // Determine reveal mode for this round (re-determine here to ensure consistency)
    // This prevents stale cached values if setFlipRevealMode() is called mid-round
    if (_flipRevealMode == 'random') {
      _flipRevealModeIsInstant = _random.nextBool();
    } else {
      _flipRevealModeIsInstant = _flipRevealMode == 'instant';
    }

    // Initialize flipped tiles (all start face-up)
    // Use shuffledWords.length to ensure sync with UI tile positions
    if (_shuffledWords.isNotEmpty) {
      _flippedTiles = List.filled(_shuffledWords.length, true);
      _flipCurrentIndex = 0;
    } else if (_currentTrivia?.words != null) {
      // Fallback to words.length if shuffledWords not yet set (defensive check)
      // Use null-aware operator for safer access
      final wordsLength =
          _currentTrivia?.words.length ??
          GameConstants.requiredWordsForGameplay;
      _flippedTiles = List.filled(wordsLength, true);
      _flipCurrentIndex = 0;
    }

    final config = ModeConfig.getConfig(_currentMode);
    final flipStartTime = config.flipStartTime; // 4 seconds
    final flipDuration = config.flipDuration; // 6 seconds

    // Store sequence ID to prevent race conditions when _startFlipSequence() is called multiple times
    // Use microsecondsSinceEpoch instead of milliseconds to prevent collisions even if called multiple times in the same millisecond
    final sequenceId = DateTime.now().microsecondsSinceEpoch;
    _flipSequenceId = sequenceId;

    // After flipStartTime, start flipping tiles one by one
    // CRITICAL: Store initial timer reference separately to prevent memory leak
    _flipInitialTimer = Timer(Duration(seconds: flipStartTime), () {
      // Check if disposed or if this sequence was canceled (new sequence started)
      if (_disposed || _flipSequenceId != sequenceId) return;

      // Start flipping tiles during the remaining memorize time
      // Use shuffledWords.length to ensure sync with UI tile positions
      final int tilesToFlip = _shuffledWords.isNotEmpty
          ? _shuffledWords.length
          : (_currentTrivia?.words.length ??
                GameConstants.requiredWordsForGameplay);

      // CRITICAL: Prevent division by zero if tilesToFlip is 0
      if (tilesToFlip == 0) {
        LoggerService.warning('Cannot start flip sequence - no tiles to flip');
        return;
      }

      int flipInterval =
          (flipDuration * 1000) ~/
          tilesToFlip; // Divide flip duration by number of tiles

      // CRITICAL: Ensure flip interval is at least 1ms to prevent Timer.periodic with Duration.zero
      // Timer.periodic with Duration(milliseconds: 0) would fire immediately and repeatedly
      // This edge case could occur if tilesToFlip is extremely large relative to flipDuration
      if (flipInterval <= 0) {
        LoggerService.warning(
          'Calculated flip interval is $flipInterval (tilesToFlip: $tilesToFlip, flipDuration: $flipDuration seconds). Using minimum 1ms.',
        );
        flipInterval = 1; // Use minimum 1ms interval
      }

      int tilesFlipped = 0;
      // CRITICAL: Check again if sequence was canceled before creating periodic timer
      if (_disposed || _flipSequenceId != sequenceId) return;

      // CRITICAL: Store periodic timer reference separately to prevent leaks
      // Check sequence ID in periodic callback to ensure we cancel if new sequence started
      _flipPeriodicTimer = Timer.periodic(Duration(milliseconds: flipInterval), (
        timer,
      ) {
        // Check if disposed or if this sequence was canceled (new sequence started)
        if (_disposed || _flipSequenceId != sequenceId) {
          timer.cancel();
          _flipPeriodicTimer = null;
          return;
        }
        if (tilesFlipped < tilesToFlip && _phase == GamePhase.memorize) {
          // Flip tile to face-down
          // CRITICAL: Check if flippedTiles is empty to prevent index errors
          if (_flippedTiles.isEmpty) {
            timer.cancel();
            _flipPeriodicTimer = null;
            return;
          }
          if (_flipCurrentIndex < _flippedTiles.length) {
            _flippedTiles[_flipCurrentIndex] = false;
            _flipCurrentIndex++;
            tilesFlipped++;
            _safeNotifyListeners();
          }
        } else {
          timer.cancel();
          _flipPeriodicTimer = null;
        }
      });
    });
  }

  GameMode get currentMode => _currentMode;
  int? get timeAttackSecondsLeft => _timeAttackSecondsLeft;
  ModeConfig get currentConfig => ModeConfig.getConfig(_currentMode);
  static const String _storageKeyGameState = 'game_state';
  static const String _storageKeyExtendedState =
      'game_extended_state'; // Power-ups, competitive challenge, mode-specific state
  static const String _storageKeyFlipRevealMode = 'flip_reveal_mode';

  // Game constants - use GameConstants class for consistency
  static const int expectedCorrectAnswers =
      GameConstants.expectedCorrectAnswers;
  static const int requiredWordsForGameplay =
      GameConstants.requiredWordsForGameplay;

  // Random number generator (reused for consistency and performance)
  final Random _random = Random();

  // Cache SharedPreferences instance
  SharedPreferences? _prefs;

  int _correctCount = 0;
  List<String> _lastCorrectAnswers = [];
  List<String> _lastSelectedAnswers = [];
  bool _isSubmitting = false; // Prevent concurrent submissions
  bool _isSaving = false; // Prevent concurrent state saves

  // Track stats for the current game session
  int _sessionCorrectAnswers = 0;
  int _sessionWrongAnswers = 0;

  int get correctCount => _correctCount;
  List<String> get lastCorrectAnswers => _lastCorrectAnswers;
  List<String> get lastSelectedAnswers => _lastSelectedAnswers;
  GameState _state = GameState(score: 0, lives: 3, round: 1, isGameOver: false);
  TriviaItem? _currentTrivia;

  // Optional service references (injected after creation)
  TriviaPersonalizationService? _personalizationService;
  TriviaGamificationService? _gamificationService;
  AnalyticsService? _analyticsService;
  SubscriptionService? _subscriptionService;

  /// Set personalization service (called from main.dart)
  void setPersonalizationService(TriviaPersonalizationService? service) {
    _personalizationService = service;
  }

  /// Set analytics service (called from main.dart)
  void setAnalyticsService(AnalyticsService? service) {
    _analyticsService = service;
  }

  /// Set gamification service (called from main.dart)
  void setGamificationService(TriviaGamificationService? service) {
    _gamificationService = service;
  }

  /// Set subscription service (called from main.dart)
  void setSubscriptionService(SubscriptionService? service) {
    _subscriptionService = service;
  }

  /// Helper method to set game over state and clear active game session
  void _setGameOver() {
    _state = _state.copyWith(isGameOver: true);
    // Clear active game session for subscription grace period
    _subscriptionService?.clearGameSession().catchError((e) {
      LoggerService.error('Failed to clear game session', error: e);
      // Log to analytics for monitoring (non-critical failure)
      _analyticsService?.logError(
        'GameService: Failed to clear game session',
        e.toString(),
      );
    });
  }

  List<String> _shuffledWords = [];
  // Map for O(1) word-to-index lookups in Flip Mode (performance optimization)
  Map<String, int> _shuffledWordsMap = {};
  final Set<String> _selectedAnswers = {};
  final Set<String> _revealedWords = {}; // Track words revealed by double-tap
  GamePhase _phase = GamePhase.memorize;

  // Power-up system: 3 uses each per game
  int _revealAllUses = 3;
  int _clearUses = 3;
  int _skipUses = 3;

  // Advanced power-ups (Premium only)
  int _streakShieldUses = 0;
  int _timeFreezeUses = 0;
  int _hintUses = 0;
  int _doubleScoreUses = 0;

  bool _isTimeFrozen = false;
  bool _hasDoubleScore = false;
  bool _hasStreakShield = false;
  final List<String> _hintedWords = []; // Words eliminated by hint
  DateTime?
  _gameStartTime; // Track game start time for marathon mode duration limits
  int _consecutiveSaveFailures =
      0; // Track consecutive save failures for user notification
  int _consecutiveExtendedStateFailures =
      0; // Track consecutive extended state save failures separately
  bool _needsSaveFailureNotification =
      false; // Flag to notify UI about persistent save failures
  bool _needsExtendedStateFailureNotification =
      false; // Flag to notify UI about persistent extended state save failures

  // Mode-specific variables
  int _streakMultiplier = 1; // For Streak Mode (max 5x)
  int _survivalPerfectCount = 0; // For Survival Mode
  DateTime?
  _competitiveChallengeStartTime; // For competitive challenge tracking
  DateTime? _competitiveChallengePauseTime; // Track when game was paused
  int _competitiveChallengePausedDuration = 0; // Total paused time in seconds
  String? _competitiveChallengeId; // Current competitive challenge ID
  int?
  _competitiveChallengeTargetRounds; // Target rounds for competitive challenge
  bool _competitiveChallengeScoreSubmitted =
      false; // Prevent duplicate submissions
  String? _precisionError; // For Precision Mode error feedback

  // AI Mode dynamic timing
  int? _aiModeMemorizeTime;
  int? _aiModePlayTime;

  // AI Mode timing tracking for accurate response time
  DateTime? _aiModeRoundStartTime;
  // Reserved for future use in detailed timing analysis
  // ignore: unused_field
  DateTime? _aiModeMemorizeStartTime; // Reserved for future use
  // ignore: unused_field
  DateTime? _aiModePlayStartTime; // Reserved for future use

  // Flip Mode variables
  List<bool> _flippedTiles =
      []; // Track which tiles are flipped (true = face-up)
  // CRITICAL: Order matters in flip mode - players must select answers in the correct sequence
  // Using List<String> (not Set) to preserve selection order for validation
  // Duplicate prevention is handled via contains() check before add (line 2406, 2477)
  final List<String> _flipModeSelectedOrder =
      []; // Track selection order for flip mode (order-sensitive)
  int _flipCurrentIndex = 0; // Current tile being flipped
  int?
  _flipSequenceId; // Track current flip sequence to prevent race conditions
  String _flipRevealMode = 'instant'; // 'instant', 'blind', 'random'
  bool _flipRevealModeIsInstant =
      true; // Cached random reveal mode for current round

  /// Get AI mode response time (actual time taken)
  double? get aiModeResponseTime {
    if (_currentMode != GameMode.ai || _aiModeRoundStartTime == null) {
      return null;
    }
    final elapsed =
        DateTime.now().difference(_aiModeRoundStartTime!).inMilliseconds /
        1000.0;
    return elapsed;
  }

  /// Set AI mode timing (called by game_screen after AI performance update)
  void setAIModeTiming(int memorizeTime, int playTime) {
    if (_currentMode == GameMode.ai) {
      _aiModeMemorizeTime = memorizeTime;
      _aiModePlayTime = playTime;
      // Update current timers if in memorize phase
      if (_phase == GamePhase.memorize) {
        _memorizeTimeLeft = memorizeTime;
      } else if (_phase == GamePhase.play) {
        _playTimeLeft = playTime;
      }
      _safeNotifyListeners();
    }
  }

  /// Set flip mode reveal setting ('instant', 'blind', or 'random')
  /// Persists the setting to SharedPreferences
  Future<void> setFlipRevealMode(String mode) async {
    if (mode == 'instant' || mode == 'blind' || mode == 'random') {
      // Prevent changing reveal mode during active Flip Mode round
      if (_currentMode == GameMode.flip &&
          _phase != GamePhase.result &&
          !_state.isGameOver) {
        LoggerService.warning(
          'Cannot change flip reveal mode during active round',
        );
        return;
      }

      _flipRevealMode = mode;
      // Update cached instant flag
      _flipRevealModeIsInstant = mode == 'instant';

      // Persist to SharedPreferences
      try {
        final prefs = await _getPrefs();
        await prefs.setString(_storageKeyFlipRevealMode, mode);
      } catch (e) {
        LoggerService.error('Failed to save flip reveal mode', error: e);
      }

      _safeNotifyListeners();
    }
  }

  /// Load flip reveal mode from SharedPreferences
  Future<void> _loadFlipRevealMode() async {
    try {
      final prefs = await _getPrefs();
      final savedMode = prefs.getString(_storageKeyFlipRevealMode);
      if (savedMode != null &&
          (savedMode == 'instant' ||
              savedMode == 'blind' ||
              savedMode == 'random')) {
        _flipRevealMode = savedMode;
        _flipRevealModeIsInstant = savedMode == 'instant';
      }
    } catch (e) {
      LoggerService.error('Failed to load flip reveal mode', error: e);
      // Continue with default 'instant' mode
    }
  }

  int get streakMultiplier => _streakMultiplier;
  int get survivalPerfectCount => _survivalPerfectCount;
  String? get precisionError => _precisionError;

  /// Set competitive challenge ID for tracking
  void setCompetitiveChallenge(String challengeId, {int? targetRounds}) {
    // Validate challenge ID
    if (challengeId.isEmpty) {
      LoggerService.warning('Invalid challenge ID: empty string');
      return;
    }

    // Validate target rounds
    if (targetRounds != null && (targetRounds <= 0 || targetRounds > 100)) {
      LoggerService.warning(
        'Invalid target rounds: $targetRounds (must be 1-100)',
      );
      return;
    }

    // Prevent setting new challenge if submission is in progress
    // CRITICAL: Check BEFORE resetting state to prevent corruption
    if (_competitiveChallengeScoreSubmitted) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ Warning: Cannot set new competitive challenge while previous submission is in progress',
        );
      }
      return;
    }

    _competitiveChallengeId = challengeId;
    _competitiveChallengeTargetRounds = targetRounds;
    _competitiveChallengeStartTime = DateTime.now()
        .toUtc(); // Use UTC for consistency
    _competitiveChallengePauseTime = null;
    _competitiveChallengePausedDuration = 0;

    // Reset session stats when starting a competitive challenge
    // This ensures accuracy only includes rounds from this challenge
    _sessionCorrectAnswers = 0;
    _sessionWrongAnswers = 0;

    // Reset game start time for marathon mode tracking (if applicable)
    _gameStartTime = null;
    _consecutiveSaveFailures = 0;
    _needsSaveFailureNotification = false;

    _safeNotifyListeners();
  }

  /// Submit competitive challenge score when game ends
  /// Returns SubmissionResponse with result details
  /// Only resets tracking on successful submission to allow retry on failure
  Future<SubmissionResponse> submitCompetitiveChallengeScore({
    int maxRetries = 3,
  }) async {
    // CRITICAL: Prevent submission during state loading to avoid using incomplete/stale session stats
    // Session stats are restored in loadState() and must be complete before submission
    if (_isLoadingState) {
      LoggerService.warning(
        'Cannot submit competitive challenge score: State is currently being loaded',
      );
      return SubmissionResponse(
        SubmissionResult.unknownError,
        'Cannot submit while state is loading',
      );
    }

    if (_competitiveChallengeId == null ||
        _competitiveChallengeStartTime == null) {
      return SubmissionResponse(
        SubmissionResult.unknownError,
        'No active challenge',
      );
    }

    // Prevent duplicate submissions
    if (_competitiveChallengeScoreSubmitted) {
      LoggerService.debug('Score already submitted for this challenge');
      return SubmissionResponse(
        SubmissionResult.unknownError,
        'Score already submitted',
      );
    }

    // Set submission flag immediately to prevent concurrent submissions
    _competitiveChallengeScoreSubmitted = true;

    final challengeId = _competitiveChallengeId!;
    SubmissionResponse lastResponse = SubmissionResponse(
      SubmissionResult.unknownError,
      'Unknown error',
    );

    // Retry logic with exponential backoff for network errors
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        // Validate challenge exists before submission
        final leaderboardService = DailyChallengeLeaderboardService();
        final validationError = await leaderboardService.validateChallenge(
          challengeId,
        );
        if (validationError != null) {
          if (kDebugMode) {
            debugPrint('Challenge validation failed: $validationError');
          }
          // Don't reset on validation failure - challenge might be valid later
          return SubmissionResponse(
            SubmissionResult.challengeInvalid,
            validationError,
          );
        }

        // Calculate completion time, accounting for paused time
        // CRITICAL: Use UTC consistently for all time calculations to avoid timezone issues
        final totalElapsed = DateTime.now()
            .toUtc()
            .difference(_competitiveChallengeStartTime!)
            .inSeconds;
        // If currently paused, add the current pause duration
        int currentPauseDuration = 0;
        if (_competitiveChallengePauseTime != null) {
          // CRITICAL: Use UTC for pause time calculation to match start time (UTC)
          currentPauseDuration = DateTime.now()
              .toUtc()
              .difference(_competitiveChallengePauseTime!.toUtc())
              .inSeconds;
        }
        final completionTime =
            totalElapsed -
            _competitiveChallengePausedDuration -
            currentPauseDuration;

        // Calculate accuracy first (before handling negative time)
        final accuracy = _sessionCorrectAnswers + _sessionWrongAnswers > 0
            ? (_sessionCorrectAnswers /
                      (_sessionCorrectAnswers + _sessionWrongAnswers)) *
                  100.0
            : 0.0;

        // Ensure completion time is non-negative (handle clock changes)
        // Preserve actual accuracy even if time is invalid
        final finalCompletionTime = completionTime < 0 ? 0 : completionTime;
        if (completionTime < 0 && kDebugMode) {
          debugPrint(
            'Warning: Negative completion time detected ($completionTime), using 0 but preserving accuracy',
          );
        }

        final response = await leaderboardService.submitDailyChallengeScore(
          challengeId: challengeId,
          score: _state.score,
          completionTime: finalCompletionTime,
          accuracy: accuracy,
        );

        // If successful, reset tracking
        if (response.isSuccess) {
          // Reset tracking only on success
          _competitiveChallengeId = null;
          _competitiveChallengeStartTime = null;
          _competitiveChallengePauseTime = null;
          _competitiveChallengePausedDuration = 0;
          _competitiveChallengeTargetRounds = null;
          _competitiveChallengeScoreSubmitted = false;
        }

        // Retry only on network errors
        if (response.result == SubmissionResult.networkError &&
            attempt < maxRetries - 1) {
          lastResponse = response;
          // Exponential backoff: 1s, 2s, 4s
          await Future.delayed(Duration(seconds: 1 << attempt));
          continue;
        }

        // If all retries exhausted and submission failed, reset flag to allow manual retry
        if (!response.isSuccess && attempt >= maxRetries - 1) {
          LoggerService.warning(
            'Competitive challenge submission failed after $maxRetries attempts - resetting flag to allow retry',
          );
          _competitiveChallengeScoreSubmitted = false;
          // Save state with reset flag so user can retry later
          _saveState();
          // Return a clear error response indicating retry exhaustion
          return SubmissionResponse(
            response.result,
            'Submission failed after $maxRetries attempts. Please try again later.',
          );
        }

        return response;
      } catch (e) {
        // Reset flag on exception to allow retry
        _competitiveChallengeScoreSubmitted = false;

        if (kDebugMode) {
          debugPrint(
            'Error submitting competitive challenge score (attempt ${attempt + 1}): $e',
          );
        }
        if (attempt < maxRetries - 1) {
          // Retry on exception (likely network error)
          lastResponse = SubmissionResponse(
            SubmissionResult.networkError,
            'Network error: $e. Retrying...',
          );
          await Future.delayed(Duration(seconds: 1 << attempt));
          continue;
        }
        // All retries exhausted - return clear error message
        lastResponse = SubmissionResponse(
          SubmissionResult.unknownError,
          'Submission failed after $maxRetries attempts: $e',
        );
      }
    }

    // CRITICAL: All retries failed - reset flag to allow manual retry
    // This ensures the user can retry submission later (e.g., when network is available)
    _competitiveChallengeScoreSubmitted = false;
    _saveState();
    // Note: This handles cases where the loop exits without returning a response
    if (!lastResponse.isSuccess) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ Warning: Competitive challenge submission failed after $maxRetries retries - resetting flag to allow retry',
        );
      }
      _competitiveChallengeScoreSubmitted = false;
      // Save state with reset flag so user can retry later
      _saveState();
    }
    return lastResponse;
  }

  int get revealAllUses => _revealAllUses;
  int get clearUses => _clearUses;
  int get skipUses => _skipUses;
  int get streakShieldUses => _streakShieldUses;
  int get timeFreezeUses => _timeFreezeUses;
  int get hintUses => _hintUses;
  int get doubleScoreUses => _doubleScoreUses;
  bool get isTimeFrozen => _isTimeFrozen;
  bool get hasDoubleScore => _hasDoubleScore;
  bool get hasStreakShield => _hasStreakShield;
  bool get needsSaveFailureNotification =>
      _needsSaveFailureNotification; // Check if UI should show save failure warning

  bool get needsExtendedStateFailureNotification =>
      _needsExtendedStateFailureNotification; // Check if UI should show extended state failure warning

  /// Clear the save failure notification flag (call after UI shows notification)
  void clearSaveFailureNotification() {
    _needsSaveFailureNotification = false;
    _safeNotifyListeners();
  }

  /// Clear the extended state failure notification flag (call after UI shows notification)
  void clearExtendedStateFailureNotification() {
    _needsExtendedStateFailureNotification = false;
    _safeNotifyListeners();
  }

  int _memorizeTimeLeft = 10;
  int _playTimeLeft = 20;
  int? _playTimeAtFreeze; // Store play time when time freeze activates
  List<TriviaItem> _currentTriviaPool =
      []; // Store current trivia pool for nextRound
  final List<String> _recentTriviaCategories =
      []; // Track recently used trivia categories to avoid repeats
  static const int _maxRecentCategories = GameConstants.maxRecentCategories;

  Timer? _memorizeTimer;
  Timer? _playTimer;

  GameState get state => _state;
  TriviaItem? get currentTrivia => _currentTrivia;
  List<String> get shuffledWords => _shuffledWords;
  Map<String, int> get shuffledWordsMap =>
      Map.unmodifiable(_shuffledWordsMap); // For UI performance optimization
  Set<String> get selectedAnswers => _selectedAnswers;
  Set<String> get revealedWords => _revealedWords;
  GamePhase get phase => _phase;
  int get memorizeTimeLeft => _memorizeTimeLeft;
  int get playTimeLeft => _playTimeLeft;
  bool get canSubmit => _selectedAnswers.length == expectedCorrectAnswers;

  // Get session stats
  int get sessionCorrectAnswers => _sessionCorrectAnswers;
  int get sessionWrongAnswers => _sessionWrongAnswers;

  // Flip Mode getters
  List<bool> get flippedTiles => _flippedTiles;
  List<String> get flipModeSelectedOrder => _flipModeSelectedOrder;
  int get flipCurrentIndex => _flipCurrentIndex;
  String get flipRevealMode => _flipRevealMode;
  bool get isFlipMode => _currentMode == GameMode.flip;

  // Get mode name as string
  String get modeName {
    switch (_currentMode) {
      case GameMode.classic:
        return 'Classic';
      case GameMode.classicII:
        return 'Classic II';
      case GameMode.speed:
        return 'Speed';
      case GameMode.regular:
        return 'Regular';
      case GameMode.shuffle:
        return 'Shuffle';
      case GameMode.random:
        return 'Random';
      case GameMode.timeAttack:
        return 'Time Attack';
      case GameMode.challenge:
        return 'Challenge';
      case GameMode.streak:
        return 'Streak';
      case GameMode.blitz:
        return 'Blitz';
      case GameMode.marathon:
        return 'Marathon';
      case GameMode.perfect:
        return 'Perfect';
      case GameMode.survival:
        return 'Survival';
      case GameMode.precision:
        return 'Precision';
      case GameMode.ai:
        return 'AI Mode';
      case GameMode.flip:
        return 'Flip Mode';
      case GameMode.practice:
        return 'Practice';
      case GameMode.learning:
        return 'Learning';
    }
  }

  // Get or initialize SharedPreferences
  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // Helper method to generate trivia using TriviaGeneratorService
  // This is for basic game modes (free tier)
  List<TriviaItem> generateTriviaPool(
    TriviaGeneratorService generator, {
    String? theme,
    int count = 50,
    bool usePersonalization = true,
  }) {
    try {
      return generator.generateBatch(
        count,
        theme: theme,
        usePersonalization: usePersonalization,
      );
    } catch (e) {
      LoggerService.error('Error generating trivia pool', error: e);
      // Return empty list if generation fails
      return [];
    }
  }

  void startNewRound(
    List<TriviaItem> triviaPool, {
    GameMode? mode,
    String? difficulty,
    int recursionDepth = 0,
  }) {
    // CRITICAL: Prevent starting new round during active submission to avoid state corruption
    // This protects against interruptions that could cause inconsistent game state
    if (_isSubmitting) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ Warning: Cannot start new round during active submission - request ignored',
        );
      }
      return;
    }

    // Clear recent trivia tracking when starting a completely new game session
    // (but keep it when called recursively to find valid trivia)
    if (recursionDepth == 0 && _state.round == 1) {
      _recentTriviaCategories.clear();
      // Reset game start time for new game (marathon mode tracking)
      // CRITICAL: Clear _gameStartTime if switching away from marathon mode
      // This prevents stale marathon start times from affecting non-marathon modes
      if (mode == GameMode.marathon) {
        _gameStartTime = DateTime.now();
      } else {
        _gameStartTime = null; // Clear if not marathon mode
      }
      // Reset save failure tracking for new game
      _consecutiveSaveFailures = 0;
      _needsSaveFailureNotification = false;
    }

    // Cancel any existing timers
    _memorizeTimer?.cancel();
    _playTimer?.cancel();
    _shuffleTimer?.cancel();
    _timeAttackTimer?.cancel();
    _flipInitialTimer?.cancel();
    _flipPeriodicTimer?.cancel();

    // Clear previous selections
    _selectedAnswers.clear();
    _revealedWords.clear();
    _correctCount = 0;
    _lastCorrectAnswers.clear();
    _lastSelectedAnswers.clear();
    // Clear flip mode selections
    _flipModeSelectedOrder.clear();
    _flippedTiles.clear();

    // CRITICAL: Always clear hinted words at start of each round (not just new games)
    // This prevents hint state from persisting between rounds
    _hintedWords.clear();

    // Store trivia pool for nextRound calls
    _currentTriviaPool = triviaPool;

    // Check if this is a new game (mode changed or game was over)
    final bool isNewGame =
        mode != null && mode != _currentMode || _state.isGameOver;

    // Reset power-ups for new game (but keep earned ones)
    if (isNewGame) {
      _revealAllUses = 3;
      _clearUses = 3;
      _skipUses = 3;
      _streakShieldUses = 0;
      _timeFreezeUses = 0;
      _hintUses = 0;
      _doubleScoreUses = 0;
      _isTimeFrozen = false;
      _playTimeAtFreeze = null; // Clear time freeze state on new game
      _hasDoubleScore = false;
      _hasStreakShield = false;

      // Reset mode-specific variables
      _streakMultiplier = 1;
      _survivalPerfectCount = 0;
      _competitiveChallengeStartTime = null;
      _competitiveChallengePauseTime = null;
      _competitiveChallengePausedDuration = 0;
      _competitiveChallengeId = null;
      _competitiveChallengeTargetRounds = null;
      _competitiveChallengeScoreSubmitted = false;

      // Mark game session as active for subscription grace period
      _subscriptionService?.markGameSessionActive().catchError((e) {
        if (kDebugMode) {
          debugPrint('Failed to mark game session active: $e');
        }
      });
    }

    if (mode != null) {
      // CRITICAL: Clear marathon start time if switching away from marathon mode
      // This prevents stale marathon tracking from affecting non-marathon modes
      if (_currentMode == GameMode.marathon && mode != GameMode.marathon) {
        _gameStartTime = null;
      }

      _currentMode = mode;
      // CRITICAL: Track game start time for marathon mode duration limits
      if (mode == GameMode.marathon && _gameStartTime == null) {
        _gameStartTime = DateTime.now();
      }
      // Reset game state when starting a new game mode
      if (isNewGame) {
        int initialLives = 3;
        // Mode-specific lives
        if (_currentMode == GameMode.perfect ||
            _currentMode == GameMode.survival) {
          initialLives = 1;
        } else if (_currentMode == GameMode.marathon) {
          initialLives = GameConstants.marathonModeInfiniteLives; // Effectively infinite
        }

        _state = GameState(
          score: 0,
          lives: initialLives,
          round: 1,
          isGameOver: false,
        );
        _sessionCorrectAnswers = 0;
        _sessionWrongAnswers = 0;

        // CRITICAL: Clear revealed words for new round to prevent stale revealed state
        _revealedWords.clear();

        // Track competitive challenge start time
        if (_competitiveChallengeId != null) {
          // CRITICAL: Use UTC for consistency with setCompetitiveChallenge() (line 540)
          _competitiveChallengeStartTime = DateTime.now().toUtc();
        }
      }
    }
    // Accept difficulty for shuffle mode
    if (difficulty != null) {
      shuffleDifficulty = difficulty;
    }
    // For random mode, pick a random mode (not random itself)
    if (_currentMode == GameMode.random) {
      final modes = [
        GameMode.classic,
        GameMode.classicII,
        GameMode.speed,
        GameMode.regular,
        GameMode.shuffle,
        GameMode.challenge,
        GameMode.streak,
        GameMode.blitz,
        GameMode.marathon,
        GameMode.perfect,
        GameMode.survival,
        GameMode.precision,
      ];
      final previousMode = _currentMode;
      _currentMode = modes[_random.nextInt(modes.length)];

      // CRITICAL: Clear marathon start time if switching away from marathon mode
      if (previousMode == GameMode.marathon &&
          _currentMode != GameMode.marathon) {
        _gameStartTime = null;
      }

      // Track game start time for marathon mode if randomly selected
      if (_currentMode == GameMode.marathon && _gameStartTime == null) {
        _gameStartTime = DateTime.now();
      }
    }

    // Check if trivia pool is empty
    if (triviaPool.isEmpty) {
      final error = 'Cannot start game: Trivia pool is empty.';
      LoggerService.error('Cannot start game: Trivia pool is empty');
      throw GameException(error);
    }

    // Select a random trivia item, avoiding recently used categories
    TriviaItem? selectedTrivia;
    int attempts = 0;
    final maxAttempts = triviaPool.length;

    // Track unique categories in pool for better selection logic
    final uniqueCategoriesInPool = triviaPool
        .where((item) => item.category.isNotEmpty)
        .map((item) => item.category)
        .toSet();

    while (selectedTrivia == null && attempts < maxAttempts) {
      final candidate = triviaPool[_random.nextInt(triviaPool.length)];
      final category = candidate.category;

      // Handle empty category: use immediately but don't track (prevents tracking issues)
      if (category.isEmpty) {
        selectedTrivia = candidate;
        break;
      }

      // Improved logic: Avoid recent categories if we have enough unique categories
      // If pool is small or all categories are recent, allow reuse
      final hasEnoughUniqueCategories =
          uniqueCategoriesInPool.length > _maxRecentCategories;
      final isRecentCategory = _recentTriviaCategories.contains(category);

      if (hasEnoughUniqueCategories && isRecentCategory) {
        attempts++;
        continue;
      }

      // If all unique categories in pool are already recent, clear recent list to allow reuse
      if (!hasEnoughUniqueCategories &&
          uniqueCategoriesInPool.every(
            (cat) => _recentTriviaCategories.contains(cat),
          ) &&
          _recentTriviaCategories.isNotEmpty) {
        _recentTriviaCategories.clear();
      }

      selectedTrivia = candidate;
      // Track this category as recently used
      if (!_recentTriviaCategories.contains(category)) {
        _recentTriviaCategories.add(category);
        // Keep only the most recent categories
        if (_recentTriviaCategories.length > _maxRecentCategories) {
          _recentTriviaCategories.removeAt(0);
        }
      }
      break;
    }

    // Fallback to any trivia if we couldn't find one (shouldn't happen often)
    if (selectedTrivia == null) {
      if (triviaPool.isEmpty) {
        // This should have been caught earlier, but defensive check
        throw GameException('Cannot select trivia: Pool is empty.');
      }
      _currentTrivia = triviaPool[_random.nextInt(triviaPool.length)];
    } else {
      _currentTrivia = selectedTrivia;
    }

    // Validate trivia item has required data
    final currentTrivia = _currentTrivia;
    if (currentTrivia == null ||
        currentTrivia.correctAnswers.isEmpty ||
        currentTrivia.words.isEmpty) {
      final error =
          'Cannot start game: Invalid trivia item - missing words or correct answers.';
      if (kDebugMode) {
        debugPrint('❌ Error: $error');
      }
      // Try to find a valid trivia item if pool has multiple items
      if (recursionDepth < GameConstants.maxRecursionDepthGameService &&
          triviaPool.length > 1) {
        return startNewRound(
          triviaPool,
          mode: mode,
          difficulty: difficulty,
          recursionDepth: recursionDepth + 1,
        );
      } else {
        throw GameException(error);
      }
    }

    // CRITICAL VALIDATION: Ensure all correct answers are in the words list
    // This prevents unwinnable rounds where correct answers aren't displayed
    // Filter empty strings first to prevent validation issues
    final wordsSet = currentTrivia.words
        .where((w) => w.trim().isNotEmpty) // Filter empty strings first
        .map((w) => w.trim().toLowerCase())
        .toSet();
    final missingCorrect = currentTrivia.correctAnswers
        .where((ca) => ca.trim().isNotEmpty) // Filter empty correct answers too
        .where((ca) => !wordsSet.contains(ca.trim().toLowerCase()))
        .toList();

    if (missingCorrect.isNotEmpty) {
      if (kDebugMode) {
        debugPrint(
          '❌ Error: Correct answers not in words list: $missingCorrect. Attempting to find valid trivia item...',
        );
      }

      // Try to find a different trivia item with valid data
      if (recursionDepth < GameConstants.maxRecursionDepthGameService &&
          triviaPool.length > 1) {
        int attempts = 0;
        TriviaItem? validTrivia;

        while (attempts < GameConstants.maxCandidateAttempts &&
            validTrivia == null) {
          final candidate = triviaPool[_random.nextInt(triviaPool.length)];
          if (candidate == _currentTrivia) {
            attempts++;
            continue;
          }

          // CRITICAL: Filter empty strings and validate correctAnswers is subset of words
          // This matches the main validation logic (lines 922-929) and candidate validation (lines 1040-1048)
          final candidateWordsSet = candidate.words
              .map((w) => w.trim().toLowerCase())
              .where((w) => w.isNotEmpty)
              .toSet();
          final candidateCorrectSet = candidate.correctAnswers
              .map((ca) => ca.trim().toLowerCase())
              .where((ca) => ca.isNotEmpty)
              .toSet();
          final candidateMissing = candidateCorrectSet
              .where((ca) => !candidateWordsSet.contains(ca))
              .toList();

          // Validate: correctAnswers is subset of words AND has exactly 3 normalized unique correct answers AND has exactly 6 unique words
          // This matches the main validation logic (lines 1158-1180) to prevent unnecessary recursion with invalid candidates
          if (candidateMissing.isEmpty &&
              candidateCorrectSet.length == expectedCorrectAnswers &&
              candidateWordsSet.length == 6) {
            validTrivia = candidate;
            break;
          }
          attempts++;
        }

        if (validTrivia != null) {
          if (kDebugMode) {
            debugPrint('✅ Found valid trivia item. Retrying...');
          }
          _currentTrivia = validTrivia;
          startNewRound(
            triviaPool,
            mode: _currentMode,
            difficulty: shuffleDifficulty,
            recursionDepth: recursionDepth + 1,
          );
          return;
        }
      }

      // If we can't find a valid item after multiple attempts, throw exception
      // This prevents continuing with invalid trivia that could cause crashes or unwinnable rounds
      final error =
          'Cannot start game: No trivia item found with all correct answers in words list (attempted ${GameConstants.maxCandidateAttempts} items).';
      if (kDebugMode) {
        debugPrint('❌ $error');
      }
      throw GameException(error);
    }

    // Get all words (correct + incorrect), removing duplicates (preventive maintenance)
    // Since correctAnswers is validated as a subset of words (above), we can simplify to just use words
    final allWordsSet = <String>{};
    allWordsSet.addAll(
      currentTrivia.words
          .map((w) => w.trim().toLowerCase())
          .where((w) => w.isNotEmpty),
    );

    // CRITICAL: Detect duplicate normalized words in input to catch data corruption early
    // This prevents silently fixing corrupted trivia items from TriviaGeneratorService
    final inputWordsCount = currentTrivia.words
        .where((w) => w.trim().isNotEmpty)
        .length;
    if (inputWordsCount != allWordsSet.length) {
      final duplicateCount = inputWordsCount - allWordsSet.length;
      final error =
          'Cannot start game: Trivia item contains $duplicateCount duplicate normalized word(s) (input has $inputWordsCount words, but only ${allWordsSet.length} unique after normalization). This indicates data corruption in TriviaGeneratorService.';
      LoggerService.error(
        'GameService: Duplicate normalized words detected in trivia item',
        error: Exception(error),
        stack: StackTrace.current,
        fatal: false,
      );

      // Reject corrupted trivia item - don't silently fix it
      if (recursionDepth < GameConstants.maxRecursionDepthGameService &&
          triviaPool.length > 1) {
        return startNewRound(
          triviaPool,
          mode: mode,
          recursionDepth: recursionDepth + 1,
        );
      } else {
        throw GameException(error);
      }
    }

    // Convert back to original case for display
    // Since we validated correctAnswers is a subset of words, we only need to map from words
    final originalWords = <String, String>{};
    for (final word in currentTrivia.words) {
      final normalized = word.trim().toLowerCase();
      if (normalized.isNotEmpty) {
        originalWords[normalized] = word.trim();
      }
    }

    // Convert to list with original casing and ensure we have exactly 6 unique words (3 correct + 3 distractors)
    // CRITICAL: Every key in allWordsSet should exist in originalWords (built from same source)
    // If lookup fails, it indicates a logic bug that should be caught immediately
    final allWords = allWordsSet.map((w) {
      final original = originalWords[w];
      if (original == null) {
        // This should never happen - indicates a logic bug in deduplication or mapping
        final error =
            'Internal error: Missing original casing for normalized word "$w". This should never occur and indicates a logic bug in word processing.';
        if (kDebugMode) {
          debugPrint('❌ $error');
        }
        throw GameException(error);
      }
      return original;
    }).toList();

    // Validate word count (need exactly 6 for game mechanics: 3 correct + 3 distractors - no more, no less)
    // CRITICAL: Do NOT merge words from different trivia items - this corrupts game logic
    // Instead, try to find a different trivia item with exactly 6 words
    if (allWords.length != 6) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ Invalid trivia item: incorrect word count (${allWords.length} != 6, expected exactly 6). Attempting to find valid trivia item...',
        );
      }

      // Prevent infinite recursion: use GameConstants for consistent limits
      // NOTE: Different from TriviaGeneratorService (max depth 3) because:
      // - GameService operates at trivia item validation level (more complex validation)
      // - Needs to validate word counts, correct answers, overlaps, etc.
      // - Higher limit allows for sufficient retry across larger trivia pools
      if (recursionDepth >= GameConstants.maxRecursionDepthGameService) {
        final errorMsg =
            'Unable to find valid trivia item after $recursionDepth attempts. All trivia items in pool failed validation.';
        if (kDebugMode) {
          debugPrint('❌ Error: $errorMsg');
        }
        // Log to Crashlytics for production monitoring
        try {
          FirebaseCrashlytics.instance.recordError(
            Exception(errorMsg),
            StackTrace.current,
            reason:
                'GameService: Max recursion depth reached while finding valid trivia',
            fatal: false,
          );
        } catch (e) {
          // Ignore Crashlytics errors - not critical
          if (kDebugMode) debugPrint('Failed to log to Crashlytics: $e');
        }
        // Will throw GameException below - do not proceed with invalid data
      } else if (triviaPool.length > 1) {
        // Try to find a different trivia item with sufficient words
        int attempts = 0;
        TriviaItem? validTrivia;

        while (attempts < GameConstants.maxCandidateAttempts &&
            validTrivia == null) {
          final candidate = triviaPool[_random.nextInt(triviaPool.length)];
          if (candidate == _currentTrivia) {
            attempts++;
            continue;
          }

          // Check if candidate has exactly 6 unique words (3 correct + 3 distractors)
          // CRITICAL: Filter empty strings and validate correctAnswers is subset of words
          // This matches the first candidate validation block (lines 948-965) and main validation (lines 922-929) for consistency
          final candidateWordsSet = candidate.words
              .map((w) => w.trim().toLowerCase())
              .where((w) => w.isNotEmpty)
              .toSet();
          final candidateCorrectSet = candidate.correctAnswers
              .map((ca) => ca.trim().toLowerCase())
              .where((ca) => ca.isNotEmpty)
              .toSet();
          final candidateMissing = candidateCorrectSet
              .where((ca) => !candidateWordsSet.contains(ca))
              .toList();

          // Validate: correctAnswers is subset of words AND has exactly 3 normalized unique correct answers AND has exactly 6 unique words
          // This matches the main validation logic (lines 1158-1180) to prevent unnecessary recursion with invalid candidates
          if (candidateMissing.isEmpty &&
              candidateCorrectSet.length == expectedCorrectAnswers &&
              candidateWordsSet.length == 6) {
            validTrivia = candidate;
            break;
          }
          attempts++;
        }

        if (validTrivia != null) {
          if (kDebugMode) {
            debugPrint(
              '✅ Found valid trivia item with ${validTrivia.words.length} words. Retrying...',
            );
          }
          _currentTrivia = validTrivia;
          // Recursively call with incremented depth
          startNewRound(
            triviaPool,
            mode: _currentMode,
            difficulty: shuffleDifficulty,
            recursionDepth: recursionDepth + 1,
          );
          return;
        }
      }

      // If we couldn't find a valid trivia item, throw error instead of continuing with invalid data
      // This ensures consistent validation with TriviaGeneratorService (requires exactly 6 words)
      final error =
          'Cannot start game: No trivia item found with exactly 6 words (attempted ${GameConstants.maxCandidateAttempts} items).';
      if (kDebugMode) {
        debugPrint('❌ $error');
      }
      throw GameException(error);
    }

    // Note: allWords already has empty strings filtered (via allWordsSet at line 994)
    // so we can use allWords directly without additional filtering
    final validWords = allWords;

    // Final validation: need exactly 6 valid words to play (3 correct + 3 distractors - no more, no less)
    // This matches TriviaGeneratorService validation (exactly 6 words required)
    if (validWords.length != 6) {
      final error =
          'Cannot start game: Invalid word count in trivia item (need exactly 6, got ${validWords.length}).';
      if (kDebugMode) {
        debugPrint('❌ $error');
      }
      throw GameException(error);
    }

    // CRITICAL: Ensure all correct answers are included in _shuffledWords
    // This prevents unwinnable rounds where correct answers aren't displayed
    final validCorrectAnswers = currentTrivia.correctAnswers
        .where((ca) => ca.trim().isNotEmpty)
        .toList();
    final correctAnswersSet = validCorrectAnswers
        .map((ca) => ca.trim().toLowerCase())
        .toSet();

    // CRITICAL: Validate that correctAnswers has exactly 3 normalized unique values
    // This catches corrupted data early with a clear error message
    // TriviaGeneratorService should have validated this, but defensive programming ensures data integrity
    if (correctAnswersSet.length != expectedCorrectAnswers) {
      final error =
          'Cannot start game: Trivia item has ${correctAnswersSet.length} normalized unique correct answers (expected $expectedCorrectAnswers). This indicates data corruption.';
      if (kDebugMode) {
        debugPrint('❌ $error');
      }
      // Log to Crashlytics for production monitoring
      try {
        FirebaseCrashlytics.instance.recordError(
          Exception(error),
          StackTrace.current,
          reason: 'GameService: Incorrect normalized correct answers count',
          fatal: false,
        );
      } catch (e) {
        if (kDebugMode) debugPrint('Failed to log to Crashlytics: $e');
      }

      // Reject corrupted trivia item - try to find a new one
      if (recursionDepth < GameConstants.maxRecursionDepthGameService &&
          triviaPool.length > 1) {
        return startNewRound(
          triviaPool,
          mode: mode,
          recursionDepth: recursionDepth + 1,
        );
      } else {
        throw GameException(error);
      }
    }

    // Separate correct answers and distractors
    // CRITICAL: Deduplicate by normalized value to prevent casing duplicates
    final correctAnswersInWords = <String>[];
    final correctAnswersInWordsNormalized =
        <String>{}; // Track normalized values to prevent duplicates
    final distractorsInWords = <String>[];
    final distractorsInWordsNormalized =
        <
          String
        >{}; // Track normalized values to prevent duplicates in distractors

    for (final word in validWords) {
      final normalized = word.trim().toLowerCase();
      if (correctAnswersSet.contains(normalized)) {
        // Only add if we haven't seen this normalized value before (prevent casing duplicates)
        if (!correctAnswersInWordsNormalized.contains(normalized)) {
          correctAnswersInWords.add(word);
          correctAnswersInWordsNormalized.add(normalized);
        }
      } else {
        // CRITICAL: Also deduplicate distractors by normalized value (defensive programming)
        // This ensures we don't have duplicates even if validWords somehow had them
        if (!distractorsInWordsNormalized.contains(normalized)) {
          distractorsInWords.add(word);
          distractorsInWordsNormalized.add(normalized);
        }
      }
    }

    // CRITICAL: Validate no overlap between correctAnswersInWords and distractorsInWords
    // This ensures separation logic worked correctly and we have truly distinct word sets
    // If there's overlap, it indicates data corruption in the trivia item
    final overlap = correctAnswersInWordsNormalized.intersection(
      distractorsInWordsNormalized,
    );
    if (overlap.isNotEmpty) {
      if (kDebugMode) {
        debugPrint(
          '❌ Error: Found ${overlap.length} overlapping normalized word(s) between correct answers and distractors: $overlap. This indicates a data integrity issue in trivia item. Cannot proceed.',
        );
      }
      // Try to find a new trivia item with valid data structure
      if (recursionDepth < GameConstants.maxRecursionDepthGameService &&
          triviaPool.length > 1) {
        return startNewRound(
          triviaPool,
          mode: mode,
          recursionDepth: recursionDepth + 1,
        );
      } else {
        final errorMsg =
            'Cannot start game: Trivia item has overlapping words between correct answers and distractors after $recursionDepth attempts.';
        if (kDebugMode) {
          debugPrint('❌ Error: $errorMsg');
        }
        // Log to Crashlytics for production monitoring
        try {
          FirebaseCrashlytics.instance.recordError(
            Exception(errorMsg),
            StackTrace.current,
            reason:
                'GameService: Overlapping words between correct answers and distractors',
            fatal: false,
          );
        } catch (e) {
          if (kDebugMode) debugPrint('Failed to log to Crashlytics: $e');
        }
        throw GameException(errorMsg);
      }
    }

    // CRITICAL: Validate we have all correct answers and exactly the expected count
    // We already validated correctAnswersSet.length == expectedCorrectAnswers (line 1167)
    // So correctAnswersInWords.length must equal expectedCorrectAnswers (which is 3)
    // This single check combines both validations: all answers found AND correct count
    // If correctAnswersInWords.length < expectedCorrectAnswers, it means not all correct answers were found in words
    // If correctAnswersInWords.length > expectedCorrectAnswers, it indicates data corruption (duplicates)
    if (correctAnswersInWords.length != expectedCorrectAnswers) {
      // Determine if it's a missing answer issue or count mismatch
      final missing = validCorrectAnswers
          .where(
            (ca) => !validWords.any(
              (w) => w.trim().toLowerCase() == ca.trim().toLowerCase(),
            ),
          )
          .toList();

      if (kDebugMode) {
        if (missing.isNotEmpty) {
          debugPrint(
            '❌ Error: Not all correct answers found in valid words. Missing: $missing',
          );
        } else {
          debugPrint(
            '❌ Error: Trivia item has ${correctAnswersInWords.length} correct answers (expected $expectedCorrectAnswers). This indicates data corruption.',
          );
        }
      }
      if (kDebugMode) {
        debugPrint(
          '❌ Error: Trivia item has ${correctAnswersInWords.length} correct answers (expected $expectedCorrectAnswers). '
          'Cannot proceed.',
        );
      }
      if (recursionDepth < GameConstants.maxRecursionDepthGameService &&
          triviaPool.length > 1) {
        return startNewRound(
          triviaPool,
          mode: mode,
          recursionDepth: recursionDepth + 1,
        );
      } else {
        final errorMsg =
            (recursionDepth >= GameConstants.maxRecursionDepthGameService)
            ? 'Max recursion depth reached while enforcing correct answer count.'
            : (triviaPool.length == 1)
            ? 'Cannot find valid trivia item: Only one trivia item available and it has incorrect correct answer count (${correctAnswersInWords.length} instead of $expectedCorrectAnswers).'
            : 'Cannot find valid trivia item after $recursionDepth attempts: Incorrect correct answer count (${correctAnswersInWords.length} instead of $expectedCorrectAnswers).';
        if (kDebugMode) {
          debugPrint('❌ Error: $errorMsg');
        }
        // Log to Crashlytics for production monitoring
        try {
          FirebaseCrashlytics.instance.recordError(
            Exception(errorMsg),
            StackTrace.current,
            reason:
                'GameService: Max recursion depth - incorrect correct answer count',
            fatal: false,
          );
        } catch (e) {
          // Ignore Crashlytics errors - not critical
          if (kDebugMode) debugPrint('Failed to log to Crashlytics: $e');
        }
        // Throw exception to prevent continuing with invalid state
        throw GameException(errorMsg);
      }
    }

    // CRITICAL: Validate we have enough distractors to reach exactly 6 words
    // This ensures we always show exactly 6 words (3 correct + 3 distractors)
    // Note: neededDistractors will be recalculated after adding correct answers to shuffledWords
    // to account for any deduplication that occurred (defensive programming)
    // At this point, correctAnswersInWords.length == expectedCorrectAnswers (validated at line 1276)
    final initialNeededDistractors =
        requiredWordsForGameplay - expectedCorrectAnswers;
    if (distractorsInWords.length < initialNeededDistractors) {
      if (kDebugMode) {
        debugPrint(
          '❌ Error: Insufficient distractors (${distractorsInWords.length} available, need $initialNeededDistractors to reach exactly $requiredWordsForGameplay total). Cannot proceed.',
        );
      }
      // Try to find a new trivia item
      if (recursionDepth < GameConstants.maxRecursionDepthGameService &&
          triviaPool.length > 1) {
        return startNewRound(
          triviaPool,
          mode: mode,
          recursionDepth: recursionDepth + 1,
        );
      } else {
        final errorMsg =
            (recursionDepth >= GameConstants.maxRecursionDepthGameService)
            ? 'Max recursion depth reached. Cannot find valid trivia item.'
            : (triviaPool.length == 1)
            ? 'Cannot find valid trivia item: Only one trivia item available and it has insufficient distractors (${distractorsInWords.length} available, need $initialNeededDistractors to reach exactly $requiredWordsForGameplay total).'
            : 'Cannot find valid trivia item after $recursionDepth attempts: Insufficient distractors (${distractorsInWords.length} available, need $initialNeededDistractors to reach exactly $requiredWordsForGameplay total).';
        if (kDebugMode) {
          debugPrint('❌ Error: $errorMsg');
        }
        // Log to Crashlytics for production monitoring
        try {
          FirebaseCrashlytics.instance.recordError(
            Exception(errorMsg),
            StackTrace.current,
            reason: 'GameService: Max recursion depth - incorrect word count',
            fatal: false,
          );
        } catch (e) {
          // Ignore Crashlytics errors - not critical
          if (kDebugMode) debugPrint('Failed to log to Crashlytics: $e');
        }
        // Throw exception to prevent continuing with invalid state
        throw GameException(errorMsg);
      }
    }

    // Build _shuffledWords: include all correct answers, then fill with distractors
    // CRITICAL: Use normalized deduplication to prevent casing duplicates
    // Set<String> compares by identity, so "Paris" and "paris" would both be added
    // We track normalized values to ensure we only add each unique word once
    // NOTE: Using List (not Set) to preserve order and allow duplicates of different casing
    final shuffledWords = <String>[];
    final addedNormalized =
        <String>{}; // Track normalized values to prevent duplicates

    // Add all correct answers first (preserve original casing from first occurrence)
    for (final word in correctAnswersInWords) {
      final normalized = word.trim().toLowerCase();
      if (!addedNormalized.contains(normalized)) {
        shuffledWords.add(word);
        addedNormalized.add(normalized);
      }
    }

    // CRITICAL: Defensive validation - ensure exactly expectedCorrectAnswers were added to shuffledWords
    // This prevents edge cases where deduplication causes fewer correct answers than expected
    final correctAnswersAdded = shuffledWords.length;
    if (correctAnswersAdded != expectedCorrectAnswers) {
      if (kDebugMode) {
        debugPrint(
          '❌ Error: Expected $expectedCorrectAnswers correct answers in shuffledWords, but found $correctAnswersAdded. This indicates a data integrity issue (duplicates detected during deduplication). Attempting to find new trivia item...',
        );
      }
      // Try to find a new trivia item with valid data structure
      if (recursionDepth < GameConstants.maxRecursionDepthGameService &&
          triviaPool.length > 1) {
        return startNewRound(
          triviaPool,
          mode: mode,
          recursionDepth: recursionDepth + 1,
        );
      } else {
        final errorMsg =
            'Cannot start game: Unable to build shuffled words with exactly $expectedCorrectAnswers correct answers after $recursionDepth attempts.';
        if (kDebugMode) {
          debugPrint('❌ Error: $errorMsg');
        }
        // Log to Crashlytics for production monitoring
        try {
          FirebaseCrashlytics.instance.recordError(
            Exception(errorMsg),
            StackTrace.current,
            reason:
                'GameService: Incorrect number of correct answers added to shuffledWords',
            fatal: false,
          );
        } catch (e) {
          // Ignore Crashlytics errors - not critical
          if (kDebugMode) debugPrint('Failed to log to Crashlytics: $e');
        }
        // Throw exception to prevent continuing with invalid state
        throw GameException(errorMsg);
      }
    }

    // Calculate needed distractors based on actual correct answers added (defensive programming)
    // This ensures we account for any deduplication that occurred during addition
    final neededDistractors = requiredWordsForGameplay - correctAnswersAdded;

    // CRITICAL: Explicitly validate that neededDistractors matches initialNeededDistractors
    // This ensures correctAnswersAdded truly equals expectedCorrectAnswers as validated
    // This should never happen if correctAnswersAdded == expectedCorrectAnswers, but defensive programming
    if (neededDistractors != initialNeededDistractors) {
      if (kDebugMode) {
        debugPrint(
          '❌ Error: neededDistractors ($neededDistractors) does not match initialNeededDistractors ($initialNeededDistractors). This indicates correctAnswersAdded ($correctAnswersAdded) does not equal expectedCorrectAnswers ($expectedCorrectAnswers) despite validation. Data integrity issue detected.',
        );
      }
      // Try to find a new trivia item with valid data structure
      if (recursionDepth < GameConstants.maxRecursionDepthGameService &&
          triviaPool.length > 1) {
        return startNewRound(
          triviaPool,
          mode: mode,
          recursionDepth: recursionDepth + 1,
        );
      } else {
        final errorMsg =
            'Cannot start game: neededDistractors ($neededDistractors) does not match initialNeededDistractors ($initialNeededDistractors) after $recursionDepth attempts.';
        if (kDebugMode) {
          debugPrint('❌ Error: $errorMsg');
        }
        // Log to Crashlytics for production monitoring
        try {
          FirebaseCrashlytics.instance.recordError(
            Exception(errorMsg),
            StackTrace.current,
            reason:
                'GameService: neededDistractors mismatch with initialNeededDistractors',
            fatal: false,
          );
        } catch (e) {
          if (kDebugMode) debugPrint('Failed to log to Crashlytics: $e');
        }
        throw GameException(errorMsg);
      }
    }

    // CRITICAL: Re-validate we have enough distractors with the recalculated neededDistractors
    // This defensive check ensures we have sufficient distractors available
    // (now guaranteed to equal initialNeededDistractors after the above validation)
    // NOTE: This should never fail since we validated distractorsInWords.length >= initialNeededDistractors
    // at line 1316 and neededDistractors == initialNeededDistractors at line 1399
    if (distractorsInWords.length < neededDistractors) {
      if (kDebugMode) {
        debugPrint(
          '❌ Error: Insufficient distractors after recalculation (${distractorsInWords.length} available, need $neededDistractors to reach exactly $requiredWordsForGameplay total). This should never occur after validating distractorsInWords.length >= initialNeededDistractors ($initialNeededDistractors) and neededDistractors == initialNeededDistractors. Unexpected data integrity issue detected. Attempting to find new trivia item...',
        );
      }
      // Try to find a new trivia item with valid data structure
      if (recursionDepth < GameConstants.maxRecursionDepthGameService &&
          triviaPool.length > 1) {
        return startNewRound(
          triviaPool,
          mode: mode,
          recursionDepth: recursionDepth + 1,
        );
      } else {
        final errorMsg =
            'Cannot start game: Insufficient distractors after recalculation (need $neededDistractors, have ${distractorsInWords.length}) after $recursionDepth attempts.';
        if (kDebugMode) {
          debugPrint('❌ Error: $errorMsg');
        }
        // Log to Crashlytics for production monitoring
        try {
          FirebaseCrashlytics.instance.recordError(
            Exception(errorMsg),
            StackTrace.current,
            reason: 'GameService: Insufficient distractors after recalculation',
            fatal: false,
          );
        } catch (e) {
          // Ignore Crashlytics errors - not critical
          if (kDebugMode) debugPrint('Failed to log to Crashlytics: $e');
        }
        // Throw exception to prevent continuing with invalid state
        throw GameException(errorMsg);
      }
    }

    // Shuffle distractors and add exactly enough to reach 6 total
    // We now have validated that we have enough distractors for the recalculated neededDistractors
    distractorsInWords.shuffle(_random);

    // Add exactly the needed number of distractors
    // CRITICAL: addedNormalized already contains all normalized correct answers (from line 1318)
    // So !addedNormalized.contains(normalized) implicitly prevents distractors from matching correct answers
    // This ensures no overlaps between correct answers and distractors in shuffledSet
    // We need exactly 6 words total, so we must add enough distractors
    int distractorsAdded = 0;
    for (final word in distractorsInWords) {
      if (distractorsAdded >= neededDistractors) break;

      final normalized = word.trim().toLowerCase();
      if (!addedNormalized.contains(normalized)) {
        shuffledWords.add(word);
        addedNormalized.add(normalized);
        distractorsAdded++;
      }
      // If duplicate (case-insensitive) or matches a correct answer, skip and try next distractor
      // This should be rare due to earlier validation, but defensive programming ensures we still get 6 words
    }

    // CRITICAL: Validate we added exactly the required number of distractors
    // This defensive check handles unexpected data integrity issues where we couldn't add enough
    // unique distractors despite earlier validation. This should be extremely rare since:
    // 1. We validate distractorsInWords.length >= initialNeededDistractors (line 1316)
    // 2. We validate neededDistractors == initialNeededDistractors (line 1399)
    // 3. We validate distractorsInWords.length >= neededDistractors after recalculation (line 1429)
    // 4. We deduplicate distractors during separation (line 1206)
    // 5. Distractors are separated from correct answers (line 1197 check)
    // 6. Loop breaks when distractorsAdded >= neededDistractors (line 1469)
    // If this occurs, it indicates a data integrity issue and we need a new trivia item
    if (distractorsAdded != neededDistractors) {
      if (kDebugMode) {
        debugPrint(
          '❌ Error: Added $distractorsAdded distractors (expected exactly $neededDistractors). Unexpected data integrity issue detected. Attempting to find new trivia item...',
        );
      }
      // Try to find a new trivia item with valid data structure
      if (recursionDepth < GameConstants.maxRecursionDepthGameService &&
          triviaPool.length > 1) {
        return startNewRound(
          triviaPool,
          mode: mode,
          recursionDepth: recursionDepth + 1,
        );
      } else {
        final errorMsg =
            'Cannot start game: Unable to build shuffled words with exactly $requiredWordsForGameplay unique words (added $distractorsAdded distractors, needed $neededDistractors) after $recursionDepth attempts.';
        if (kDebugMode) {
          debugPrint('❌ Error: $errorMsg');
        }
        // Log to Crashlytics for production monitoring
        try {
          FirebaseCrashlytics.instance.recordError(
            Exception(errorMsg),
            StackTrace.current,
            reason:
                'GameService: Incorrect number of distractors added to shuffled words',
            fatal: false,
          );
        } catch (e) {
          // Ignore Crashlytics errors - not critical
          if (kDebugMode) debugPrint('Failed to log to Crashlytics: $e');
        }
        // Throw exception to prevent continuing with invalid state
        throw GameException(errorMsg);
      }
    }

    // CRITICAL: Validate shuffledWords has exactly 6 words immediately after adding distractors
    // This ensures we catch any data integrity issues before converting to list and shuffling
    // shuffledWords should contain: correctAnswersAdded (3) + distractorsAdded (3) = 6 total
    if (shuffledWords.length != requiredWordsForGameplay) {
      if (kDebugMode) {
        debugPrint(
          '❌ Error: shuffledWords has ${shuffledWords.length} words (expected exactly $requiredWordsForGameplay: $expectedCorrectAnswers correct + $neededDistractors distractors). Data integrity issue detected. Attempting to find new trivia item...',
        );
      }
      // Try to find a new trivia item with valid data structure
      if (recursionDepth < GameConstants.maxRecursionDepthGameService &&
          triviaPool.length > 1) {
        return startNewRound(
          triviaPool,
          mode: mode,
          recursionDepth: recursionDepth + 1,
        );
      } else {
        final errorMsg =
            'Cannot start game: shuffledWords has ${shuffledWords.length} words (expected exactly $requiredWordsForGameplay) after $recursionDepth attempts.';
        if (kDebugMode) {
          debugPrint('❌ Error: $errorMsg');
        }
        // Log to Crashlytics for production monitoring
        try {
          FirebaseCrashlytics.instance.recordError(
            Exception(errorMsg),
            StackTrace.current,
            reason: 'GameService: shuffledSet has incorrect word count',
            fatal: false,
          );
        } catch (e) {
          // Ignore Crashlytics errors - not critical
          if (kDebugMode) debugPrint('Failed to log to Crashlytics: $e');
        }
        // Throw exception to prevent continuing with invalid state
        throw GameException(errorMsg);
      }
    }

    // CRITICAL: Validate shuffled words are unique before setting (defensive check)
    // This prevents duplicate words from corrupting game state even if input validation fails
    final shuffledWordsSet = Set<String>.from(shuffledWords);
    if (shuffledWordsSet.length != shuffledWords.length) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ Warning: Duplicate words detected in shuffled words list. Removing duplicates.',
        );
      }
      // Remove duplicates by converting to Set and back to List (preserves uniqueness)
      _shuffledWords = shuffledWordsSet.toList()..shuffle(_random);
    } else {
      // Convert to list and shuffle to mix correct answers and distractors
      _shuffledWords = shuffledWords..shuffle(_random);
    }

    // CRITICAL: Filter empty/whitespace strings from list to maintain size consistency with map
    _shuffledWords = _shuffledWords
        .where((word) => word.trim().isNotEmpty)
        .toList();

    // Clear and rebuild word-to-index map for O(1) lookups in Flip Mode (performance optimization)
    // CRITICAL: Clear map before rebuilding to prevent stale entries
    // Both list and map now have the same length, ensuring index consistency
    _shuffledWordsMap.clear();
    _shuffledWordsMap = {
      for (int i = 0; i < _shuffledWords.length; i++) _shuffledWords[i]: i,
    };

    // CRITICAL: Validate we have exactly 6 words (required, not preferred)
    // This is a hard requirement - the game must always show exactly 6 words
    if (_shuffledWords.length != requiredWordsForGameplay) {
      if (kDebugMode) {
        debugPrint(
          '❌ Error: Invalid word count (${_shuffledWords.length}, must be exactly $requiredWordsForGameplay). Cannot proceed.',
        );
      }
      // Try to find a new trivia item
      if (recursionDepth < GameConstants.maxRecursionDepthGameService &&
          triviaPool.length > 1) {
        return startNewRound(
          triviaPool,
          mode: mode,
          recursionDepth: recursionDepth + 1,
        );
      } else {
        final errorMsg =
            (recursionDepth >= GameConstants.maxRecursionDepthGameService)
            ? 'Max recursion depth reached. Cannot find valid trivia item.'
            : (triviaPool.length == 1)
            ? 'Cannot find valid trivia item: Only one trivia item available and it has invalid word count (${_shuffledWords.length}, must be exactly $requiredWordsForGameplay).'
            : 'Cannot find valid trivia item after $recursionDepth attempts: Invalid word count (${_shuffledWords.length}, must be exactly $requiredWordsForGameplay).';
        if (kDebugMode) {
          debugPrint('❌ Error: $errorMsg');
        }
        // Log to Crashlytics for production monitoring
        try {
          FirebaseCrashlytics.instance.recordError(
            Exception(errorMsg),
            StackTrace.current,
            reason: 'GameService: Max recursion depth - incorrect word count',
            fatal: false,
          );
        } catch (e) {
          // Ignore Crashlytics errors - not critical
          if (kDebugMode) debugPrint('Failed to log to Crashlytics: $e');
        }
        // Throw exception to prevent continuing with invalid state
        throw GameException(errorMsg);
      }
    }

    // Set up phase and timers based on mode
    final ModeConfig config = currentConfig;

    // AI Mode: Use dynamic timing if set, otherwise use default
    if (_currentMode == GameMode.ai) {
      // Track round start time for accurate response time calculation
      _aiModeRoundStartTime = DateTime.now();
      _aiModeMemorizeStartTime = null;
      _aiModePlayStartTime = null;

      if (_aiModeMemorizeTime != null && _aiModePlayTime != null) {
        // Use AI mode timing
        _memorizeTimeLeft = _aiModeMemorizeTime!;
        _playTimeLeft = _aiModePlayTime!;
        _phase = _memorizeTimeLeft > 0 ? GamePhase.memorize : GamePhase.play;
      } else {
        // Default AI mode timing (will be updated after first round)
        _memorizeTimeLeft = 10;
        _playTimeLeft = 20;
        _phase = GamePhase.memorize;
      }
    } else {
      // Use config timing for other modes
      _memorizeTimeLeft = config.memorizeTime;
      _playTimeLeft = config.playTime;
      _phase = config.memorizeTime > 0 ? GamePhase.memorize : GamePhase.play;
    }

    _shuffleCount = 0;

    // Initialize flip mode if needed
    if (config.enableFlip && _currentMode == GameMode.flip) {
      // Reset flip mode state
      _flipModeSelectedOrder.clear();
      _flipCurrentIndex = 0;
      // Initialize flipped tiles (all start face-up for memorize phase)
      _flippedTiles = List.filled(_shuffledWords.length, true);
      // Determine reveal mode for this round (if random)
      if (_flipRevealMode == 'random') {
        _flipRevealModeIsInstant = _random.nextBool();
      } else {
        _flipRevealModeIsInstant = _flipRevealMode == 'instant';
      }
    }

    _safeNotifyListeners();

    // Note: Round start sound will be played in game_screen.dart

    // Start memorize phase timer if needed
    if (_memorizeTimeLeft > 0) {
      // Start flip sequence if in flip mode
      if (config.enableFlip && _currentMode == GameMode.flip) {
        _startFlipSequence();
      }
      // Track memorize phase start for AI mode
      if (_currentMode == GameMode.ai) {
        _aiModeMemorizeStartTime = DateTime.now();
      }
      // Cancel any existing memorize timer to prevent leaks
      _memorizeTimer?.cancel();
      _memorizeTimer = null;
      _memorizeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_disposed) {
          timer.cancel();
          return;
        }
        // CRITICAL: Clamp memorize time to prevent negative values (defensive programming)
        _memorizeTimeLeft = (_memorizeTimeLeft - 1).clamp(0, 999);
        _safeNotifyListeners();
        if (_memorizeTimeLeft <= 0) {
          timer.cancel();
          if (_disposed) return;
          // For flip mode, ensure all tiles are face-down when play starts
          if (config.enableFlip && _currentMode == GameMode.flip) {
            _flippedTiles = List.filled(_shuffledWords.length, false);
            _flipInitialTimer?.cancel(); // Cancel any ongoing flip animation
            _flipPeriodicTimer?.cancel();
            _flipInitialTimer = null;
            _flipPeriodicTimer = null;
          }
          _phase = GamePhase.play;
          // Use AI mode play time if set
          if (_currentMode == GameMode.ai) {
            if (_aiModePlayTime != null) {
              _playTimeLeft = _aiModePlayTime!;
            }
            // Track play phase start for AI mode
            _aiModePlayStartTime = DateTime.now();
          }
          _safeNotifyListeners();
          // Start play timer
          _startPlayTimer();
        }
      });
    } else {
      // No memorize phase, go straight to play
      _phase = GamePhase.play;
      _safeNotifyListeners();
      _startPlayTimer();
    }

    // Start shuffle timer for shuffle mode
    if (config.enableShuffle && _currentMode == GameMode.shuffle) {
      _startShuffleSequence();
    }
  }

  void _startPlayTimer() {
    // Cancel any existing play timer to prevent leaks
    _playTimer?.cancel();
    _playTimer = null;
    _playTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }
      // Don't count down if time is frozen
      if (_isTimeFrozen) return;

      // CRITICAL: Clamp play time to prevent negative values (defensive programming)
      _playTimeLeft = (_playTimeLeft - 1).clamp(0, GameConstants.maxTimerSeconds);
      _safeNotifyListeners();
      if (_playTimeLeft <= 0) {
        timer.cancel();
        if (_disposed) return;
        _shuffleTimer?.cancel();
        submitAnswers();
      }
    });
  }

  void toggleTileSelection(String word) {
    if (_phase != GamePhase.play) return;

    // Flip Mode: Must select in correct order (no deselection allowed)
    if (_currentMode == GameMode.flip) {
      _handleFlipModeSelection(word);
      return;
    }

    if (_selectedAnswers.contains(word)) {
      _selectedAnswers.remove(word);
    } else {
      if (_selectedAnswers.length < expectedCorrectAnswers) {
        // Precision Mode: Check if wrong word selected, lose life immediately
        final currentTrivia = _currentTrivia;
        if (_currentMode == GameMode.precision && currentTrivia != null) {
          // CRITICAL: Normalize strings for case-insensitive, whitespace-tolerant comparison
          // This matches the normalization logic used in normal mode for consistency
          final correct = Set<String>.from(
            currentTrivia.correctAnswers.map((w) => w.trim().toLowerCase()),
          );
          if (!correct.contains(word.trim().toLowerCase())) {
            // Wrong word selected - lose life immediately
            // CRITICAL: Clamp lives to prevent negative values (defensive programming)
            _state = _state.copyWith(lives: (_state.lives - 1).clamp(0, 999));
            if (_state.lives <= 0) {
              _state = _state.copyWith(isGameOver: true);
              unawaited(
                submitCompetitiveChallengeScore(),
              ); // Submit if competitive challenge
            }
            HapticService().error();
            // Show visual feedback - don't add wrong word, clear selection
            _selectedAnswers.clear();
            // Store error message for UI to display
            _precisionError = 'Wrong answer! Life lost.';
            _safeNotifyListeners();
            // Clear error message after a short delay (use constant for delay)
            Future.delayed(
              const Duration(
                milliseconds:
                    GameConstants.flipModeInstantRevealDelayMilliseconds,
              ),
              () {
                if (!_disposed) {
                  _precisionError = null;
                  _safeNotifyListeners();
                }
              },
            );
            _saveState();
            return; // Don't add wrong word
          }
        }
        // Double-check length before adding (defensive programming)
        if (_selectedAnswers.length < expectedCorrectAnswers) {
          _selectedAnswers.add(word);
        } else {
          // Already at max - ignore (shouldn't happen, but defensive)
          LoggerService.debug('Attempted to add 4th answer, ignoring');
        }
      } else {
        // Already at max - ignore additional selections
        LoggerService.debug(
          'Maximum selections reached, ignoring additional selection',
        );
      }
    }
    _safeNotifyListeners();
  }

  /// Handle flip mode selection (must select correct tiles in correct order)
  void _handleFlipModeSelection(String word) {
    final words = _currentTrivia?.words ?? [];
    final correctAnswers = _currentTrivia?.correctAnswers ?? [];

    // CRITICAL: Ensure _flippedTiles is initialized before handling selection
    // This prevents race condition where selection happens before flip sequence starts
    if (_flippedTiles.isEmpty && _shuffledWords.isNotEmpty) {
      _flippedTiles = List.filled(_shuffledWords.length, true);
      _flipCurrentIndex = 0;
    }

    // Find the index of the selected word in shuffledWords (matches UI tile positions)
    // Use Map for O(1) lookup performance (optimized from O(n) indexOf)
    int wordIndex = _shuffledWordsMap[word] ?? -1;
    if (wordIndex == -1) {
      // Fallback to indexOf if not in map (defensive check for edge cases)
      wordIndex = _shuffledWords.indexOf(word);
      if (wordIndex == -1) {
        // Final fallback to words array
        wordIndex = words.indexOf(word);
        if (wordIndex == -1) {
          if (kDebugMode) {
            debugPrint(
              '⚠️ Warning: Word "$word" not found in shuffledWords or words array',
            );
          }
          return;
        }
      }
    }

    // Already selected all expected correct answers
    if (_flipModeSelectedOrder.length >= expectedCorrectAnswers) {
      return;
    }

    // Check if this is the next correct answer in order
    final int expectedOrderIndex = _flipModeSelectedOrder.length;
    if (expectedOrderIndex >= correctAnswers.length) {
      // Safety check: prevent index out of bounds
      if (kDebugMode) {
        debugPrint(
          '⚠️ Warning: Expected order index $expectedOrderIndex exceeds correctAnswers length ${correctAnswers.length}',
        );
      }
      return; // Early return if index out of bounds
    }
    final String expectedWord = correctAnswers[expectedOrderIndex];
    // CRITICAL: Normalize strings for case-insensitive, whitespace-tolerant comparison
    // This matches the normalization logic used in normal mode for consistency
    final normalizedWord = word.trim().toLowerCase();
    final normalizedExpected = expectedWord.trim().toLowerCase();
    final normalizedCorrectAnswers = correctAnswers
        .map((w) => w.trim().toLowerCase())
        .toSet();
    final bool isCorrect =
        normalizedWord == normalizedExpected &&
        normalizedCorrectAnswers.contains(normalizedWord);

    // Handle reveal based on mode
    if (_flipRevealModeIsInstant) {
      // Instant: Flip tile immediately (with defensive bounds check)
      if (wordIndex >= 0 &&
          wordIndex < _flippedTiles.length &&
          !_flippedTiles[wordIndex]) {
        _flippedTiles[wordIndex] = true;
      }

      if (isCorrect) {
        // Prevent duplicate selections (defensive check)
        if (!_flipModeSelectedOrder.contains(word)) {
          _flipModeSelectedOrder.add(word);
          _selectedAnswers.add(
            word,
          ); // Also add to selectedAnswers for consistency
          HapticService().success();
          if (_flipModeSelectedOrder.length == expectedCorrectAnswers) {
            // All correct in order - submit as perfect round
            _playTimer?.cancel();

            // Log analytics for Flip Mode perfect round
            _analyticsService?.logGameModeSelected(
              'flip_perfect_round',
              'flip',
            );

            _submitFlipModeAnswers(true);
          }
        }
      } else {
        // Wrong selection - lose life
        HapticService().error();

        // Log analytics for Flip Mode wrong selection
        _analyticsService?.logGameModeSelected('flip_wrong_selection', 'flip');

        // CRITICAL: Track session stats for instant wrong selections
        // Wrong selection means user selected an incorrect word, so:
        // - 0 correct answers (wrong word selected)
        // - 1 wrong answer (the wrong selection)
        // Note: This tracks individual wrong selections, not the full round result
        // Each wrong click in instant mode counts as 1 wrong answer for session stats
        // CRITICAL: Clamp session stats to prevent integer overflow (defensive programming)
        _sessionWrongAnswers = (_sessionWrongAnswers + 1).clamp(0, GameConstants.maxSessionAnswers);

        // CRITICAL: Clamp lives to prevent negative values (defensive programming)
        _state = _state.copyWith(lives: (_state.lives - 1).clamp(0, GameConstants.maxLives));
        _safeNotifyListeners(); // CRITICAL: Notify listeners of state change (life loss)
        if (_state.lives <= 0) {
          _state = _state.copyWith(isGameOver: true);
          unawaited(submitCompetitiveChallengeScore());
          // CRITICAL: Track results for UI display when game over occurs
          // Wrong selection means 0 correct, 1 wrong selection
          // Store current trivia answers and the wrong selection made for UI feedback
          _correctCount = 0;
          if (_currentTrivia != null) {
            _lastCorrectAnswers = List<String>.from(
              _currentTrivia!.correctAnswers,
            );
            // Store the wrong selection that was made for UI display
            _lastSelectedAnswers = [word]; // Single wrong selection
          }
          // CRITICAL: Update phase, notify listeners, and save state for game over
          // This ensures UI updates immediately and state is persisted
          _phase = GamePhase.result;
          _safeNotifyListeners();
          _saveState();
        } else {
          // Clear selections and continue
          _flipModeSelectedOrder.clear();
          _selectedAnswers.clear();
        }
      }
    } else {
      // Blind: Track selection, reveal later
      // CRITICAL: Explicitly prevent exceeding expected correct answers count
      // This defensive check prevents state corruption if rapid taps occur
      if (_flipModeSelectedOrder.length >= expectedCorrectAnswers) {
        return; // Already have all expected selections, ignore additional taps
      }
      // Prevent duplicate selections (defensive check)
      if (!_flipModeSelectedOrder.contains(word)) {
        _flipModeSelectedOrder.add(word);
        _selectedAnswers.add(word);
        if (_flipModeSelectedOrder.length == expectedCorrectAnswers) {
          // All expected correct answers selected - now reveal results
          _revealFlipModeResults();
        }
      }
    }

    _safeNotifyListeners();
  }

  /// Reveal flip mode results (for blind mode)
  void _revealFlipModeResults() {
    final words = _currentTrivia?.words ?? [];
    final correctAnswers = _currentTrivia?.correctAnswers ?? [];

    // Flip all selected tiles (use shuffledWords to match UI tile positions)
    // Use Map for O(1) lookup performance (optimized from O(n) indexOf)
    for (final selectedWord in _flipModeSelectedOrder) {
      int index = _shuffledWordsMap[selectedWord] ?? -1;
      if (index == -1) {
        // Fallback to indexOf if not in map (defensive check)
        index = _shuffledWords.indexOf(selectedWord);
        if (index == -1) {
          // Final fallback to words array
          index = words.indexOf(selectedWord);
        }
      }
      if (index >= 0 && index < _flippedTiles.length) {
        _flippedTiles[index] = true;
      } else if (index >= 0 && index >= _flippedTiles.length) {
        // Defensive: ensure flippedTiles length matches shuffledWords
        if (kDebugMode) {
          debugPrint(
            '⚠️ Warning: Index $index out of bounds for flippedTiles (length: ${_flippedTiles.length})',
          );
        }
      }
    }

    // Check if all 3 are correct and in order
    // CRITICAL: Normalize strings for consistent comparison (matches _handleFlipModeSelection)
    // This prevents false negatives due to whitespace/case differences between words and correctAnswers
    final normalizedSelected = _flipModeSelectedOrder
        .map((w) => w.trim().toLowerCase())
        .toList();
    final normalizedCorrect = correctAnswers
        .map((w) => w.trim().toLowerCase())
        .toList();
    // CRITICAL: Use loop instead of hardcoded array access to support variable expectedCorrectAnswers
    // This prevents breakage if expectedCorrectAnswers changes from 3
    bool isPerfect =
        normalizedSelected.length == expectedCorrectAnswers &&
        normalizedSelected.length == normalizedCorrect.length;
    if (isPerfect) {
      for (int i = 0; i < normalizedSelected.length; i++) {
        if (normalizedSelected[i] != normalizedCorrect[i]) {
          isPerfect = false;
          break;
        }
      }
    }

    if (isPerfect) {
      HapticService().success();
      _playTimer?.cancel();

      // Log analytics for Flip Mode blind mode perfect round
      _analyticsService?.logGameModeSelected('flip_blind_perfect', 'flip');

      _submitFlipModeAnswers(true);
    } else {
      // Count wrong answers
      // CRITICAL: Normalize strings for consistent comparison (matches perfect check above)
      // This ensures wrong count calculation uses the same normalization as perfect check
      final normalizedSelected = _flipModeSelectedOrder
          .map((w) => w.trim().toLowerCase())
          .toList();
      final normalizedCorrect = correctAnswers
          .map((w) => w.trim().toLowerCase())
          .toList();
      int wrongCount = 0;
      for (int i = 0; i < normalizedSelected.length; i++) {
        if (i >= normalizedCorrect.length ||
            normalizedSelected[i] != normalizedCorrect[i]) {
          wrongCount++;
        }
      }
      HapticService().error();

      // Log analytics for Flip Mode blind mode wrong answers
      _analyticsService?.logGameModeSelected('flip_blind_wrong', 'flip');

      // CRITICAL: Track session stats for blind non-perfect rounds
      // This ensures consistent stats tracking across all Flip Mode paths
      // Use same calculation pattern as _submitFlipModeAnswers() for consistency
      final expectedCorrect = correctAnswers.length;
      final correct = Set<String>.from(
        correctAnswers.map((w) => w.trim().toLowerCase()),
      );
      int numCorrect = 0;
      for (final selected in _flipModeSelectedOrder) {
        if (correct.contains(selected.trim().toLowerCase())) {
          numCorrect++;
        }
      }
      // CRITICAL: Clamp session stats to prevent integer overflow (defensive programming)
      _sessionCorrectAnswers = (_sessionCorrectAnswers + numCorrect).clamp(
        0,
        GameConstants.maxSessionAnswers,
      );
      final selectedWrong = _flipModeSelectedOrder.length - numCorrect;
      final missedCorrect = expectedCorrect - numCorrect;
      _sessionWrongAnswers =
          (_sessionWrongAnswers +
                  (selectedWrong + missedCorrect).clamp(0, expectedCorrect))
              .clamp(0, GameConstants.maxSessionAnswers);

      // CRITICAL: Track results for UI display (matches _submitFlipModeAnswers pattern)
      // This ensures the result screen can display correct/wrong answers correctly
      _correctCount = numCorrect;
      _lastCorrectAnswers = List<String>.from(correctAnswers);
      _lastSelectedAnswers = List<String>.from(_flipModeSelectedOrder);

      // CRITICAL: Cap life loss at 1 per round for consistency with other modes
      // Flip Mode blind can have 0-3 wrong answers, but losing multiple lives at once
      // is too harsh and inconsistent with normal mode behavior
      final lifeLoss = wrongCount > 0 ? 1 : 0;
      // CRITICAL: Clamp lives to prevent negative values (defensive programming)
      _state = _state.copyWith(lives: (_state.lives - lifeLoss).clamp(0, 999));
      if (_state.lives <= 0) {
        _state = _state.copyWith(isGameOver: true);
        unawaited(submitCompetitiveChallengeScore());
        // CRITICAL: Update phase, notify listeners, and save state for game over
        // This ensures UI updates immediately and state is persisted
        _phase = GamePhase.result;
        _safeNotifyListeners();
        _saveState();
      } else {
        // Move to result phase to show feedback
        _phase = GamePhase.result;
        _safeNotifyListeners();

        // Cancel any pending nextRound delay to prevent race conditions
        _cancelPendingNextRoundDelay();

        // Auto-advance after showing results (use constant for delay)
        _pendingNextRoundDelay = Future.delayed(
          const Duration(
            seconds: GameConstants.nextRoundAutoAdvanceDelaySeconds,
          ),
          () {
            // Validate that this callback is still the current one (prevents race conditions)
            if (_disposed || _pendingNextRoundDelay == null) return;
            // Validate state before calling nextRound() - ensure trivia pool is available
            if (_phase == GamePhase.result &&
                !_state.isGameOver &&
                _currentTriviaPool.isNotEmpty) {
              try {
                nextRound();
              } catch (e) {
                if (kDebugMode) {
                  debugPrint('Error in delayed nextRound callback: $e');
                }
                // Log to Crashlytics for production monitoring
                FirebaseCrashlytics.instance.recordError(
                  e,
                  StackTrace.current,
                  reason: 'Error in Future.delayed nextRound callback',
                  fatal: false,
                );
              } finally {
                _pendingNextRoundDelay =
                    null; // Clear reference after execution
              }
            }
          },
        );
      }
    }

    _safeNotifyListeners();
  }

  /// Submit flip mode answers (with order validation)
  void _submitFlipModeAnswers(bool isPerfect) {
    if (_currentTrivia == null) return;

    final currentTrivia = _currentTrivia!;
    final correctAnswers = currentTrivia.correctAnswers;

    // Track results
    _correctCount = isPerfect ? 3 : 0;
    _lastCorrectAnswers = List<String>.from(correctAnswers);
    _lastSelectedAnswers = List<String>.from(_flipModeSelectedOrder);

    // Track stats - use same calculation pattern as normal mode for consistency
    if (isPerfect) {
      // CRITICAL: Clamp session stats to prevent integer overflow (defensive programming)
      _sessionCorrectAnswers = (_sessionCorrectAnswers + 3).clamp(
        0,
        2147483647,
      );
    } else {
      final expectedCorrect =
          correctAnswers.length; // Should be 3, but use actual value

      // Count how many selected answers are correct (regardless of order for stats purposes)
      // In Flip Mode, we track order separately, but for session stats we count correct answers
      // CRITICAL: Normalize strings to match normal mode comparison logic (case-insensitive, whitespace-trimmed)
      final correct = Set<String>.from(
        correctAnswers.map((w) => w.trim().toLowerCase()),
      );
      int numCorrect = 0;
      for (final selected in _flipModeSelectedOrder) {
        if (correct.contains(selected.trim().toLowerCase())) {
          numCorrect++;
        }
      }

      _sessionCorrectAnswers = (_sessionCorrectAnswers + numCorrect).clamp(
        0,
        GameConstants.maxSessionAnswers,
      );

      // Use same calculation as normal mode: selected wrong + missed correct
      // In Flip Mode, user must select exactly 3 answers, so:
      // selectedWrong = total selected - correct selected = 3 - numCorrect
      // missedCorrect = expected correct - correct selected = expectedCorrect - numCorrect
      final selectedWrong = _flipModeSelectedOrder.length - numCorrect;
      final missedCorrect = expectedCorrect - numCorrect;
      _sessionWrongAnswers =
          (_sessionWrongAnswers +
                  (selectedWrong + missedCorrect).clamp(0, expectedCorrect))
              .clamp(0, GameConstants.maxSessionAnswers);
    }

    int points = 0;
    int newPerfectStreak = _state.perfectStreak;

    if (isPerfect) {
      // Perfect round: 10 points per correct answer + 10 bonus
      points = 30 + 10; // 3 correct * 10 + 10 bonus
      // CRITICAL: Clamp perfect streak to prevent integer overflow (defensive programming)
      newPerfectStreak = (_state.perfectStreak + 1).clamp(0, GameConstants.maxPerfectStreak);
      _awardStreakReward(newPerfectStreak);

      // Log analytics for Flip Mode perfect round completion
      _analyticsService?.logGameModeSelected('flip_perfect_complete', 'flip');

      // Update state
      // CRITICAL: Don't increment round here - let nextRound() handle it to prevent double increment
      // CRITICAL: Clamp score to prevent integer overflow (especially in marathon mode with multipliers)
        final newScore = (_state.score + points).clamp(0, GameConstants.maxScore);
      _state = _state.copyWith(
        score: newScore,
        perfectStreak: newPerfectStreak,
      );

      // Update personalization
      if (_personalizationService != null) {
        final String theme =
            (currentTrivia.theme != null && currentTrivia.theme!.isNotEmpty)
            ? currentTrivia.theme!.toLowerCase().trim()
            : 'general';
        final difficulty = currentTrivia.difficulty ?? DifficultyLevel.medium;
        _personalizationService!.updatePerformance(
          category: currentTrivia.category,
          theme: theme,
          wasCorrect: isPerfect,
          difficulty: difficulty,
          score: points,
        );
      }

      // CRITICAL: Auto-advance to next round for perfect Flip Mode rounds
      // This matches the behavior of non-perfect blind mode and ensures gameplay continues
      if (!_state.isGameOver && _currentTriviaPool.isNotEmpty) {
        _phase = GamePhase.result;
        _safeNotifyListeners();
        _saveState();

        // Cancel any pending nextRound delay to prevent race conditions
        _cancelPendingNextRoundDelay();

        // Auto-advance after showing results (use constant for delay)
        _pendingNextRoundDelay = Future.delayed(
          const Duration(
            seconds: GameConstants.nextRoundAutoAdvanceDelaySeconds,
          ),
          () {
            // Validate that this callback is still the current one (prevents race conditions)
            if (_disposed || _pendingNextRoundDelay == null) return;
            if (_phase == GamePhase.result &&
                !_state.isGameOver &&
                _currentTriviaPool.isNotEmpty) {
              try {
                nextRound();
              } catch (e) {
                if (kDebugMode) {
                  debugPrint(
                    'Error in delayed nextRound callback (Flip Mode perfect): $e',
                  );
                }
                // Log to Crashlytics for production monitoring
                FirebaseCrashlytics.instance.recordError(
                  e,
                  StackTrace.current,
                  reason:
                      'Error in Future.delayed nextRound callback (Flip Mode perfect)',
                  fatal: false,
                );
              } finally {
                _pendingNextRoundDelay =
                    null; // Clear reference after execution
              }
            }
          },
        );
        return; // Exit early to avoid setting phase/notifying again at end of method
      }
    } else {
      // Not perfect - lose lives based on wrong answers
      // CRITICAL: Normalize strings for consistent comparison (matches other Flip Mode logic)
      // This ensures wrong count calculation is consistent with _handleFlipModeSelection and _revealFlipModeResults
      final normalizedSelected = _flipModeSelectedOrder
          .map((w) => w.trim().toLowerCase())
          .toList();
      final normalizedCorrect = correctAnswers
          .map((w) => w.trim().toLowerCase())
          .toList();
      int wrongCount = 0;
      for (int i = 0; i < normalizedSelected.length; i++) {
        if (i >= normalizedCorrect.length ||
            normalizedSelected[i] != normalizedCorrect[i]) {
          wrongCount++;
        }
      }
      // CRITICAL: Cap life loss at 1 per round for consistency with other Flip Mode paths
      // This ensures Flip Mode doesn't lose multiple lives at once, matching:
      // - Flip Mode instant reveal: 1 life per wrong selection
      // - Flip Mode blind mode: capped at 1 life loss
      final lifeLoss = wrongCount > 0 ? 1 : 0;
      _state = _state.copyWith(
        lives: _state.lives - lifeLoss,
        perfectStreak: 0,
      );

      if (_state.lives <= 0) {
        _state = _state.copyWith(isGameOver: true);
        unawaited(submitCompetitiveChallengeScore());
        _phase = GamePhase.result;
        _safeNotifyListeners();
        _saveState();
        return; // Exit early - game over
      } else {
        // CRITICAL: Don't increment round here - let nextRound() handle it to prevent double increment
        // Auto-advance to next round (matches perfect path behavior)
        if (_currentTriviaPool.isNotEmpty) {
          _phase = GamePhase.result;
          _safeNotifyListeners();
          _saveState();

          // Cancel any pending nextRound delay to prevent race conditions
          _cancelPendingNextRoundDelay();

          // Auto-advance after showing results (use constant for delay)
          _pendingNextRoundDelay = Future.delayed(
            const Duration(
              seconds: GameConstants.nextRoundAutoAdvanceDelaySeconds,
            ),
            () {
              // Validate that this callback is still the current one (prevents race conditions)
              if (_disposed || _pendingNextRoundDelay == null) return;
              if (_phase == GamePhase.result &&
                  !_state.isGameOver &&
                  _currentTriviaPool.isNotEmpty) {
                try {
                  nextRound();
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint(
                      'Error in delayed nextRound callback (Flip Mode non-perfect): $e',
                    );
                  }
                  // Log to Crashlytics for production monitoring
                  FirebaseCrashlytics.instance.recordError(
                    e,
                    StackTrace.current,
                    reason:
                        'Error in Future.delayed nextRound callback (Flip Mode non-perfect)',
                    fatal: false,
                  );
                } finally {
                  _pendingNextRoundDelay =
                      null; // Clear reference after execution
                }
              }
            },
          );
          return; // Exit early to avoid setting phase/notifying again at end of method
        }
      }
    }

    // Fallback: If we reach here, set result phase (should not happen with proper flow)
    _phase = GamePhase.result;
    _safeNotifyListeners();
    _saveState();
  }

  // Reveal word on double-tap (only in play phase when word is hidden)
  void revealWord(String word) {
    if (_phase != GamePhase.play) return;
    // CRITICAL: Validate word exists in current trivia item to prevent revealing invalid words
    // This ensures revealed words are always part of the current round's word list
    final currentWords = _currentTrivia?.words ?? [];
    if (!currentWords.contains(word)) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ Warning: Attempted to reveal word "$word" not in current trivia words list',
        );
      }
      return; // Word not in current trivia, ignore reveal attempt
    }
    if (!_revealedWords.contains(word)) {
      _revealedWords.add(word);
      _safeNotifyListeners();
    }
  }

  // Reveal only correct answers (for reveal button)
  void revealAllWords() {
    if (_phase != GamePhase.play) return;
    if (_state.isGameOver) return; // Cannot use power-ups when game is over
    if (_revealAllUses <= 0) return; // No uses left
    // Only reveal correct answers, not all words
    final currentTrivia = _currentTrivia;
    if (currentTrivia != null) {
      // CRITICAL: Validate correct answers exist in current trivia words list
      // This defensive check prevents revealing invalid words if data is corrupted
      final currentWords = currentTrivia.words.toSet();
      final validCorrectAnswers = currentTrivia.correctAnswers
          .where((word) => currentWords.contains(word))
          .toList();
      _revealedWords.addAll(validCorrectAnswers);
      if (validCorrectAnswers.length != currentTrivia.correctAnswers.length &&
          kDebugMode) {
        debugPrint(
          '⚠️ Warning: Some correct answers not found in trivia words list - filtered invalid entries',
        );
      }
    }
    // CRITICAL: Clamp reveal all uses to prevent negative values (defensive programming)
    _revealAllUses = (_revealAllUses - 1).clamp(0, GameConstants.maxPowerUpUses);
    _safeNotifyListeners();
  }

  // Clear all selections
  void clearSelections() {
    if (_phase != GamePhase.play) return;
    if (_state.isGameOver) return; // Cannot use power-ups when game is over
    if (_clearUses <= 0) return; // No uses left
    _selectedAnswers.clear();
    // CRITICAL: Clamp clear uses to prevent negative values (defensive programming)
    _clearUses = (_clearUses - 1).clamp(0, GameConstants.maxPowerUpUses);
    _safeNotifyListeners();
  }

  // Skip current round (lose a life and move to next)
  void skipRound(List<TriviaItem> triviaPool) {
    if (_phase == GamePhase.result) return;
    if (_skipUses <= 0) return; // No uses left

    // Prevent skipping during active submission to avoid state corruption
    if (_isSubmitting) {
      if (kDebugMode) {
        debugPrint('⚠️ Warning: Cannot skip round during active submission');
      }
      return;
    }
    _playTimer?.cancel();
    _memorizeTimer?.cancel();
    _shuffleTimer?.cancel();
    _flipInitialTimer?.cancel(); // Cancel flip timers if in flip mode
    _flipPeriodicTimer?.cancel();

    // CRITICAL: Clamp skip uses to prevent negative values (defensive programming)
    _skipUses = (_skipUses - 1).clamp(0, GameConstants.maxPowerUpUses);

    // Reset submission flag if submission was in progress (defensive check)
    _isSubmitting = false;

    // Lose a life for skipping
    // CRITICAL: Clamp lives to prevent negative values (defensive programming)
    _state = _state.copyWith(lives: (_state.lives - 1).clamp(0, 999));

    // Standardize session wrong answers calculation (consistent with submitAnswers logic)
    // Skip counts as missing all correct answers
    final currentTrivia = _currentTrivia;
    final expectedCorrect =
        currentTrivia?.correctAnswers.length ?? expectedCorrectAnswers;
    // CRITICAL: Clamp session stats to prevent integer overflow (defensive programming)
    _sessionWrongAnswers = (_sessionWrongAnswers + expectedCorrect).clamp(
      0,
      2147483647,
    ); // All answers missed when skipping

    // Check for game over
    if (_state.lives <= 0) {
      _state = _state.copyWith(isGameOver: true);
      unawaited(
        submitCompetitiveChallengeScore(),
      ); // Submit if competitive challenge
      _safeNotifyListeners();
      _saveState();
    } else {
      // Move to next round
      nextRound(triviaPool);
    }
  }

  // Advanced Power-ups (Premium only)

  /// Activate Streak Shield - protects from losing a life on next wrong answer
  void activateStreakShield() {
    if (_streakShieldUses <= 0) return;
    if (_phase != GamePhase.play) return;
    if (_state.isGameOver) return; // Cannot use power-ups when game is over
    // CRITICAL: Clamp streak shield uses to prevent negative values (defensive programming)
    _streakShieldUses = (_streakShieldUses - 1).clamp(0, GameConstants.maxPowerUpUses);
    _hasStreakShield = true;
    _safeNotifyListeners();
  }

  /// Activate Time Freeze - pauses timer for 10 seconds
  void activateTimeFreeze() {
    if (_timeFreezeUses <= 0 || _isTimeFrozen) return;
    if (_phase != GamePhase.play) return;
    if (_state.isGameOver) return; // Cannot use power-ups when game is over

    // CRITICAL: Clamp time freeze uses to prevent negative values (defensive programming)
    _timeFreezeUses = (_timeFreezeUses - 1).clamp(0, GameConstants.maxPowerUpUses);
    _isTimeFrozen = true;

    // CRITICAL: Store current play time to preserve it during freeze
    // This ensures time freeze doesn't give extra time, but preserves remaining time
    _playTimeAtFreeze = _playTimeLeft;

    // Pause timers
    _playTimer?.cancel();
    _memorizeTimer?.cancel();

    // Cancel any existing time freeze timer
    _timeFreezeTimer?.cancel();

    // Resume after time freeze duration (using constant for maintainability)
    _timeFreezeTimer = Timer(
      const Duration(seconds: GameConstants.timeFreezeDurationSeconds),
      () {
        if (_disposed) return;
        _isTimeFrozen = false;
        if (_phase == GamePhase.play && _playTimeLeft > 0) {
          // CRITICAL: Restore play time to what it was when freeze started
          // This preserves the remaining time instead of giving extra time
          if (_playTimeAtFreeze != null) {
            _playTimeLeft = _playTimeAtFreeze!;
            _playTimeAtFreeze = null;
          }
          _startPlayTimer();
        }
        _safeNotifyListeners();
      },
    );

    _safeNotifyListeners();
  }

  /// Activate Hint - eliminates one wrong answer
  void activateHint() {
    if (_hintUses <= 0) return;
    if (_phase != GamePhase.play) return;
    if (_state.isGameOver) return; // Cannot use power-ups when game is over
    if (_currentTrivia == null) return;

    // CRITICAL: Clamp hint uses to prevent negative values (defensive programming)
    _hintUses = (_hintUses - 1).clamp(0, GameConstants.maxPowerUpUses);

    // Find a wrong answer to eliminate
    final currentTrivia = _currentTrivia;
    if (currentTrivia == null) return;
    // Use case-insensitive comparison for consistency
    final correctAnswers = Set<String>.from(
      currentTrivia.correctAnswers
          .where((w) => w.trim().isNotEmpty) // Filter empty strings
          .map((w) => w.trim().toLowerCase()),
    );
    final wrongAnswers = _shuffledWords
        .where((w) => w.trim().isNotEmpty) // Filter empty strings first
        .where((w) => !correctAnswers.contains(w.trim().toLowerCase()))
        .toList();

    if (wrongAnswers.isNotEmpty) {
      // Remove a random wrong answer (mark it as hinted)
      final wordToHint = wrongAnswers[_random.nextInt(wrongAnswers.length)];
      _hintedWords.add(wordToHint);
      _safeNotifyListeners();
    }
  }

  /// Activate Double Score - doubles points for next round
  void activateDoubleScore() {
    if (_doubleScoreUses <= 0) return;
    if (_phase != GamePhase.play) return;
    if (_state.isGameOver) return; // Cannot use power-ups when game is over
    // CRITICAL: Clamp double score uses to prevent negative values (defensive programming)
    _doubleScoreUses = (_doubleScoreUses - 1).clamp(0, GameConstants.maxPowerUpUses);
    _hasDoubleScore = true;
    _safeNotifyListeners();
  }

  /// Get list of hinted (eliminated) words
  List<String> get hintedWords => List.unmodifiable(_hintedWords);

  // Award power-up based on streak
  void _awardStreakReward(int streak) {
    if (streak == 3) {
      // 3rd perfect streak: +1 life (capped at 999 to prevent unbounded growth)
      if (_state.lives < GameConstants.maxLives) {
        _state = _state.copyWith(lives: _state.lives + 1);
      }
    } else if (streak == 6) {
      // 6th perfect streak: +1 skip
      // CRITICAL: Clamp skip uses to prevent integer overflow (defensive programming)
      _skipUses = (_skipUses + 1).clamp(0, GameConstants.maxPowerUpUses);
    } else if (streak == 9) {
      // 9th perfect streak: +1 clear
      // CRITICAL: Clamp clear uses to prevent integer overflow (defensive programming)
      _clearUses = (_clearUses + 1).clamp(0, GameConstants.maxPowerUpUses);
    } else if (streak == 12) {
      // 12th perfect streak: +1 reveal
      // CRITICAL: Clamp reveal all uses to prevent integer overflow (defensive programming)
      _revealAllUses = (_revealAllUses + 1).clamp(0, GameConstants.maxPowerUpUses);
    }
  }

  void submitAnswers() {
    if (_phase != GamePhase.play) return;

    // Prevent concurrent submissions
    if (_isSubmitting) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ Warning: Submission already in progress, ignoring duplicate call',
        );
      }
      return;
    }

    // Safe null check
    final currentTrivia = _currentTrivia;
    if (currentTrivia == null || currentTrivia.correctAnswers.isEmpty) {
      if (kDebugMode) {
        debugPrint('Cannot submit answers: no trivia item selected');
      }
      return;
    }

    _isSubmitting = true; // Set flag to prevent concurrent calls
    try {
      _playTimer?.cancel();

      // Normalize both sets to lowercase for case-insensitive comparison
      // This prevents false negatives due to casing mismatches
      final correct = Set<String>.from(
        currentTrivia.correctAnswers.map((w) => w.trim().toLowerCase()),
      );
      final selected = _selectedAnswers
          .map((w) => w.trim().toLowerCase())
          .toSet();
      final numCorrect = selected.where((w) => correct.contains(w)).length;

      // Get actual expected correct answers count (handle edge cases)
      final expectedCorrect = currentTrivia.correctAnswers.length;

      // Validate that we have the expected number of correct answers
      if (expectedCorrect != expectedCorrectAnswers && kDebugMode) {
        debugPrint(
          '⚠️ Warning: Trivia item has $expectedCorrect correct answers (expected $expectedCorrectAnswers)',
        );
      }

      // CRITICAL: Validate selected answers count matches expected (prevents processing invalid submissions)
      // Flip Mode handles selection differently, so skip this check for Flip Mode
      if (_currentMode != GameMode.flip &&
          _selectedAnswers.length != expectedCorrect) {
        if (kDebugMode) {
          debugPrint(
            '⚠️ Warning: Invalid submission - ${_selectedAnswers.length} answers selected, expected $expectedCorrect',
          );
        }
        return; // Don't process invalid submission
      }

      // TRACK RESULTS FOR UI
      _correctCount = numCorrect;
      _lastCorrectAnswers = List<String>.from(currentTrivia.correctAnswers);
      _lastSelectedAnswers = List<String>.from(_selectedAnswers);

      // Mark trivia item as used for content freshness tracking
      currentTrivia.markAsUsed();

      // Track stats for the session
      // Calculate wrong answers: selected wrong + missed correct
      // Wrong = total selected - correct selected
      // Missed = expected correct - correct selected
      final selectedWrong = _selectedAnswers.length - numCorrect;
      final missedCorrect = expectedCorrect - numCorrect;
      // CRITICAL: Clamp session stats to prevent integer overflow (defensive programming)
      _sessionCorrectAnswers = (_sessionCorrectAnswers + numCorrect).clamp(
        0,
        GameConstants.maxSessionAnswers,
      );
      _sessionWrongAnswers =
          (_sessionWrongAnswers +
                  (selectedWrong + missedCorrect).clamp(0, expectedCorrect))
              .clamp(0, GameConstants.maxSessionAnswers);

      int points = 0;
      int newPerfectStreak = _state.perfectStreak;

      // Perfect Mode: Must get all correct answers, wrong = game over
      if (_currentMode == GameMode.perfect && numCorrect != expectedCorrect) {
        _state = _state.copyWith(isGameOver: true);
        _phase = GamePhase.result;
        unawaited(
          submitCompetitiveChallengeScore(),
        ); // Submit if competitive challenge
        _safeNotifyListeners();
        _saveState();
        return; // Flag will be reset in finally block
      }

      // Calculate points based on number of correct answers
      // Points scale: 10 per correct answer (1 correct = 10, 2 = 20, 3 = 30, etc.)
      // Perfect round = all correct answers selected
      final isPerfect = numCorrect == expectedCorrect && numCorrect > 0;

      if (isPerfect) {
        // Perfect round: 10 points per correct answer
        points = expectedCorrect * 10;
        // CRITICAL: Clamp perfect streak to prevent integer overflow (defensive programming)
        newPerfectStreak = (_state.perfectStreak + 1).clamp(
          0,
          GameConstants.maxPerfectStreak,
        ); // Increment streak
        // Award streak rewards
        _awardStreakReward(newPerfectStreak);

        // Streak Mode: Increment multiplier (max 5x)
        if (_currentMode == GameMode.streak) {
          if (_streakMultiplier < 5) {
            _streakMultiplier++;
          }
        }

        // Survival Mode: Increment perfect count, gain life every 3
        if (_currentMode == GameMode.survival) {
          // CRITICAL: Clamp survival perfect count to prevent integer overflow (defensive programming)
          // Counter resets to 0 when >= 3, so clamp prevents overflow if reset logic fails
          _survivalPerfectCount = (_survivalPerfectCount + 1).clamp(0, GameConstants.maxPowerUpUses);
          if (_survivalPerfectCount >= 3 && _state.lives < 5) {
            _state = _state.copyWith(lives: _state.lives + 1);
            _survivalPerfectCount = 0; // Reset counter
          }
        }
      } else if (numCorrect > 0) {
        // Partial correct: 10 points per correct answer
        points = numCorrect * 10;
        newPerfectStreak = 0; // Reset streak
        // Streak Mode: Reset multiplier on non-perfect
        if (_currentMode == GameMode.streak) {
          _streakMultiplier = 1;
        }
        // Survival Mode: Reset perfect count on non-perfect
        if (_currentMode == GameMode.survival) {
          _survivalPerfectCount = 0;
        }
      } else {
        // No correct answers
        points = 0;
        newPerfectStreak = 0; // Reset streak
        // Streak Mode: Reset multiplier
        if (_currentMode == GameMode.streak) {
          _streakMultiplier = 1;
        }
        // Survival Mode: Reset perfect count
        if (_currentMode == GameMode.survival) {
          _survivalPerfectCount = 0;
        }
      }

      // Store base points before any multipliers for tracking
      final basePoints = points;

      // Update personalization service with base points (before multipliers)
      if (_personalizationService != null) {
        final wasPerfect = numCorrect == 3;
        final finalDifficulty =
            currentTrivia.difficulty ?? DifficultyLevel.medium;

        // Use stored theme from TriviaItem, fallback to category-based detection
        // Theme should never be null due to validation, but ensure it's always set
        // Normalize theme to lowercase for consistency with personalization service
        String theme =
            (currentTrivia.theme != null && currentTrivia.theme!.isNotEmpty)
            ? currentTrivia.theme!.toLowerCase().trim()
            : 'general';
        if (theme.isEmpty || theme == 'general') {
          // Fallback: Try to extract theme from category pattern
          final category = currentTrivia.category;
          if (category.toLowerCase().contains('capital') ||
              category.toLowerCase().contains('country')) {
            theme = 'geography';
          } else if (category.toLowerCase().contains('science') ||
              category.toLowerCase().contains('element') ||
              category.toLowerCase().contains('planet')) {
            theme = 'science';
          } else if (category.toLowerCase().contains('artist') ||
              category.toLowerCase().contains('painting') ||
              category.toLowerCase().contains('music')) {
            theme = 'arts';
          } else if (category.toLowerCase().contains('sport') ||
              category.toLowerCase().contains('olympic')) {
            theme = 'sports';
          } else if (category.toLowerCase().contains('history') ||
              category.toLowerCase().contains('war') ||
              category.toLowerCase().contains('emperor')) {
            theme = 'history';
          }
        }
        // Ensure theme is normalized (fallback themes are already lowercase)
        theme = theme.toLowerCase().trim();

        _personalizationService!.updatePerformance(
          category: currentTrivia.category,
          theme: theme,
          wasCorrect: wasPerfect,
          difficulty: finalDifficulty,
          score: basePoints, // Use base points for tracking, not multiplied
        );
      }

      // Haptic feedback based on result
      if (numCorrect == 3) {
        HapticService().success(); // Perfect score
      } else if (numCorrect == 0) {
        HapticService().error(); // Wrong answer
        newPerfectStreak = 0; // Reset streak
        // Streak Mode: Reset multiplier
        if (_currentMode == GameMode.streak) {
          _streakMultiplier = 1;
        }
        // Survival Mode: Reset perfect count
        if (_currentMode == GameMode.survival) {
          _survivalPerfectCount = 0;
        }
      } else {
        HapticService().lightImpact(); // Partial correct
      }

      // Apply multipliers in correct order: difficulty first, then double score, then streak multipliers
      // This ensures: final = base * difficulty * (double_score?) * (gamification_streak?) * (streak_mode?)

      // 1. Apply difficulty-based scoring multiplier FIRST (affects base points)
      // Default to medium if difficulty is null (should never happen due to validation, but safety check)
      final triviaDifficulty =
          currentTrivia.difficulty ?? DifficultyLevel.medium;
      double difficultyMultiplier = 1.0;
      switch (triviaDifficulty) {
        case DifficultyLevel.easy:
          difficultyMultiplier = 0.8; // Easier = lower score
          break;
        case DifficultyLevel.medium:
          difficultyMultiplier = 1.0; // Standard
          break;
        case DifficultyLevel.hard:
          difficultyMultiplier = 1.5; // Harder = higher score
          break;
      }
      points = (points * difficultyMultiplier).round();

      // 2. Apply double score if active (applies to difficulty-adjusted points)
      // NOTE: Only applied once - removed duplicate check that was here before
      if (_hasDoubleScore) {
        // CRITICAL: Clamp during multiplication to prevent intermediate overflow
        points = (points * 2).clamp(0, GameConstants.maxScore);
        _hasDoubleScore = false; // One-time use
      }

      // 3. Store points before streak multipliers for gamification tracking
      final pointsBeforeStreak = points;

      // 4. Apply gamification streak multiplier (if available)
      if (_gamificationService != null) {
        final gamificationMultiplier = _gamificationService!
            .getStreakMultiplier();
        if (gamificationMultiplier > 1.0) {
          // CRITICAL: Clamp during multiplication to prevent intermediate overflow
          points = (points * gamificationMultiplier).round().clamp(
            0,
            GameConstants.maxScore,
          );
        }

        // Update gamification service with points before streak multiplier
        final wasPerfect = numCorrect == 3;
        _gamificationService!.updateStreak(
          category: currentTrivia.category,
          perfectRound: wasPerfect,
          score:
              pointsBeforeStreak, // Use points before streak multiplier for tracking
        );
      }

      // 5. Streak Mode: Apply multiplier to points (applies after all other multipliers)
      // Note: Streak Mode multiplier is separate from gamification streak multiplier
      // They can compound, but this is intentional for Streak Mode gameplay
      if (_currentMode == GameMode.streak) {
        // CRITICAL: Clamp during multiplication to prevent intermediate overflow
        // Multiply and clamp to prevent integer overflow before final cap check
        points = (points * _streakMultiplier).clamp(0, GameConstants.maxScore);
      }

      // Cap total multiplier at 50x to prevent extreme score inflation
      // This ensures fair gameplay while still rewarding high streaks
      // Calculate effective multiplier to verify cap (guard against division by zero)
      final effectiveMultiplier = basePoints > 0 ? (points / basePoints) : 0.0;
      final maxPoints = basePoints * 50;
      if (points > maxPoints) {
        if (kDebugMode) {
          debugPrint(
            '⚠️ Score capped at 50x multiplier: $points -> $maxPoints (effective multiplier: ${effectiveMultiplier.toStringAsFixed(2)}x)',
          );
        }
        points = maxPoints;
      } else if (kDebugMode && basePoints > 0 && effectiveMultiplier > 10) {
        // Log high multipliers for monitoring (but don't cap)
        debugPrint(
          'ℹ️ High score multiplier: ${effectiveMultiplier.toStringAsFixed(2)}x (base: $basePoints, final: $points)',
        );
      }

      if (numCorrect == 0) {
        // Check for streak shield
        if (_hasStreakShield) {
          _hasStreakShield = false; // One-time use
          // Don't lose a life
        } else {
          // Marathon Mode: Don't lose lives (effectively infinite)
          if (_currentMode != GameMode.marathon) {
            // CRITICAL: Clamp lives to prevent negative values (defensive programming)
            _state = _state.copyWith(
              lives: (_state.lives - 1).clamp(0, 999),
              perfectStreak: 0,
            );
            if (_state.lives <= 0) {
              _state = _state.copyWith(isGameOver: true);
              unawaited(
                submitCompetitiveChallengeScore(),
              ); // Submit if competitive challenge
            }
          } else {
            // Marathon mode: Still submit if competitive challenge ends
            if (_competitiveChallengeTargetRounds != null &&
                _state.round >= _competitiveChallengeTargetRounds!) {
              _state = _state.copyWith(isGameOver: true);
              unawaited(submitCompetitiveChallengeScore());
            }
          }
        }
      } else {
        // CRITICAL: Clamp score to prevent integer overflow (especially in marathon mode with multipliers)
        final newScore = (_state.score + points).clamp(
          0,
          2147483647,
        ); // Int max
        _state = _state.copyWith(
          score: newScore,
          perfectStreak: newPerfectStreak,
        );
      }

      _phase = GamePhase.result;
      _safeNotifyListeners();
      _saveState();
    } finally {
      // Always reset flag, even if exception occurs
      _isSubmitting = false;

      // CRITICAL: Check if time attack timer expired during submission
      // If time expired while submission was in progress, end the game now
      if (_currentMode == GameMode.timeAttack &&
          (_timeAttackSecondsLeft == null || _timeAttackSecondsLeft! <= 0) &&
          !_state.isGameOver) {
        _state = _state.copyWith(isGameOver: true);
        unawaited(submitCompetitiveChallengeScore());
        _safeNotifyListeners();
      }
    }
  }

  void nextRound([List<TriviaItem>? triviaPool]) {
    // Check competitive challenge round limit
    if (_competitiveChallengeTargetRounds != null &&
        _state.round >= _competitiveChallengeTargetRounds!) {
      // Challenge completed - submit score and end game
      _state = _state.copyWith(isGameOver: true);
      unawaited(submitCompetitiveChallengeScore());
      _safeNotifyListeners();
      _saveState();
      return;
    }

    if (_state.lives <= 0) {
      _state = _state.copyWith(isGameOver: true);
      unawaited(
        submitCompetitiveChallengeScore(),
      ); // Submit if competitive challenge
      _safeNotifyListeners();
      _saveState();
      return;
    }

    // Use provided pool or fall back to stored pool
    final pool = triviaPool ?? _currentTriviaPool;

    // Validate trivia pool is not null or empty
    if (pool.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          'Cannot advance to next round: trivia pool is null or empty',
        );
      }
      throw GameException(
        'No trivia items available. Please add trivia content.',
      );
    }

    // CRITICAL: Warn if trivia pool is running low to prevent repetitive content
    // Small pools may exhaust unique trivia and repeat categories too frequently
    // Auto-regenerate pool if below threshold to maintain content diversity
    if (pool.length < GameConstants.triviaPoolAutoRegenerateThreshold) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ Warning: Trivia pool is low (${pool.length} items remaining) - auto-regenerating pool to maintain content diversity',
        );
      }
      // Auto-regenerate trivia pool to prevent repetitive content
      // NOTE: Pool regeneration synchronization is handled by the caller (TriviaGeneratorService)
      // This exception-based signaling pattern ensures:
      // 1. Single responsibility: GameService detects low pool, caller handles regeneration
      // 2. No race conditions: Caller (typically UI layer) coordinates regeneration with game state
      // 3. Clear error messaging: Exception provides user-visible feedback
      throw GameException(
        'Trivia pool depleted. Please start a new game to get fresh content.',
      );
    }

    // For time attack, check if time is up
    if (_currentMode == GameMode.timeAttack &&
        (_timeAttackSecondsLeft == null || _timeAttackSecondsLeft! <= 0)) {
      _state = _state.copyWith(isGameOver: true);
      unawaited(
        submitCompetitiveChallengeScore(),
      ); // Submit if competitive challenge
      _safeNotifyListeners();
      _saveState();
      return;
    }

    // CRITICAL: Marathon mode resource limits - prevent infinite play
    // NOTE: Round limit is checked first (takes precedence if both limits reached simultaneously)
    // This ensures consistent behavior: round limit is more predictable than duration
    if (_currentMode == GameMode.marathon &&
        _state.round >= GameConstants.marathonModeMaxRounds) {
      if (kDebugMode) {
        debugPrint(
          'Marathon mode completed: Reached maximum rounds (${GameConstants.marathonModeMaxRounds})',
        );
      }
      _state = _state.copyWith(isGameOver: true);
      unawaited(submitCompetitiveChallengeScore());
      _safeNotifyListeners();
      _saveState();
      return;
    }

    // Check marathon mode duration limit (if start time is tracked)
    // Note: This requires _gameStartTime to be set when marathon mode starts
    // NOTE: Duration limit is checked second - if round limit is reached first, this won't execute
    if (_currentMode == GameMode.marathon && _gameStartTime != null) {
      final elapsedMinutes = DateTime.now()
          .difference(_gameStartTime!)
          .inMinutes;
      // CRITICAL: Protect against negative duration if system clock is adjusted backward
      // Clamp to minimum 0 to prevent false-positive game over
      final safeElapsedMinutes = elapsedMinutes < 0 ? 0 : elapsedMinutes;
      if (safeElapsedMinutes >= GameConstants.marathonModeMaxDurationMinutes) {
        if (kDebugMode) {
          debugPrint(
            'Marathon mode completed: Reached maximum duration (${GameConstants.marathonModeMaxDurationMinutes} minutes)',
          );
        }
        _state = _state.copyWith(isGameOver: true);
        unawaited(submitCompetitiveChallengeScore());
        _safeNotifyListeners();
        _saveState();
        return;
      }
    }

    // Clear result tracking
    _correctCount = 0;
    _lastCorrectAnswers.clear();
    _lastSelectedAnswers.clear();
    _shuffleCount = 0;

    // CRITICAL: Reset power-up states between rounds to prevent state leakage
    // Clear selections, revealed words, and active power-ups
    _selectedAnswers.clear();
    _revealedWords.clear();
    _hintedWords.clear();

    // Reset active power-up flags (if any were active)
    _isTimeFrozen = false;
    _playTimeAtFreeze = null; // Clear time freeze state between rounds
    _hasDoubleScore = false;
    _hasStreakShield = false;

    // Defensive: Clear flip mode state between rounds (already cleared in startNewRound, but defensive here)
    _flipModeSelectedOrder.clear();
    _flipCurrentIndex = 0;

    // Clear precision mode error message between rounds
    _precisionError = null;

    // CRITICAL: Clamp round to prevent integer overflow (especially in marathon mode)
    // Marathon mode can run for many rounds, so protect against overflow
    final newRound = (_state.round + 1).clamp(1, GameConstants.maxRoundCount);
    _state = _state.copyWith(round: newRound);
    startNewRound(pool);
    _saveState();
  }

  // Save game state to SharedPreferences with retry logic
  Future<void> _saveState() async {
    // Prevent concurrent saves with mutex
    if (_isSaving) {
      if (kDebugMode) {
        debugPrint('State save already in progress, skipping concurrent save');
      }
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

          // CRITICAL: Prepare all state data before saving to ensure atomicity
          // This prevents partial saves where core state succeeds but extended state fails
          final stateJson = jsonEncode({
            'score': _state.score,
            'lives': _state.lives,
            'round': _state.round,
            'isGameOver': _state.isGameOver,
            'perfectStreak': _state.perfectStreak,
          });

          String? extendedStateJson;
          bool shouldClearExtendedState = false;

          // Prepare extended state (power-ups, competitive challenge, mode-specific)
          // Only save if game is in progress (not game over) to allow resume
          if (!_state.isGameOver) {
            extendedStateJson = jsonEncode({
              // Power-up uses (during active game)
              'revealAllUses': _revealAllUses,
              'clearUses': _clearUses,
              'skipUses': _skipUses,
              'streakShieldUses': _streakShieldUses,
              'timeFreezeUses': _timeFreezeUses,
              'hintUses': _hintUses,
              'doubleScoreUses': _doubleScoreUses,

              // Competitive challenge state
              'competitiveChallengeId': _competitiveChallengeId,
              'competitiveChallengeStartTime': _competitiveChallengeStartTime
                  ?.toIso8601String(),
              'competitiveChallengePauseTime': _competitiveChallengePauseTime
                  ?.toIso8601String(),
              'competitiveChallengePausedDuration':
                  _competitiveChallengePausedDuration,
              'competitiveChallengeTargetRounds':
                  _competitiveChallengeTargetRounds,
              'competitiveChallengeScoreSubmitted':
                  _competitiveChallengeScoreSubmitted,

              // Mode-specific state
              'currentMode': _currentMode.name,
              'streakMultiplier': _streakMultiplier,
              'survivalPerfectCount': _survivalPerfectCount,

              // Power-up active states (critical for resume)
              'isTimeFrozen': _isTimeFrozen,
              'hasDoubleScore': _hasDoubleScore,
              'hasStreakShield': _hasStreakShield,
              'playTimeAtFreeze':
                  _playTimeAtFreeze, // Time freeze state preservation
              // Session stats (for competitive challenge accuracy)
              'sessionCorrectAnswers': _sessionCorrectAnswers,
              'sessionWrongAnswers': _sessionWrongAnswers,

              // CRITICAL: Round-level state for full game resumption
              // Phase, trivia, words, timers, selections - all needed to resume mid-round
              'phase': _phase.name, // memorize, play, or result
              'currentTrivia': _currentTrivia
                  ?.toJson(), // Current trivia item (null if no active round)
              'shuffledWords': _shuffledWords, // Current shuffled word list
              'selectedAnswers': _selectedAnswers
                  .toList(), // Currently selected answers
              'revealedWords': _revealedWords
                  .toList(), // Words revealed by double-tap
              'memorizeTimeLeft': _memorizeTimeLeft, // Remaining memorize time
              'playTimeLeft': _playTimeLeft, // Remaining play time
              'timeAttackSecondsLeft':
                  _timeAttackSecondsLeft, // Time attack timer (null if not in time attack)
              // Trivia pool for continuing to next round
              'currentTriviaPool': _currentTriviaPool
                  .map((item) => item.toJson())
                  .toList(),

              // Flip mode state (if applicable)
              'flipModeSelectedOrder': _flipModeSelectedOrder,
              'flipCurrentIndex': _flipCurrentIndex,
              'flippedTiles': _flippedTiles,
              'hintedWords': _hintedWords
                  .toList(), // Words eliminated by hint power-up
              // Additional state
              'shuffleCount': _shuffleCount,
              'isShuffling': _isShuffling,
              'shuffleDifficulty': shuffleDifficulty,

              // Marathon mode duration tracking (critical for marathon mode limits)
              'gameStartTime': _gameStartTime?.toIso8601String(),
            });
          } else {
            // Mark extended state for removal when game is over
            shouldClearExtendedState = true;
          }

          // CRITICAL: Save core state first (most critical)
          // Core state must succeed for the save to be considered successful
          await prefs.setString(_storageKeyGameState, stateJson);

          // Save extended state (best-effort - failure doesn't fail entire save)
          // This ensures core state is always saved even if extended state fails
          if (extendedStateJson != null) {
            try {
              await prefs.setString(
                _storageKeyExtendedState,
                extendedStateJson,
              );
              // Reset consecutive extended state failure counter on success
              _consecutiveExtendedStateFailures = 0;
              _needsExtendedStateFailureNotification = false;
            } catch (extendedStateError) {
              // Track extended state save failures separately
              _consecutiveExtendedStateFailures++;

              // Log extended state save failure but don't fail entire save
              // Core state is more critical - extended state is best-effort
              if (kDebugMode) {
                debugPrint(
                  'Warning: Failed to save extended state (non-critical): $extendedStateError '
                  '($_consecutiveExtendedStateFailures consecutive failures)',
                );
              }

              // Notify user if persistent extended state failures detected
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
                _safeNotifyListeners(); // Notify UI to show warning

                // Track persistent extended state failures in analytics
                try {
                  unawaited(
                    _analyticsService?.logError(
                      'persistent_extended_state_save_failure',
                      'Extended state save failed. Consecutive failures: $_consecutiveExtendedStateFailures. Error: $extendedStateError',
                    ),
                  );
                } catch (e) {
                  // Analytics failure shouldn't block error handling
                  if (kDebugMode) {
                    debugPrint(
                      'Failed to log extended state failure analytics: $e',
                    );
                  }
                }
              } else {
                // Track single extended state failure for monitoring
                try {
                  unawaited(
                    _analyticsService?.logError(
                      'extended_state_save_failure',
                      'Extended state save failed. Consecutive failures: $_consecutiveExtendedStateFailures. Error: $extendedStateError',
                    ),
                  );
                } catch (e) {
                  // Analytics failure shouldn't block error handling
                  if (kDebugMode) {
                    debugPrint(
                      'Failed to log extended state failure analytics: $e',
                    );
                  }
                }
              }
              // Continue - core state is saved, which is the critical part
            }
          } else if (shouldClearExtendedState) {
            // Clear extended state when game is over
            // If removal fails, log but don't fail the entire save (extended state will be ignored on load)
            try {
              await prefs.remove(_storageKeyExtendedState);
            } catch (removeError) {
              if (kDebugMode) {
                debugPrint(
                  'Warning: Failed to remove extended state (non-critical): $removeError',
                );
              }
              // Continue - core state is saved, which is the critical part
            }
          }

          // CRITICAL: Reset consecutive failure counter on successful save
          _consecutiveSaveFailures = 0;

          // Track performance metrics
          final saveDuration = DateTime.now().difference(saveStartTime);
          try {
            unawaited(
              _analyticsService?.logGameStateSave(
                saveDuration,
                success: true,
                retryCount: attempt,
              ),
            );
          } catch (e) {
            // Analytics failure shouldn't block save success
            if (kDebugMode) {
              debugPrint('Failed to log save performance: $e');
            }
          }

          return; // Success - exit retry loop (core state saved, extended state is best-effort)
        } catch (e) {
          lastError = e.toString();
          if (kDebugMode) {
            debugPrint(
              'Failed to save game state (attempt ${attempt + 1}/$maxRetries): $e',
            );
          }

          // Retry with exponential backoff (except on last attempt)
          if (attempt < maxRetries - 1) {
            await Future.delayed(Duration(milliseconds: 100 * (1 << attempt)));
            continue;
          }
        }
      }

      // All retries failed - increment consecutive failure counter
      _consecutiveSaveFailures++;

      // CRITICAL: Notify user if persistent save failures detected
      if (_consecutiveSaveFailures >=
          GameConstants.maxConsecutiveSaveFailures) {
        if (kDebugMode) {
          debugPrint(
            '⚠️ CRITICAL: Persistent save failures detected ($_consecutiveSaveFailures consecutive failures). '
            'Game state may not be saved. User should be notified.',
          );
        }
        // Store notification flag in service for UI to check
        _needsSaveFailureNotification = true;
        _safeNotifyListeners(); // Notify UI to show warning

        // Track persistent save failures in analytics for monitoring
        try {
          unawaited(
            _analyticsService?.logError(
              'persistent_save_failure',
              'Core state save failed after $maxRetries attempts. Consecutive failures: $_consecutiveSaveFailures. Error: $lastError',
            ),
          );
        } catch (e) {
          // Analytics failure shouldn't block error handling
          if (kDebugMode) {
            debugPrint('Failed to log save failure analytics: $e');
          }
        }
      } else {
        // Track single save failure (non-persistent) for monitoring
        try {
          unawaited(
            _analyticsService?.logError(
              'save_failure',
              'Game state save failed (attempt $maxRetries/$maxRetries). Consecutive failures: $_consecutiveSaveFailures. Error: $lastError',
            ),
          );
        } catch (e) {
          // Analytics failure shouldn't block error handling
          if (kDebugMode) {
            debugPrint('Failed to log save failure analytics: $e');
          }
        }
      }

      // All retries failed - log final error
      if (kDebugMode) {
        debugPrint(
          '⚠️ Warning: Failed to save game state after $maxRetries attempts. Last error: $lastError',
        );
        debugPrint('   Game state may be lost if app crashes.');
        if (_consecutiveSaveFailures >=
            GameConstants.maxConsecutiveSaveFailures) {
          debugPrint(
            '   Persistent failure detected - user notification should be displayed.',
          );
        }
      }

      // Log to Crashlytics for production monitoring
      try {
        await FirebaseCrashlytics.instance.recordError(
          Exception('Game state save failed: $lastError'),
          StackTrace.current,
          reason: 'Failed to save game state after $maxRetries retries',
          fatal: false,
        );
      } catch (e) {
        // Ignore Crashlytics errors - not critical
        if (kDebugMode) {
          debugPrint(
            'Failed to log game state save failure to Crashlytics: $e',
          );
        }
      }

      // Track performance metrics even on failure
      final saveDuration = DateTime.now().difference(saveStartTime);
      try {
        unawaited(
          _analyticsService?.logGameStateSave(
            saveDuration,
            success: false,
            retryCount: maxRetries,
          ),
        );
      } catch (e) {
        // Analytics failure shouldn't block error handling
        if (kDebugMode) {
          debugPrint('Failed to log save failure performance: $e');
        }
      }
    } finally {
      _isSaving = false; // Always reset flag
    }
  }

  // Load game state from SharedPreferences
  Future<void> loadState() async {
    // CRITICAL: Prevent concurrent loadState calls to avoid state corruption
    if (_isLoadingState) {
      if (kDebugMode) {
        debugPrint(
          'State loading already in progress, skipping duplicate call',
        );
      }
      return;
    }

    _isLoadingState = true;
    final loadStartTime = DateTime.now();
    bool loadSuccess = false;
    try {
      // CRITICAL: Cancel ALL existing timers before state restoration
      // This prevents duplicate timers if loadState is called while game is in progress
      _memorizeTimer?.cancel();
      _playTimer?.cancel();
      _shuffleTimer?.cancel();
      _timeAttackTimer?.cancel();
      _timeFreezeTimer?.cancel();
      _flipInitialTimer?.cancel();
      _flipPeriodicTimer?.cancel();
      _cancelPendingNextRoundDelay();

      // Clear timer references to prevent stale callbacks
      _memorizeTimer = null;
      _playTimer = null;
      _shuffleTimer = null;
      _timeAttackTimer = null;
      _timeFreezeTimer = null;
      _flipInitialTimer = null;
      _flipPeriodicTimer = null;

      final prefs = await _getPrefs();
      final stateJson = prefs.getString(_storageKeyGameState);

      if (stateJson != null) {
        final stateMap = jsonDecode(stateJson) as Map<String, dynamic>;

        // CRITICAL: Validate and sanitize loaded core state values
        // This prevents corrupted storage from creating invalid game states
        final loadedScore = (stateMap['score'] as int? ?? 0).clamp(
          0,
          GameConstants.maxLoadedScore,
        );
        final loadedLives = (stateMap['lives'] as int? ?? 3).clamp(0, GameConstants.maxLives);
        final loadedRound = (stateMap['round'] as int? ?? 1).clamp(1, GameConstants.maxRoundCount);
        final loadedPerfectStreak = (stateMap['perfectStreak'] as int? ?? 0)
            .clamp(0, GameConstants.maxPerfectStreak);
        final loadedIsGameOver = stateMap['isGameOver'] as bool? ?? false;

        // CRITICAL: Validate state consistency
        // If lives <= 0, game must be over (enforce consistency)
        final isGameOver = loadedIsGameOver || loadedLives <= 0;

        _state = GameState(
          score: loadedScore,
          lives: loadedLives,
          round: loadedRound,
          isGameOver: isGameOver, // Enforce consistency
          perfectStreak: loadedPerfectStreak,
        );

        // Load extended state if game is in progress
        if (!_state.isGameOver) {
          final extendedStateJson = prefs.getString(_storageKeyExtendedState);
          if (extendedStateJson != null) {
            try {
              final extendedStateMap =
                  jsonDecode(extendedStateJson) as Map<String, dynamic>;

              // Restore power-up uses with validation to prevent corrupted values
              // Clamp values to reasonable ranges (0-999) to handle storage corruption
              _revealAllUses = (extendedStateMap['revealAllUses'] as int? ?? 3)
                  .clamp(0, 999);
              _clearUses = (extendedStateMap['clearUses'] as int? ?? 3).clamp(
                0,
                999,
              );
              _skipUses = (extendedStateMap['skipUses'] as int? ?? 3).clamp(
                0,
                999,
              );
              _streakShieldUses =
                  (extendedStateMap['streakShieldUses'] as int? ?? 0).clamp(
                    0,
                    999,
                  );
              _timeFreezeUses =
                  (extendedStateMap['timeFreezeUses'] as int? ?? 0).clamp(
                    0,
                    999,
                  );
              _hintUses = (extendedStateMap['hintUses'] as int? ?? 0).clamp(
                0,
                999,
              );
              _doubleScoreUses =
                  (extendedStateMap['doubleScoreUses'] as int? ?? 0).clamp(
                    0,
                    999,
                  );

              // Restore competitive challenge state
              _competitiveChallengeId =
                  extendedStateMap['competitiveChallengeId'] as String?;

              // CRITICAL: Validate competitive challenge state consistency
              // If challenge ID exists, start time should exist (validate consistency)
              if (_competitiveChallengeId != null &&
                  _competitiveChallengeId!.isNotEmpty) {
                // CRITICAL: Add exception handling for DateTime.parse() to prevent crashes
                // from corrupted or malformed ISO8601 strings
                if (extendedStateMap['competitiveChallengeStartTime'] != null) {
                  try {
                    final parsedTime = DateTime.parse(
                      extendedStateMap['competitiveChallengeStartTime']
                          as String,
                    );
                    final now = DateTime.now();
                    // CRITICAL: Validate date is within reasonable bounds (not too far in past or future)
                    // Prevents corrupted storage from creating invalid challenge submissions
                    // Allow 1 hour future tolerance for clock drift, 30 days past tolerance for reasonable gameplay
                    final maxPastTime = now.subtract(const Duration(days: 30));
                    if (parsedTime.isAfter(now.add(const Duration(hours: 1)))) {
                      // Future date (beyond 1 hour tolerance)
                      if (kDebugMode) {
                        debugPrint(
                          '⚠️ Warning: Invalid competitiveChallengeStartTime (future date beyond tolerance) - resetting',
                        );
                      }
                      _competitiveChallengeStartTime = null;
                      // Clear invalid challenge state
                      _competitiveChallengeId = null;
                    } else if (parsedTime.isBefore(maxPastTime)) {
                      // Too far in the past (older than 30 days)
                      if (kDebugMode) {
                        debugPrint(
                          '⚠️ Warning: Invalid competitiveChallengeStartTime (too old, >30 days) - resetting',
                        );
                      }
                      _competitiveChallengeStartTime = null;
                      // Clear invalid challenge state
                      _competitiveChallengeId = null;
                    } else {
                      // Valid date range
                      _competitiveChallengeStartTime = parsedTime;
                    }
                  } on FormatException catch (e) {
                    if (kDebugMode) {
                      debugPrint(
                        'Invalid date format for competitiveChallengeStartTime: $e',
                      );
                    }
                    // Set to null on parse failure - challenge will need to be restarted
                    _competitiveChallengeStartTime = null;
                    // Clear invalid challenge state
                    _competitiveChallengeId = null;
                  }
                } else {
                  // Challenge ID exists but start time is missing - invalid state
                  if (kDebugMode) {
                    debugPrint(
                      'Warning: Competitive challenge ID exists but start time is missing - clearing challenge state',
                    );
                  }
                  // Clear invalid challenge state
                  _competitiveChallengeId = null;
                  _competitiveChallengeStartTime = null;
                }
              } else {
                // No challenge ID - ensure all challenge state is cleared
                _competitiveChallengeStartTime = null;
              }

              if (extendedStateMap['competitiveChallengePauseTime'] != null) {
                try {
                  _competitiveChallengePauseTime = DateTime.parse(
                    extendedStateMap['competitiveChallengePauseTime'] as String,
                  );
                } on FormatException catch (e) {
                  if (kDebugMode) {
                    debugPrint(
                      'Invalid date format for competitiveChallengePauseTime: $e',
                    );
                  }
                  // Set to null on parse failure - pause tracking will reset
                  _competitiveChallengePauseTime = null;
                }
              }
              // Validate competitive challenge duration (should be non-negative)
              _competitiveChallengePausedDuration =
                  (extendedStateMap['competitiveChallengePausedDuration']
                              as int? ??
                          0)
                      .clamp(0, 86400); // Max 24 hours (86400 seconds)

              // Validate target rounds (should be 1-100)
              final targetRounds =
                  extendedStateMap['competitiveChallengeTargetRounds'] as int?;
              _competitiveChallengeTargetRounds =
                  targetRounds != null &&
                      targetRounds > 0 &&
                      targetRounds <= 100
                  ? targetRounds
                  : null;

              _competitiveChallengeScoreSubmitted =
                  extendedStateMap['competitiveChallengeScoreSubmitted']
                      as bool? ??
                  false;

              // CRITICAL: Validate submission flag consistency
              // If score is marked as submitted but no challenge ID, reset flag
              if (_competitiveChallengeScoreSubmitted &&
                  (_competitiveChallengeId == null ||
                      _competitiveChallengeId!.isEmpty)) {
                if (kDebugMode) {
                  debugPrint(
                    'Warning: Score submitted flag is true but no challenge ID - resetting flag',
                  );
                }
                _competitiveChallengeScoreSubmitted = false;
              }

              // Restore mode-specific state
              final modeString = extendedStateMap['currentMode'] as String?;
              if (modeString != null) {
                try {
                  _currentMode = GameMode.values.firstWhere(
                    (mode) => mode.name == modeString,
                    orElse: () => GameMode.classic,
                  );
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint('Failed to restore game mode: $e');
                  }
                  // Keep default mode
                }
              }
              // Validate mode-specific state with reasonable ranges
              _streakMultiplier =
                  (extendedStateMap['streakMultiplier'] as int? ?? 1).clamp(
                    1,
                    5,
                  ); // Streak multiplier should be 1-5x (matches runtime max at line 3213)

              // CRITICAL: Reset streak multiplier if not in streak mode (state consistency)
              if (_currentMode != GameMode.streak) {
                _streakMultiplier = 1;
              }

              _survivalPerfectCount =
                  (extendedStateMap['survivalPerfectCount'] as int? ?? 0).clamp(
                    0,
                    999,
                  ); // Survival perfect count should be reasonable

              // CRITICAL: Reset survival perfect count if not in survival mode (state consistency)
              if (_currentMode != GameMode.survival) {
                _survivalPerfectCount = 0;
              }

              // Restore power-up active states (critical for resume)
              _isTimeFrozen =
                  extendedStateMap['isTimeFrozen'] as bool? ?? false;
              _hasDoubleScore =
                  extendedStateMap['hasDoubleScore'] as bool? ?? false;
              _hasStreakShield =
                  extendedStateMap['hasStreakShield'] as bool? ?? false;
              _playTimeAtFreeze = extendedStateMap['playTimeAtFreeze'] as int?;

              // CRITICAL: Validate playTimeAtFreeze doesn't exceed mode's configured playTime
              // This prevents corrupted saved state from giving excessive time when resuming
              if (_playTimeAtFreeze != null && _currentTrivia != null) {
                final config = ModeConfig.getConfig(
                  _currentMode,
                  round: _state.round,
                );
                if (_playTimeAtFreeze! > config.playTime) {
                  if (kDebugMode) {
                    debugPrint(
                      '⚠️ Warning: playTimeAtFreeze ($_playTimeAtFreeze) exceeds mode playTime (${config.playTime}) for ${_currentMode.name} mode - clamping',
                    );
                  }
                  _playTimeAtFreeze = config.playTime.clamp(0, 999);
                }
              }

              // Restore session stats with validation (should be non-negative)
              _sessionCorrectAnswers =
                  (extendedStateMap['sessionCorrectAnswers'] as int? ?? 0)
                      .clamp(0, GameConstants.maxSessionAnswers);
              _sessionWrongAnswers =
                  (extendedStateMap['sessionWrongAnswers'] as int? ?? 0).clamp(
                    0,
                    GameConstants.maxSessionAnswers,
                  );

              // CRITICAL: Restore round-level state for full game resumption
              // Restore phase
              final phaseString = extendedStateMap['phase'] as String?;
              if (phaseString != null) {
                try {
                  _phase = GamePhase.values.firstWhere(
                    (phase) => phase.name == phaseString,
                    orElse: () => GamePhase.memorize,
                  );
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint('Failed to restore phase: $e');
                  }
                  _phase = GamePhase.memorize; // Default fallback
                }
              }

              // Restore current trivia item
              final currentTriviaJson = extendedStateMap['currentTrivia'];
              if (currentTriviaJson != null) {
                try {
                  _currentTrivia = TriviaItem.fromJson(
                    currentTriviaJson as Map<String, dynamic>,
                  );
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint('Failed to restore current trivia: $e');
                  }
                  _currentTrivia = null; // Clear if restoration fails
                }
              }

              // Restore shuffled words and rebuild map
              final shuffledWordsList = extendedStateMap['shuffledWords'];
              if (shuffledWordsList != null) {
                try {
                  _shuffledWords = List<String>.from(shuffledWordsList as List);
                  // CRITICAL: Filter empty/whitespace strings to maintain size consistency with map
                  _shuffledWords = _shuffledWords
                      .where((word) => word.trim().isNotEmpty)
                      .toList();
                  // Rebuild shuffledWordsMap for O(1) lookups
                  // Both list and map now have the same length, ensuring index consistency
                  _shuffledWordsMap = {
                    for (int i = 0; i < _shuffledWords.length; i++)
                      _shuffledWords[i]: i,
                  };
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint('Failed to restore shuffled words: $e');
                  }
                  _shuffledWords = [];
                  _shuffledWordsMap = {};
                }
              }

              // Restore selected and revealed words
              final selectedAnswersList = extendedStateMap['selectedAnswers'];
              if (selectedAnswersList != null) {
                try {
                  _selectedAnswers.clear();
                  _selectedAnswers.addAll(
                    List<String>.from(selectedAnswersList as List),
                  );
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint('Failed to restore selected answers: $e');
                  }
                  _selectedAnswers.clear();
                }
              }

              final revealedWordsList = extendedStateMap['revealedWords'];
              if (revealedWordsList != null) {
                try {
                  _revealedWords.clear();
                  _revealedWords.addAll(
                    List<String>.from(revealedWordsList as List),
                  );
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint('Failed to restore revealed words: $e');
                  }
                  _revealedWords.clear();
                }
              }

              // Restore timer states
              _memorizeTimeLeft =
                  (extendedStateMap['memorizeTimeLeft'] as int? ?? 10).clamp(
                    0,
                    999,
                  );
              _playTimeLeft = (extendedStateMap['playTimeLeft'] as int? ?? 20)
                  .clamp(0, 999);

              // Restore time attack timer
              final timeAttackSecondsLeft =
                  extendedStateMap['timeAttackSecondsLeft'];
              _timeAttackSecondsLeft = timeAttackSecondsLeft != null
                  ? (timeAttackSecondsLeft as int).clamp(0, GameConstants.maxTimeSeconds)
                  : null;

              // Restore trivia pool
              final triviaPoolList = extendedStateMap['currentTriviaPool'];
              if (triviaPoolList != null) {
                try {
                  _currentTriviaPool = (triviaPoolList as List)
                      .map(
                        (item) =>
                            TriviaItem.fromJson(item as Map<String, dynamic>),
                      )
                      .toList();
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint('Failed to restore trivia pool: $e');
                  }
                  _currentTriviaPool = []; // Clear if restoration fails
                }
              }

              // Restore flip mode state
              final flipModeSelectedOrderList =
                  extendedStateMap['flipModeSelectedOrder'];
              if (flipModeSelectedOrderList != null) {
                try {
                  _flipModeSelectedOrder.clear();
                  _flipModeSelectedOrder.addAll(
                    List<String>.from(flipModeSelectedOrderList as List),
                  );
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint(
                      'Failed to restore flip mode selected order: $e',
                    );
                  }
                  _flipModeSelectedOrder.clear();
                }
              }

              _flipCurrentIndex =
                  (extendedStateMap['flipCurrentIndex'] as int? ?? 0).clamp(
                    0,
                    999,
                  );

              // CRITICAL: Validate flip current index is within flippedTiles bounds
              // This prevents index out of bounds errors when resuming flip mode
              if (_flippedTiles.isNotEmpty &&
                  _flipCurrentIndex >= _flippedTiles.length) {
                if (kDebugMode) {
                  debugPrint(
                    '⚠️ Warning: Flip current index $_flipCurrentIndex exceeds flippedTiles length ${_flippedTiles.length}. Resetting to 0.',
                  );
                }
                _flipCurrentIndex = 0;
              }

              final flippedTilesList = extendedStateMap['flippedTiles'];
              if (flippedTilesList != null) {
                try {
                  _flippedTiles = List<bool>.from(flippedTilesList as List);
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint('Failed to restore flipped tiles: $e');
                  }
                  _flippedTiles = [];
                }
              }

              final hintedWordsList = extendedStateMap['hintedWords'];
              if (hintedWordsList != null) {
                try {
                  _hintedWords.clear();
                  _hintedWords.addAll(
                    List<String>.from(hintedWordsList as List),
                  );
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint('Failed to restore hinted words: $e');
                  }
                  _hintedWords.clear();
                }
              }

              // Restore shuffle state
              _shuffleCount = (extendedStateMap['shuffleCount'] as int? ?? 0)
                  .clamp(0, GameConstants.maxShuffleCount);
              _isShuffling = extendedStateMap['isShuffling'] as bool? ?? false;

              // Restore shuffle difficulty
              final shuffleDifficultyString =
                  extendedStateMap['shuffleDifficulty'] as String?;
              if (shuffleDifficultyString != null &&
                  [
                    'easy',
                    'medium',
                    'hard',
                    'insane',
                  ].contains(shuffleDifficultyString)) {
                shuffleDifficulty = shuffleDifficultyString;
              }

              // Restore marathon mode start time (critical for duration tracking)
              final gameStartTimeStr =
                  extendedStateMap['gameStartTime'] as String?;
              if (gameStartTimeStr != null) {
                try {
                  final parsedTime = DateTime.parse(gameStartTimeStr);
                  // CRITICAL: Validate not in future (within 1 hour tolerance for clock drift)
                  // This prevents corrupted state from causing marathon mode to never end
                  if (parsedTime.isBefore(
                    DateTime.now().add(const Duration(hours: 1)),
                  )) {
                    _gameStartTime = parsedTime;
                  } else {
                    if (kDebugMode) {
                      debugPrint(
                        '⚠️ Warning: Invalid gameStartTime (future date) - resetting',
                      );
                    }
                    _gameStartTime = null;
                  }
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint('Failed to restore game start time: $e');
                  }
                  _gameStartTime = null; // Reset if corrupted or invalid
                }
              } else {
                _gameStartTime = null;
              }

              // CRITICAL: Validate state consistency after restoration
              // This ensures restored state is valid and prevents crashes
              _validateRestoredState();

              // CRITICAL: Resume gameplay after state restoration
              // Restart timers and continue gameplay from restored state
              _resumeGameplayAfterStateLoad();
            } catch (e) {
              if (kDebugMode) {
                debugPrint('Failed to load extended game state: $e');
              }
              // Continue with defaults if extended state fails to load
            }
          }
        }

        _safeNotifyListeners();
        loadSuccess = true;
      }

      // Load flip reveal mode setting
      await _loadFlipRevealMode();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to load game state: $e');
      }
      // Continue with default state if loading fails
      // Still try to load flip reveal mode
      await _loadFlipRevealMode();
      loadSuccess = false;
    } finally {
      _isLoadingState = false; // Always reset mutex flag

      // Track performance metrics
      final loadDuration = DateTime.now().difference(loadStartTime);
      try {
        unawaited(
          _analyticsService?.logGameStateLoad(
            loadDuration,
            success: loadSuccess,
          ),
        );
      } catch (e) {
        // Analytics failure shouldn't block state loading
        if (kDebugMode) {
          debugPrint('Failed to log load performance: $e');
        }
      }
    }
  }

  // Reset game state
  Future<void> resetGame() async {
    _memorizeTimer?.cancel();
    _playTimer?.cancel();
    _timeAttackTimer?.cancel();
    _shuffleTimer?.cancel();
    _flipInitialTimer?.cancel();
    _flipPeriodicTimer?.cancel();
    _timeFreezeTimer?.cancel();

    // Clear time freeze state
    _playTimeAtFreeze = null;
    _isTimeFrozen = false;

    _state = GameState(score: 0, lives: 3, round: 1, isGameOver: false);
    _currentTrivia = null;
    _shuffledWords = [];
    _shuffledWordsMap.clear(); // Clear map on reset
    _selectedAnswers.clear();
    _correctCount = 0;
    _lastCorrectAnswers.clear();
    _lastSelectedAnswers.clear();
    _phase = GamePhase.memorize;
    _memorizeTimeLeft = 10;
    _playTimeLeft = 20;
    _timeAttackSecondsLeft = 60;

    // Reset session stats (critical for competitive challenge accuracy)
    _sessionCorrectAnswers = 0;
    _sessionWrongAnswers = 0;

    // CRITICAL: Clear marathon mode start time on game reset
    // This ensures marathon tracking doesn't persist across game resets
    _gameStartTime = null;

    // Reset competitive challenge tracking
    _competitiveChallengeId = null;
    _competitiveChallengeStartTime = null;
    _competitiveChallengePauseTime = null;
    _competitiveChallengePausedDuration = 0;
    _competitiveChallengeTargetRounds = null;
    _competitiveChallengeScoreSubmitted = false;

    // Reset submission flag and saving flag
    _isSubmitting = false;
    _isSaving = false;

    // Reset power-up flags and uses
    _hasDoubleScore = false;
    _hasStreakShield = false;
    _hintedWords.clear();
    _revealedWords.clear();
    _revealAllUses = 3;
    _clearUses = 3;
    _skipUses = 3;
    _streakShieldUses = 0;
    _timeFreezeUses = 0;
    _hintUses = 0;
    _doubleScoreUses = 0;

    // Reset mode-specific state
    _streakMultiplier = 1;
    _survivalPerfectCount = 0;
    _shuffleCount = 0;

    // Reset Flip Mode state
    _flipModeSelectedOrder.clear();
    _flipCurrentIndex = 0;
    _flippedTiles = [];

    // Reset precision mode error
    _precisionError = null;

    // Clear recent trivia categories (fresh start for new game)
    _recentTriviaCategories.clear();

    try {
      final prefs = await _getPrefs();
      await prefs.remove(_storageKeyGameState);
      await prefs.remove(_storageKeyExtendedState); // Also clear extended state
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to clear game state: $e');
      }
    }

    _safeNotifyListeners();
  }

  // Pause game when app goes to background
  void pauseGame() {
    _memorizeTimer?.cancel();
    _playTimer?.cancel();
    _shuffleTimer?.cancel();
    _timeAttackTimer?.cancel();
    _timeFreezeTimer?.cancel(); // Cancel time freeze timer on pause
    _flipInitialTimer?.cancel(); // Cancel flip timers on pause
    _flipPeriodicTimer?.cancel();

    // Track pause time for competitive challenges
    if (_competitiveChallengeId != null &&
        _competitiveChallengeStartTime != null) {
      // CRITICAL: Use UTC for consistency with start time (UTC)
      _competitiveChallengePauseTime = DateTime.now().toUtc();
    }

    _saveState();
    _safeNotifyListeners();
  }

  // Resume game when app comes to foreground
  void resumeGame() {
    // Track resume time for competitive challenges
    // Only accumulate pause duration if game was actually paused
    if (_competitiveChallengeId != null &&
        _competitiveChallengePauseTime != null) {
      // CRITICAL: Use UTC for consistency with pause time (UTC)
      final pauseDuration = DateTime.now()
          .toUtc()
          .difference(_competitiveChallengePauseTime!.toUtc())
          .inSeconds;
      // Protect against negative values (system clock changes backwards)
      if (pauseDuration > 0) {
        // CRITICAL: Clamp paused duration to prevent unbounded growth (max 10000 seconds ~2.7 hours)
        // This prevents edge cases where pause/resume cycles could accumulate excessive time
        _competitiveChallengePausedDuration =
            (_competitiveChallengePausedDuration + pauseDuration).clamp(
              0,
              10000,
            );
      }
      _competitiveChallengePauseTime = null;
    }
    // If resume is called without pause, _competitiveChallengePauseTime will be null
    // and no pause duration will be accumulated (correct behavior)

    if (_phase == GamePhase.memorize && _memorizeTimeLeft > 0) {
      // Resume memorize phase
      // Cancel any existing memorize timer to prevent leaks
      _memorizeTimer?.cancel();
      _memorizeTimer = null;

      // CRITICAL: Restart flip sequence if in flip mode (tiles were flipping during memorize)
      if (_currentMode == GameMode.flip && currentConfig.enableFlip) {
        // Validate flip current index is within bounds
        if (_flipCurrentIndex < 0 ||
            _flipCurrentIndex >= _flippedTiles.length) {
          if (kDebugMode) {
            debugPrint(
              '⚠️ Warning: Flip current index out of bounds on resume. Resetting to 0.',
            );
          }
          _flipCurrentIndex = 0;
        }
        _startFlipSequence();
      }

      _memorizeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_disposed) {
          timer.cancel();
          return;
        }
        // CRITICAL: Clamp memorize time to prevent negative values (defensive programming)
        _memorizeTimeLeft = (_memorizeTimeLeft - 1).clamp(0, 999);
        _safeNotifyListeners();
        if (_memorizeTimeLeft <= 0) {
          timer.cancel();
          if (_disposed) return;
          _phase = GamePhase.play;
          _safeNotifyListeners();
          _startPlayTimer();
        }
      });
    } else if (_phase == GamePhase.play && _playTimeLeft > 0) {
      // Resume play phase
      // CRITICAL: Restore time freeze state - if time was frozen, don't start timer yet
      if (_isTimeFrozen) {
        // Time freeze was active - timer should remain paused
        // The time freeze timer will handle unfreezing
        // But we need to ensure playTimeLeft is restored from _playTimeAtFreeze if available
        if (_playTimeAtFreeze != null) {
          _playTimeLeft = _playTimeAtFreeze!;
        } else {
          // CRITICAL: Corrupted state - time frozen but playTimeAtFreeze is null
          // Reset time freeze state to prevent inconsistent state
          if (kDebugMode) {
            debugPrint(
              '⚠️ Warning: Time frozen but playTimeAtFreeze is null - resetting freeze state',
            );
          }
          _isTimeFrozen = false;
          _playTimeAtFreeze = null;
          // Start play timer normally since freeze state is invalid
          _startPlayTimer();
        }
      } else {
        // Normal resume - start play timer
        _startPlayTimer();
      }

      if (currentConfig.enableShuffle && _currentMode == GameMode.shuffle) {
        _startShuffleSequence();
      }
      _safeNotifyListeners();
    } else if (_currentMode == GameMode.timeAttack &&
        _timeAttackSecondsLeft != null &&
        _timeAttackSecondsLeft! > 0) {
      // Resume time attack
      // Cancel any existing time attack timer to prevent leaks
      _timeAttackTimer?.cancel();
      _timeAttackTimer = null;
      _timeAttackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_timeAttackSecondsLeft != null && _timeAttackSecondsLeft! > 0) {
          // CRITICAL: Clamp time attack seconds to prevent negative values (defensive programming)
          _timeAttackSecondsLeft = (_timeAttackSecondsLeft! - 1).clamp(0, GameConstants.maxTimeSeconds);
          _safeNotifyListeners();
        } else {
          timer.cancel();
          if (!_disposed) {
            // CRITICAL: Check if submission is in progress before ending game
            // This prevents race condition where timer expires during answer submission
            // If submission is active, let it complete before ending the game
            if (!_isSubmitting) {
              _state = _state.copyWith(isGameOver: true);
              unawaited(submitCompetitiveChallengeScore());
              _safeNotifyListeners();
            } else {
              // Submission in progress - will end after submission completes (handled in finally block)
              if (kDebugMode) {
                debugPrint(
                  'Time attack timer expired during submission - will end game after submission completes',
                );
              }
            }
          }
        }
      });
    }
    _safeNotifyListeners();
  }

  /// Cancel any pending nextRound delay to prevent memory leaks and race conditions
  void _cancelPendingNextRoundDelay() {
    _pendingNextRoundDelay =
        null; // Cancel by clearing reference (prevents execution if pending)
  }

  /// Validate restored state for consistency
  /// Ensures all restored state is valid and prevents crashes from corrupted data
  void _validateRestoredState() {
    // Validate current trivia and shuffled words consistency
    if (_currentTrivia != null && _shuffledWords.isNotEmpty) {
      final triviaWords = Set<String>.from(
        _currentTrivia!.words.map((w) => w.trim().toLowerCase()),
      );
      final shuffledWordsSet = Set<String>.from(
        _shuffledWords.map((w) => w.trim().toLowerCase()),
      );

      // CRITICAL: Validate shuffled words match trivia words
      // If they don't match, reset shuffled words to prevent state corruption
      if (!triviaWords.containsAll(shuffledWordsSet) ||
          !shuffledWordsSet.containsAll(triviaWords)) {
        if (kDebugMode) {
          debugPrint(
            '⚠️ Warning: Shuffled words do not match trivia - resetting shuffled words',
          );
        }
        // Reset to safe state - regenerate shuffled words from trivia
        _shuffledWords = List.from(_currentTrivia!.words);
        _shuffledWords.shuffle(_random);
        // CRITICAL: Filter empty/whitespace strings to maintain size consistency with map
        _shuffledWords = _shuffledWords
            .where((word) => word.trim().isNotEmpty)
            .toList();
        // Rebuild shuffledWordsMap for O(1) lookups
        // Both list and map now have the same length, ensuring index consistency
        _shuffledWordsMap = {
          for (int i = 0; i < _shuffledWords.length; i++) _shuffledWords[i]: i,
        };
      }

      // CRITICAL: Validate flipped tiles length matches shuffled words
      // Prevents index out of bounds errors in flip mode
      if (_flippedTiles.length != _shuffledWords.length) {
        if (kDebugMode) {
          debugPrint(
            '⚠️ Warning: Flipped tiles length (${_flippedTiles.length}) does not match shuffled words length (${_shuffledWords.length}) - resetting',
          );
        }
        // Reset flipped tiles to match shuffled words
        _flippedTiles = List.filled(_shuffledWords.length, false);
        _flipCurrentIndex = 0;
      }

      // CRITICAL: Validate flipCurrentIndex is within bounds
      if (_flipCurrentIndex < 0 || _flipCurrentIndex >= _flippedTiles.length) {
        if (kDebugMode) {
          debugPrint(
            '⚠️ Warning: Flip current index ($_flipCurrentIndex) is out of bounds (0-${_flippedTiles.length - 1}) - resetting',
          );
        }
        _flipCurrentIndex = 0;
      }

      // CRITICAL: Validate selected answers contain only valid words
      // Remove any selected words that don't exist in shuffled words
      final invalidSelected = _selectedAnswers
          .where(
            (word) => !shuffledWordsSet.contains(word.trim().toLowerCase()),
          )
          .toList();
      if (invalidSelected.isNotEmpty) {
        if (kDebugMode) {
          debugPrint(
            '⚠️ Warning: Removing ${invalidSelected.length} invalid selected answers: $invalidSelected',
          );
        }
        _selectedAnswers.removeAll(invalidSelected);
      }

      // CRITICAL: Validate revealed words contain only valid words
      // Remove any revealed words that don't exist in shuffled words
      final invalidRevealed = _revealedWords
          .where(
            (word) => !shuffledWordsSet.contains(word.trim().toLowerCase()),
          )
          .toList();
      if (invalidRevealed.isNotEmpty) {
        if (kDebugMode) {
          debugPrint(
            '⚠️ Warning: Removing ${invalidRevealed.length} invalid revealed words: $invalidRevealed',
          );
        }
        _revealedWords.removeAll(invalidRevealed);
      }

      // CRITICAL: Validate hinted words contain only valid words
      final invalidHinted = _hintedWords
          .where(
            (word) => !shuffledWordsSet.contains(word.trim().toLowerCase()),
          )
          .toList();
      if (invalidHinted.isNotEmpty) {
        if (kDebugMode) {
          debugPrint(
            '⚠️ Warning: Removing ${invalidHinted.length} invalid hinted words: $invalidHinted',
          );
        }
        _hintedWords.removeWhere((word) => invalidHinted.contains(word));
      }

      // CRITICAL: Validate flip mode selected order contains only valid words
      final invalidFlipOrder = _flipModeSelectedOrder
          .where(
            (word) => !shuffledWordsSet.contains(word.trim().toLowerCase()),
          )
          .toList();
      if (invalidFlipOrder.isNotEmpty) {
        if (kDebugMode) {
          debugPrint(
            '⚠️ Warning: Removing ${invalidFlipOrder.length} invalid flip mode selected order words: $invalidFlipOrder',
          );
        }
        _flipModeSelectedOrder.removeWhere(
          (word) => invalidFlipOrder.contains(word),
        );
      }
    } else if (_currentTrivia == null && _shuffledWords.isNotEmpty) {
      // Current trivia is null but shuffled words exist - clear shuffled words
      if (kDebugMode) {
        debugPrint(
          '⚠️ Warning: Current trivia is null but shuffled words exist - clearing shuffled words',
        );
      }
      _shuffledWords = [];
      _shuffledWordsMap = {};
      _selectedAnswers.clear();
      _revealedWords.clear();
      _hintedWords.clear();
      _flipModeSelectedOrder.clear();
      _flippedTiles = [];
      _flipCurrentIndex = 0;
    }

    // CRITICAL: Validate trivia pool is non-empty if game is in progress
    // If trivia pool is empty, game cannot continue to next round
    if (_currentTriviaPool.isEmpty && !_state.isGameOver) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ Warning: Trivia pool exhausted - marking game as over. Game mode: $_currentMode, Round: ${_state.round}',
        );
        // Log to Crashlytics for tracking trivia exhaustion issues
        try {
          FirebaseCrashlytics.instance.log(
            'Trivia pool exhausted during gameplay - mode: $_currentMode, round: ${_state.round}',
          );
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Failed to log trivia exhaustion to Crashlytics: $e');
          }
        }
      }
      _state = _state.copyWith(isGameOver: true);
    }

    // CRITICAL: Validate phase consistency
    // If play time is 0 and phase is play, should be result phase
    if (_phase == GamePhase.play && _playTimeLeft <= 0) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ Warning: Phase is play but play time is 0 - transitioning to result phase',
        );
      }
      _phase = GamePhase.result;
    }

    // CRITICAL: Validate memorize time consistency
    // If memorize time is 0 and phase is memorize, should transition to play
    if (_phase == GamePhase.memorize && _memorizeTimeLeft <= 0) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ Warning: Phase is memorize but memorize time is 0 - transitioning to play phase',
        );
      }
      _phase = GamePhase.play;
    }

    // CRITICAL: Validate shuffle state consistency
    // If not shuffling, shuffle count should be reasonable
    if (!_isShuffling && _shuffleCount > 0) {
      // This is OK - shuffle count persists after shuffle stops
      // But if shuffle count is unreasonably high, reset it
      // CRITICAL: Use constant for consistency
      if (_shuffleCount > GameConstants.maxShuffleCount) {
        if (kDebugMode) {
          debugPrint(
            '⚠️ Warning: Shuffle count ($_shuffleCount) is unreasonably high - resetting',
          );
        }
        _shuffleCount = 0;
      }
    }
  }

  /// Resume gameplay after state restoration
  /// Restarts timers and continues gameplay from the restored state
  void _resumeGameplayAfterStateLoad() {
    // Only resume if game is in progress and not game over
    if (_state.isGameOver) return;

    final config = ModeConfig.getConfig(_currentMode, round: _state.round);

    // Resume based on current phase
    if (_phase == GamePhase.memorize) {
      // Resume memorize phase - restart memorize timer if time remaining
      if (_memorizeTimeLeft > 0) {
        _memorizeTimer?.cancel();
        _memorizeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_disposed) {
            timer.cancel();
            return;
          }
          if (_memorizeTimeLeft > 0) {
            // CRITICAL: Clamp memorize time to prevent negative values (defensive programming)
            _memorizeTimeLeft = (_memorizeTimeLeft - 1).clamp(0, 999);
            _safeNotifyListeners();
          } else {
            timer.cancel();
            if (!_disposed) {
              // Transition to play phase
              _phase = GamePhase.play;
              _startPlayTimer();
              // Start shuffle/flip sequences if enabled
              if (config.enableShuffle && _currentMode == GameMode.shuffle) {
                _startShuffleSequence();
              }
              if (config.enableFlip && _currentMode == GameMode.flip) {
                _startFlipSequence();
              }
              _safeNotifyListeners();
            }
          }
        });
      } else {
        // Memorize time expired - transition to play phase
        _phase = GamePhase.play;
        _startPlayTimer();
        if (config.enableShuffle && _currentMode == GameMode.shuffle) {
          _startShuffleSequence();
        }
        if (config.enableFlip && _currentMode == GameMode.flip) {
          _startFlipSequence();
        }
      }
    } else if (_phase == GamePhase.play) {
      // Resume play phase - restart play timer if time remaining
      if (_playTimeLeft > 0) {
        _startPlayTimer();
        // Resume shuffle/flip sequences if enabled
        if (config.enableShuffle &&
            _currentMode == GameMode.shuffle &&
            !_isShuffling) {
          _startShuffleSequence();
        }
        if (config.enableFlip && _currentMode == GameMode.flip) {
          // Flip sequence would have completed, but restore state is fine
        }
      } else {
        // Play time expired - phase should be result
        // Don't restart timer, but ensure phase is correct
        _phase = GamePhase.result;
        if (kDebugMode) {
          debugPrint('Play time expired on resume - setting phase to result');
        }
      }
    } else if (_phase == GamePhase.result) {
      // Result phase - no timers needed, just ensure state is correct
      // This is fine - result phase doesn't need active timers
      if (kDebugMode) {
        debugPrint('Resuming in result phase - no timers needed');
      }
    }

    // Resume time attack timer if in time attack mode
    if (_currentMode == GameMode.timeAttack &&
        _timeAttackSecondsLeft != null &&
        _timeAttackSecondsLeft! > 0) {
      _timeAttackTimer?.cancel();
      _timeAttackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_disposed) {
          timer.cancel();
          return;
        }
        if (_timeAttackSecondsLeft != null && _timeAttackSecondsLeft! > 0) {
          // CRITICAL: Clamp time attack seconds to prevent negative values (defensive programming)
          _timeAttackSecondsLeft = (_timeAttackSecondsLeft! - 1).clamp(0, GameConstants.maxTimeSeconds);
          _safeNotifyListeners();
        } else {
          timer.cancel();
          if (!_disposed) {
            // CRITICAL: Check if submission is in progress before ending game
            // This prevents race condition where timer expires during answer submission
            // If submission is active, let it complete before ending the game
            if (!_isSubmitting) {
              _state = _state.copyWith(isGameOver: true);
              unawaited(submitCompetitiveChallengeScore());
              _safeNotifyListeners();
            } else {
              // Submission in progress - schedule game over after submission completes
              // The submission logic will handle game over state properly
              if (kDebugMode) {
                debugPrint(
                  'Time attack timer expired during submission - will end game after submission completes',
                );
              }
            }
          }
        }
      });
    }
  }

  @override
  void dispose() {
    // Set disposed flag first to prevent any timer callbacks from calling notifyListeners
    _disposed = true;

    // Cancel all timers and nullify references to prevent memory leaks
    _memorizeTimer?.cancel();
    _memorizeTimer = null;
    _playTimer?.cancel();
    _playTimer = null;
    _timeAttackTimer?.cancel();
    _timeAttackTimer = null;
    _shuffleTimer?.cancel();
    _shuffleTimer = null;
    _timeFreezeTimer?.cancel(); // Cancel time freeze timer
    _timeFreezeTimer = null;
    _flipInitialTimer?.cancel(); // Cancel flip initial timer
    _flipInitialTimer = null;
    _flipPeriodicTimer?.cancel(); // Cancel flip periodic timer
    _flipPeriodicTimer = null;

    // Cancel any pending async operations to prevent memory leaks
    _cancelPendingNextRoundDelay();

    unawaited(_saveState()); // Save state on dispose (fire-and-forget)
    super.dispose();
  }
}
