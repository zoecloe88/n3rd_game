import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/services/pronunciation_dictionary_service.dart';

class VoiceRecognitionService extends ChangeNotifier {
  stt.SpeechToText? _speech;
  bool _isAvailable = false;
  bool _isListening = false;
  bool _isEnabled = false;
  String _lastWords = '';
  double _confidence = 0.0;
  bool _pushToTalkMode = true; // true = push to talk, false = always on

  bool get isAvailable => _isAvailable;
  bool get isListening => _isListening;
  bool get isEnabled => _isEnabled;
  String get lastWords => _lastWords;
  double get confidence => _confidence;
  bool get pushToTalkMode => _pushToTalkMode;

  PronunciationDictionaryService? _pronunciationService;

  void setPronunciationService(PronunciationDictionaryService service) {
    _pronunciationService = service;
  }

  Future<void> init() async {
    _speech = stt.SpeechToText();

    // Check availability
    _isAvailable = await _speech!.initialize(
      onError: (error) {
        debugPrint('Speech recognition error: $error');
        _isListening = false;
        notifyListeners();
      },
      onStatus: (status) {
        debugPrint('Speech recognition status: $status');
        if (status == 'done' || status == 'notListening') {
          _isListening = false;
          notifyListeners();
        }
      },
    );

    // Request microphone permission
    await _requestMicrophonePermission();

    // Load preferences
    await _loadPreferences();

    notifyListeners();
  }

  Future<void> _requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    if (status.isDenied) {
      debugPrint('Microphone permission denied');
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool('stt_enabled') ?? false;
      _pushToTalkMode = prefs.getBool('stt_push_to_talk') ?? true;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load STT preferences: $e');
    }
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('stt_enabled', _isEnabled);
      await prefs.setBool('stt_push_to_talk', _pushToTalkMode);
    } catch (e) {
      debugPrint('Failed to save STT preferences: $e');
    }
  }

  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    if (!enabled && _isListening) {
      await stop();
    }
    await _savePreferences();
    notifyListeners();
  }

  Future<void> setPushToTalkMode(bool pushToTalk) async {
    _pushToTalkMode = pushToTalk;
    if (!pushToTalk && _isListening) {
      await stop();
    }
    await _savePreferences();
    notifyListeners();
  }

  /// Start listening (push-to-talk mode)
  Future<void> startListening({Function(String)? onResult}) async {
    if (!_isAvailable || !_isEnabled || _speech == null) return;
    if (_isListening) return;

    try {
      _isListening = true;
      _lastWords = '';
      _confidence = 0.0;
      notifyListeners();

      await _speech!.listen(
        onResult: (result) {
          _lastWords = result.recognizedWords;
          _confidence = result.confidence;

          if (result.finalResult) {
            _isListening = false;
            if (onResult != null) {
              onResult(result.recognizedWords);
            }
          }

          notifyListeners();
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: stt.ListenMode.confirmation,
        ),
        localeId: 'en_US',
      );
    } catch (e) {
      debugPrint('Failed to start listening: $e');
      _isListening = false;
      notifyListeners();
    }
  }

  /// Stop listening
  Future<void> stop() async {
    if (_speech != null && _isListening) {
      await _speech!.stop();
      _isListening = false;
      notifyListeners();
    }
  }

  /// Cancel listening
  Future<void> cancel() async {
    if (_speech != null) {
      await _speech!.cancel();
      _isListening = false;
      _lastWords = '';
      _confidence = 0.0;
      notifyListeners();
    }
  }

  /// Match spoken word to available words in game
  String? matchSpokenWord(String spokenText, List<String> availableWords) {
    if (spokenText.isEmpty || availableWords.isEmpty) return null;

    final normalizedSpoken = spokenText.trim().toLowerCase();

    // First, try exact match
    for (final word in availableWords) {
      if (word.trim().toLowerCase() == normalizedSpoken) {
        return word;
      }
    }

    // Try phonetic matching if pronunciation service is available
    if (_pronunciationService != null) {
      for (final word in availableWords) {
        final pronunciation = _pronunciationService!.getPronunciation(word);
        if (pronunciation != null && pronunciation.matches(normalizedSpoken)) {
          return word;
        }
      }
    }

    // Try fuzzy matching (Levenshtein distance)
    String? bestMatch;
    double bestScore = 0.0;

    for (final word in availableWords) {
      final normalizedWord = word.trim().toLowerCase();
      final similarity = _calculateSimilarity(normalizedSpoken, normalizedWord);

      if (similarity > bestScore && similarity > 0.7) {
        bestScore = similarity;
        bestMatch = word;
      }
    }

    return bestMatch;
  }

  double _calculateSimilarity(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    // Check if one contains the other
    if (a.contains(b) || b.contains(a)) {
      return 0.8;
    }

    // Levenshtein distance
    final distance = _levenshteinDistance(a, b);
    final maxLen = a.length > b.length ? a.length : b.length;
    return 1.0 - (distance / maxLen);
  }

  int _levenshteinDistance(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final matrix = List.generate(
      a.length + 1,
      (i) => List.generate(b.length + 1, (j) => 0),
    );

    for (int i = 0; i <= a.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= b.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[a.length][b.length];
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
