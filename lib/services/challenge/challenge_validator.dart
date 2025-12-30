import 'package:n3rd_game/models/daily_challenge.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/exceptions/error_codes.dart';

/// Service for validating challenge data
///
/// Centralizes validation logic for challenges to ensure consistency.
class ChallengeValidator {
  static const int _maxChallengeIdLength = 512;
  static const int _maxTitleLength = 200;
  static const int _maxDescriptionLength = 500;
  static const int _minRewardPoints = 0;
  static const int _maxRewardPoints = 10000;
  static const int _minProgress = 0;
  static const int _maxProgress = 1000000;

  /// Validate challenge ID
  static void validateChallengeId(String challengeId) {
    if (challengeId.isEmpty) {
      throw ValidationException(
        'Challenge ID cannot be empty',
        errorCode: ErrorCode.validationEmptyField,
        recoverySuggestion: 'Please provide a valid challenge ID.',
      );
    }

    if (challengeId.length > _maxChallengeIdLength) {
      throw ValidationException(
        'Challenge ID is too long (max $_maxChallengeIdLength characters)',
        errorCode: ErrorCode.validationTooLong,
        recoverySuggestion: 'Please use a shorter challenge ID.',
      );
    }
  }

  /// Validate challenge date
  static void validateChallengeDate(DateTime date) {
    if (date.isAfter(DateTime.now().add(const Duration(days: 365)))) {
      throw ValidationException(
        'Challenge date cannot be more than 1 year in the future',
        errorCode: ErrorCode.validationOutOfRange,
        recoverySuggestion: 'Please use a valid date.',
      );
    }

    if (date.isBefore(DateTime.now().subtract(const Duration(days: 365)))) {
      throw ValidationException(
        'Challenge date cannot be more than 1 year in the past',
        errorCode: ErrorCode.validationOutOfRange,
        recoverySuggestion: 'Please use a valid date.',
      );
    }
  }

  /// Validate challenge title
  static void validateTitle(String title) {
    if (title.isEmpty) {
      throw ValidationException(
        'Challenge title cannot be empty',
        errorCode: ErrorCode.validationEmptyField,
        recoverySuggestion: 'Please provide a challenge title.',
      );
    }

    if (title.length > _maxTitleLength) {
      throw ValidationException(
        'Challenge title is too long (max $_maxTitleLength characters)',
        errorCode: ErrorCode.validationTooLong,
        recoverySuggestion: 'Please use a shorter title.',
      );
    }
  }

  /// Validate challenge description
  static void validateDescription(String description) {
    if (description.isEmpty) {
      throw ValidationException(
        'Challenge description cannot be empty',
        errorCode: ErrorCode.validationEmptyField,
        recoverySuggestion: 'Please provide a challenge description.',
      );
    }

    if (description.length > _maxDescriptionLength) {
      throw ValidationException(
        'Challenge description is too long (max $_maxDescriptionLength characters)',
        errorCode: ErrorCode.validationTooLong,
        recoverySuggestion: 'Please use a shorter description.',
      );
    }
  }

  /// Validate challenge type
  static void validateChallengeType(ChallengeType type) {
    if (!ChallengeType.values.contains(type)) {
      throw ValidationException(
        'Invalid challenge type',
        errorCode: ErrorCode.validationInvalidType,
        recoverySuggestion: 'Please use a valid challenge type.',
      );
    }
  }

  /// Validate challenge target
  static void validateChallengeTarget(Map<String, dynamic> target) {
    if (target.isEmpty) {
      throw ValidationException(
        'Challenge target cannot be empty',
        errorCode: ErrorCode.validationEmptyField,
        recoverySuggestion: 'Please provide challenge target data.',
      );
    }

    // Validate specific target fields based on challenge type
    // This is a basic validation - more specific validation can be added
    for (final value in target.values) {
      if (value is String && value.length > 200) {
        throw ValidationException(
          'Challenge target value is too long',
          errorCode: ErrorCode.validationTooLong,
          recoverySuggestion: 'Please use shorter target values.',
        );
      }
    }
  }

  /// Validate reward points
  static void validateRewardPoints(int rewardPoints) {
    if (rewardPoints < _minRewardPoints) {
      throw ValidationException(
        'Reward points cannot be negative',
        errorCode: ErrorCode.validationOutOfRange,
        recoverySuggestion: 'Please use a valid reward point value.',
      );
    }

    if (rewardPoints > _maxRewardPoints) {
      throw ValidationException(
        'Reward points cannot exceed $_maxRewardPoints',
        errorCode: ErrorCode.validationOutOfRange,
        recoverySuggestion: 'Please use a valid reward point value.',
      );
    }
  }

  /// Validate progress
  static void validateProgress(int progress) {
    if (progress < _minProgress) {
      throw ValidationException(
        'Progress cannot be negative',
        errorCode: ErrorCode.validationOutOfRange,
        recoverySuggestion: 'Please use a valid progress value.',
      );
    }

    if (progress > _maxProgress) {
      throw ValidationException(
        'Progress cannot exceed $_maxProgress',
        errorCode: ErrorCode.validationOutOfRange,
        recoverySuggestion: 'Please use a valid progress value.',
      );
    }
  }

  /// Validate a complete challenge
  static void validateChallenge(DailyChallenge challenge) {
    validateChallengeId(challenge.id);
    validateTitle(challenge.title);
    validateDescription(challenge.description);
    validateChallengeType(challenge.type);
    validateChallengeTarget(challenge.target);
    validateChallengeDate(challenge.date);
    validateRewardPoints(challenge.rewardPoints);
    validateProgress(challenge.progress);
  }
}













