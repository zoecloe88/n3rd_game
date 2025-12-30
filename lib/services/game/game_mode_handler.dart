import 'dart:async';
import 'dart:math';
import 'package:n3rd_game/models/game_mode_config.dart';
import 'package:n3rd_game/config/app_config.dart';
import 'package:n3rd_game/config/game_constants.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Handles mode-specific game logic (shuffle, flip, time attack, etc.)
///
/// This service manages mode-specific behaviors including:
/// - Shuffle sequence management
/// - Flip sequence management
/// - Time attack mode logic
/// - Mode transitions and configurations
class GameModeHandler {
  /// Random number generator
  final Random _random = Random();

  /// Shuffle difficulty level
  String shuffleDifficulty = 'medium';

  /// Shuffle count
  int _shuffleCount = 0;

  /// Whether shuffling is active
  bool _isShuffling = false;

  /// Shuffled words list
  List<String> _shuffledWords = [];

  /// Shuffled words map for O(1) lookups
  Map<String, int> _shuffledWordsMap = {};

  /// Flipped tiles state
  List<bool> _flippedTiles = [];

  /// Current flip index
  int _flipCurrentIndex = 0;

  /// Flip sequence ID (for race condition prevention)
  int? _flipSequenceId;

  /// Flip reveal mode ('instant', 'gradual', 'random')
  String _flipRevealMode = 'instant';

  /// Get shuffle count
  int get shuffleCount => _shuffleCount;

  /// Get whether shuffling is active
  bool get isShuffling => _isShuffling;

  /// Get shuffled words
  List<String> get shuffledWords => List.unmodifiable(_shuffledWords);

  /// Get shuffled words map
  Map<String, int> get shuffledWordsMap => Map.unmodifiable(_shuffledWordsMap);

  /// Get flipped tiles state
  List<bool> get flippedTiles => List.unmodifiable(_flippedTiles);

  /// Get current flip index
  int get flipCurrentIndex => _flipCurrentIndex;

  /// Get flip reveal mode
  String get flipRevealMode => _flipRevealMode;

  /// Set flip reveal mode
  void setFlipRevealMode(String mode) {
    _flipRevealMode = mode;
  }

  /// Check if flip reveal is instant
  bool isFlipRevealInstant() {
    if (_flipRevealMode == 'random') {
      return _random.nextBool();
    }
    return _flipRevealMode == 'instant';
  }

  /// Initialize shuffle sequence
  ///
  /// [words] - Words to shuffle
  /// [onShuffle] - Callback when shuffle occurs
  /// [onComplete] - Callback when shuffle completes
  void initializeShuffle({
    required List<String> words,
    required VoidCallback onShuffle,
    required VoidCallback onComplete,
  }) {
    _shuffledWords = List.from(words);
    _shuffledWordsMap = {};
    for (int i = 0; i < _shuffledWords.length; i++) {
      _shuffledWordsMap[_shuffledWords[i]] = i;
    }
    _shuffleCount = 0;
    _isShuffling = false;
  }

  /// Start shuffle sequence
  ///
  /// [onShuffleTick] - Callback for each shuffle tick
  /// [onComplete] - Callback when shuffle completes
  ///
  /// Returns the shuffle timer (for cancellation)
  Timer startShuffleSequence({
    required VoidCallback onShuffleTick,
    required VoidCallback onComplete,
  }) {
    _isShuffling = true;
    _shuffleCount = 0;

    // Determine shuffle interval based on difficulty
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
      default:
        shuffleInterval = AppConfig.shuffleIntervalMedium;
    }

    return Timer.periodic(Duration(milliseconds: shuffleInterval), (timer) {
      // Perform shuffle
      _shuffledWords.shuffle(_random);

      // Filter empty strings
      _shuffledWords =
          _shuffledWords.where((word) => word.trim().isNotEmpty).toList();

      // Rebuild map
      _shuffledWordsMap = {};
      for (int i = 0; i < _shuffledWords.length; i++) {
        _shuffledWordsMap[_shuffledWords[i]] = i;
      }

      // Increment count (clamp to prevent overflow)
      _shuffleCount =
          (_shuffleCount + 1).clamp(0, GameConstants.maxShuffleCount);

      onShuffleTick();
    });
  }

  /// Stop shuffle sequence
  void stopShuffleSequence() {
    _isShuffling = false;
  }

  /// Initialize flip sequence
  ///
  /// [words] - Words to flip
  /// [totalTiles] - Total number of tiles
  void initializeFlipSequence({
    required List<String> words,
    required int totalTiles,
  }) {
    _shuffledWords = List.from(words);
    _flippedTiles = List.filled(totalTiles, true); // All start face-up
    _flipCurrentIndex = 0;
    _flipSequenceId = DateTime.now().microsecondsSinceEpoch;
  }

  /// Start flip sequence
  ///
  /// [config] - Mode configuration
  /// [onTileFlip] - Callback when a tile flips (receives index)
  ///
  /// Returns initial delay timer and periodic timer
  ({Timer initialTimer, Timer? periodicTimer}) startFlipSequence({
    required ModeConfig config,
    required ValueChanged<int> onTileFlip,
  }) {
    final sequenceId = DateTime.now().microsecondsSinceEpoch;
    _flipSequenceId = sequenceId;

    // Determine reveal mode
    final isInstant = isFlipRevealInstant();

    final flipStartTime = config.flipStartTime;
    final flipDuration = config.flipDuration;
    final tilesToFlip = _shuffledWords.length;

    if (tilesToFlip == 0) {
      LoggerService.warning('Cannot start flip sequence - no tiles to flip');
      return (initialTimer: Timer(Duration.zero, () {}), periodicTimer: null);
    }

    // If instant reveal, flip all tiles immediately
    if (isInstant) {
      for (int i = 0; i < tilesToFlip && i < _flippedTiles.length; i++) {
        _flippedTiles[i] = false;
        onTileFlip(i);
      }
      _flipCurrentIndex = tilesToFlip;
      return (initialTimer: Timer(Duration.zero, () {}), periodicTimer: null);
    }

    // Calculate flip interval for gradual reveal
    int flipInterval = (flipDuration * 1000) ~/ tilesToFlip;
    if (flipInterval <= 0) {
      flipInterval = 1; // Minimum 1ms
    }

    Timer? periodicTimer;

    final initialTimer = Timer(Duration(seconds: flipStartTime), () {
      if (_flipSequenceId != sequenceId) return;

      periodicTimer =
          Timer.periodic(Duration(milliseconds: flipInterval), (timer) {
        if (_flipSequenceId != sequenceId) {
          timer.cancel();
          return;
        }

        if (_flipCurrentIndex < tilesToFlip) {
          if (_flipCurrentIndex < _flippedTiles.length) {
            _flippedTiles[_flipCurrentIndex] = false;
            onTileFlip(_flipCurrentIndex);
            _flipCurrentIndex++;
          }
        } else {
          timer.cancel();
        }
      });
    });

    return (initialTimer: initialTimer, periodicTimer: periodicTimer);
  }

  /// Reset flip sequence
  void resetFlipSequence() {
    _flipCurrentIndex = 0;
    _flipSequenceId = null;
  }

  /// Reset all mode-specific state
  void reset() {
    _shuffleCount = 0;
    _isShuffling = false;
    _shuffledWords = [];
    _shuffledWordsMap = {};
    _flippedTiles = [];
    _flipCurrentIndex = 0;
    _flipSequenceId = null;
  }
}
