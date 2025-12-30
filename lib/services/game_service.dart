import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:n3rd_game/models/game_state.dart';
import 'package:n3rd_game/models/trivia_item.dart';
import 'package:n3rd_game/models/game_mode_config.dart';
import 'package:n3rd_game/services/game/game_state_manager.dart';
import 'package:n3rd_game/services/game/game_round_manager.dart';
import 'package:n3rd_game/services/game/game_trivia_manager.dart';
import 'package:n3rd_game/services/game/game_timer_manager.dart';
import 'package:n3rd_game/services/game/game_flip_mode_manager.dart';
import 'package:n3rd_game/services/game/game_selection_manager.dart';
import 'package:n3rd_game/services/game/game_mode_handler.dart';
import 'package:n3rd_game/services/game/game_validation_manager.dart';
import 'package:n3rd_game/services/game/game_mode_specific_manager.dart';
import 'package:n3rd_game/services/game/game_powerup_manager.dart';
import 'package:n3rd_game/services/game/game_competitive_challenge_manager.dart';
import 'package:n3rd_game/services/interfaces/game_service_interface.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/services/haptic_service.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/services/daily_challenge_leaderboard_service.dart';
import 'package:n3rd_game/config/game_constants.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/services/game/game_persistence_manager.dart'
    show ExtendedGameState, GamePersistenceManager;
import 'package:n3rd_game/utils/unawaited_helper.dart';

/// Game service for managing game state and operations
/// 
/// Coordinates all game managers to provide a unified game service interface.
/// This service acts as the central coordinator for game state, rounds, timers,
/// mode-specific logic, power-ups, and persistence.
class GameService extends ChangeNotifier implements GameServiceInterface {
  // Core managers
  final GameStateManager _stateManager = GameStateManager();
  final GameRoundManager _roundManager = GameRoundManager();
  final GameTriviaManager _triviaManager = GameTriviaManager();
  final GameTimerManager _timerManager = GameTimerManager();
  final GameFlipModeManager _flipModeManager = GameFlipModeManager();
  final GameSelectionManager _selectionManager = GameSelectionManager();
  final GameModeHandler _modeHandler = GameModeHandler();
  final GameValidationManager _validationManager = GameValidationManager();
  final GamePersistenceManager _persistenceManager = GamePersistenceManager();
  final GameModeSpecificManager _modeSpecificManager = GameModeSpecificManager();
  final GamePowerupManager _powerupManager = GamePowerupManager();
  final GameCompetitiveChallengeManager _competitiveChallengeManager =
      GameCompetitiveChallengeManager();

  // Game state
  GameMode _currentMode = GameMode.classic;
  bool _isPaused = false;
  bool _isDisposed = false;
  int _playTimeLeft = 0;
  int _memorizeTimeLeft = 0;
  int _timeAttackSecondsLeft = 0;
  DateTime? _gameStartTime;
  int _sessionCorrectAnswers = 0;
  int _sessionWrongAnswers = 0;

  // Optional dependencies (set via setters)
  HapticService? _hapticService;
  DailyChallengeLeaderboardService? _leaderboardService;

  // Revealed words set (combines power-up hints and flip mode reveals)
  final Set<String> _revealedWords = {};

  GameService() {
    _setupTimerCallbacks();
    _loadFlipRevealMode();
  }

  /// Set haptic service for feedback
  void setHapticService(HapticService? service) {
    _hapticService = service;
  }

  /// Set analytics service for tracking
  void setAnalyticsService(AnalyticsService? service) {
    _persistenceManager.setAnalyticsService(service);
  }

  /// Set leaderboard service for competitive challenges
  void setLeaderboardService(DailyChallengeLeaderboardService? service) {
    _leaderboardService = service;
  }

  /// Set up timer callbacks for phase transitions
  void _setupTimerCallbacks() {
    _timerManager.onMemorizeComplete = () {
      if (_isDisposed) return;
      _transitionToPlayPhase();
    };

    _timerManager.onPlayComplete = () {
      if (_isDisposed) return;
      _transitionToResultPhase();
    };

    _timerManager.onTimeAttackTick = (secondsLeft) {
      if (_isDisposed) return;
      _timeAttackSecondsLeft = secondsLeft;
      _playTimeLeft = secondsLeft;
      notifyListeners();
    };

    _timerManager.onTimeAttackExpired = () {
      if (_isDisposed) return;
      _transitionToResultPhase();
    };

    _timerManager.onShuffleTick = () {
      if (_isDisposed) return;
      notifyListeners();
    };
  }

