import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Utility class for managing stats and leaderboard view preferences
class StatsPreferences {
  static const String _keyViewType = 'leaderboard_view_type';
  static const String _keyChartType = 'stats_chart_type';
  static const String _keyTimePeriod = 'stats_time_period';

  // Default values
  static const String _defaultViewType = 'leaderboard';
  static const String _defaultChartType = 'line';
  static const int _defaultTimePeriod = 30;

  /// Get the preferred view type (leaderboard or personal_stats)
  static Future<String> getViewType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyViewType) ?? _defaultViewType;
    } catch (e) {
      LoggerService.error('Failed to get view type preference', error: e);
      return _defaultViewType;
    }
  }

  /// Set the preferred view type
  static Future<bool> setViewType(String viewType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_keyViewType, viewType);
    } catch (e) {
      LoggerService.error('Failed to set view type preference', error: e);
      return false;
    }
  }

  /// Get the preferred chart type (line, bar, or area)
  static Future<String> getChartType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyChartType) ?? _defaultChartType;
    } catch (e) {
      LoggerService.error('Failed to get chart type preference', error: e);
      return _defaultChartType;
    }
  }

  /// Set the preferred chart type
  static Future<bool> setChartType(String chartType) async {
    try {
      if (!['line', 'bar', 'area'].contains(chartType)) {
        LoggerService.warning('Invalid chart type: $chartType');
        return false;
      }
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_keyChartType, chartType);
    } catch (e) {
      LoggerService.error('Failed to set chart type preference', error: e);
      return false;
    }
  }

  /// Get the preferred time period in days
  static Future<int> getTimePeriod() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_keyTimePeriod) ?? _defaultTimePeriod;
    } catch (e) {
      LoggerService.error('Failed to get time period preference', error: e);
      return _defaultTimePeriod;
    }
  }

  /// Set the preferred time period in days
  static Future<bool> setTimePeriod(int days) async {
    try {
      if (days < 1) {
        LoggerService.warning('Invalid time period: $days');
        return false;
      }
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setInt(_keyTimePeriod, days);
    } catch (e) {
      LoggerService.error('Failed to set time period preference', error: e);
      return false;
    }
  }

  /// Clear all stats preferences
  static Future<bool> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_keyViewType) &&
          await prefs.remove(_keyChartType) &&
          await prefs.remove(_keyTimePeriod);
    } catch (e) {
      LoggerService.error('Failed to clear stats preferences', error: e);
      return false;
    }
  }
}













