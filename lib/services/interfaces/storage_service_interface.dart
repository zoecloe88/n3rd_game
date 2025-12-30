/// Interface for storage service
/// Provides contract for storage operations
abstract class StorageServiceInterface {
  /// Get string value
  Future<String?> getString(String key);

  /// Set string value
  Future<bool> setString(String key, String value);

  /// Get int value
  Future<int?> getInt(String key);

  /// Set int value
  Future<bool> setInt(String key, int value);

  /// Get bool value
  Future<bool?> getBool(String key);

  /// Set bool value
  Future<bool> setBool(String key, bool value);

  /// Remove value
  Future<bool> remove(String key);

  /// Clear all values
  Future<bool> clear();

  /// Check if key exists
  Future<bool> containsKey(String key);
}
















