import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TextToSpeechService extends ChangeNotifier {
  FlutterTts? _flutterTts;
  bool _isEnabled = false;
  bool _isSpeaking = false;
  double _speechRate = 0.5; // 0.0 to 1.0
  double _volume = 1.0; // 0.0 to 1.0
  double _pitch = 1.0; // 0.5 to 2.0
  String _selectedLanguage = 'en-US';

  bool get isEnabled => _isEnabled;
  bool get isSpeaking => _isSpeaking;
  double get speechRate => _speechRate;
  double get volume => _volume;
  double get pitch => _pitch;
  String get selectedLanguage => _selectedLanguage;

  Future<void> init() async {
    _flutterTts = FlutterTts();

    // Set up TTS callbacks
    _flutterTts!.setStartHandler(() {
      _isSpeaking = true;
      notifyListeners();
    });

    _flutterTts!.setCompletionHandler(() {
      _isSpeaking = false;
      notifyListeners();
    });

    _flutterTts!.setErrorHandler((msg) {
      debugPrint('TTS Error: $msg');
      _isSpeaking = false;
      notifyListeners();
    });

    // Set default language
    await _flutterTts!.setLanguage(_selectedLanguage);
    await _flutterTts!.setSpeechRate(_speechRate);
    await _flutterTts!.setVolume(_volume);
    await _flutterTts!.setPitch(_pitch);

    // Load saved preferences
    await _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool('tts_enabled') ?? false;
      _speechRate = prefs.getDouble('tts_speech_rate') ?? 0.5;
      _volume = prefs.getDouble('tts_volume') ?? 1.0;
      _pitch = prefs.getDouble('tts_pitch') ?? 1.0;
      _selectedLanguage = prefs.getString('tts_language') ?? 'en-US';

      if (_flutterTts != null) {
        await _flutterTts!.setLanguage(_selectedLanguage);
        await _flutterTts!.setSpeechRate(_speechRate);
        await _flutterTts!.setVolume(_volume);
        await _flutterTts!.setPitch(_pitch);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load TTS preferences: $e');
    }
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('tts_enabled', _isEnabled);
      await prefs.setDouble('tts_speech_rate', _speechRate);
      await prefs.setDouble('tts_volume', _volume);
      await prefs.setDouble('tts_pitch', _pitch);
      await prefs.setString('tts_language', _selectedLanguage);
    } catch (e) {
      debugPrint('Failed to save TTS preferences: $e');
    }
  }

  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    await _savePreferences();
    notifyListeners();
  }

  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.0, 1.0);
    if (_flutterTts != null) {
      await _flutterTts!.setSpeechRate(_speechRate);
    }
    await _savePreferences();
    notifyListeners();
  }

  Future<void> setVolume(double vol) async {
    _volume = vol.clamp(0.0, 1.0);
    if (_flutterTts != null) {
      await _flutterTts!.setVolume(_volume);
    }
    await _savePreferences();
    notifyListeners();
  }

  Future<void> setPitch(double p) async {
    _pitch = p.clamp(0.5, 2.0);
    if (_flutterTts != null) {
      await _flutterTts!.setPitch(_pitch);
    }
    await _savePreferences();
    notifyListeners();
  }

  Future<void> setLanguage(String language) async {
    _selectedLanguage = language;
    if (_flutterTts != null) {
      await _flutterTts!.setLanguage(_selectedLanguage);
    }
    await _savePreferences();
    notifyListeners();
  }

  /// Speak text
  Future<void> speak(String text) async {
    if (!_isEnabled || _flutterTts == null || text.isEmpty) return;

    try {
      await _flutterTts!.speak(text);
    } catch (e) {
      debugPrint('Failed to speak text: $e');
    }
  }

  /// Stop speaking
  Future<void> stop() async {
    if (_flutterTts != null) {
      await _flutterTts!.stop();
      _isSpeaking = false;
      notifyListeners();
    }
  }

  /// Pause speaking
  Future<void> pause() async {
    if (_flutterTts != null) {
      await _flutterTts!.pause();
    }
  }

  /// Get available languages
  Future<List<dynamic>> getAvailableLanguages() async {
    if (_flutterTts == null) return [];
    try {
      return await _flutterTts!.getLanguages ?? [];
    } catch (e) {
      debugPrint('Failed to get available languages: $e');
      return [];
    }
  }

  /// Get available voices
  Future<List<dynamic>> getAvailableVoices() async {
    if (_flutterTts == null) return [];
    try {
      return await _flutterTts!.getVoices ?? [];
    } catch (e) {
      debugPrint('Failed to get available voices: $e');
      return [];
    }
  }

  @override
  void dispose() {
    _flutterTts?.stop();
    _flutterTts = null; // Nullify reference for memory cleanup
    super.dispose();
  }
}
