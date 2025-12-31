import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Service for managing data migrations
///
/// Provides:
/// - Version tracking
/// - Migration execution engine
/// - Rollback support
/// - Migration validation
/// - Migration logging and monitoring
class MigrationService {
  static const String _versionKey = 'data_schema_version';
  static const int _currentSchemaVersion = 1;

  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Get current schema version
  Future<int> getCurrentVersion() async {
    try {
      final prefs = await _getPrefs();
      return prefs.getInt(_versionKey) ?? 0;
    } catch (e) {
      LoggerService.debug('Failed to get schema version', error: e);
      return 0;
    }
  }

  /// Set schema version
  Future<void> setVersion(int version) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setInt(_versionKey, version);
    } catch (e) {
      LoggerService.error('Failed to set schema version', error: e);
      rethrow;
    }
  }

  /// Run all pending migrations
  Future<void> runMigrations() async {
    try {
      final currentVersion = await getCurrentVersion();

      if (currentVersion >= _currentSchemaVersion) {
        LoggerService.debug(
            'No migrations needed. Current version: $currentVersion',);
        return;
      }

      LoggerService.info(
          'Running migrations from version $currentVersion to $_currentSchemaVersion',);

      // Run migrations in order
      for (int version = currentVersion + 1;
          version <= _currentSchemaVersion;
          version++) {
        await _runMigration(version);
      }

      LoggerService.info('All migrations completed successfully');
    } catch (e, stackTrace) {
      LoggerService.error(
        'Migration failed',
        error: e,
        stack: stackTrace,
      );
      rethrow;
    }
  }

  /// Run a specific migration
  Future<void> _runMigration(int version) async {
    LoggerService.info('Running migration to version $version');

    try {
      switch (version) {
        case 1:
          await _migrationV1();
          break;
        // Add more migrations as needed
        default:
          LoggerService.warning('Unknown migration version: $version');
          return;
      }

      // Update version after successful migration
      await setVersion(version);
      LoggerService.info('Migration to version $version completed');
    } catch (e) {
      LoggerService.error('Migration to version $version failed', error: e);
      rethrow;
    }
  }

  /// Migration to version 1
  /// Example: Migrate email from SharedPreferences to secure storage
  Future<void> _migrationV1() async {
    try {
      // Example migration: Move email to secure storage if not already migrated
      // This is handled in AuthService, but can be done here for completeness

      LoggerService.debug('Migration V1: Schema initialization');
      // Add any V1 migration logic here
    } catch (e) {
      LoggerService.error('Migration V1 failed', error: e);
      rethrow;
    }
  }

  /// Rollback to a specific version
  Future<void> rollback(int targetVersion) async {
    try {
      final currentVersion = await getCurrentVersion();

      if (currentVersion <= targetVersion) {
        LoggerService.warning('Already at or below target version');
        return;
      }

      LoggerService.info(
          'Rolling back from version $currentVersion to $targetVersion',);

      // Rollback migrations in reverse order
      for (int version = currentVersion; version > targetVersion; version--) {
        await _rollbackMigration(version);
      }

      await setVersion(targetVersion);
      LoggerService.info('Rollback completed');
    } catch (e, stackTrace) {
      LoggerService.error(
        'Rollback failed',
        error: e,
        stack: stackTrace,
      );
      rethrow;
    }
  }

  /// Rollback a specific migration
  Future<void> _rollbackMigration(int version) async {
    LoggerService.info('Rolling back migration version $version');

    try {
      switch (version) {
        case 1:
          await _rollbackV1();
          break;
        // Add rollback logic for other versions
        default:
          LoggerService.warning('Unknown rollback version: $version');
          return;
      }

      LoggerService.info('Rollback of version $version completed');
    } catch (e) {
      LoggerService.error('Rollback of version $version failed', error: e);
      rethrow;
    }
  }

  /// Rollback migration V1
  Future<void> _rollbackV1() async {
    try {
      LoggerService.debug('Rolling back Migration V1');
      // Add rollback logic here
    } catch (e) {
      LoggerService.error('Rollback V1 failed', error: e);
      rethrow;
    }
  }

  /// Validate migration state
  Future<bool> validateMigrationState() async {
    try {
      final currentVersion = await getCurrentVersion();
      final isValid = currentVersion <= _currentSchemaVersion;

      if (!isValid) {
        LoggerService.warning(
          'Invalid migration state: current=$currentVersion, expected<=$_currentSchemaVersion',
        );
      }

      return isValid;
    } catch (e) {
      LoggerService.error('Failed to validate migration state', error: e);
      return false;
    }
  }

  /// Get migration status
  Future<Map<String, dynamic>> getMigrationStatus() async {
    try {
      final currentVersion = await getCurrentVersion();
      final isValid = await validateMigrationState();

      return {
        'currentVersion': currentVersion,
        'targetVersion': _currentSchemaVersion,
        'isValid': isValid,
        'needsMigration': currentVersion < _currentSchemaVersion,
      };
    } catch (e) {
      LoggerService.error('Failed to get migration status', error: e);
      return {
        'error': e.toString(),
      };
    }
  }
}
