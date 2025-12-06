import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Haptic feedback service for tactile user feedback
/// Provides subtle, professional haptic responses matching the app's aesthetic
class HapticService {
  static final HapticService _instance = HapticService._internal();
  factory HapticService() => _instance;
  HapticService._internal();

  bool _hapticsEnabled = true;

  bool get hapticsEnabled => _hapticsEnabled;

  void setHapticsEnabled(bool enabled) {
    _hapticsEnabled = enabled;
  }

  /// Light haptic feedback for button taps
  Future<void> lightImpact() async {
    if (!_hapticsEnabled) return;
    try {
      await HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('Error with haptic feedback: $e');
    }
  }

  /// Medium haptic feedback for selections
  Future<void> mediumImpact() async {
    if (!_hapticsEnabled) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('Error with haptic feedback: $e');
    }
  }

  /// Heavy haptic feedback for important actions
  Future<void> heavyImpact() async {
    if (!_hapticsEnabled) return;
    try {
      await HapticFeedback.heavyImpact();
    } catch (e) {
      debugPrint('Error with haptic feedback: $e');
    }
  }

  /// Selection haptic for tile selections
  Future<void> selectionClick() async {
    if (!_hapticsEnabled) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (e) {
      debugPrint('Error with haptic feedback: $e');
    }
  }

  /// Vibrate for correct answers
  Future<void> success() async {
    if (!_hapticsEnabled) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('Error with haptic feedback: $e');
    }
  }

  /// Vibrate for wrong answers
  Future<void> error() async {
    if (!_hapticsEnabled) return;
    try {
      await HapticFeedback.heavyImpact();
    } catch (e) {
      debugPrint('Error with haptic feedback: $e');
    }
  }
}
