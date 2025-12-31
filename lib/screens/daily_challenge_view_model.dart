import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:n3rd_game/services/challenge_service.dart';
import 'package:n3rd_game/services/daily_challenge_leaderboard_service.dart';
import 'package:n3rd_game/services/challenge/challenge_mode_mapper.dart';
import 'package:n3rd_game/models/daily_challenge.dart';
import 'package:n3rd_game/models/game_mode_config.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';

/// ViewModel for DailyChallengesScreen
///
/// Manages UI state, handles loading states, error states, and debounces operations.
class DailyChallengeViewModel extends ChangeNotifier {

  DailyChallengeViewModel({
    required ChallengeService challengeService,
    required DailyChallengeLeaderboardService leaderboardService,
  })  : _challengeService = challengeService,
        _leaderboardService = leaderboardService {
    // Initialize leaderboard service if needed
    unawaited(_leaderboardService.init());
  }
  final ChallengeService _challengeService;
  final DailyChallengeLeaderboardService _leaderboardService;

  bool _isLoading = false;
  String? _errorMessage;
  Timer? _refreshDebounceTimer;
  static const Duration _refreshDebounceDelay = Duration(milliseconds: 500);

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<DailyChallenge> get challenges => _challengeService.challenges;
  List<DailyChallenge> get todayChallenges => _challengeService.todayChallenges;

  /// Refresh leaderboard with debouncing
  void refreshLeaderboard() {
    _refreshDebounceTimer?.cancel();
    _refreshDebounceTimer = Timer(_refreshDebounceDelay, () {
      notifyListeners();
    });
  }

  /// Play competitive challenge
  /// Returns GameMode if successful, null if error
  Future<GameMode?> playCompetitiveChallenge(DailyChallenge challenge) async {
    if (_isLoading) {
      LoggerService.warning('Challenge play already in progress');
      return null;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Validate challenge type
      if (challenge.type != ChallengeType.dailyCompetitive) {
        _errorMessage =
            'Invalid challenge type. Only competitive challenges can be played.';
        return null;
      }

      // Validate challenge date
      final today = DateTime.now().toUtc();
      final challengeDate = challenge.date.toUtc();
      if (challengeDate.year != today.year ||
          challengeDate.month != today.month ||
          challengeDate.day != today.day) {
        _errorMessage = 'This challenge is not available today.';
        return null;
      }

      // Get target mode
      final targetMode = challenge.target['mode'] as String?;

      // Map challenge mode string to GameMode
      GameMode? gameMode;
      try {
        gameMode = ChallengeModeMapper.mapModeString(targetMode);
      } on ValidationException catch (e) {
        _errorMessage = e.message;
        return null;
      }

      if (gameMode == null) {
        _errorMessage = 'Invalid challenge mode. Please try again.';
        return null;
      }

      // Check attempt count
      final attemptCount =
          await _leaderboardService.getAttemptCount(challenge.id, null);
      if (attemptCount >= 5) {
        _errorMessage = 'Maximum attempts (5) reached for this challenge.';
        return null;
      }

      return gameMode;
    } catch (e, stack) {
      LoggerService.error('Error playing competitive challenge',
          error: e, stack: stack,);
      _errorMessage = 'Failed to start challenge. Please try again.';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get attempt count for a challenge
  Future<int> getAttemptCount(String challengeId) async {
    try {
      return await _leaderboardService.getAttemptCount(challengeId, null);
    } catch (e) {
      LoggerService.error('Error getting attempt count', error: e);
      return 0;
    }
  }

  /// Get top 5 leaderboard for a challenge
  Future<List<DailyChallengeLeaderboardEntry>> getTop5Leaderboard(
      String challengeId,) async {
    try {
      return await _leaderboardService.getTop5Leaderboard(
          challengeId: challengeId,);
    } catch (e) {
      LoggerService.error('Error getting leaderboard', error: e);
      return [];
    }
  }

  /// Get user rank for a challenge
  Future<int?> getUserRank(String challengeId, String userId) async {
    try {
      return await _leaderboardService.getUserRank(
        challengeId: challengeId,
        userId: userId,
      );
    } catch (e) {
      LoggerService.error('Error getting user rank', error: e);
      return null;
    }
  }

  @override
  void dispose() {
    _refreshDebounceTimer?.cancel();
    super.dispose();
  }
}

// Helper function for unawaited futures
void unawaited(Future<void> future) {
  // Intentionally not awaiting
}
