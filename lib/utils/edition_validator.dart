/// Utility class for validating and normalizing edition IDs
class EditionValidator {
  /// Validates edition ID format
  /// Returns true if valid, false otherwise
  /// Valid format: lowercase alphanumeric, underscore, hyphen only
  static bool isValidEditionId(String? editionId) {
    if (editionId == null || editionId.isEmpty) return false;
    // Allow alphanumeric, underscore, hyphen
    return RegExp(r'^[a-z0-9_-]+$').hasMatch(editionId);
  }

  /// Normalizes edition ID to standard format
  /// Converts to lowercase, replaces spaces with underscores, removes invalid characters
  static String normalizeEditionId(String id) {
    return id
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-z0-9_-]'), '');
  }
}
















