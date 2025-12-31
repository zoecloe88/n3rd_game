import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/models/trivia_item.dart';
import 'package:n3rd_game/models/game_mode_config.dart';
import 'package:n3rd_game/config/game_constants.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Manages flip mode functionality
///
/// Handles flip sequence timing, tile state management, selection order tracking,
/// and reveal mode settings (instant, blind, random) for flip mode gameplay.
class GameFlipModeManager {
  // Flip mode state
  List<bool> _flippedTiles = [];
  final List<String> _flipModeSelectedOrder = [];
  int _flipCurrentIndex = 0;
  int? _flipSequenceId;
  String _flipRevealMode = 'instant';
  bool _flipRevealModeIsInstant = true;

  // Timers
  Timer? _flipInitialTimer;
  Timer? _flipPeriodicTimer;

  // Random number generator
  final Random _random = Random();

  // Storage key for persistence
  static const String _storageKeyFlipRevealMode = 'flip_reveal_mode';

  // SharedPreferences cache
  SharedPreferences? _prefs;

  // Getters
  List<bool> get flippedTiles => List.unmodifiable(_flippedTiles);
  List<String> get flipModeSelectedOrder =>
      List.unmodifiable(_flipModeSelectedOrder);
  int get flipCurrentIndex => _flipCurrentIndex;
  String get flipRevealMode => _flipRevealMode;
  bool get flipRevealModeIsInstant => _flipRevealModeIsInstant;

