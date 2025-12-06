import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sound service for managing game audio effects
/// Maintains the app's clean aesthetic with subtle, professional sound design
/// Uses Flutter's built-in SystemSound for instant, native feedback
class SoundService extends ChangeNotifier {
  static const String _soundEnabledKey = 'sound_enabled';

  bool _soundEnabled = true;

  bool get soundEnabled => _soundEnabled;

  // Sound effect types
  static const String soundCorrect = 'correct';
  static const String soundWrong = 'wrong';
  static const String soundPerfect = 'perfect';
  static const String soundPartial = 'partial';
  static const String soundClick = 'click';
  static const String soundGameOver = 'game_over';
  static const String soundRoundStart = 'round_start';
  static const String soundTimeUp = 'time_up';

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _soundEnabled = prefs.getBool(_soundEnabledKey) ?? true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing sound service: $e');
    }
  }

  /// Play a sound effect using system sounds
  /// System sounds are native, instant, and require no files
  Future<void> playSound(String soundType) async {
    if (!_soundEnabled) return;

    try {
      switch (soundType) {
        case soundClick:
          SystemSound.play(SystemSoundType.click);
          break;
        case soundCorrect:
        case soundPartial:
          // Use alert sound for success feedback
          SystemSound.play(SystemSoundType.alert);
          break;
        case soundPerfect:
          // Play alert twice for emphasis on perfect score
          SystemSound.play(SystemSoundType.alert);
          await Future.delayed(const Duration(milliseconds: 100));
          SystemSound.play(SystemSoundType.alert);
          break;
        case soundWrong:
        case soundGameOver:
          SystemSound.play(SystemSoundType.alert);
          break;
        case soundRoundStart:
        case soundTimeUp:
          SystemSound.play(SystemSoundType.alert);
          break;
        default:
          SystemSound.play(SystemSoundType.click);
      }
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  /// Toggle sound on/off
  Future<void> toggleSound() async {
    _soundEnabled = !_soundEnabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_soundEnabledKey, _soundEnabled);
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving sound preference: $e');
    }
  }

  /// Play correct answer sound
  Future<void> playCorrect() => playSound(soundCorrect);

  /// Play wrong answer sound
  Future<void> playWrong() => playSound(soundWrong);

  /// Play perfect score sound (3/3 correct)
  Future<void> playPerfect() => playSound(soundPerfect);

  /// Play partial correct sound (1-2/3 correct)
  Future<void> playPartial() => playSound(soundPartial);

  /// Play click/tap sound
  Future<void> playClick() => playSound(soundClick);

  /// Play game over sound
  Future<void> playGameOver() => playSound(soundGameOver);

  /// Play round start sound
  Future<void> playRoundStart() => playSound(soundRoundStart);

  /// Play time up sound
  Future<void> playTimeUp() => playSound(soundTimeUp);

  /// Dispose of the service and clean up resources
  @override
  void dispose() {
    // SoundService uses SystemSound which doesn't require explicit cleanup
    // However, we dispose for consistency with other services
    super.dispose();
  }
}
