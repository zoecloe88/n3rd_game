import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Service for managing feature flags and remote configuration
///
/// Provides:
/// - Firebase Remote Config integration
/// - Feature flag management
/// - Gradual rollouts and A/B testing infrastructure
/// - Feature flag analytics tracking
class FeatureFlagService extends ChangeNotifier {
  FeatureFlagService._();

  static FeatureFlagService? _instance;

  static FeatureFlagService get instance {
    _instance ??= FeatureFlagService._();
    return _instance!;
  }

  FirebaseRemoteConfig? _remoteConfig;
  bool _initialized = false;
  SharedPreferences? _prefs;
  Timer? _refreshTimer;

  // Default feature flag values (fallback if Remote Config unavailable)
  static const Map<String, dynamic> _defaultFlags = {
    'enable_biometric_auth': true,
    'enable_mfa': false,
    'enable_advanced_analytics': true,
    'enable_experimental_features': false,
    'enable_ai_trivia_generation': true,
    'enable_multiplayer': true,
    'enable_daily_challenges': true,
    'enable_leaderboards': true,
    'enable_social_features': true,
    'enable_premium_features': true,
    'max_trivia_generation_per_day': 20,
    'enable_offline_mode': true,
    'enable_push_notifications': true,
    'enable_deep_linking': true,
  };

  // Cache for feature flags
  final Map<String, dynamic> _flagCache = {};

  bool get isInitialized => _initialized;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Initialize Firebase Remote Config
  Future<void> init() async {
    if (_initialized) return;

    try {
      _remoteConfig = FirebaseRemoteConfig.instance;

      // Set default values
      await _remoteConfig!.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ),);

      // Set defaults
      await _remoteConfig!.setDefaults(_defaultFlags);

      // Fetch and activate
      await _remoteConfig!.fetchAndActivate();

      // Load cached flags
      await _loadCachedFlags();

      _initialized = true;
      notifyListeners();

      // Set up periodic refresh
      _startRefreshTimer();

