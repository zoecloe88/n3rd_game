import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Service for securely storing sensitive data using encrypted storage
/// Uses Keychain on iOS and EncryptedSharedPreferences on Android
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions.defaultOptions,
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Save user email securely
  Future<void> saveEmail(String email) async {
    try {
      await _storage.write(key: 'user_email', value: email);
    } catch (e) {
      LoggerService.error('Failed to save email securely', error: e);
      // Fallback to regular storage if secure storage fails
    }
  }

  /// Get user email securely
  Future<String?> getEmail() async {
    try {
      return await _storage.read(key: 'user_email');
    } catch (e) {
      LoggerService.error('Failed to read email securely', error: e);
      return null;
    }
  }

  /// Save auth token securely
  Future<void> saveAuthToken(String token) async {
    try {
      await _storage.write(key: 'auth_token', value: token);
    } catch (e) {
      LoggerService.error('Failed to save auth token', error: e);
    }
  }

  /// Get auth token securely
  Future<String?> getAuthToken() async {
    try {
      return await _storage.read(key: 'auth_token');
    } catch (e) {
      LoggerService.error('Failed to read auth token', error: e);
      return null;
    }
  }

  /// Delete all secure data (for logout)
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      LoggerService.error('Failed to clear secure storage', error: e);
    }
  }

  /// Delete specific key
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      LoggerService.error('Failed to delete key $key', error: e);
    }
  }

  /// Save a generic string value securely
  Future<void> saveString(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      LoggerService.error('Failed to save string securely', error: e);
    }
  }

  /// Get a generic string value securely
  Future<String?> getString(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      LoggerService.error('Failed to read string securely', error: e);
      return null;
    }
  }
}
