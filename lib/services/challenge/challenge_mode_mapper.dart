import 'package:n3rd_game/models/game_mode_config.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/exceptions/error_codes.dart';

/// Service for mapping challenge mode strings to GameMode enum
///
/// Centralizes mode mapping logic and provides error handling for invalid modes.
class ChallengeModeMapper {
  /// Map challenge mode string to GameMode enum
  ///
  /// Throws ValidationException if mode string is invalid.
  static GameMode? mapModeString(String? modeString) {
    if (modeString == null || modeString.isEmpty) {
      return null;
    }

    switch (modeString) {
      case 'Blitz':
        return GameMode.blitz;
      case 'Speed':
        return GameMode.speed;
      case 'Classic':
        return GameMode.classic;
      case 'Streak':
        return GameMode.streak;
      case 'Shuffle':
        return GameMode.shuffle;
      case 'TimeAttack':
      case 'Time Attack':
        return GameMode.timeAttack;
      default:
        throw ValidationException(
          'Invalid challenge mode: $modeString',
          errorCode: ErrorCode.validationInvalidType,
          recoverySuggestion:
              'Please use a valid game mode (Blitz, Speed, Classic, Streak, Shuffle, or TimeAttack).',
        );
    }
  }

  /// Map GameMode enum to challenge mode string
  static String mapGameModeToString(GameMode mode) {
    switch (mode) {
      case GameMode.blitz:
        return 'Blitz';
      case GameMode.speed:
        return 'Speed';
      case GameMode.classic:
        return 'Classic';
      case GameMode.streak:
        return 'Streak';
      case GameMode.shuffle:
        return 'Shuffle';
      case GameMode.timeAttack:
        return 'TimeAttack';
      default:
        return mode.toString().split('.').last;
    }
  }

  /// Validate mode string
  ///
  /// Returns true if mode string is valid, false otherwise.
  static bool isValidModeString(String? modeString) {
    if (modeString == null || modeString.isEmpty) {
      return false;
    }

    try {
      mapModeString(modeString);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get all valid mode strings
  static List<String> getValidModeStrings() {
    return ['Blitz', 'Speed', 'Classic', 'Streak', 'Shuffle', 'TimeAttack'];
  }
}













