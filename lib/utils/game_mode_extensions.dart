import 'package:n3rd_game/models/game_mode_config.dart';

/// Extension methods for GameMode enum
///
/// Provides consistent string conversion and display methods
/// to replace fragile `toString().split('.').last` patterns.
extension GameModeExtensions on GameMode {
  /// Get the display name of the game mode
  ///
  /// Returns a human-readable name for the game mode.
  /// Example: GameMode.classic -> "classic"
  String get displayName {
    return toString().split('.').last;
  }

  /// Convert to Firestore-compatible string
  ///
  /// Returns the enum name as a string suitable for Firestore queries.
  /// This is the same as displayName but explicitly named for clarity.
  String toFirestoreString() {
    return displayName;
  }

  /// Get a formatted display name with proper capitalization
  ///
  /// Example: GameMode.timeAttack -> "Time Attack"
  String get formattedName {
    final name = displayName;
    // Handle camelCase: timeAttack -> Time Attack
    return name
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => ' ${match.group(1)}',
        )
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? ''
              : word[0].toUpperCase() + word.substring(1).toLowerCase(),
        )
        .join(' ')
        .trim();
  }
}
