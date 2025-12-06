import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

/// Service for securely storing sensitive data using encrypted storage
/// Uses Keychain on iOS and EncryptedSharedPreferences on Android
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Save user email securely
  Future<void> saveEmail(String email) async {
    try {
      await _storage.write(key: 'user_email', value: email);
    } catch (e) {
      debugPrint('Failed to save email securely: $e');
      // Fallback to regular storage if secure storage fails
    }
  }

  /// Get user email securely
  Future<String?> getEmail() async {
    try {
      return await _storage.read(key: 'user_email');
    } catch (e) {
      debugPrint('Failed to read email securely: $e');
      return null;
    }
  }

  /// Save auth token securely
  Future<void> saveAuthToken(String token) async {
    try {
      await _storage.write(key: 'auth_token', value: token);
    } catch (e) {
      debugPrint('Failed to save auth token: $e');
    }
  }

  /// Get auth token securely
  Future<String?> getAuthToken() async {
    try {
      return await _storage.read(key: 'auth_token');
    } catch (e) {
      debugPrint('Failed to read auth token: $e');
      return null;
    }
  }

  /// Delete all secure data (for logout)
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      debugPrint('Failed to clear secure storage: $e');
    }
  }

  /// Delete specific key
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('Failed to delete key $key: $e');
    }
  }
}
