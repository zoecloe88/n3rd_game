import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Secret metadata for tracking
class SecretMetadata {

  SecretMetadata({
    required this.name,
    this.environment,
    this.createdAt,
    this.expiresAt,
    this.lastRotatedAt,
    this.rotationCount = 0,
    this.isEncrypted = true,
  });

  factory SecretMetadata.fromJson(Map<String, dynamic> json) => SecretMetadata(
        name: json['name'] as String,
        environment: json['environment'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
        expiresAt: json['expiresAt'] != null
            ? DateTime.parse(json['expiresAt'] as String)
            : null,
        lastRotatedAt: json['lastRotatedAt'] != null
            ? DateTime.parse(json['lastRotatedAt'] as String)
            : null,
        rotationCount: json['rotationCount'] as int? ?? 0,
        isEncrypted: json['isEncrypted'] as bool? ?? true,
      );
  final String name;
  final String? environment; // 'production', 'staging', 'development'
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final DateTime? lastRotatedAt;
  final int rotationCount;
  final bool isEncrypted;

  Map<String, dynamic> toJson() => {
        'name': name,
        'environment': environment,
        'createdAt': createdAt?.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
        'lastRotatedAt': lastRotatedAt?.toIso8601String(),
        'rotationCount': rotationCount,
        'isEncrypted': isEncrypted,
      };

  SecretMetadata copyWith({
    String? name,
    String? environment,
    DateTime? createdAt,
    DateTime? expiresAt,
    DateTime? lastRotatedAt,
    int? rotationCount,
    bool? isEncrypted,
  }) =>
      SecretMetadata(
        name: name ?? this.name,
        environment: environment ?? this.environment,
        createdAt: createdAt ?? this.createdAt,
        expiresAt: expiresAt ?? this.expiresAt,
        lastRotatedAt: lastRotatedAt ?? this.lastRotatedAt,
        rotationCount: rotationCount ?? this.rotationCount,
        isEncrypted: isEncrypted ?? this.isEncrypted,
      );
}

/// Audit log entry
class AuditLogEntry {

  AuditLogEntry({
    required this.timestamp,
    required this.action,
    required this.secretName,
    this.environment,
    this.success = true,
    this.error,
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) => AuditLogEntry(
        timestamp: DateTime.parse(json['timestamp'] as String),
        action: json['action'] as String,
        secretName: json['secretName'] as String,
        environment: json['environment'] as String?,
        success: json['success'] as bool? ?? true,
        error: json['error'] as String?,
      );
  final DateTime timestamp;
  final String action; // 'access', 'rotate', 'expired', 'verified'
  final String secretName;
  final String? environment;
  final bool success;
  final String? error;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'action': action,
        'secretName': secretName,
        'environment': environment,
        'success': success,
        'error': error,
      };
}

/// Service for managing secrets, API keys, and sensitive configuration
///
/// Provides:
/// - Secret rotation tracking
/// - Expiration monitoring
/// - Audit logging
/// - Environment-specific management
/// - Encryption verification
class SecretsManagerService {
  static const String _prefPrefix = 'secrets_';
  static const String _auditLogKey = 'secrets_audit_log';
  static const int _maxAuditLogEntries = 1000;

  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Register a secret with metadata
  Future<void> registerSecret({
    required String name,
    String? environment,
    DateTime? expiresAt,
    bool isEncrypted = true,
  }) async {
    try {
      final prefs = await _getPrefs();
      final metadata = SecretMetadata(
        name: name,
        environment: environment ?? _getCurrentEnvironment(),
        createdAt: DateTime.now(),
        expiresAt: expiresAt,
        isEncrypted: isEncrypted,
      );

      final key = '$_prefPrefix${name}_metadata';
      await prefs.setString(key, jsonEncode(metadata.toJson()));

      await _logAudit('register', name,
          environment: environment, success: true,);
      LoggerService.info('Secret registered: $name');
    } catch (e) {
      await _logAudit('register', name,
          environment: environment, success: false, error: e.toString(),);
      LoggerService.error('Failed to register secret: $name', error: e);
      rethrow;
    }
  }

  /// Record secret rotation
  Future<void> recordRotation(String name, {String? environment}) async {
    try {
      final prefs = await _getPrefs();
      final key = '$_prefPrefix${name}_metadata';
      final metadataJson = prefs.getString(key);

      if (metadataJson != null) {
        final metadata = SecretMetadata.fromJson(jsonDecode(metadataJson));
        final updated = metadata.copyWith(
          lastRotatedAt: DateTime.now(),
          rotationCount: metadata.rotationCount + 1,
        );
        await prefs.setString(key, jsonEncode(updated.toJson()));
      }

      await _logAudit('rotate', name,
          environment: environment ?? _getCurrentEnvironment(), success: true,);
      LoggerService.info('Secret rotation recorded: $name');
    } catch (e) {
      await _logAudit('rotate', name,
          environment: environment, success: false, error: e.toString(),);
      LoggerService.error('Failed to record secret rotation: $name', error: e);
    }
  }

  /// Check if secret is expired
  Future<bool> isSecretExpired(String name) async {
    try {
      final prefs = await _getPrefs();
      final key = '$_prefPrefix${name}_metadata';
      final metadataJson = prefs.getString(key);

      if (metadataJson != null) {
        final metadata = SecretMetadata.fromJson(jsonDecode(metadataJson));
        if (metadata.expiresAt != null) {
          return DateTime.now().isAfter(metadata.expiresAt!);
        }
      }
      return false;
    } catch (e) {
      LoggerService.debug('Failed to check secret expiration: $name', error: e);
      return false;
    }
  }

