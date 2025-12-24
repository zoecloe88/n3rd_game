import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sound service for managing game audio effects
/// Maintains the app's clean aesthetic with subtle, professional sound design
/// Uses Flutter's built-in SystemSound for instant, native feedback
class SoundService extends ChangeNotifier {
  static const String _soundEnabledKey = 'sound_enabled';
  static const String _soundVolumeKey = 'sound_volume';
  static const String _musicEnabledKey = 'music_enabled';
  static const String _musicVolumeKey = 'music_volume';

  bool _soundEnabled = true;
  double _soundVolume = 1.0; // 0.0 to 1.0
  bool _musicEnabled = false;
  double _musicVolume = 0.5; // 0.0 to 1.0

  bool get soundEnabled => _soundEnabled;
  double get soundVolume => _soundVolume;
  bool get musicEnabled => _musicEnabled;
  double get musicVolume => _musicVolume;

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
      _soundVolume = prefs.getDouble(_soundVolumeKey) ?? 1.0;
      _musicEnabled = prefs.getBool(_musicEnabledKey) ?? false;
      _musicVolume = prefs.getDouble(_musicVolumeKey) ?? 0.5;
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

  /// Set sound enabled state
  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_soundEnabledKey, _soundEnabled);
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving sound enabled: $e');
    }
  }

  /// Set sound volume (0.0 to 1.0)
  Future<void> setSoundVolume(double volume) async {
    _soundVolume = volume.clamp(0.0, 1.0);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_soundVolumeKey, _soundVolume);
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving sound volume: $e');
    }
  }

  /// Set music enabled state
  Future<void> setMusicEnabled(bool enabled) async {
    _musicEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_musicEnabledKey, _musicEnabled);
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving music enabled: $e');
    }
  }

  /// Set music volume (0.0 to 1.0)
  Future<void> setMusicVolume(double volume) async {
    _musicVolume = volume.clamp(0.0, 1.0);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_musicVolumeKey, _musicVolume);
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving music volume: $e');
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
