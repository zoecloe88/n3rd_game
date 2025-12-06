import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/services/auth_service.dart';

/// Service for managing user session timeout
class SessionService extends ChangeNotifier {
  static const String _prefKeyLastActivity = 'last_activity_timestamp';
  static const Duration _sessionTimeout = Duration(minutes: 30);
  static const Duration _warningThreshold = Duration(minutes: 25);

  Timer? _activityTimer;
  Timer? _checkTimer;
  DateTime? _lastActivity;
  bool _isWarningShown = false;

  bool get isSessionActive =>
      _lastActivity != null &&
      DateTime.now().difference(_lastActivity!) < _sessionTimeout;

  Duration? get timeUntilTimeout {
    if (_lastActivity == null) return null;
    final elapsed = DateTime.now().difference(_lastActivity!);
    if (elapsed >= _sessionTimeout) return null;
    return _sessionTimeout - elapsed;
  }

  Future<void> init(AuthService authService) async {
    // Load last activity from storage
    await _loadLastActivity();

    // Start checking for timeout
    _startTimeoutCheck(authService);

    // Record initial activity
    recordActivity();
  }

  Future<void> _loadLastActivity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_prefKeyLastActivity);
      if (timestamp != null) {
        _lastActivity = DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    } catch (e) {
      debugPrint('Failed to load last activity: $e');
    }
  }

  Future<void> _saveLastActivity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_lastActivity != null) {
        await prefs.setInt(
          _prefKeyLastActivity,
          _lastActivity!.millisecondsSinceEpoch,
        );
      }
    } catch (e) {
      debugPrint('Failed to save last activity: $e');
    }
  }

  /// Record user activity (call on user interactions)
  void recordActivity() {
    _lastActivity = DateTime.now();
    _isWarningShown = false;
    _saveLastActivity();
    notifyListeners();
  }

  void _startTimeoutCheck(AuthService authService) {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!isSessionActive && authService.isAuthenticated) {
        // Session expired, logout user
        debugPrint('Session expired, logging out user');
        authService.signOut();
        timer.cancel();
      } else if (timeUntilTimeout != null &&
          timeUntilTimeout! <= _warningThreshold &&
          !_isWarningShown) {
        // Show warning
        _isWarningShown = true;
        notifyListeners();
      }
    });
  }

  /// Check if session is about to expire (for showing warning)
  bool shouldShowWarning() {
    final timeLeft = timeUntilTimeout;
    return timeLeft != null && timeLeft <= _warningThreshold && _isWarningShown;
  }

  /// Extend session (called when user dismisses warning)
  void extendSession() {
    recordActivity();
  }

  @override
  void dispose() {
    _activityTimer?.cancel();
    _checkTimer?.cancel();
    super.dispose();
  }
}