  /// Get or initialize SharedPreferences
  Future<SharedPreferences> _getPrefs() async {
    if (_prefs != null) return _prefs!;
    _prefs = await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Set flip reveal mode ('instant', 'blind', or 'random')
  /// Persists the setting to SharedPreferences
  Future<void> setFlipRevealMode(
    String mode, {
    required GameMode currentMode,
    required GamePhase phase,
    required bool isGameOver,
    required VoidCallback onNotifyListeners,
  }) async {
    if (mode == 'instant' || mode == 'blind' || mode == 'random') {
      // Prevent changing reveal mode during active Flip Mode round
      if (currentMode == GameMode.flip &&
          phase != GamePhase.result &&
          !isGameOver) {
        LoggerService.warning(
          'Cannot change flip reveal mode during active round',
        );
        return;
      }

      _flipRevealMode = mode;
      _flipRevealModeIsInstant = mode == 'instant';

      // Persist to SharedPreferences
      try {
        final prefs = await _getPrefs();
        await prefs.setString(_storageKeyFlipRevealMode, mode);
      } catch (e) {
        LoggerService.error('Failed to save flip reveal mode', error: e);
      }

      onNotifyListeners();
    }
  }

  /// Load flip reveal mode from SharedPreferences
  Future<void> loadFlipRevealMode() async {
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

  /// Start flip sequence
  ///
  /// Initializes tiles and starts the flip animation sequence.
  /// Tiles start face-up and flip face-down over time.
  void startFlipSequence({
    required List<String> shuffledWords,
    required TriviaItem? currentTrivia,
    required GameMode currentMode,
    required GamePhase phase,
    required bool isDisposed,
    required VoidCallback onNotifyListeners,
  }) {
    // Validate shuffledWords is populated before starting flip sequence
    if (shuffledWords.isEmpty && (currentTrivia?.words.isEmpty ?? true)) {
      LoggerService.warning('Cannot start flip sequence - no words available');
      return;
    }

    // Cancel any existing flip timers
    _flipInitialTimer?.cancel();
    _flipPeriodicTimer?.cancel();
    _flipInitialTimer = null;
    _flipPeriodicTimer = null;

    // Determine reveal mode for this round (re-determine here to ensure consistency)
    if (_flipRevealMode == 'random') {
      _flipRevealModeIsInstant = _random.nextBool();
    } else {
      _flipRevealModeIsInstant = _flipRevealMode == 'instant';
    }

    // Initialize flipped tiles (all start face-up)
    if (shuffledWords.isNotEmpty) {
      _flippedTiles = List.filled(shuffledWords.length, true);
      _flipCurrentIndex = 0;
    } else if (currentTrivia?.words != null) {
      final wordsLength =
          currentTrivia?.words.length ?? GameConstants.requiredWordsForGameplay;
      _flippedTiles = List.filled(wordsLength, true);
      _flipCurrentIndex = 0;
    }

    final config = ModeConfig.getConfig(currentMode);
    final flipStartTime = config.flipStartTime;
    final flipDuration = config.flipDuration;

    // Store sequence ID to prevent race conditions
    final sequenceId = DateTime.now().microsecondsSinceEpoch;
    _flipSequenceId = sequenceId;

    // After flipStartTime, start flipping tiles one by one
    _flipInitialTimer = Timer(Duration(seconds: flipStartTime), () {
      if (isDisposed || _flipSequenceId != sequenceId) return;

      final int tilesToFlip = shuffledWords.isNotEmpty
          ? shuffledWords.length
          : (currentTrivia?.words.length ??
              GameConstants.requiredWordsForGameplay);

      if (tilesToFlip == 0) {
        LoggerService.warning('Cannot start flip sequence - no tiles to flip');
        return;
      }

      int flipInterval = (flipDuration * 1000) ~/ tilesToFlip;

      if (flipInterval <= 0) {
        LoggerService.warning(
          'Calculated flip interval is $flipInterval. Using minimum 1ms.',
        );
        flipInterval = 1;
      }

      if (isDisposed || _flipSequenceId != sequenceId) return;

      _flipPeriodicTimer = Timer.periodic(
        Duration(milliseconds: flipInterval),
        (timer) {
          if (isDisposed || _flipSequenceId != sequenceId) {
            timer.cancel();
            _flipPeriodicTimer = null;
            return;
          }

          if (_flipCurrentIndex < tilesToFlip && phase == GamePhase.memorize) {
            if (_flippedTiles.isEmpty) {
              timer.cancel();
              _flipPeriodicTimer = null;
              return;
            }
            if (_flipCurrentIndex < _flippedTiles.length) {
              _flippedTiles[_flipCurrentIndex] = false;
              _flipCurrentIndex++;
              onNotifyListeners();
            }
          } else {
            timer.cancel();
            _flipPeriodicTimer = null;
          }
        },
      );
    });
  }

  /// Handle flip mode selection
  ///
  /// Processes word selection in flip mode, handling both instant and blind modes.
  /// Returns FlipModeSelectionResult with action to take.
  FlipModeSelectionResult handleFlipModeSelection({
    required String word,
    required TriviaItem? currentTrivia,
    required List<String> shuffledWords,
    required Map<String, int> shuffledWordsMap,
    required Set<String> selectedAnswers,
    required int expectedCorrectAnswers,
    required bool isDisposed,
    required Function(String) onAddToFlipModeSelectedOrder,
    required Function(String) onAddToSelectedAnswers,
    required VoidCallback onNotifyListeners,
    required Function(bool) onSubmitFlipModeAnswers,
    required Function() onRevealFlipModeResults,
  }) {
    if (currentTrivia == null || currentTrivia.correctAnswers.isEmpty) {
      LoggerService.warning(
        'Cannot handle flip mode selection: no trivia available',
      );
      return FlipModeSelectionResult.noAction();
    }

    final words = currentTrivia.words;
    final correctAnswers = currentTrivia.correctAnswers;

    // Ensure _flippedTiles is initialized
    if (_flippedTiles.isEmpty && shuffledWords.isNotEmpty) {
      _flippedTiles = List.filled(shuffledWords.length, true);
      _flipCurrentIndex = 0;
    }

    // Find the index of the selected word
    int wordIndex = shuffledWordsMap[word] ?? -1;
    if (wordIndex == -1) {
      wordIndex = shuffledWords.indexOf(word);
      if (wordIndex == -1) {
        wordIndex = words.indexOf(word);
        if (wordIndex == -1) {
          LoggerService.warning('Warning: Word "$word" not found');
          return FlipModeSelectionResult.noAction();
        }
      }
    }

    // Already selected all expected correct answers
    if (_flipModeSelectedOrder.length >= expectedCorrectAnswers) {
      return FlipModeSelectionResult.noAction();
    }

    // Check if this is the next correct answer in order
    final int expectedOrderIndex = _flipModeSelectedOrder.length;
    if (expectedOrderIndex >= correctAnswers.length) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ Warning: Expected order index $expectedOrderIndex exceeds correctAnswers length',
        );
      }
      return FlipModeSelectionResult.noAction();
    }

    final String expectedWord = correctAnswers[expectedOrderIndex];
    final normalizedWord = word.trim().toLowerCase();
    final normalizedExpected = expectedWord.trim().toLowerCase();
    final normalizedCorrectAnswers =
        correctAnswers.map((w) => w.trim().toLowerCase()).toSet();
    final bool isCorrect = normalizedWord == normalizedExpected &&
        normalizedCorrectAnswers.contains(normalizedWord);

    // Handle reveal based on mode
    if (_flipRevealModeIsInstant) {
      // Instant: Flip tile immediately
      if (wordIndex >= 0 &&
          wordIndex < _flippedTiles.length &&
          !_flippedTiles[wordIndex]) {
        _flippedTiles[wordIndex] = true;
      }

      if (isCorrect) {
        if (!_flipModeSelectedOrder.contains(word)) {
          onAddToFlipModeSelectedOrder(word);
          onAddToSelectedAnswers(word);
          if (_flipModeSelectedOrder.length == expectedCorrectAnswers) {
            return FlipModeSelectionResult.submitPerfect();
          }
          return FlipModeSelectionResult.correct();
        }
      } else {
        return FlipModeSelectionResult.wrong();
      }
    } else {
      // Blind: Track selection, reveal later
      if (_flipModeSelectedOrder.length >= expectedCorrectAnswers) {
        return FlipModeSelectionResult.noAction();
      }
      if (!_flipModeSelectedOrder.contains(word)) {
        onAddToFlipModeSelectedOrder(word);
        onAddToSelectedAnswers(word);
        if (_flipModeSelectedOrder.length == expectedCorrectAnswers) {
          return FlipModeSelectionResult.revealResults();
        }
        return FlipModeSelectionResult.selected();
      }
    }

