/// Standardized error code system for the application
///
/// Error codes are categorized by domain:
/// - AUTH_*: Authentication errors
/// - NETWORK_*: Network errors
/// - GAME_*: Game logic errors
/// - VALIDATION_*: Input validation errors
/// - STORAGE_*: Storage/persistence errors
/// - SUBSCRIPTION_*: Subscription/payment errors
/// - ANALYTICS_*: Analytics errors
/// - SYSTEM_*: System-level errors
enum ErrorCode {
  // Authentication errors (AUTH_001 - AUTH_099)
  authUserNotFound('AUTH_001', 'User not found'),
  authInvalidCredentials('AUTH_002', 'Invalid email or password'),
  authEmailAlreadyInUse('AUTH_003', 'Email already in use'),
  authWeakPassword('AUTH_004', 'Password does not meet requirements'),
  authInvalidEmail('AUTH_005', 'Invalid email format'),
  authUserDisabled('AUTH_006', 'User account is disabled'),
  authTooManyRequests('AUTH_007', 'Too many requests. Please try again later'),
  authTokenExpired('AUTH_008', 'Authentication token expired'),
  authTokenInvalid('AUTH_009', 'Invalid authentication token'),
  authSessionExpired('AUTH_009', 'Session expired. Please log in again'),

  // Network errors (NETWORK_001 - NETWORK_099)
  networkNoConnection('NETWORK_001', 'No internet connection'),
  networkTimeout('NETWORK_002', 'Request timed out'),
  networkServerError('NETWORK_003', 'Server error. Please try again later'),
  networkBadRequest('NETWORK_004', 'Invalid request'),
  networkUnauthorized('NETWORK_005', 'Unauthorized access'),
  networkForbidden('NETWORK_006', 'Access forbidden'),
  networkNotFound('NETWORK_007', 'Resource not found'),
  networkCertificateError('NETWORK_008', 'Certificate validation failed'),
  networkConnectionRefused('NETWORK_009', 'Connection refused'),

  // Game logic errors (GAME_001 - GAME_099)
  gameInvalidTriviaPool('GAME_001', 'Invalid trivia pool'),
  gameNoTriviaAvailable('GAME_002', 'No trivia items available'),
  gameInvalidRound('GAME_003', 'Invalid round state'),
  gameStateCorrupted('GAME_004', 'Game state is corrupted'),
  gameSaveFailed('GAME_005', 'Failed to save game state'),
  gameLoadFailed('GAME_006', 'Failed to load game state'),
  gameInvalidAnswer('GAME_007', 'Invalid answer selection'),
  gameRoundStartFailed('GAME_008', 'Failed to start round'),
  gameTimerError('GAME_009', 'Timer error occurred'),

  // Validation errors (VALIDATION_001 - VALIDATION_099)
  validationEmptyField('VALIDATION_001', 'Field cannot be empty'),
  validationInvalidFormat('VALIDATION_002', 'Invalid format'),
  validationTooLong('VALIDATION_003', 'Value is too long'),
  validationTooShort('VALIDATION_004', 'Value is too short'),
  validationOutOfRange('VALIDATION_005', 'Value is out of range'),
  validationInvalidType('VALIDATION_006', 'Invalid data type'),
  validationMissingRequired('VALIDATION_007', 'Required field is missing'),

  // Storage errors (STORAGE_001 - STORAGE_099)
  storageReadFailed('STORAGE_001', 'Failed to read from storage'),
  storageWriteFailed('STORAGE_002', 'Failed to write to storage'),
  storageDeleteFailed('STORAGE_003', 'Failed to delete from storage'),
  storageQuotaExceeded('STORAGE_004', 'Storage quota exceeded'),
  storagePermissionDenied('STORAGE_005', 'Storage permission denied'),

  // Subscription errors (SUBSCRIPTION_001 - SUBSCRIPTION_099)
  subscriptionNotActive('SUBSCRIPTION_001', 'Subscription is not active'),
  subscriptionPurchaseFailed('SUBSCRIPTION_002', 'Purchase failed'),
  subscriptionRestoreFailed('SUBSCRIPTION_003', 'Failed to restore purchases'),
  subscriptionInvalidProduct('SUBSCRIPTION_004', 'Invalid product ID'),
  subscriptionNetworkError('SUBSCRIPTION_005', 'Subscription network error'),

  // Analytics errors (ANALYTICS_001 - ANALYTICS_099)
  analyticsLogFailed('ANALYTICS_001', 'Failed to log analytics event'),
  analyticsInitializationFailed(
      'ANALYTICS_002', 'Analytics initialization failed',),

  // System errors (SYSTEM_001 - SYSTEM_099)
  systemUnknown('SYSTEM_001', 'Unknown system error'),
  systemOutOfMemory('SYSTEM_002', 'Out of memory'),
  systemPermissionDenied('SYSTEM_003', 'Permission denied'),
  systemFeatureUnavailable('SYSTEM_004', 'Feature unavailable on this device'),

  // Friend errors (FRIEND_001 - FRIEND_099)
  friendNotFound('FRIEND_001', 'Friend not found'),
  friendRequestAlreadySent('FRIEND_002', 'Friend request already sent'),
  friendRequestNotFound('FRIEND_003', 'Friend request not found'),
  friendMaxRequestsReached('FRIEND_004', 'Maximum friend requests reached'),
  friendRateLimitExceeded(
      'FRIEND_005', 'Too many friend operations. Please wait a moment.',),
  friendSearchFailed('FRIEND_006', 'Failed to search for friends'),
  friendInviteFailed('FRIEND_007', 'Failed to send invitation'),
  friendReportFailed('FRIEND_008', 'Failed to submit report'),
  friendBlockFailed('FRIEND_009', 'Failed to block user'),
  friendUnblockFailed('FRIEND_010', 'Failed to unblock user'),

