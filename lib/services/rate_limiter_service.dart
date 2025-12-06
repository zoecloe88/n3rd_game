import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

/// Service for rate limiting user actions to prevent abuse
class RateLimiterService {
  static const String _prefPrefix = 'rate_limit_';
  static const Duration _defaultWindow = Duration(minutes: 15);

  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Check if an action is allowed based on rate limits
  /// Returns true if allowed, false if rate limited
  Future<bool> isAllowed(
    String action, {
    int maxAttempts = 5,
    Duration window = _defaultWindow,
  }) async {
    try {
      final prefs = await _getPrefs();
      final key = '$_prefPrefix$action';
      final timestampKey = '${key}_timestamp';

      final lastAttempts = prefs.getInt(key) ?? 0;
      final lastTimestamp = prefs.getInt(timestampKey);

      final now = DateTime.now().millisecondsSinceEpoch;

      // Reset if window has passed
      if (lastTimestamp != null) {
        final timeSinceLastAttempt = Duration(
          milliseconds: now - lastTimestamp,
        );
        if (timeSinceLastAttempt > window) {
          await prefs.setInt(key, 0);
          await prefs.setInt(timestampKey, now);
          return true;
        }
      }

      // Check if limit exceeded
      if (lastAttempts >= maxAttempts) {
        return false;
      }

      // Increment attempts
      await prefs.setInt(key, lastAttempts + 1);
      await prefs.setInt(timestampKey, now);

      return true;
    } catch (e) {
      debugPrint('Rate limiter error: $e');
      // On error, allow the action (fail open)
      return true;
    }
  }

  /// Reset rate limit for an action
  Future<void> reset(String action) async {
    try {
      final prefs = await _getPrefs();
      final key = '$_prefPrefix$action';
      final timestampKey = '${key}_timestamp';
      await prefs.remove(key);
      await prefs.remove(timestampKey);
    } catch (e) {
      debugPrint('Rate limiter reset error: $e');
    }
  }

  /// Get remaining attempts for an action
  Future<int> getRemainingAttempts(
    String action, {
    int maxAttempts = 5,
    Duration window = _defaultWindow,
  }) async {
    try {
      final prefs = await _getPrefs();
      final key = '$_prefPrefix$action';
      final timestampKey = '${key}_timestamp';

      final lastAttempts = prefs.getInt(key) ?? 0;
      final lastTimestamp = prefs.getInt(timestampKey);

      final now = DateTime.now().millisecondsSinceEpoch;

      // Reset if window has passed
      if (lastTimestamp != null) {
        final timeSinceLastAttempt = Duration(
          milliseconds: now - lastTimestamp,
        );
        if (timeSinceLastAttempt > window) {
          return maxAttempts;
        }
      }

      return maxAttempts - lastAttempts;
    } catch (e) {
      debugPrint('Rate limiter get remaining error: $e');
      return maxAttempts;
    }
  }

  /// Get time until rate limit resets
  Future<Duration?> getTimeUntilReset(
    String action, {
    Duration window = _defaultWindow,
  }) async {
    try {
      final prefs = await _getPrefs();
      final timestampKey = '$_prefPrefix${action}_timestamp';
      final lastTimestamp = prefs.getInt(timestampKey);

      if (lastTimestamp == null) return null;

      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsed = Duration(milliseconds: now - lastTimestamp);

      if (elapsed >= window) return null;

      return window - elapsed;
    } catch (e) {
      debugPrint('Rate limiter get time error: $e');
      return null;
    }
  }
}