    return FlipModeSelectionResult.noAction();
  }

  /// Add word to flip mode selected order
  void addToFlipModeSelectedOrder(String word) {
    if (!_flipModeSelectedOrder.contains(word)) {
      _flipModeSelectedOrder.add(word);
    }
  }

  /// Reveal flip mode results (for blind mode)
  ///
  /// Flips all selected tiles and checks if the selection is perfect.
  /// Returns true if perfect, false otherwise.
  bool revealFlipModeResults({
    required TriviaItem? currentTrivia,
    required List<String> shuffledWords,
    required Map<String, int> shuffledWordsMap,
    required int expectedCorrectAnswers,
  }) {
    final words = currentTrivia?.words ?? [];
    final correctAnswers = currentTrivia?.correctAnswers ?? [];

    // Flip all selected tiles
    for (final selectedWord in _flipModeSelectedOrder) {
      int index = shuffledWordsMap[selectedWord] ?? -1;
      if (index == -1) {
        index = shuffledWords.indexOf(selectedWord);
        if (index == -1) {
          index = words.indexOf(selectedWord);
        }
      }
      if (index >= 0 && index < _flippedTiles.length) {
        _flippedTiles[index] = true;
      } else if (index >= 0 && index >= _flippedTiles.length) {
        if (kDebugMode) {
          debugPrint(
            '⚠️ Warning: Index $index out of bounds for flippedTiles',
          );
        }
      }
    }

    // Check if all are correct and in order
    final normalizedSelected =
        _flipModeSelectedOrder.map((w) => w.trim().toLowerCase()).toList();
    final normalizedCorrect =
        correctAnswers.map((w) => w.trim().toLowerCase()).toList();

    bool isPerfect = normalizedSelected.length == expectedCorrectAnswers &&
        normalizedSelected.length == normalizedCorrect.length;

    if (isPerfect) {
      for (int i = 0; i < normalizedSelected.length; i++) {
        if (normalizedSelected[i] != normalizedCorrect[i]) {
          isPerfect = false;
          break;
        }
      }
    }

    return isPerfect;
  }

  /// Initialize flipped tiles for a new round
  void initializeFlippedTiles(int tilesCount) {
    _flippedTiles = List.filled(tilesCount, true);
    _flipCurrentIndex = 0;
  }

  /// Clear flip mode state
  void clear() {
    _flipModeSelectedOrder.clear();
    _flippedTiles =
        []; // Reassign to empty list instead of clearing (handles fixed-length lists)
    _flipCurrentIndex = 0;
    _flipSequenceId = null;
  }

  /// Reset flip mode state for new round
  void reset() {
    _flipModeSelectedOrder.clear();
    _flipCurrentIndex = 0;
    // Determine reveal mode for this round (if random)
    if (_flipRevealMode == 'random') {
      _flipRevealModeIsInstant = _random.nextBool();
    } else {
      _flipRevealModeIsInstant = _flipRevealMode == 'instant';
    }
  }

  /// Cancel flip timers
  void cancelTimers() {
    _flipInitialTimer?.cancel();
    _flipPeriodicTimer?.cancel();
    _flipInitialTimer = null;
    _flipPeriodicTimer = null;
  }

  /// Dispose resources
  void dispose() {
    cancelTimers();
    clear();
  }
}

/// Result of a flip mode selection operation
class FlipModeSelectionResult {

  const FlipModeSelectionResult({
    required this.action,
    this.message,
  });

  factory FlipModeSelectionResult.noAction() =>
      const FlipModeSelectionResult(action: FlipModeSelectionAction.noAction);

  factory FlipModeSelectionResult.correct() =>
      const FlipModeSelectionResult(action: FlipModeSelectionAction.correct);

  factory FlipModeSelectionResult.wrong() =>
      const FlipModeSelectionResult(action: FlipModeSelectionAction.wrong);

  factory FlipModeSelectionResult.selected() =>
      const FlipModeSelectionResult(action: FlipModeSelectionAction.selected);

  factory FlipModeSelectionResult.submitPerfect() =>
      const FlipModeSelectionResult(
          action: FlipModeSelectionAction.submitPerfect,);

  factory FlipModeSelectionResult.revealResults() =>
      const FlipModeSelectionResult(
          action: FlipModeSelectionAction.revealResults,);
  final FlipModeSelectionAction action;
  final String? message;
}

/// Flip mode selection actions
enum FlipModeSelectionAction {
  noAction,
  correct,
  wrong,
  selected,
  submitPerfect,
  revealResults,
}
