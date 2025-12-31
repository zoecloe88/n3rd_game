import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/exceptions/error_codes.dart';
import 'package:n3rd_game/utils/input_sanitizer.dart';

/// Service for validating friend-related data
///
/// Provides centralized validation logic for all friend-related inputs,
/// ensuring data integrity and security. All validation methods throw
/// `ValidationException` with appropriate error codes if validation fails.
///
/// **Validation Rules:**
/// - Email: 5-254 characters, valid email format
/// - Phone: 10-15 digits, normalized format
/// - User ID: 10-128 characters, alphanumeric
/// - Report Reason: 10-500 characters, sanitized text
/// - Display Name: 1-50 characters, sanitized
/// - Search Query: Max 100 characters, sanitized
///
/// **Usage:**
/// ```dart
/// try {
///   final email = FriendsValidator.validateEmail(userInput);
///   // Use validated email
/// } on ValidationException catch (e) {
///   // Handle validation error
/// }
/// ```
class FriendsValidator {
  static const int _minEmailLength = 5;
  static const int _maxEmailLength = 254;
  static const int _minPhoneLength = 10;
  static const int _maxPhoneLength = 15;
  static const int _minUserIdLength = 10;
  static const int _maxUserIdLength = 128;
  static const int _minReportReasonLength = 10;
  static const int _maxReportReasonLength = 500;
  static const int _minDisplayNameLength = 1;
  static const int _maxDisplayNameLength = 50;

  /// Validate email address
  static String validateEmail(String email) {
    if (email.isEmpty) {
      throw ValidationException(
        'Email cannot be empty',
        errorCode: ErrorCode.validationEmptyField,
      );
    }

    if (email.length < _minEmailLength || email.length > _maxEmailLength) {
      throw ValidationException(
        'Email must be between $_minEmailLength and $_maxEmailLength characters',
        errorCode: ErrorCode.validationOutOfRange,
      );
    }

    // Sanitize email
    final sanitized = InputSanitizer.sanitizeEmail(email);
    if (sanitized == null) {
      throw ValidationException(
        'Invalid email format',
        errorCode: ErrorCode.validationInvalidFormat,
        recoverySuggestion: 'Please enter a valid email address.',
      );
    }

    return sanitized;
  }

  /// Validate phone number
  static String validatePhone(String phone) {
    if (phone.isEmpty) {
      throw ValidationException(
        'Phone number cannot be empty',
        errorCode: ErrorCode.validationEmptyField,
      );
    }

    // Normalize phone number (remove spaces, dashes, etc.)
    final normalized = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    if (normalized.length < _minPhoneLength ||
        normalized.length > _maxPhoneLength) {
      throw ValidationException(
        'Phone number must be between $_minPhoneLength and $_maxPhoneLength digits',
        errorCode: ErrorCode.validationOutOfRange,
      );
    }

    // Check if phone contains only digits
    if (!RegExp(r'^\d+$').hasMatch(normalized)) {
      throw ValidationException(
        'Phone number must contain only digits',
        errorCode: ErrorCode.validationInvalidFormat,
        recoverySuggestion: 'Please enter a valid phone number.',
      );
    }

    return normalized;
  }

  /// Validate user ID
  static void validateUserId(String userId) {
    if (userId.isEmpty) {
      throw ValidationException(
        'User ID cannot be empty',
        errorCode: ErrorCode.validationEmptyField,
      );
    }

    if (userId.length < _minUserIdLength || userId.length > _maxUserIdLength) {
      throw ValidationException(
        'User ID must be between $_minUserIdLength and $_maxUserIdLength characters',
        errorCode: ErrorCode.validationOutOfRange,
      );
    }

    // Sanitize user ID
    final sanitized = InputSanitizer.sanitizeText(userId);
    if (sanitized != userId) {
      throw ValidationException(
        'User ID contains invalid characters',
        errorCode: ErrorCode.validationInvalidFormat,
      );
    }
  }

  /// Validate report reason
  static String validateReportReason(String reason) {
    if (reason.isEmpty) {
      throw ValidationException(
        'Report reason cannot be empty',
        errorCode: ErrorCode.validationEmptyField,
      );
    }

    if (reason.length < _minReportReasonLength ||
        reason.length > _maxReportReasonLength) {
      throw ValidationException(
        'Report reason must be between $_minReportReasonLength and $_maxReportReasonLength characters',
        errorCode: ErrorCode.validationOutOfRange,
      );
    }

    // Sanitize report reason
    final sanitized = InputSanitizer.sanitizeText(reason);
    if (sanitized != reason) {
      throw ValidationException(
        'Report reason contains invalid characters',
        errorCode: ErrorCode.validationInvalidFormat,
      );
    }

    return sanitized;
  }

  /// Validate display name
  static String validateDisplayName(String displayName) {
    if (displayName.isEmpty) {
      throw ValidationException(
        'Display name cannot be empty',
        errorCode: ErrorCode.validationEmptyField,
      );
    }

    if (displayName.length < _minDisplayNameLength ||
        displayName.length > _maxDisplayNameLength) {
      throw ValidationException(
        'Display name must be between $_minDisplayNameLength and $_maxDisplayNameLength characters',
        errorCode: ErrorCode.validationOutOfRange,
      );
    }

    // Sanitize display name
    final sanitized = InputSanitizer.sanitizeDisplayName(displayName);
    if (sanitized.isEmpty) {
      throw ValidationException(
        'Display name contains only invalid characters',
        errorCode: ErrorCode.validationInvalidFormat,
      );
    }

    return sanitized;
  }

  /// Validate search query
  static String validateSearchQuery(String query) {
    if (query.isEmpty) {
      throw ValidationException(
        'Search query cannot be empty',
        errorCode: ErrorCode.validationEmptyField,
      );
    }

    if (query.length > 100) {
      throw ValidationException(
        'Search query must be less than 100 characters',
        errorCode: ErrorCode.validationTooLong,
      );
    }

    // Sanitize search query
    return InputSanitizer.sanitizeText(query);
  }

  /// Validate that two user IDs are different
  static void validateDifferentUsers(String userId1, String userId2) {
    if (userId1 == userId2) {
      throw ValidationException(
        'Cannot perform operation on yourself',
        errorCode: ErrorCode.validationInvalidFormat,
        recoverySuggestion: 'Please select a different user.',
      );
    }
  }
}
