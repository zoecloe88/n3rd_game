import 'package:n3rd_game/exceptions/error_codes.dart';

/// Custom exception classes for the application
/// Exception thrown when authentication fails
class AuthenticationException implements Exception {

  AuthenticationException(
    this.message, {
    this.errorCode,
    this.recoverySuggestion,
  });
  final String message;
  final ErrorCode? errorCode;
  final String? recoverySuggestion;

  @override
  String toString() => message;

  /// Get recovery suggestion
  String? get recovery =>
      recoverySuggestion ??
      (errorCode != null
          ? ErrorRecoverySuggestions.getSuggestion(errorCode!)
          : null);
}

/// Exception thrown when validation fails
class ValidationException implements Exception {

  ValidationException(
    this.message, {
    this.errorCode,
    this.recoverySuggestion,
  });
  final String message;
  final ErrorCode? errorCode;
  final String? recoverySuggestion;

  @override
  String toString() => message;

  /// Get recovery suggestion
  String? get recovery =>
      recoverySuggestion ??
      (errorCode != null
          ? ErrorRecoverySuggestions.getSuggestion(errorCode!)
          : null);
}

/// Exception thrown when game operation fails
class GameException implements Exception {

  GameException(
    this.message, {
    this.errorCode,
    this.recoverySuggestion,
  });
  final String message;
  final ErrorCode? errorCode;
  final String? recoverySuggestion;

  @override
  String toString() => message;

  /// Get recovery suggestion
  String? get recovery =>
      recoverySuggestion ??
      (errorCode != null
          ? ErrorRecoverySuggestions.getSuggestion(errorCode!)
          : null);
}

/// Exception thrown when network operation fails
class NetworkException implements Exception {

  NetworkException(
    this.message, {
    this.errorCode,
    this.recoverySuggestion,
  });
  final String message;
  final ErrorCode? errorCode;
  final String? recoverySuggestion;

  @override
  String toString() => message;

  /// Get recovery suggestion
  String? get recovery =>
      recoverySuggestion ??
      (errorCode != null
          ? ErrorRecoverySuggestions.getSuggestion(errorCode!)
          : null);
}

/// Exception thrown when storage operation fails
class StorageException implements Exception {

  StorageException(
    this.message, {
    this.errorCode,
    this.recoverySuggestion,
  });
  final String message;
  final ErrorCode? errorCode;
  final String? recoverySuggestion;

  @override
  String toString() => message;

  /// Get recovery suggestion
  String? get recovery =>
      recoverySuggestion ??
      (errorCode != null
          ? ErrorRecoverySuggestions.getSuggestion(errorCode!)
          : null);
}

/// Exception thrown when permission is denied
class PermissionException implements Exception {

  PermissionException(
    this.message, {
    this.errorCode,
    this.recoverySuggestion,
  });
  final String message;
  final ErrorCode? errorCode;
  final String? recoverySuggestion;

  @override
  String toString() => message;

  /// Get recovery suggestion
  String? get recovery =>
      recoverySuggestion ??
      (errorCode != null
          ? ErrorRecoverySuggestions.getSuggestion(errorCode!)
          : null);
}
