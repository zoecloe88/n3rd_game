import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Service for managing application settings and preferences.
/// Abstracts SharedPreferences access for better maintainability and testability.
class SettingsService extends ChangeNotifier {
  static const String _keyEmailGameNotifications = 'email_game_notifications';
  static const String _keyEmailLeaderboardUpdates = 'email_leaderboard_updates';
  static const String _keyPushNotifications = 'push_notifications';
  static const String _keyDailyReminders = 'daily_reminders';
  static const String _keyAchievementAlerts = 'achievement_alerts';

  SharedPreferences? _prefs;
  bool _isInitialized = false;

  // Email settings
  bool _emailGameNotifications = true;
  bool _emailLeaderboardUpdates = true;

  // Notification settings
  bool _pushNotifications = true;
  bool _dailyReminders = true;
  bool _achievementAlerts = true;

  bool get isInitialized => _isInitialized;
  bool get emailGameNotifications => _emailGameNotifications;
  bool get emailLeaderboardUpdates => _emailLeaderboardUpdates;
  bool get pushNotifications => _pushNotifications;
  bool get dailyReminders => _dailyReminders;
  bool get achievementAlerts => _achievementAlerts;

  /// Initialize the service and load preferences
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadPreferences();
      _isInitialized = true;
      notifyListeners();
      LoggerService.debug('SettingsService initialized');
    } catch (e) {
      LoggerService.error('Failed to initialize SettingsService', error: e);
      // Continue with defaults if initialization fails
      _isInitialized = true;
    }
  }

  /// Load all preferences from SharedPreferences
  Future<void> _loadPreferences() async {
    _prefs ??= await SharedPreferences.getInstance();

    _emailGameNotifications =
        _prefs!.getBool(_keyEmailGameNotifications) ?? true;
    _emailLeaderboardUpdates =
        _prefs!.getBool(_keyEmailLeaderboardUpdates) ?? true;
    _pushNotifications = _prefs!.getBool(_keyPushNotifications) ?? true;
    _dailyReminders = _prefs!.getBool(_keyDailyReminders) ?? true;
    _achievementAlerts = _prefs!.getBool(_keyAchievementAlerts) ?? true;
  }

  /// Set email game notifications preference
  Future<bool> setEmailGameNotifications(bool value) async {
    if (!_isInitialized) await init();

    try {
      _prefs ??= await SharedPreferences.getInstance();
      final success = await _prefs!.setBool(_keyEmailGameNotifications, value);
      if (success) {
        _emailGameNotifications = value;
        notifyListeners();
        LoggerService.debug('Email game notifications set to: $value');
      }
      return success;
    } catch (e) {
      LoggerService.error('Failed to set email game notifications', error: e);
      return false;
    }
  }

  /// Set email leaderboard updates preference
  Future<bool> setEmailLeaderboardUpdates(bool value) async {
    if (!_isInitialized) await init();

    try {
      _prefs ??= await SharedPreferences.getInstance();
      final success = await _prefs!.setBool(_keyEmailLeaderboardUpdates, value);
      if (success) {
        _emailLeaderboardUpdates = value;
        notifyListeners();
        LoggerService.debug('Email leaderboard updates set to: $value');
      }
      return success;
    } catch (e) {
      LoggerService.error('Failed to set email leaderboard updates', error: e);
      return false;
    }
  }

  /// Set push notifications preference
  Future<bool> setPushNotifications(bool value) async {
    if (!_isInitialized) await init();

    try {
      _prefs ??= await SharedPreferences.getInstance();
      final success = await _prefs!.setBool(_keyPushNotifications, value);
      if (success) {
        _pushNotifications = value;
        notifyListeners();
        LoggerService.debug('Push notifications set to: $value');
      }
      return success;
    } catch (e) {
      LoggerService.error('Failed to set push notifications', error: e);
      return false;
    }
  }

  /// Set daily reminders preference
  Future<bool> setDailyReminders(bool value) async {
    if (!_isInitialized) await init();

    try {
      _prefs ??= await SharedPreferences.getInstance();
      final success = await _prefs!.setBool(_keyDailyReminders, value);
      if (success) {
        _dailyReminders = value;
        notifyListeners();
        LoggerService.debug('Daily reminders set to: $value');
      }
      return success;
    } catch (e) {
      LoggerService.error('Failed to set daily reminders', error: e);
      return false;
    }
  }

  /// Set achievement alerts preference
  Future<bool> setAchievementAlerts(bool value) async {
    if (!_isInitialized) await init();

    try {
      _prefs ??= await SharedPreferences.getInstance();
      final success = await _prefs!.setBool(_keyAchievementAlerts, value);
      if (success) {
        _achievementAlerts = value;
        notifyListeners();
        LoggerService.debug('Achievement alerts set to: $value');
      }
      return success;
    } catch (e) {
      LoggerService.error('Failed to set achievement alerts', error: e);
      return false;
    }
  }

  /// Get a preference value by key (generic method for future extensibility)
  Future<T?> getPreference<T>(String key, T defaultValue) async {
    if (!_isInitialized) await init();

    try {
      _prefs ??= await SharedPreferences.getInstance();

      if (T == bool) {
        return _prefs!.getBool(key) as T? ?? defaultValue;
      } else if (T == int) {
        return _prefs!.getInt(key) as T? ?? defaultValue;
      } else if (T == double) {
        return _prefs!.getDouble(key) as T? ?? defaultValue;
      } else if (T == String) {
        return _prefs!.getString(key) as T? ?? defaultValue;
      } else if (T == List<String>) {
        return _prefs!.getStringList(key) as T? ?? defaultValue;
      }

      return defaultValue;
    } catch (e) {
      LoggerService.error('Failed to get preference: $key', error: e);
      return defaultValue;
    }
  }

  /// Set a preference value by key (generic method for future extensibility)
  Future<bool> setPreference<T>(String key, T value) async {
    if (!_isInitialized) await init();

    try {
      _prefs ??= await SharedPreferences.getInstance();

      if (value is bool) {
        return await _prefs!.setBool(key, value);
      } else if (value is int) {
        return await _prefs!.setInt(key, value);
      } else if (value is double) {
        return await _prefs!.setDouble(key, value);
      } else if (value is String) {
        return await _prefs!.setString(key, value);
      } else if (value is List<String>) {
        return await _prefs!.setStringList(key, value);
      }

      return false;
    } catch (e) {
      LoggerService.error('Failed to set preference: $key', error: e);
      return false;
    }
  }
}







