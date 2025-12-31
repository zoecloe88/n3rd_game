import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/services/pronunciation_dictionary_service.dart';
import 'package:n3rd_game/services/voice_calibration_service.dart';
import 'package:n3rd_game/services/logger_service.dart';

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
  bool get isCalibrated => _calibrationService?.isCalibrated ?? false;

  PronunciationDictionaryService? _pronunciationService;
  VoiceCalibrationService? _calibrationService;

  void setPronunciationService(PronunciationDictionaryService service) {
    _pronunciationService = service;
  }

  void setVoiceCalibrationService(VoiceCalibrationService service) {
    _calibrationService = service;
  }

  Future<void> init() async {
    try {
      // Validate microphone permission before attempting initialization
      final micStatus = await Permission.microphone.status;
      if (micStatus.isPermanentlyDenied) {
        LoggerService.warning(
          'VoiceRecognitionService: Microphone permission permanently denied',
        );
        _isAvailable = false;
        notifyListeners();
        return;
      }

      // Create speech instance with null check
      _speech = stt.SpeechToText();
      if (_speech == null) {
        LoggerService.error(
          'VoiceRecognitionService: Failed to create SpeechToText instance',
          fatal: false,
        );
        _isAvailable = false;
        notifyListeners();
        return;
      }

      // Check availability with comprehensive error handling
      try {
        _isAvailable = await _speech!.initialize(
          onError: (error) {
            LoggerService.error(
              'VoiceRecognitionService: Speech recognition error',
              error: error,
              fatal: false,
            );
            _isListening = false;
            _isAvailable = false;
            notifyListeners();
          },
          onStatus: (status) {
            LoggerService.debug('VoiceRecognitionService: Speech recognition status: $status');
            if (status == 'done' || status == 'notListening') {
              _isListening = false;
              notifyListeners();
            }
          },
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            LoggerService.warning(
              'VoiceRecognitionService: Speech recognition initialization timed out',
            );
            _isAvailable = false;
            return false;
          },
        );
      } catch (e) {
        LoggerService.error(
          'VoiceRecognitionService: Speech recognition initialization failed',
          error: e,
          stack: StackTrace.current,
          fatal: false,
        );
        _isAvailable = false;
        notifyListeners();
        return;
      }

      // Request microphone permission (non-blocking)
      await _requestMicrophonePermission();

      // Load preferences
      await _loadPreferences();

      notifyListeners();
    } catch (e) {
      LoggerService.error(
        'VoiceRecognitionService: Init error',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
      _isAvailable = false;
      _isListening = false;
      notifyListeners();
    }
  }

  Future<void> _requestMicrophonePermission() async {
    try {
      final status = await Permission.microphone.request();
      if (status.isDenied) {
        LoggerService.warning(
          'VoiceRecognitionService: Microphone permission denied',
        );
        _isAvailable = false;
        notifyListeners();
      } else if (status.isPermanentlyDenied) {
        LoggerService.warning(
          'VoiceRecognitionService: Microphone permission permanently denied',
        );
        _isAvailable = false;
        notifyListeners();
      }
    } catch (e) {
      LoggerService.error(
        'VoiceRecognitionService: Error requesting microphone permission',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
      _isAvailable = false;
      notifyListeners();
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool('stt_enabled') ?? false;
      _pushToTalkMode = prefs.getBool('stt_push_to_talk') ?? true;
      notifyListeners();
    } catch (e) {
      LoggerService.error(
        'VoiceRecognitionService: Failed to load STT preferences',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
    }
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('stt_enabled', _isEnabled);
      await prefs.setBool('stt_push_to_talk', _pushToTalkMode);
    } catch (e) {
      LoggerService.error(
        'VoiceRecognitionService: Failed to save STT preferences',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
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
    // Comprehensive null and availability checks
    if (_speech == null) {
      LoggerService.warning(
        'VoiceRecognitionService: SpeechToText instance is null, cannot start listening',
      );
      return;
    }
    if (!_isAvailable) {
      LoggerService.warning(
        'VoiceRecognitionService: Speech recognition not available',
      );
      return;
    }
    if (!_isEnabled) {
      LoggerService.debug('VoiceRecognitionService: Speech recognition not enabled');
      return;
    }
    if (_isListening) {
      LoggerService.debug('VoiceRecognitionService: Already listening');
      return;
    }

    // Validate microphone permission before starting
    try {
      final micStatus = await Permission.microphone.status;
      if (!micStatus.isGranted) {
        LoggerService.warning(
          'VoiceRecognitionService: Microphone permission not granted',
        );
        _isAvailable = false;
        notifyListeners();
        return;
      }
    } catch (e) {
      LoggerService.error(
        'VoiceRecognitionService: Error checking microphone permission',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
      return;
    }

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
      LoggerService.error(
        'VoiceRecognitionService: Failed to start listening',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
      _isListening = false;
      _isAvailable = false;
      notifyListeners();
    }
  }

  /// Stop listening
  Future<void> stop() async {
    if (_speech == null) return;
    if (!_isListening) return;

    try {
      await _speech!.stop();
      _isListening = false;
      notifyListeners();
    } catch (e) {
      LoggerService.error(
        'VoiceRecognitionService: Error stopping speech recognition',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
      _isListening = false;
      notifyListeners();
    }
  }

  /// Cancel listening
  Future<void> cancel() async {
    if (_speech == null) return;

    try {
      await _speech!.cancel();
      _isListening = false;
      _lastWords = '';
      _confidence = 0.0;
      notifyListeners();
    } catch (e) {
      LoggerService.error(
        'VoiceRecognitionService: Error canceling speech recognition',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
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

    // Try calibration profile matching if available and user is calibrated
    if (_calibrationService?.isCalibrated == true) {
      for (final word in availableWords) {
        if (_calibrationService!.matchesUserPattern(word, normalizedSpoken)) {
          return word;
        }
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
