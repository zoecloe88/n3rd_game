/// Game mode enumeration
///
/// Defines all available game modes with their characteristics.
enum GameMode {
  /// Classic mode: 10s memorize, 20s play
  classic,

  /// Classic II mode: 5s memorize, 10s play
  classicII,

  /// Speed mode: 0s memorize (shown together), 7s play
  speed,

  /// Regular mode: 0s memorize (shown together), 15s play
  regular,

  /// Shuffle mode: 10s memorize, tiles shuffle, 20s play
  shuffle,

  /// Random mode: Random mode each round
  random,

  /// Time Attack mode: 60s continuous play
  timeAttack,

  /// Challenge mode: Progressive difficulty - gets harder each round
  challenge,

  /// Streak mode: Score multiplier increases with perfect rounds
  streak,

  /// Blitz mode: Ultra-fast: 3s memorize, 5s play
  blitz,

  /// Marathon mode: Infinite rounds, progressive difficulty
  marathon,

  /// Perfect mode: Must get all correct answers, wrong = game over
  perfect,

  /// Survival mode: Start with 1 life, gain lives every 3 perfect rounds
  survival,

  /// Precision mode: Wrong selection = lose life immediately
  precision,

  /// AI mode: AI-powered adaptive mode (Premium only)
  ai,

  /// Flip mode: 10s study (4s visible, 6s flipping), 20s play (face-down, correct order)
  flip,

  /// Practice mode: No scoring, unlimited hints (Premium only)
  practice,

  /// Learning mode: Review missed questions (Premium only)
  learning,
}

/// Game mode configuration
///
/// Contains timing and behavior configuration for each game mode.
class ModeConfig {

  const ModeConfig({
    required this.memorizeTime,
    required this.playTime,
    this.showWordsWithQuestion = false,
    this.enableShuffle = false,
    this.enableFlip = false,
    this.flipStartTime = 4,
    this.flipDuration = 6,
  });
  /// Memorize phase duration in seconds
  final int memorizeTime;

  /// Play phase duration in seconds
  final int playTime;

  /// Whether to show words with the question
  final bool showWordsWithQuestion;

  /// Whether shuffle is enabled for this mode
  final bool enableShuffle;

  /// Whether flip mode mechanics are enabled
  final bool enableFlip;

  /// When tiles start flipping (in seconds)
  final int flipStartTime;

  /// How long flipping takes (in seconds)
  final int flipDuration;

  /// Get configuration for a specific game mode
  ///
  /// [mode] - The game mode to get configuration for
  /// [round] - Current round number (used for progressive difficulty modes)
  /// [extendedTimeMultiplier] - Optional multiplier for extended time limits (default: 1.0)
  ///
  /// Returns the appropriate ModeConfig for the given mode and round.
  static ModeConfig getConfig(
    GameMode mode, {
    int round = 1,
    double extendedTimeMultiplier = 1.0,
  }) {
    // Base configurations (will be multiplied by extendedTimeMultiplier if > 1.0)
    ModeConfig baseConfig;
    
    switch (mode) {
        case GameMode.classic:
          baseConfig = const ModeConfig(memorizeTime: 10, playTime: 20);
          break;
        case GameMode.classicII:
          baseConfig = const ModeConfig(memorizeTime: 5, playTime: 10);
          break;
        case GameMode.speed:
          baseConfig = const ModeConfig(
            memorizeTime: 0,
            playTime: 7,
            showWordsWithQuestion: true,
          );
          break;
        case GameMode.regular:
          baseConfig = const ModeConfig(
            memorizeTime: 0,
            playTime: 15,
            showWordsWithQuestion: true,
          );
          break;
        case GameMode.shuffle:
          baseConfig = const ModeConfig(
            memorizeTime: 10,
            playTime: 20,
            enableShuffle: true,
          );
          break;
        case GameMode.random:
          baseConfig = const ModeConfig(memorizeTime: 10, playTime: 20);
          break;
        case GameMode.timeAttack:
          baseConfig = const ModeConfig(memorizeTime: 10, playTime: 20);
          break;
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
          baseConfig = ModeConfig(memorizeTime: memorizeTime, playTime: playTime);
          break;
        case GameMode.streak:
          baseConfig = const ModeConfig(memorizeTime: 10, playTime: 20);
          break;
        case GameMode.blitz:
          baseConfig = const ModeConfig(memorizeTime: 3, playTime: 5);
          break;
        case GameMode.marathon:
          // Progressive difficulty based on round
          if (round <= 5) {
            baseConfig = const ModeConfig(memorizeTime: 10, playTime: 20);
          } else if (round <= 10) {
            baseConfig = const ModeConfig(memorizeTime: 8, playTime: 15);
          } else if (round <= 15) {
            baseConfig = const ModeConfig(memorizeTime: 6, playTime: 12);
          } else {
            baseConfig = const ModeConfig(memorizeTime: 5, playTime: 10);
          }
          break;
        case GameMode.perfect:
          baseConfig = const ModeConfig(memorizeTime: 10, playTime: 20);
          break;
        case GameMode.survival:
          baseConfig = const ModeConfig(memorizeTime: 10, playTime: 20);
          break;
        case GameMode.precision:
          baseConfig = const ModeConfig(memorizeTime: 10, playTime: 20);
          break;
        case GameMode.ai:
          // AI mode timing is determined dynamically by AIModeService
          // Default values here, will be overridden
          baseConfig = const ModeConfig(memorizeTime: 10, playTime: 20);
          break;
        case GameMode.flip:
          baseConfig = const ModeConfig(
            memorizeTime: 10,
            playTime: 20,
            enableFlip: true,
            flipStartTime: 4,
            flipDuration: 6,
          );
          break;
        case GameMode.practice:
          // Practice mode: relaxed timing, no scoring
          baseConfig = const ModeConfig(memorizeTime: 15, playTime: 30);
          break;
        case GameMode.learning:
          // Learning mode: review mode with extended time
          baseConfig = const ModeConfig(memorizeTime: 15, playTime: 30);
          break;
      }
      
      // Apply extended time multiplier if > 1.0 (1.5x multiplier for extended time limits)
      if (extendedTimeMultiplier > 1.0) {
        return ModeConfig(
          memorizeTime: (baseConfig.memorizeTime * extendedTimeMultiplier).round(),
          playTime: (baseConfig.playTime * extendedTimeMultiplier).round(),
          showWordsWithQuestion: baseConfig.showWordsWithQuestion,
          enableShuffle: baseConfig.enableShuffle,
          enableFlip: baseConfig.enableFlip,
          flipStartTime: baseConfig.flipStartTime,
          flipDuration: baseConfig.flipDuration,
        );
      }
      
      return baseConfig;
  }
}

/// Game phase enumeration
///
/// Defines the phases of a game round.
enum GamePhase {
  /// Memorize phase: player studies the words
  memorize,
  
  /// Play phase: player selects answers
  play,
  
  /// Result phase: results are shown
  result,
}