  /// Load persisted flip reveal mode
  Future<void> _loadFlipRevealMode() async {
    try {
      await _flipModeManager.loadFlipRevealMode();
    } catch (e) {
      LoggerService.error('Failed to load flip reveal mode', error: e);
    }
  }

  /// Transition from memorize to play phase
  void _transitionToPlayPhase() {
    if (_stateManager.phase != GamePhase.memorize) return;
    if (_isPaused) return;

    _stateManager.updatePhase(GamePhase.play);
    final config = ModeConfig.getConfig(_currentMode);
    _playTimeLeft = config.playTime;

    // Start play phase timer (unless time attack mode)
    if (_currentMode != GameMode.timeAttack) {
      _timerManager.startPlayTimer(Duration(seconds: config.playTime));
    } else {
      // Time attack mode: 60 second continuous timer
      _timerManager.startTimeAttackTimer(
        totalSeconds: 60,
        tickInterval: const Duration(seconds: 1),
      );
      _timeAttackSecondsLeft = 60;
      _playTimeLeft = 60;
    }

    // Start shuffle sequence if shuffle mode
    if (_currentMode == GameMode.shuffle && config.enableShuffle) {
      _startShuffleSequence();
    }

    // Start flip sequence if flip mode
    if (_currentMode == GameMode.flip && config.enableFlip) {
      _startFlipSequence();
    }

    // Update memorize time left for display
    _memorizeTimeLeft = config.memorizeTime;

    notifyListeners();
  }

  /// Transition from play to result phase
  void _transitionToResultPhase() {
    if (_stateManager.phase != GamePhase.play) return;

    _timerManager.cancelPlayTimer();
    _timerManager.cancelTimeAttackTimer();
    _timerManager.cancelShuffleTimer();
    _modeHandler.stopShuffleSequence();

    _stateManager.updatePhase(GamePhase.result);
    _playTimeLeft = 0;
    _timeAttackSecondsLeft = 0;

    notifyListeners();
  }

  /// Start shuffle sequence for shuffle mode
  void _startShuffleSequence() {
    final shuffleInterval = Duration(
      milliseconds: _getShuffleIntervalForDifficulty(
        _modeHandler.shuffleDifficulty,
      ),
    );

    _timerManager.startShuffleTimer(
      interval: shuffleInterval,
      onTick: () {
        if (_isDisposed || _stateManager.phase != GamePhase.play) return;
        _modeHandler.startShuffleSequence(
          onShuffleTick: () {
            notifyListeners();
          },
          onComplete: () {
            _timerManager.cancelShuffleTimer();
          },
        );
      },
    );
  }

