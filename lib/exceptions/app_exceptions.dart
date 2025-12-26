/// Custom exception classes for the application
/// Exception thrown when authentication fails
class AuthenticationException implements Exception {
  final String message;
  AuthenticationException(this.message);

  @override
  String toString() => message;
}

/// Exception thrown when validation fails
class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);

  @override
  String toString() => message;
}

/// Exception thrown when game operation fails
class GameException implements Exception {
  final String message;
  GameException(this.message);

  @override
  String toString() => message;
}

/// Exception thrown when network operation fails
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);

  @override
  String toString() => message;
}

/// Exception thrown when storage operation fails
class StorageException implements Exception {
  final String message;
  StorageException(this.message);

  @override
  String toString() => message;
}

/// Exception thrown when permission is denied
class PermissionException implements Exception {
  final String message;
  PermissionException(this.message);

  @override
  String toString() => message;
}