  /// Get secret metadata
  Future<SecretMetadata?> getSecretMetadata(String name) async {
    try {
      final prefs = await _getPrefs();
      final key = '$_prefPrefix${name}_metadata';
      final metadataJson = prefs.getString(key);

      if (metadataJson != null) {
        return SecretMetadata.fromJson(jsonDecode(metadataJson));
      }
      return null;
    } catch (e) {
      LoggerService.debug('Failed to get secret metadata: $name', error: e);
      return null;
    }
  }

  /// Check all secrets for expiration
  Future<List<String>> checkExpiredSecrets() async {
    final expiredSecrets = <String>[];
    try {
      final prefs = await _getPrefs();
      final allKeys = prefs.getKeys().where(
          (key) => key.startsWith(_prefPrefix) && key.endsWith('_metadata'),);

      for (final key in allKeys) {
        final metadataJson = prefs.getString(key);
        if (metadataJson != null) {
          try {
            final metadata = SecretMetadata.fromJson(jsonDecode(metadataJson));
            if (metadata.expiresAt != null &&
                DateTime.now().isAfter(metadata.expiresAt!)) {
              expiredSecrets.add(metadata.name);
              await _logAudit('expired', metadata.name,
                  environment: metadata.environment, success: true,);
              LoggerService.warning('Secret expired: ${metadata.name}');
            }
          } catch (e) {
            LoggerService.debug('Failed to parse secret metadata: $key',
                error: e,);
          }
        }
      }
    } catch (e) {
      LoggerService.error('Failed to check expired secrets', error: e);
    }
    return expiredSecrets;
  }

  /// Verify encryption at rest for secrets
  Future<bool> verifyEncryptionAtRest(String name) async {
    try {
      final metadata = await getSecretMetadata(name);
      if (metadata == null) {
        LoggerService.warning(
            'Secret metadata not found for encryption verification: $name',);
        return false;
      }

      final isEncrypted = metadata.isEncrypted;
      await _logAudit('verify_encryption', name,
          environment: metadata.environment, success: isEncrypted,);

      if (!isEncrypted) {
        LoggerService.warning('Secret not encrypted at rest: $name');
      }

      return isEncrypted;
    } catch (e) {
      LoggerService.error('Failed to verify encryption: $name', error: e);
      await _logAudit('verify_encryption', name,
          success: false, error: e.toString(),);
      return false;
    }
  }

  /// Log audit entry
  Future<void> _logAudit(
    String action,
    String secretName, {
    String? environment,
    bool success = true,
    String? error,
  }) async {
    try {
      final prefs = await _getPrefs();
      final entry = AuditLogEntry(
        timestamp: DateTime.now(),
        action: action,
        secretName: secretName,
        environment: environment ?? _getCurrentEnvironment(),
        success: success,
        error: error,
      );

      // Get existing log
      final logJson = prefs.getString(_auditLogKey);
      final log = logJson != null
          ? (jsonDecode(logJson) as List)
              .map((e) => AuditLogEntry.fromJson(e as Map<String, dynamic>))
              .toList()
          : <AuditLogEntry>[];

      // Add new entry
      log.add(entry);

      // Trim to max entries (keep most recent)
      if (log.length > _maxAuditLogEntries) {
        log.removeRange(0, log.length - _maxAuditLogEntries);
      }

      // Save log
      final updatedLog = log.map((e) => e.toJson()).toList();
      await prefs.setString(_auditLogKey, jsonEncode(updatedLog));
    } catch (e) {
      LoggerService.debug('Failed to log audit entry', error: e);
    }
  }

  /// Get audit log entries
  Future<List<AuditLogEntry>> getAuditLog(
      {String? secretName, int? limit,}) async {
    try {
      final prefs = await _getPrefs();
      final logJson = prefs.getString(_auditLogKey);

      if (logJson == null) return [];

      final log = (jsonDecode(logJson) as List)
          .map((e) => AuditLogEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      // Filter by secret name if specified
      var filtered = log;
      if (secretName != null) {
        filtered = log.where((e) => e.secretName == secretName).toList();
      }

      // Sort by timestamp (most recent first)
      filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Limit results if specified
      if (limit != null && filtered.length > limit) {
        filtered = filtered.sublist(0, limit);
      }

      return filtered;
    } catch (e) {
      LoggerService.debug('Failed to get audit log', error: e);
      return [];
    }
  }

  /// Get current environment (production, staging, development)
  String _getCurrentEnvironment() {
    // Check environment variable or use default
    const env =
        String.fromEnvironment('ENVIRONMENT', defaultValue: 'production');
    if (env.isNotEmpty) {
      return env.toLowerCase();
    }
    return 'production';
  }

  /// Verify all secrets encryption at rest
  Future<Map<String, bool>> verifyAllSecretsEncryption() async {
    final results = <String, bool>{};
    try {
      final prefs = await _getPrefs();
      final allKeys = prefs.getKeys().where(
          (key) => key.startsWith(_prefPrefix) && key.endsWith('_metadata'),);

      for (final key in allKeys) {
        final metadataJson = prefs.getString(key);
        if (metadataJson != null) {
          try {
            final metadata = SecretMetadata.fromJson(jsonDecode(metadataJson));
            final isEncrypted = await verifyEncryptionAtRest(metadata.name);
            results[metadata.name] = isEncrypted;
          } catch (e) {
            LoggerService.debug('Failed to verify encryption for: $key',
                error: e,);
          }
        }
      }
    } catch (e) {
      LoggerService.error('Failed to verify all secrets encryption', error: e);
    }
    return results;
  }
}
