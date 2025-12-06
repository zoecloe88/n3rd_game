import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage free tier restrictions
/// Free tier gets 5 games per day (games started), resets at midnight UTC
/// This tracks games STARTED, not games completed or lost
class FreeTierService extends ChangeNotifier {
  static const String _prefKeyGamesStarted = 'free_tier_games_started';
  static const String _prefKeyLastDate = 'free_tier_last_date';
  static const int _maxGamesPerDay = 5;

  SharedPreferences? _prefs;
  int _gamesStartedToday = 0;
  DateTime _lastDate = DateTime.now().toUtc();
  bool _isRecording =
      false; // Mutex to prevent concurrent recordGameStart() calls

  int get gamesStartedToday => _gamesStartedToday;
  int get gamesRemaining => _maxGamesPerDay - _gamesStartedToday;
  int get maxGamesPerDay => _maxGamesPerDay;
  bool get hasGamesRemaining => _gamesStartedToday < _maxGamesPerDay;

  /// Initialize and load free tier state
  Future<void> init() async {
    try {
      await _getPrefs(); // Use _getPrefs() which already handles errors
      await _loadState();
      _checkDateReset();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to initialize FreeTierService: $e');
      }
      // Continue with default state if SharedPreferences fails
      _gamesStartedToday = 0;
      _lastDate = DateTime.now().toUtc();
      notifyListeners();
    }
  }

  /// Load state from SharedPreferences
  Future<void> _loadState() async {
    final prefs = await _getPrefs();
    _gamesStartedToday = prefs.getInt(_prefKeyGamesStarted) ?? 0;

    final lastDateTimestamp = prefs.getInt(_prefKeyLastDate);
    if (lastDateTimestamp != null) {
      _lastDate = DateTime.fromMillisecondsSinceEpoch(lastDateTimestamp);
    } else {
      _lastDate = DateTime.now().toUtc();
    }
  }

  /// Save state to SharedPreferences
  Future<void> _saveState() async {
    final prefs = await _getPrefs();
    await prefs.setInt(_prefKeyGamesStarted, _gamesStartedToday);
    await prefs.setInt(_prefKeyLastDate, _lastDate.millisecondsSinceEpoch);
  }

  /// Check if date has changed and reset if needed
  void _checkDateReset() {
    final now = DateTime.now().toUtc();
    final today = DateTime(now.year, now.month, now.day);
    final lastDay = DateTime(_lastDate.year, _lastDate.month, _lastDate.day);

    if (today.isAfter(lastDay)) {
      // New day - reset games started
      _gamesStartedToday = 0;
      _lastDate = now;
      _saveState();
      notifyListeners();
    }
  }

  /// Check if free tier user can play (has games remaining)
  /// Returns true if under the daily limit
  bool canPlay() {
    _checkDateReset();
    return _gamesStartedToday < _maxGamesPerDay;
  }

  /// Record a game start for free tier user
  /// This should be called when a game begins, not when it ends
  /// Uses mutex to prevent concurrent race conditions from simultaneous calls
  /// Returns true if game was recorded, false if limit reached or already recording
  Future<bool> recordGameStart() async {
    // Mutex: Prevent concurrent calls
    if (_isRecording) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ FreeTierService: recordGameStart() already in progress, skipping concurrent call',
        );
      }
      return false; // Already processing another call
    }

    _isRecording = true;
    try {
      _checkDateReset();

      // Double-check limit to prevent race conditions from concurrent game starts
      if (_gamesStartedToday < _maxGamesPerDay) {
        _gamesStartedToday++;
        await _saveState();

        // Final check after increment (prevent going over limit)
        if (_gamesStartedToday > _maxGamesPerDay) {
          _gamesStartedToday = _maxGamesPerDay;
          await _saveState();
          notifyListeners();
          return false;
        }

        notifyListeners();
        return true;
      }
      return false;
    } finally {
      _isRecording = false; // Release mutex
    }
  }

  /// Rollback/refund a game start if the game failed to actually start
  /// This prevents slot waste when game initialization fails after recordGameStart()
  /// Returns true if rollback succeeded, false if already at 0
  Future<bool> rollbackGameStart() async {
    _checkDateReset();

    if (_gamesStartedToday > 0) {
      _gamesStartedToday--;
      await _saveState();
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Get number of games started today
  int getGamesStartedToday() {
    _checkDateReset();
    return _gamesStartedToday;
  }

  /// Get number of games remaining today
  int getGamesRemaining() {
    _checkDateReset();
    return _maxGamesPerDay - _gamesStartedToday;
  }

  /// Get time until reset (next midnight UTC)
  Duration getTimeUntilReset() {
    final now = DateTime.now().toUtc();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tomorrow.difference(now);
  }

  /// Get formatted string for time until reset
  String getTimeUntilResetString() {
    final duration = getTimeUntilReset();
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '$hours hour${hours > 1 ? 's' : ''} $minutes minute${minutes != 1 ? 's' : ''}';
    }
    return '$minutes minute${minutes != 1 ? 's' : ''}';
  }

  /// Get formatted string for next reset
  String getNextResetString() {
    final now = DateTime.now().toUtc();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final hoursUntilReset = tomorrow.difference(now).inHours;

    if (hoursUntilReset < 1) {
      return 'Less than an hour';
    } else if (hoursUntilReset == 1) {
      return 'In 1 hour';
    } else {
      return 'In $hoursUntilReset hours';
    }
  }

  Future<SharedPreferences> _getPrefs() async {
    if (_prefs != null) return _prefs!;
    try {
      _prefs = await SharedPreferences.getInstance();
      return _prefs!;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to get SharedPreferences in FreeTierService: $e');
      }
      rethrow; // Re-throw to let caller handle
    }
  }

  @override
  void dispose() {
    // FreeTierService uses SharedPreferences which doesn't require explicit cleanup
    // but dispose for consistency with other services
    super.dispose();
  }
}