      LoggerService.info('FeatureFlagService initialized');
    } catch (e) {
      LoggerService.warning(
          'Failed to initialize Remote Config, using defaults',
          error: e,);
      // Use default flags if Remote Config fails
      _flagCache.addAll(_defaultFlags);
      _initialized = true;
    }
  }

  /// Load cached flags from local storage
  Future<void> _loadCachedFlags() async {
    try {
      final prefs = await _getPrefs();
      final cachedJson = prefs.getString('feature_flags_cache');
      if (cachedJson != null) {
        // Parse cached flags (simplified - in production use proper JSON)
        _flagCache.addAll(_defaultFlags);
      } else {
        _flagCache.addAll(_defaultFlags);
      }
    } catch (e) {
      LoggerService.debug('Failed to load cached flags', error: e);
      _flagCache.addAll(_defaultFlags);
    }
  }

  /// Start periodic refresh timer
  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(hours: 1), (_) {
      _refreshFlags();
    });
  }

  /// Refresh feature flags from Remote Config
  Future<void> _refreshFlags() async {
    if (!_initialized || _remoteConfig == null) return;

    try {
      await _remoteConfig!.fetchAndActivate();
      _updateFlagCache();
      notifyListeners();
      LoggerService.debug('Feature flags refreshed');
    } catch (e) {
      LoggerService.debug('Failed to refresh feature flags', error: e);
    }
  }

  /// Update flag cache from Remote Config
  void _updateFlagCache() {
    if (_remoteConfig == null) return;

    try {
      final allKeys = _remoteConfig!.getAll();
      _flagCache.clear();
      for (final entry in allKeys.entries) {
        _flagCache[entry.key] = entry.value.asString();
      }
    } catch (e) {
      LoggerService.debug('Failed to update flag cache', error: e);
    }
  }

  /// Get a boolean feature flag
  bool getFlag(String flagName, {bool defaultValue = false}) {
    if (!_initialized) {
      LoggerService.warning(
          'FeatureFlagService not initialized, using default for: $flagName',);
      return _defaultFlags[flagName] as bool? ?? defaultValue;
    }

    try {
      if (_remoteConfig != null) {
        final value = _remoteConfig!.getBool(flagName);
        _trackFlagAccess(flagName, value);
        return value;
      }

      // Fallback to cache
      final cached = _flagCache[flagName];
      if (cached is bool) {
        return cached;
      }
      if (cached is String) {
        return cached.toLowerCase() == 'true';
      }

      return _defaultFlags[flagName] as bool? ?? defaultValue;
    } catch (e) {
      LoggerService.debug('Failed to get flag: $flagName', error: e);
      return _defaultFlags[flagName] as bool? ?? defaultValue;
    }
  }

  /// Get a string feature flag
  String getStringFlag(String flagName, {String defaultValue = ''}) {
    if (!_initialized) {
      return _defaultFlags[flagName] as String? ?? defaultValue;
    }

    try {
      if (_remoteConfig != null) {
        final value = _remoteConfig!.getString(flagName);
        _trackFlagAccess(flagName, value);
        return value.isNotEmpty ? value : defaultValue;
      }

      final cached = _flagCache[flagName];
      if (cached is String) {
        return cached;
      }

      return _defaultFlags[flagName] as String? ?? defaultValue;
    } catch (e) {
      LoggerService.debug('Failed to get string flag: $flagName', error: e);
      return _defaultFlags[flagName] as String? ?? defaultValue;
    }
  }

  /// Get an integer feature flag
  int getIntFlag(String flagName, {int defaultValue = 0}) {
    if (!_initialized) {
      return _defaultFlags[flagName] as int? ?? defaultValue;
    }

    try {
      if (_remoteConfig != null) {
        final value = _remoteConfig!.getInt(flagName);
        _trackFlagAccess(flagName, value);
        return value;
      }

      final cached = _flagCache[flagName];
      if (cached is int) {
        return cached;
      }
      if (cached is String) {
        return int.tryParse(cached) ?? defaultValue;
      }

      return _defaultFlags[flagName] as int? ?? defaultValue;
    } catch (e) {
      LoggerService.debug('Failed to get int flag: $flagName', error: e);
      return _defaultFlags[flagName] as int? ?? defaultValue;
    }
  }

  /// Get a double feature flag
  double getDoubleFlag(String flagName, {double defaultValue = 0.0}) {
    if (!_initialized) {
      return _defaultFlags[flagName] as double? ?? defaultValue;
    }

    try {
      if (_remoteConfig != null) {
        final value = _remoteConfig!.getDouble(flagName);
        _trackFlagAccess(flagName, value);
        return value;
      }

      final cached = _flagCache[flagName];
      if (cached is double) {
        return cached;
      }
      if (cached is String) {
        return double.tryParse(cached) ?? defaultValue;
      }

      return _defaultFlags[flagName] as double? ?? defaultValue;
    } catch (e) {
      LoggerService.debug('Failed to get double flag: $flagName', error: e);
      return _defaultFlags[flagName] as double? ?? defaultValue;
    }
  }

  /// Track feature flag access for analytics
  void _trackFlagAccess(String flagName, dynamic value) {
    try {
      // Log to analytics if available
      // This helps track feature flag usage
      if (kDebugMode) {
        LoggerService.debug('Feature flag accessed: $flagName = $value');
      }
    } catch (e) {
      // Ignore analytics errors
    }
  }

  /// Force refresh feature flags
  Future<void> refresh() async {
    await _refreshFlags();
  }

  /// Get all feature flags as a map
  Map<String, dynamic> getAllFlags() {
    if (!_initialized) {
      return Map<String, dynamic>.from(_defaultFlags);
    }

    try {
      if (_remoteConfig != null) {
        final all = _remoteConfig!.getAll();
        final result = <String, dynamic>{};
        for (final entry in all.entries) {
          result[entry.key] = entry.value.asString();
        }
        return result;
      }

      return Map<String, dynamic>.from(_flagCache);
    } catch (e) {
      LoggerService.debug('Failed to get all flags', error: e);
      return Map<String, dynamic>.from(_defaultFlags);
    }
  }

  /// Check if a feature is enabled (convenience method)
  bool isEnabled(String featureName) {
    return getFlag(featureName, defaultValue: false);
  }

  /// Dispose resources
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Reset singleton instance and state for testing
  /// Clears the singleton instance and cancels timers to prevent resource leaks
  static void resetForTesting() {
    if (_instance != null) {
      _instance!._refreshTimer?.cancel();
      _instance = null;
    }
  }
}
