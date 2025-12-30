import 'package:flutter/foundation.dart';
import 'package:n3rd_game/models/game_state.dart';
import 'package:n3rd_game/services/daily_challenge_leaderboard_service.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Manages competitive challenge state and submission
///
/// Handles competitive challenge tracking, pause/resume time management,
/// and score submission with retry logic.
class GameCompetitiveChallengeManager {
  // Competitive challenge state
  String? competitiveChallengeId;
  DateTime? competitiveChallengeStartTime;
  DateTime? competitiveChallengePauseTime;
  int competitiveChallengePausedDuration = 0;
  int? competitiveChallengeTargetRounds;
  bool competitiveChallengeScoreSubmitted = false;

  /// Set competitive challenge
  ///
  /// Initializes challenge tracking with the given challenge ID and optional target rounds.
  /// Resets previous challenge state and session stats.
  void setCompetitiveChallenge(
    String challengeId, {
    int? targetRounds,
    VoidCallback? onResetSessionStats,
    VoidCallback? onResetGameStartTime,
    VoidCallback? onNotifyListeners,
  }) {
    // Validate challenge ID
    if (challengeId.isEmpty) {
      LoggerService.warning('Invalid challenge ID: empty string');
      return;
    }

    // Validate target rounds
    if (targetRounds != null && (targetRounds <= 0 || targetRounds > 100)) {
      LoggerService.warning(
        'Invalid target rounds: $targetRounds (must be 1-100);',
      );
      return;
    }

    // Prevent setting new challenge if submission is in progress
    // CRITICAL: Check BEFORE resetting state to prevent corruption
    if (competitiveChallengeScoreSubmitted) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ Warning: Cannot set new competitive challenge while previous submission is in progress',
        );
      }
      return;
    }

    competitiveChallengeId = challengeId;
    competitiveChallengeTargetRounds = targetRounds;
    competitiveChallengeStartTime =
        DateTime.now().toUtc(); // Use UTC for consistency
    competitiveChallengePauseTime = null;
    competitiveChallengePausedDuration = 0;

    // Reset session stats when starting a competitive challenge
    // This ensures accuracy only includes rounds from this challenge
    onResetSessionStats?.call();

    // Reset game start time for marathon mode tracking (if applicable)
    onResetGameStartTime?.call();

    onNotifyListeners?.call();
  }

  /// Submit competitive challenge score when game ends
  ///
  /// Returns SubmissionResponse with result details.
  /// Only resets tracking on successful submission to allow retry on failure.
  Future<SubmissionResponse> submitCompetitiveChallengeScore({
    required GameState state,
    required int sessionCorrectAnswers,
    required int sessionWrongAnswers,
    required bool isLoadingState,
    required DailyChallengeLeaderboardService leaderboardService,
    required VoidCallback onSaveState,
    int maxRetries = 3,
  }) async {
    // CRITICAL: Prevent submission during state loading to avoid using incomplete/stale session stats
    // Session stats are restored in loadState() and must be complete before submission
    if (isLoadingState) {
      LoggerService.warning(
        'Cannot submit competitive challenge score: State is currently being loaded',
      );
      return SubmissionResponse(
        SubmissionResult.unknownError,
        'Cannot submit while state is loading',
      );
    }

    if (competitiveChallengeId == null ||
        competitiveChallengeStartTime == null) {
      return SubmissionResponse(
        SubmissionResult.unknownError,
        'No active challenge',
      );
    }

    // Prevent duplicate submissions
    if (competitiveChallengeScoreSubmitted) {
      LoggerService.debug('Score already submitted for this challenge');
      return SubmissionResponse(
        SubmissionResult.unknownError,
        'Score already submitted',
      );
    }

    // Set submission flag immediately to prevent concurrent submissions
    competitiveChallengeScoreSubmitted = true;

    final challengeId = competitiveChallengeId!;
    SubmissionResponse lastResponse = SubmissionResponse(
      SubmissionResult.unknownError,
      'Unknown error',
    );

    // Retry logic with exponential backoff for network errors
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        // Validate challenge exists before submission
        final validationError = await leaderboardService.validateChallenge(
          challengeId,
        );
        if (validationError != null) {
          LoggerService.error('Challenge validation failed: $validationError');
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
            .difference(competitiveChallengeStartTime!)
            .inSeconds;
        // If currently paused, add the current pause duration
        int currentPauseDuration = 0;
        if (competitiveChallengePauseTime != null) {
          // CRITICAL: Use UTC for pause time calculation to match start time (UTC)
          currentPauseDuration = DateTime.now()
              .toUtc()
              .difference(competitiveChallengePauseTime!.toUtc())
              .inSeconds;
        }
        final completionTime = totalElapsed -
            competitiveChallengePausedDuration -
            currentPauseDuration;

        // Calculate accuracy first (before handling negative time)
        final accuracy = sessionCorrectAnswers + sessionWrongAnswers > 0
            ? (sessionCorrectAnswers /
                    (sessionCorrectAnswers + sessionWrongAnswers)) *
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
          score: state.score,
          completionTime: finalCompletionTime,
          accuracy: accuracy,
        );

        // If successful, reset tracking
        if (response.isSuccess) {
          // Reset tracking only on success
          competitiveChallengeId = null;
          competitiveChallengeStartTime = null;
          competitiveChallengePauseTime = null;
          competitiveChallengePausedDuration = 0;
          competitiveChallengeTargetRounds = null;
          competitiveChallengeScoreSubmitted = false;
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
          competitiveChallengeScoreSubmitted = false;
          // Save state with reset flag so user can retry later
          onSaveState();
          // Return a clear error response indicating retry exhaustion
          return SubmissionResponse(
            response.result,
            'Submission failed after $maxRetries attempts. Please try again later.',
          );
        }

        return response;
      } catch (e) {
        // Reset flag on exception to allow retry
        competitiveChallengeScoreSubmitted = false;

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
    competitiveChallengeScoreSubmitted = false;
    onSaveState();
    // Note: This handles cases where the loop exits without returning a response
    if (!lastResponse.isSuccess) {
      if (kDebugMode) {
        debugPrint(
          'Competitive challenge submission failed after all retries: ${lastResponse.message}',
        );
      }
    }

    return lastResponse;
  }

  /// Reset competitive challenge state
  void reset() {
    competitiveChallengeId = null;
    competitiveChallengeStartTime = null;
    competitiveChallengePauseTime = null;
    competitiveChallengePausedDuration = 0;
    competitiveChallengeTargetRounds = null;
    competitiveChallengeScoreSubmitted = false;
  }
}













