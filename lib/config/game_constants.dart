/// Game constants for consistent configuration across the codebase
class GameConstants {
  // Trivia validation constants
  static const int expectedCorrectAnswers =
      3; // Expected number of correct answers per trivia item
  static const int requiredWordsForGameplay =
      6; // REQUIRED: Must have exactly 6 words (3 correct + 3 distractors)

  // Recursion depth limits
  static const int maxRecursionDepthGameService =
      5; // Max recursion depth for GameService trivia validation
  static const int maxRecursionDepthTriviaGenerator =
      3; // Max recursion depth for TriviaGeneratorService

  // Trivia selection constants
  static const int maxRecentCategories =
      5; // Number of recent categories to track to avoid repeats
  static const int maxCandidateAttempts =
      10; // Max attempts to find valid candidate trivia item

  // Validation constants
  static const int minTemplateCount =
      100; // Minimum number of templates required
  static const int minCombinations =
      20700000; // Minimum total combinations required (20.7M+)
  static const int maxWordLength =
      50; // Maximum word length to prevent UI overflow issues

  // Timing constants
  static const int nextRoundAutoAdvanceDelaySeconds =
      2; // Delay before auto-advancing to next round after result phase
  static const int flipModeInstantRevealDelayMilliseconds =
      100; // Delay before revealing correct answer in flip mode instant reveal
  static const int timeFreezeDurationSeconds =
      10; // Duration of time freeze power-up in seconds

  // Marathon mode limits (prevent infinite resource consumption)
  static const int marathonModeMaxRounds =
      100; // Maximum rounds in marathon mode before graceful completion
  static const int marathonModeMaxDurationMinutes =
      120; // Maximum duration (2 hours) in marathon mode before graceful completion

  // Trivia pool management
  static const int triviaPoolAutoRegenerateThreshold =
      5; // Auto-regenerate pool when items fall below this count

  // State persistence failure tracking
  static const int maxConsecutiveSaveFailures =
      3; // Max consecutive save failures before showing user notification

  // Prevent instantiation
  GameConstants._();
}
