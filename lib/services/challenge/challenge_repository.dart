import 'package:n3rd_game/models/daily_challenge.dart';

/// Abstract repository interface for challenge storage
///
/// Allows for easier testing and potential future storage backends.
abstract class ChallengeRepository {
  /// Load challenges for a user
  Future<List<DailyChallenge>> loadChallenges(String userId);

  /// Save challenges for a user
  Future<void> saveChallenges({
    required String userId,
    required List<DailyChallenge> challenges,
  });

  /// Update a single challenge
  Future<void> updateChallenge({
    required String userId,
    required DailyChallenge challenge,
  });

  /// Check if repository is available (e.g., Firebase initialized)
  bool get isAvailable;
}













