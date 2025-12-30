import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Service for managing user onboarding state
class OnboardingService {
  static const String _onboardingKey = 'onboarding_completed';
  static const String _dontShowAgainKey = 'onboarding_dont_show_again';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Check if user has completed onboarding
  Future<bool> hasCompletedOnboarding() async {
    try {
      final prefs = await _getPrefs();
      // If "don't show again" is set, consider onboarding completed
      if (prefs.getBool(_dontShowAgainKey) ?? false) {
        return true;
      }
      return prefs.getBool(_onboardingKey) ?? false;
    } catch (e) {
      LoggerService.warning('Error checking onboarding status', error: e);
      // Return false on error to ensure onboarding is shown
      return false;
    }
  }

  /// Set "don't show again" preference
  Future<void> setDontShowAgain(bool value) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setBool(_dontShowAgainKey, value);
      if (value) {
        // Also mark onboarding as completed
        await prefs.setBool(_onboardingKey, true);
      }
    } catch (e) {
      LoggerService.warning('Error setting dont show again', error: e);
    }
  }

  /// Mark onboarding as completed
  /// Returns true if successful, false if failed
  Future<bool> completeOnboarding() async {
    try {
      final prefs = await _getPrefs();
      final success = await prefs.setBool(_onboardingKey, true);
      if (!success) {
        LoggerService.warning('Failed to save onboarding completion status');
        return false;
      }
      return true; // Success
    } catch (e) {
      LoggerService.warning('Error completing onboarding', error: e);
      return false; // Failure
    }
  }

  /// Reset onboarding (for testing)
  Future<void> resetOnboarding() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_onboardingKey);
      await prefs.remove(_dontShowAgainKey);
    } catch (e) {
      LoggerService.warning('Error resetting onboarding', error: e);
    }
  }
}
