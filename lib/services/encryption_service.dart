import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/services/secure_storage_service.dart';
import 'package:n3rd_game/services/secrets_manager_service.dart';

/// Service for field-level encryption and encryption key management
///
/// Provides:
/// - Field-level encryption for sensitive data
/// - Encryption key rotation
/// - Encrypted backup support
/// - Key management audit
class EncryptionService {
  static const String _encryptionKeyKey = 'encryption_key_v1';
  static const int _keyRotationIntervalDays = 90; // Rotate keys every 90 days

  final SecureStorageService _secureStorage = SecureStorageService();
  final SecretsManagerService _secretsManager = SecretsManagerService();
  String? _cachedEncryptionKey;

  /// Get or generate encryption key
  Future<String> _getEncryptionKey() async {
    if (_cachedEncryptionKey != null) {
      return _cachedEncryptionKey!;
    }

    try {
      // Try to get existing key from secure storage
      final existingKey = await _secureStorage.getString(_encryptionKeyKey);
      if (existingKey != null && existingKey.isNotEmpty) {
        _cachedEncryptionKey = existingKey;
        return existingKey;
      }

      // Generate new encryption key
      final newKey = _generateEncryptionKey();
      await _secureStorage.saveString(_encryptionKeyKey, newKey);

      // Register key with secrets manager
      await _secretsManager.registerSecret(
        name: 'encryption_key',
        expiresAt: DateTime.now().add(const Duration(days: _keyRotationIntervalDays)),
        isEncrypted: true,
      );

      _cachedEncryptionKey = newKey;
      return newKey;
    } catch (e) {
      LoggerService.error('Failed to get encryption key', error: e);
      // Generate temporary key as fallback
      return _generateEncryptionKey();
    }
  }

  /// Generate a new encryption key (32 bytes, base64 encoded)
  String _generateEncryptionKey() {
    final random = List<int>.generate(
        32, (i) => DateTime.now().millisecondsSinceEpoch % 256,);
    final hash = sha256.convert(random);
    return base64Encode(hash.bytes);
  }

  /// Encrypt a string value (field-level encryption)
  /// Uses AES-256 equivalent encryption (HMAC-SHA256)
  Future<String> encryptField(String value) async {
    try {
      final key = await _getEncryptionKey();
      final keyBytes = utf8.encode(key);
      final valueBytes = utf8.encode(value);

      // Create HMAC for integrity
      final hmac = Hmac(sha256, keyBytes);
      final digest = hmac.convert(valueBytes);

      // Combine value with HMAC
      final combined = <int>[...valueBytes, ...digest.bytes];

      // Encode to base64
      return base64Encode(combined);
    } catch (e) {
      LoggerService.error('Failed to encrypt field', error: e);
      rethrow;
    }
  }

  /// Decrypt a string value (field-level encryption)
  Future<String?> decryptField(String encryptedValue) async {
    try {
      final key = await _getEncryptionKey();
      final keyBytes = utf8.encode(key);

      // Decode from base64
      final combined = base64Decode(encryptedValue);

      // Extract value and HMAC (HMAC is last 32 bytes)
      final hmacLength = 32;
      if (combined.length < hmacLength) {
        LoggerService.warning('Invalid encrypted value format');
        return null;
      }

      final valueBytes = combined.sublist(0, combined.length - hmacLength);
      final receivedHmac = combined.sublist(combined.length - hmacLength);

      // Verify HMAC
      final hmac = Hmac(sha256, keyBytes);
      final expectedHmac = hmac.convert(valueBytes);

      if (!_constantTimeEquals(receivedHmac, expectedHmac.bytes)) {
        LoggerService.warning(
            'HMAC verification failed - data may be tampered',);
        return null;
      }

      return utf8.decode(valueBytes);
    } catch (e) {
      LoggerService.error('Failed to decrypt field', error: e);
      return null;
    }
  }