  /// Get shuffle interval based on difficulty
  int _getShuffleIntervalForDifficulty(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return 2000; // 2 seconds
      case 'medium':
        return 1500; // 1.5 seconds
      case 'hard':
        return 1000; // 1 second
      case 'insane':
        return 500; // 0.5 seconds
      default:
        return 1500;
    }
  }

  /// Start flip sequence for flip mode
  void _startFlipSequence() {
    _flipModeManager.startFlipSequence(
      shuffledWords: _modeHandler.shuffledWords,
      currentTrivia: _roundManager.currentTrivia,
      currentMode: _currentMode,
      phase: _stateManager.phase,
      isDisposed: _isDisposed,
      onNotifyListeners: () {
        notifyListeners();
      },
    );
  }

  // Getters
  @override
  GameState get state => _stateManager.state;

  @override
  GameMode get currentMode => _currentMode;

  @override
  int get score => _stateManager.state.score;

  @override
  bool get isGameOver => _stateManager.state.isGameOver;

  bool get isPaused => _isPaused;

  TriviaItem? get currentTrivia => _roundManager.currentTrivia;

  int get correctCount => _stateManager.state.correctCount;

  List<String> get shuffledWords => _modeHandler.shuffledWords;

  Map<String, int> get shuffledWordsMap => _modeHandler.shuffledWordsMap;

  GamePhase get phase => _stateManager.phase;

  bool get canSubmit =>
      phase == GamePhase.play &&
      _roundManager.selectedAnswers.isNotEmpty &&
      !_isPaused;

  List<String> get selectedAnswers => _roundManager.selectedAnswers;

  Set<String> get revealedWords => Set.unmodifiable(_revealedWords);

  bool get isFlipMode => _currentMode == GameMode.flip;

  int get playTimeLeft => _playTimeLeft;

  int get memorizeTimeLeft => _memorizeTimeLeft;

  bool get isTimeFrozen => _powerupManager.isTimeFrozen;

  /// Start a new game round
  @override
  void startNewRound(
    List<TriviaItem> triviaPool, {
    GameMode? mode,
    String? difficulty,
  }) {
    if (_isDisposed) return;
    if (triviaPool.isEmpty) {
      LoggerService.warning('Cannot start round: trivia pool is empty');
      return;
    }

    LoggerService.debug(
      'GameService: startNewRound called with mode=$mode, difficulty=$difficulty',
    );

    // Update mode if provided
    if (mode != null) {
      final oldMode = _currentMode;
      _currentMode = mode;

      // Reset mode-specific state if mode changed
      if (_modeSpecificManager.shouldResetForModeChange(
        oldMode: oldMode,
        newMode: mode,
      )) {
        _modeSpecificManager.resetForModeChange(newMode: mode);
      }
    }

    // Set difficulty for shuffle mode
    if (difficulty != null && _currentMode == GameMode.shuffle) {
      _modeHandler.shuffleDifficulty = difficulty;
    }

    // Cancel any existing timers
    _timerManager.cancelAllTimers();

    // Set trivia pool
    _triviaManager.setTriviaPool(triviaPool);
    _roundManager.setTriviaPool(triviaPool);

    // Select trivia for round
    try {
      final selectedTrivia = _roundManager.selectTriviaForRound(
        mode: _currentMode,
      );

      // Validate trivia
      final validationResult =
          _validationManager.validateTriviaItem(selectedTrivia);
      if (!validationResult.isValid) {
        LoggerService.error(
          'Invalid trivia selected: ${validationResult.errorMessage}',
        );
        throw GameException(
          'Invalid trivia item: ${validationResult.errorMessage}',
        );
      }

      // Add category to recent
      _triviaManager.addRecentCategory(selectedTrivia.category);

      // Initialize shuffled words
      _modeHandler.initializeShuffle(
        words: selectedTrivia.words,
        onShuffle: () {
          notifyListeners();
        },
        onComplete: () {
          notifyListeners();
        },
      );

      // Reset for new round
      _roundManager.resetForNewRound();
      _modeSpecificManager.resetForNewRound();
      _flipModeManager.reset();
      _revealedWords.clear();
      _powerupManager.hintedWords.clear();

      // Update phase to memorize
      _stateManager.updatePhase(GamePhase.memorize);

      // Start memorize phase timer
      final config = ModeConfig.getConfig(_currentMode);
      _memorizeTimeLeft = config.memorizeTime;
      if (config.memorizeTime > 0) {
        _timerManager.startMemorizeTimer(
          Duration(seconds: config.memorizeTime),
        );
      } else {
        // No memorize time - transition immediately to play
        _transitionToPlayPhase();
      }

      // Initialize flip mode if applicable
      if (_currentMode == GameMode.flip && config.enableFlip) {
        _flipModeManager.initializeFlippedTiles(selectedTrivia.words.length);
      }

      notifyListeners();
    } catch (e) {
      LoggerService.error('Failed to start new round', error: e);
      rethrow;
    }
  }

  /// Submit answers for current round
  @override
  void submitAnswers() {
    if (_isDisposed) return;
    if (phase != GamePhase.play) {
      LoggerService.warning('Cannot submit answers: not in play phase');
      return;
    }
    if (_roundManager.currentTrivia == null) {
      LoggerService.warning('Cannot submit answers: no trivia available');
      return;
    }

    LoggerService.debug('GameService: submitAnswers called');

    // Cancel play timer
    _timerManager.cancelPlayTimer();
    _timerManager.cancelTimeAttackTimer();
    _timerManager.cancelShuffleTimer();
    _modeHandler.stopShuffleSequence();

    // Validate answers
    final correctCount = _roundManager.validateAnswers();
    final currentState = _stateManager.state;
    final trivia = _roundManager.currentTrivia!;
    final expectedCorrect = trivia.correctAnswers.length;

    // Update session stats
    _sessionCorrectAnswers += correctCount;
    _sessionWrongAnswers += (expectedCorrect - correctCount);

    // Calculate base points
    int points = correctCount * 10;

    // Apply mode-specific scoring
    points = _modeSpecificManager.applyModeScoring(
      points: points,
      currentMode: _currentMode,
    );

    // Apply power-up multipliers
    if (_powerupManager.consumeDoubleScore()) {
      points = (points * 2).clamp(0, GameConstants.maxScore);
    }

    // Check if perfect round
    final isPerfect = correctCount == expectedCorrect;

    // Update game state
    GameState newState = currentState.copyWith(
      score: (currentState.score + points).clamp(0, GameConstants.maxScore),
      correctCount: correctCount,
      lastCorrectAnswers: List.from(trivia.correctAnswers),
      lastSelectedAnswers: List.from(_roundManager.selectedAnswers),
    );

    // Handle perfect round
    if (isPerfect) {
      newState = newState.copyWith(
        perfectStreak: currentState.perfectStreak + 1,
      );

      // Handle mode-specific perfect round logic
      final modeStateUpdate =
          _modeSpecificManager.handlePerfectRound(
        currentMode: _currentMode,
        currentState: newState,
      );
      if (modeStateUpdate != null) {
        newState = modeStateUpdate;
      }

      // Award power-ups based on streak
      _powerupManager.awardStreakReward(
        streak: newState.perfectStreak,
        onAddLife: (lives) {
          newState = newState.copyWith(
            lives: (newState.lives + lives).clamp(0, GameConstants.maxLives),
          );
        },
        currentLives: newState.lives,
      );
    } else {
      // Non-perfect round
      _modeSpecificManager.handleNonPerfectRound(currentMode: _currentMode);
      newState = newState.copyWith(perfectStreak: 0);

      // Lose a life (unless streak shield active)
      if (!_powerupManager.consumeStreakShield()) {
        final newLives = (newState.lives - 1).clamp(0, GameConstants.maxLives);
        newState = newState.copyWith(lives: newLives);

        // Check game over
        if (newLives <= 0) {
          newState = newState.copyWith(isGameOver: true);
        }
      }
    }

    // Update round
    if (!newState.isGameOver) {
      newState = newState.copyWith(round: newState.round + 1);
    }

    // Update state
    _stateManager.updateState(newState);

    // Transition to result phase
    _transitionToResultPhase();

    // Submit competitive challenge score if game over
    if (newState.isGameOver && _competitiveChallengeManager.competitiveChallengeId != null) {
      _submitCompetitiveChallengeScore();
    }

    // Save state
    unawaited(_saveStateInternal());

    notifyListeners();
  }

  /// Submit competitive challenge score
  Future<void> _submitCompetitiveChallengeScore() async {
    if (_leaderboardService == null) return;

    try {
      await _competitiveChallengeManager.submitCompetitiveChallengeScore(
        state: _stateManager.state,
        sessionCorrectAnswers: _sessionCorrectAnswers,
        sessionWrongAnswers: _sessionWrongAnswers,
        isLoadingState: false,
        leaderboardService: _leaderboardService!,
        onSaveState: () {
          unawaited(_saveStateInternal());
        },
      );
    } catch (e) {
      LoggerService.error('Failed to submit competitive challenge score', error: e);
    }
  }

  /// Toggle tile selection
  void toggleTileSelection(String word) {
    if (_isDisposed) return;
    if (phase != GamePhase.play) {
      LoggerService.warning('Cannot toggle selection: not in play phase');
      return;
    }

    LoggerService.debug('GameService: toggleTileSelection called with word=$word');

    // Handle flip mode selection
    if (_currentMode == GameMode.flip) {
      _handleFlipModeSelection(word);
      return;
    }

    // Normal mode selection via GameSelectionManager
    final selectedAnswersSet = Set<String>.from(_roundManager.selectedAnswers);
    final result = _selectionManager.toggleTileSelection(
      word: word,
      phase: phase,
      currentMode: _currentMode,
      currentTrivia: _roundManager.currentTrivia,
      selectedAnswers: selectedAnswersSet,
      state: _stateManager.state,
      expectedCorrectAnswers: GameConstants.expectedCorrectAnswers,
      isDisposed: _isDisposed,
      onFlipModeSelection: (_) {
        // Not used in normal mode
      },
      onStateUpdate: (newState) {
        _stateManager.updateState(newState);
        if (newState.isGameOver) {
          _submitCompetitiveChallengeScore();
        }
      },
      onPrecisionErrorUpdate: (error) {
        _modeSpecificManager.setPrecisionError(error);
      },
      onNotifyListeners: () {
        notifyListeners();
      },
      onSaveState: () {
        unawaited(_saveStateInternal());
      },
      hapticService: _hapticService,
    );

    // Update selected answers in round manager
    _roundManager.clearSelectedAnswers();
    for (final answer in selectedAnswersSet) {
      _roundManager.addSelectedAnswer(answer);
    }

    // Provide haptic feedback
    if (result.success) {
      _hapticService?.selectionClick();
    } else if (result.errorType == SelectionErrorType.precisionError) {
      _hapticService?.error();
    }

    notifyListeners();
  }

  /// Handle flip mode selection
  void _handleFlipModeSelection(String word) {
    final result = _flipModeManager.handleFlipModeSelection(
      word: word,
      currentTrivia: _roundManager.currentTrivia,
      shuffledWords: _modeHandler.shuffledWords,
      shuffledWordsMap: _modeHandler.shuffledWordsMap,
      selectedAnswers: Set<String>.from(_roundManager.selectedAnswers),
      expectedCorrectAnswers: GameConstants.expectedCorrectAnswers,
      isDisposed: _isDisposed,
      onAddToFlipModeSelectedOrder: (word) {
        _flipModeManager.addToFlipModeSelectedOrder(word);
      },
      onAddToSelectedAnswers: (word) {
        _roundManager.addSelectedAnswer(word);
      },
      onNotifyListeners: () {
        notifyListeners();
      },
      onSubmitFlipModeAnswers: (isPerfect) {
        if (isPerfect) {
          submitAnswers();
        }
      },
      onRevealFlipModeResults: () {
        final isPerfect = _flipModeManager.revealFlipModeResults(
          currentTrivia: _roundManager.currentTrivia,
          shuffledWords: _modeHandler.shuffledWords,
          shuffledWordsMap: _modeHandler.shuffledWordsMap,
          expectedCorrectAnswers: GameConstants.expectedCorrectAnswers,
        );
        notifyListeners();
        if (isPerfect) {
          submitAnswers();
        }
      },
    );

    // Handle result
    switch (result.action) {
      case FlipModeSelectionAction.correct:
        _hapticService?.success();
        notifyListeners();
        break;
      case FlipModeSelectionAction.wrong:
        _hapticService?.error();
        notifyListeners();
        break;
      case FlipModeSelectionAction.selected:
        _hapticService?.selectionClick();
        notifyListeners();
        break;
      case FlipModeSelectionAction.submitPerfect:
        submitAnswers();
        break;
      case FlipModeSelectionAction.revealResults:
        // Handled by callback
        break;
      case FlipModeSelectionAction.noAction:
        break;
    }
  }

  /// Set flip reveal mode
  Future<void> setFlipRevealMode(String mode) async {
    if (_isDisposed) return;

    LoggerService.debug('GameService: setFlipRevealMode called with mode=$mode');

    await _flipModeManager.setFlipRevealMode(
      mode,
      currentMode: _currentMode,
      phase: phase,
      isGameOver: isGameOver,
      onNotifyListeners: () {
        notifyListeners();
      },
    );
  }

  /// Reveal a word (for flip mode or power-ups)
  void revealWord(String word) {
    if (_isDisposed) return;

    LoggerService.debug('GameService: revealWord called with word=$word');

    _revealedWords.add(word);
    notifyListeners();
  }

  /// Reset game to initial state
  @override
  Future<void> resetGame() async {
    if (_isDisposed) return;

    LoggerService.debug('GameService: resetGame called');

    // Cancel all timers
    _timerManager.cancelAllTimers();

    // Reset all managers
    _stateManager.resetState();
    _roundManager.reset();
    _triviaManager.reset();
    _flipModeManager.clear();
    _modeHandler.reset();
    _modeSpecificManager.reset(currentMode: _currentMode);
    _powerupManager.reset();
    _competitiveChallengeManager.reset();

    // Reset state
    _currentMode = GameMode.classic;
    _isPaused = false;
    _playTimeLeft = 0;
    _memorizeTimeLeft = 0;
    _timeAttackSecondsLeft = 0;
    _gameStartTime = null;
    _sessionCorrectAnswers = 0;
    _sessionWrongAnswers = 0;
    _revealedWords.clear();

    // Clear persisted state
    await _persistenceManager.clearState();

    notifyListeners();
  }

  /// Pause the game
  @override
  void pauseGame() {
    if (_isDisposed) return;
    if (_isPaused) return;

    _isPaused = true;

    // Track pause time for competitive challenges
    if (_competitiveChallengeManager.competitiveChallengeId != null) {
      _competitiveChallengeManager.competitiveChallengePauseTime = DateTime.now().toUtc();
    }

    // Cancel timers (they will be resumed when game resumes)
    _timerManager.cancelAllTimers();

    // Save state
    unawaited(_saveStateInternal());

    notifyListeners();
  }

  /// Resume the game
  @override
  void resumeGame() {
    if (_isDisposed) return;
    if (!_isPaused) return;

    _isPaused = false;

    // Update pause duration for competitive challenges
    if (_competitiveChallengeManager.competitiveChallengeId != null &&
        _competitiveChallengeManager.competitiveChallengePauseTime != null) {
      final pauseDuration = DateTime.now()
          .toUtc()
          .difference(_competitiveChallengeManager.competitiveChallengePauseTime!.toUtc())
          .inSeconds;
      _competitiveChallengeManager.competitiveChallengePausedDuration += pauseDuration;
      _competitiveChallengeManager.competitiveChallengePauseTime = null;
    }

    // Resume timers based on current phase
    final config = ModeConfig.getConfig(_currentMode);
    if (phase == GamePhase.memorize && config.memorizeTime > 0) {
      _timerManager.startMemorizeTimer(
        Duration(seconds: _memorizeTimeLeft),
      );
    } else if (phase == GamePhase.play) {
      if (_currentMode == GameMode.timeAttack) {
        _timerManager.startTimeAttackTimer(
          totalSeconds: _timeAttackSecondsLeft,
          tickInterval: const Duration(seconds: 1),
        );
      } else {
        _timerManager.startPlayTimer(
          Duration(seconds: _playTimeLeft),
        );
      }

      // Resume shuffle if shuffle mode
      if (_currentMode == GameMode.shuffle) {
        _startShuffleSequence();
      }
    }

    notifyListeners();
  }

  /// Load game state from storage
  @override
  Future<void> loadState() async {
    if (_isDisposed) return;

    LoggerService.debug('GameService: loadState called');

    try {
      final loadedData = await _persistenceManager.loadState();
      if (loadedData == null) {
        LoggerService.debug('No saved state found');
        return;
      }

      final coreState = loadedData['coreState'] as GameState;
      final extendedState = loadedData['extendedState'] as ExtendedGameState?;

      // Restore core state
      _stateManager.updateState(coreState);
      _stateManager.updatePhase(extendedState?.phase ?? GamePhase.memorize);

      // Restore extended state
      if (extendedState != null) {
        _currentMode = extendedState.currentMode;
        _playTimeLeft = extendedState.playTimeLeft;
        _memorizeTimeLeft = extendedState.memorizeTimeLeft;
        _timeAttackSecondsLeft = extendedState.timeAttackSecondsLeft ?? 0;
        _gameStartTime = extendedState.gameStartTime;
        _sessionCorrectAnswers = extendedState.sessionCorrectAnswers;
        _sessionWrongAnswers = extendedState.sessionWrongAnswers;

        // Restore trivia pool
        if (extendedState.currentTriviaPool.isNotEmpty) {
          _triviaManager.setTriviaPool(extendedState.currentTriviaPool);
          _roundManager.setTriviaPool(extendedState.currentTriviaPool);
        }

        // Restore current trivia
        // Note: currentTrivia is set when we select trivia, so we'll need to
        // ensure it's in the pool and select it
        if (extendedState.currentTrivia != null) {
          // Add trivia to pool if not already there, then select it
          final triviaPool = List<TriviaItem>.from(_triviaManager.currentTriviaPool);
          if (!triviaPool.contains(extendedState.currentTrivia)) {
            triviaPool.insert(0, extendedState.currentTrivia!);
          }
          _roundManager.setTriviaPool(triviaPool);
          // Select the trivia (this will set currentTrivia internally)
          try {
            _roundManager.selectTriviaForRound(mode: _currentMode);
          } catch (e) {
            LoggerService.warning('Could not restore current trivia: $e');
          }
        }

        // Restore shuffled words
        if (extendedState.shuffledWords.isNotEmpty) {
          _modeHandler.initializeShuffle(
            words: extendedState.shuffledWords,
            onShuffle: () {},
            onComplete: () {},
          );
        }

        // Restore selected answers
        for (final answer in extendedState.selectedAnswers) {
          _roundManager.addSelectedAnswer(answer);
        }

        // Restore revealed words
        _revealedWords.clear();
        _revealedWords.addAll(extendedState.revealedWords);

        // Restore power-up state
        _powerupManager.revealAllUses = extendedState.revealAllUses;
        _powerupManager.clearUses = extendedState.clearUses;
        _powerupManager.skipUses = extendedState.skipUses;
        _powerupManager.streakShieldUses = extendedState.streakShieldUses;
        _powerupManager.timeFreezeUses = extendedState.timeFreezeUses;
        _powerupManager.hintUses = extendedState.hintUses;
        _powerupManager.doubleScoreUses = extendedState.doubleScoreUses;
        _powerupManager.isTimeFrozen = extendedState.isTimeFrozen;
        _powerupManager.hasDoubleScore = extendedState.hasDoubleScore;
        _powerupManager.hasStreakShield = extendedState.hasStreakShield;
        _powerupManager.playTimeAtFreeze = extendedState.playTimeAtFreeze;
        _powerupManager.hintedWords.clear();
        _powerupManager.hintedWords.addAll(extendedState.hintedWords);

        // Restore mode-specific state
        _modeSpecificManager.restoreState(
          extendedStateMap: {
            'streakMultiplier': extendedState.streakMultiplier,
            'survivalPerfectCount': extendedState.survivalPerfectCount,
          },
          currentMode: _currentMode,
        );

        // Restore competitive challenge state
        _competitiveChallengeManager.competitiveChallengeId =
            extendedState.competitiveChallengeId;
        _competitiveChallengeManager.competitiveChallengeStartTime =
            extendedState.competitiveChallengeStartTime;
        _competitiveChallengeManager.competitiveChallengePauseTime =
            extendedState.competitiveChallengePauseTime;
        _competitiveChallengeManager.competitiveChallengePausedDuration =
            extendedState.competitiveChallengePausedDuration;
        _competitiveChallengeManager.competitiveChallengeTargetRounds =
            extendedState.competitiveChallengeTargetRounds;
        _competitiveChallengeManager.competitiveChallengeScoreSubmitted =
            extendedState.competitiveChallengeScoreSubmitted;

        // Restore flip mode state
        if (extendedState.flipModeSelectedOrder.isNotEmpty) {
          for (final word in extendedState.flipModeSelectedOrder) {
            _flipModeManager.addToFlipModeSelectedOrder(word);
          }
        }
        // Initialize flipped tiles (resets flipCurrentIndex to 0)
        // Note: We can't restore the exact flip index, but this is acceptable
        // as flip state is primarily used during memorize phase
        if (extendedState.flippedTiles.isNotEmpty) {
          _flipModeManager.initializeFlippedTiles(extendedState.flippedTiles.length);
        }

        // Validate restored state
        final validationResult = _validationManager.validateRestoredState(
          trivia: extendedState.currentTrivia,
          shuffledWords: extendedState.shuffledWords,
          flippedTilesLength: extendedState.flippedTiles.length,
          flipCurrentIndex: extendedState.flipCurrentIndex,
          selectedAnswers: extendedState.selectedAnswers,
          revealedWords: extendedState.revealedWords,
          hintedWords: extendedState.hintedWords,
          flipModeSelectedOrder: extendedState.flipModeSelectedOrder,
        );

        if (!validationResult.isValid) {
          LoggerService.warning(
            'Restored state validation failed, resetting invalid parts',
          );
          // Reset invalid parts
          if (validationResult.shuffledWordsNeedReset) {
            if (extendedState.currentTrivia != null) {
              _modeHandler.initializeShuffle(
                words: extendedState.currentTrivia!.words,
                onShuffle: () {},
                onComplete: () {},
              );
            }
          }
          // Clear invalid selected/revealed words
          for (final word in validationResult.invalidSelectedWords) {
            _roundManager.removeSelectedAnswer(word);
          }
          for (final word in validationResult.invalidRevealedWords) {
            _revealedWords.remove(word);
          }
        }

        // Reinitialize timers if game was in progress
        if (!coreState.isGameOver) {
          final config = ModeConfig.getConfig(_currentMode);
          if (extendedState.phase == GamePhase.memorize &&
              config.memorizeTime > 0) {
            _timerManager.startMemorizeTimer(
              Duration(seconds: _memorizeTimeLeft),
            );
          } else if (extendedState.phase == GamePhase.play) {
            if (_currentMode == GameMode.timeAttack) {
              _timerManager.startTimeAttackTimer(
                totalSeconds: _timeAttackSecondsLeft,
                tickInterval: const Duration(seconds: 1),
              );
            } else {
              _timerManager.startPlayTimer(
                Duration(seconds: _playTimeLeft),
              );
            }

            // Resume shuffle if shuffle mode
            if (_currentMode == GameMode.shuffle) {
              _startShuffleSequence();
            }
          }
        }
      }

      notifyListeners();
    } catch (e) {
      LoggerService.error('Failed to load game state', error: e);
      rethrow;
    }
  }

  /// Save game state to storage
  @override
  Future<void> saveState() async {
    await _saveStateInternal();
  }

  /// Internal save state method
  Future<void> _saveStateInternal() async {
    if (_isDisposed) return;

    try {
      // Build extended state
      final extendedState = ExtendedGameState(
        revealAllUses: _powerupManager.revealAllUses,
        clearUses: _powerupManager.clearUses,
        skipUses: _powerupManager.skipUses,
        streakShieldUses: _powerupManager.streakShieldUses,
        timeFreezeUses: _powerupManager.timeFreezeUses,
        hintUses: _powerupManager.hintUses,
        doubleScoreUses: _powerupManager.doubleScoreUses,
        competitiveChallengeId:
            _competitiveChallengeManager.competitiveChallengeId,
        competitiveChallengeStartTime:
            _competitiveChallengeManager.competitiveChallengeStartTime,
        competitiveChallengePauseTime:
            _competitiveChallengeManager.competitiveChallengePauseTime,
        competitiveChallengePausedDuration:
            _competitiveChallengeManager.competitiveChallengePausedDuration,
        competitiveChallengeTargetRounds:
            _competitiveChallengeManager.competitiveChallengeTargetRounds,
        competitiveChallengeScoreSubmitted:
            _competitiveChallengeManager.competitiveChallengeScoreSubmitted,
        currentMode: _currentMode,
        streakMultiplier: _modeSpecificManager.streakMultiplier,
        survivalPerfectCount: _modeSpecificManager.survivalPerfectCount,
        isTimeFrozen: _powerupManager.isTimeFrozen,
        hasDoubleScore: _powerupManager.hasDoubleScore,
        hasStreakShield: _powerupManager.hasStreakShield,
        playTimeAtFreeze: _powerupManager.playTimeAtFreeze,
        sessionCorrectAnswers: _sessionCorrectAnswers,
        sessionWrongAnswers: _sessionWrongAnswers,
        phase: _stateManager.phase,
        currentTrivia: _roundManager.currentTrivia,
        shuffledWords: _modeHandler.shuffledWords,
        selectedAnswers: _roundManager.selectedAnswers,
        revealedWords: _revealedWords.toList(),
        memorizeTimeLeft: _memorizeTimeLeft,
        playTimeLeft: _playTimeLeft,
        timeAttackSecondsLeft:
            _currentMode == GameMode.timeAttack ? _timeAttackSecondsLeft : null,
        currentTriviaPool: _triviaManager.currentTriviaPool,
        flipModeSelectedOrder:
            _flipModeManager.flipModeSelectedOrder.toList(),
        flipCurrentIndex: _flipModeManager.flipCurrentIndex,
        flippedTiles: _flipModeManager.flippedTiles.toList(),
        hintedWords: _powerupManager.hintedWords,
        shuffleCount: _modeHandler.shuffleCount,
        isShuffling: _modeHandler.isShuffling,
        shuffleDifficulty: _modeHandler.shuffleDifficulty,
        gameStartTime: _gameStartTime,
      );

      // Save using persistence manager
      await _persistenceManager.saveState(
        coreState: _stateManager.state,
        extendedState: extendedState,
        onNotifyListeners: () {
          notifyListeners();
        },
        isDisposed: () => _isDisposed,
      );
    } catch (e) {
      LoggerService.error('Failed to save game state', error: e);
      // Don't rethrow - save failures are non-critical
    }
  }

  /// Dispose resources
  @override
  void dispose() {
    if (_isDisposed) return;

    _isDisposed = true;

    // Cancel all timers
    _timerManager.dispose();

    // Dispose flip mode manager
    _flipModeManager.dispose();

    // Clear all callbacks
    _timerManager.onMemorizeComplete = null;
    _timerManager.onPlayComplete = null;
    _timerManager.onTimeAttackTick = null;
    _timerManager.onTimeAttackExpired = null;
    _timerManager.onShuffleTick = null;

    super.dispose();
  }
}
