import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing user onboarding state
class OnboardingService {
  static const String _onboardingKey = 'onboarding_completed';
  static const String _tutorialShownKey = 'tutorial_shown';
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
      debugPrint('Error checking onboarding status: $e');
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
      debugPrint('Error setting dont show again: $e');
    }
  }

  /// Mark onboarding as completed
  /// Returns true if successful, false if failed
  Future<bool> completeOnboarding() async {
    try {
      final prefs = await _getPrefs();
      await prefs.setBool(_onboardingKey, true);
      return true; // Success
    } catch (e) {
      debugPrint('Error completing onboarding: $e');
      return false; // Failure
    }
  }

  /// Check if tutorial has been shown
  Future<bool> hasSeenTutorial() async {
    try {
      final prefs = await _getPrefs();
      return prefs.getBool(_tutorialShownKey) ?? false;
    } catch (e) {
      debugPrint('Error checking tutorial status: $e');
      return false;
    }
  }

  /// Mark tutorial as shown
  Future<void> markTutorialShown() async {
    try {
      final prefs = await _getPrefs();
      await prefs.setBool(_tutorialShownKey, true);
    } catch (e) {
      debugPrint('Error marking tutorial as shown: $e');
    }
  }

  /// Reset onboarding (for testing)
  Future<void> resetOnboarding() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_onboardingKey);
      await prefs.remove(_tutorialShownKey);
    } catch (e) {
      debugPrint('Error resetting onboarding: $e');
    }
  }
}