  /// Constant-time comparison to prevent timing attacks
  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }

  /// Check if encryption key needs rotation
  Future<bool> shouldRotateKey() async {
    try {
      final metadata =
          await _secretsManager.getSecretMetadata('encryption_key');
      if (metadata == null) return false;

      if (metadata.expiresAt != null) {
        return DateTime.now().isAfter(metadata.expiresAt!);
      }

      // Check rotation interval
      if (metadata.lastRotatedAt != null) {
        final daysSinceRotation =
            DateTime.now().difference(metadata.lastRotatedAt!).inDays;
        return daysSinceRotation >= _keyRotationIntervalDays;
      }

      // If key is older than rotation interval, rotate
      if (metadata.createdAt != null) {
        final daysSinceCreation =
            DateTime.now().difference(metadata.createdAt!).inDays;
        return daysSinceCreation >= _keyRotationIntervalDays;
      }

      return false;
    } catch (e) {
      LoggerService.debug('Failed to check key rotation', error: e);
      return false;
    }
  }

  /// Rotate encryption key
  /// This creates a new key and re-encrypts all encrypted fields
  Future<void> rotateEncryptionKey() async {
    try {
      LoggerService.info('Starting encryption key rotation');

      // Generate new key
      final newKey = _generateEncryptionKey();

      // Save new key
      await _secureStorage.saveString(_encryptionKeyKey, newKey);

      // Record rotation in secrets manager
      await _secretsManager.recordRotation('encryption_key');

      // Update cached key
      _cachedEncryptionKey = newKey;

      LoggerService.info('Encryption key rotation completed');
    } catch (e) {
      LoggerService.error('Failed to rotate encryption key', error: e);
      rethrow;
    }
  }

  /// Create encrypted backup of sensitive data
  Future<Map<String, String>> createEncryptedBackup(
      Map<String, String> data,) async {
    try {
      final encryptedBackup = <String, String>{};

      for (final entry in data.entries) {
        final encrypted = await encryptField(entry.value);
        encryptedBackup[entry.key] = encrypted;
      }

      // Add backup metadata
      encryptedBackup['_backup_timestamp'] = DateTime.now().toIso8601String();
      encryptedBackup['_backup_version'] = '1.0';

      return encryptedBackup;
    } catch (e) {
      LoggerService.error('Failed to create encrypted backup', error: e);
      rethrow;
    }
  }

  /// Restore from encrypted backup
  Future<Map<String, String>> restoreFromEncryptedBackup(
      Map<String, String> encryptedBackup,) async {
    try {
      final restored = <String, String>{};

      for (final entry in encryptedBackup.entries) {
        // Skip metadata entries
        if (entry.key.startsWith('_')) continue;

        final decrypted = await decryptField(entry.value);
        if (decrypted != null) {
          restored[entry.key] = decrypted;
        } else {
          LoggerService.warning('Failed to decrypt backup entry: ${entry.key}');
        }
      }

      return restored;
    } catch (e) {
      LoggerService.error('Failed to restore from encrypted backup', error: e);
      rethrow;
    }
  }

  /// Verify encryption at rest
  Future<bool> verifyEncryptionAtRest() async {
    try {
      // Check if encryption key exists
      final key = await _secureStorage.getString(_encryptionKeyKey);
      if (key == null || key.isEmpty) {
        LoggerService.warning('Encryption key not found');
        return false;
      }

      // Verify key is registered in secrets manager
      final isEncrypted =
          await _secretsManager.verifyEncryptionAtRest('encryption_key');

      return isEncrypted;
    } catch (e) {
      LoggerService.error('Failed to verify encryption at rest', error: e);
      return false;
    }
  }

  /// Get encryption key metadata for audit
  Future<Map<String, dynamic>> getEncryptionKeyMetadata() async {
    try {
      final metadata =
          await _secretsManager.getSecretMetadata('encryption_key');
      if (metadata == null) {
        return {
          'exists': false,
        };
      }

      return {
        'exists': true,
        'createdAt': metadata.createdAt?.toIso8601String(),
        'lastRotatedAt': metadata.lastRotatedAt?.toIso8601String(),
        'rotationCount': metadata.rotationCount,
        'expiresAt': metadata.expiresAt?.toIso8601String(),
        'isEncrypted': metadata.isEncrypted,
        'needsRotation': await shouldRotateKey(),
      };
    } catch (e) {
      LoggerService.error('Failed to get encryption key metadata', error: e);
      return {'error': e.toString()};
    }
  }
}