  // Multiplayer errors (MULTIPLAYER_001 - MULTIPLAYER_099)
  multiplayerRateLimitExceeded('MULTIPLAYER_001',
      'Too many multiplayer operations. Please wait a moment.',),
  multiplayerRoomNotFound('MULTIPLAYER_002', 'Game room not found'),
  multiplayerRoomFull('MULTIPLAYER_003', 'Room is full'),
  multiplayerNotInRoom('MULTIPLAYER_004', 'You are not a member of this room'),
  multiplayerInvalidScore('MULTIPLAYER_005', 'Invalid score submission'),
  multiplayerScoreValidationFailed(
      'MULTIPLAYER_006', 'Score validation failed',),
  multiplayerHostOnly(
      'MULTIPLAYER_007', 'Only the host can perform this action',),
  multiplayerNotReady('MULTIPLAYER_008', 'Not all players are ready'),
  multiplayerReconnectionFailed(
      'MULTIPLAYER_009', 'Failed to reconnect to room',),
  multiplayerSpectatorLimitReached(
      'MULTIPLAYER_010', 'Maximum number of spectators reached',),

  // Generic errors
  unknownError('UNKNOWN_001', 'An unknown error occurred');

  const ErrorCode(this.code, this.message);

  /// Error code string (e.g., "AUTH_001")
  final String code;

  /// Human-readable error message
  final String message;

  /// Get error code by string code
  static ErrorCode? fromCode(String code) {
    try {
      return ErrorCode.values.firstWhere(
        (e) => e.code == code,
        orElse: () => ErrorCode.unknownError,
      );
    } catch (e) {
      return ErrorCode.unknownError;
    }
  }

  /// Get all error codes for a category
  static List<ErrorCode> getCategory(String prefix) {
    return ErrorCode.values.where((e) => e.code.startsWith(prefix)).toList();
  }
}

/// Error recovery suggestions
class ErrorRecoverySuggestions {
  static const Map<ErrorCode, String> suggestions = {
    ErrorCode.authUserNotFound:
        'Please check your email and try again, or create a new account.',
    ErrorCode.authInvalidCredentials:
        'Please check your email and password and try again.',
    ErrorCode.authEmailAlreadyInUse:
        'This email is already registered. Please log in or use a different email.',
    ErrorCode.authWeakPassword:
        'Password must be at least 8 characters with uppercase, lowercase, number, and special character.',
    ErrorCode.networkNoConnection:
        'Please check your internet connection and try again.',
    ErrorCode.networkTimeout:
        'The request took too long. Please check your connection and try again.',
    ErrorCode.networkServerError:
        'The server is experiencing issues. Please try again in a few moments.',
    ErrorCode.gameInvalidTriviaPool:
        'Please restart the game or select a different mode.',
    ErrorCode.gameStateCorrupted:
        'Your game state may be corrupted. Starting a new game.',
    ErrorCode.storageReadFailed:
        'Failed to read saved data. Some features may not work correctly.',
    ErrorCode.storageWriteFailed: 'Failed to save data. Please try again.',
    ErrorCode.subscriptionPurchaseFailed:
        'Purchase could not be completed. Please check your payment method and try again.',
    ErrorCode.friendNotFound:
        'This user could not be found. Please check the email or username and try again.',
    ErrorCode.friendRequestAlreadySent:
        'You have already sent a friend request to this user.',
    ErrorCode.friendRequestNotFound:
        'This friend request may have been cancelled or expired.',
    ErrorCode.friendMaxRequestsReached:
        'You have reached the maximum number of friend requests. Please wait before sending more.',
    ErrorCode.friendRateLimitExceeded:
        'Too many friend operations. Please wait a moment before trying again.',
    ErrorCode.friendSearchFailed:
        'Failed to search for friends. Please check your connection and try again.',
    ErrorCode.friendInviteFailed:
        'Failed to send invitation. Please check your connection and try again.',
    ErrorCode.friendReportFailed:
        'Failed to submit report. Please try again later.',
    ErrorCode.friendBlockFailed:
        'Failed to block user. Please try again later.',
    ErrorCode.friendUnblockFailed:
        'Failed to unblock user. Please try again later.',
    ErrorCode.multiplayerRateLimitExceeded:
        'Too many multiplayer operations. Please wait a moment before trying again.',
    ErrorCode.multiplayerRoomNotFound:
        'The game room could not be found. It may have been deleted or expired.',
    ErrorCode.multiplayerRoomFull:
        'This room is full. Please join a different room or create your own.',
    ErrorCode.multiplayerNotInRoom:
        'You are not a member of this room. Please join the room first.',
    ErrorCode.multiplayerInvalidScore:
        'Invalid score submission. Please try again.',
    ErrorCode.multiplayerScoreValidationFailed:
        'Score validation failed. Please try again or contact support if the issue persists.',
    ErrorCode.multiplayerHostOnly:
        'Only the room host can perform this action.',
    ErrorCode.multiplayerNotReady:
        'Not all players are ready. Please wait for all players to be ready.',
    ErrorCode.multiplayerReconnectionFailed:
        'Failed to reconnect to the room. Please try joining again.',
    ErrorCode.multiplayerSpectatorLimitReached:
        'Maximum number of spectators reached. Please try again later.',
  };

  /// Get recovery suggestion for an error code
  static String? getSuggestion(ErrorCode code) {
    return suggestions[code];
  }
}
