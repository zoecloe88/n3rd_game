import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/models/daily_challenge.dart';
import 'package:n3rd_game/services/challenge/challenge_repository.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/exceptions/error_codes.dart';

/// Local storage implementation of ChallengeRepository
///
/// Uses SharedPreferences for offline support and caching.
class LocalChallengeRepository implements ChallengeRepository {
  static const String _storageKey = 'daily_challenges';
  static const int _maxCachedChallenges = 1000; // Limit cache size

  @override
  bool get isAvailable => true; // SharedPreferences is always available

  @override
  Future<List<DailyChallenge>> loadChallenges(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);

      if (jsonString == null) {
        return [];
      }

      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final challengesList = data['challenges'] as List?;

      if (challengesList == null) {
        return [];
      }

      final challenges = challengesList
          .map((c) => DailyChallenge.fromJson(c as Map<String, dynamic>))
          .toList();

      // Limit cache size if exceeded
      if (challenges.length > _maxCachedChallenges) {
        LoggerService.warning(
          'Challenge cache exceeded limit ($_maxCachedChallenges), truncating',
        );
        final truncated = challenges.take(_maxCachedChallenges).toList();
        await saveChallenges(userId: userId, challenges: truncated);
        return truncated;
      }

      return challenges;
    } catch (e, stack) {
      LoggerService.error('Failed to load challenges from local storage',
          error: e, stack: stack,);
      throw StorageException(
        'Failed to load challenges from local storage',
        errorCode: ErrorCode.storageReadFailed,
        recoverySuggestion: 'Please try again later.',
      );
    }
  }

  @override
  Future<void> saveChallenges({
    required String userId,
    required List<DailyChallenge> challenges,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Limit cache size
      final challengesToSave = challenges.length > _maxCachedChallenges
          ? challenges.take(_maxCachedChallenges).toList()
          : challenges;

      final data = {
        'challenges': challengesToSave.map((c) => c.toJson()).toList(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await prefs.setString(_storageKey, jsonEncode(data));
    } catch (e, stack) {
      LoggerService.error('Failed to save challenges to local storage',
          error: e, stack: stack,);
      throw StorageException(
        'Failed to save challenges to local storage',
        errorCode: ErrorCode.storageWriteFailed,
        recoverySuggestion: 'Please try again later.',
      );
    }
  }

  @override
  Future<void> updateChallenge({
    required String userId,
    required DailyChallenge challenge,
  }) async {
    try {
      final challenges = await loadChallenges(userId);
      final index = challenges.indexWhere((c) => c.id == challenge.id);

      if (index == -1) {
        challenges.add(challenge);
      } else {
        challenges[index] = challenge;
      }

      await saveChallenges(userId: userId, challenges: challenges);
    } catch (e) {
      // Re-throw storage exceptions
      if (e is StorageException) rethrow;

      LoggerService.error('Failed to update challenge in local storage',
          error: e,);
      throw StorageException(
        'Failed to update challenge in local storage',
        errorCode: ErrorCode.storageWriteFailed,
        recoverySuggestion: 'Please try again later.',
      );
    }
  }
}













