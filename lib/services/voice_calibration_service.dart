import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:convert';
import 'package:n3rd_game/models/voice_profile.dart';
import 'package:n3rd_game/services/voice_recognition_service.dart';
import 'package:n3rd_game/services/pronunciation_dictionary_service.dart';

class VoiceCalibrationService extends ChangeNotifier {
  static const String _storageKey = 'voice_profile';
  VoiceProfile? _profile;
  bool _isCalibrating = false;
  int _calibrationStep = 0;
  List<String> _calibrationWords = [];
  final Map<String, List<String>> _calibrationResults =
      {}; // word -> list of recognized pronunciations
  bool _firebaseAvailable = false;

  VoiceProfile? get profile => _profile;
  bool get isCalibrating => _isCalibrating;
  int get calibrationStep => _calibrationStep;
  List<String> get calibrationWords => _calibrationWords;
  bool get isCalibrated => _profile != null && _profile!.isActive;

  FirebaseFirestore? get _firestore {
    if (!_firebaseAvailable) return null;
    try {
      Firebase.app();
      return FirebaseFirestore.instance;
    } catch (e) {
      _firebaseAvailable = false;
      return null;
    }
  }

  String? get _userId {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (e) {
      return null;
    }
  }

  Future<void> init() async {
    try {
      Firebase.app();
      _firebaseAvailable = true;
    } catch (e) {
      _firebaseAvailable = false;
    }

    await _loadProfile();
  }

  Future<void> _loadProfile() async {
    // Try Firestore first
    if (_firebaseAvailable) {
      final userId = _userId;
      if (userId != null) {
        try {
          final doc =
              await _firestore!.collection('voice_profiles').doc(userId).get();
          if (doc.exists && doc.data() != null) {
            final data = doc.data();
            if (data != null) {
              _profile = VoiceProfile.fromJson(data);
            }
            notifyListeners();
            await _saveLocal();
            return;
          }
        } catch (e) {
          debugPrint('Failed to load voice profile from Firestore: $e');
        }
      }
    }

    // Load from local storage
    await _loadLocal();
  }

  Future<void> _loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        _profile = VoiceProfile.fromJson(data);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to load voice profile from local storage: $e');
    }
  }

  Future<void> _saveLocal() async {
    if (_profile == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_profile!.toJson()));
    } catch (e) {
      debugPrint('Failed to save voice profile to local storage: $e');
    }
  }

  Future<void> _saveToFirestore() async {
    if (!_firebaseAvailable || _profile == null) return;
    final userId = _userId;
    if (userId == null) return;

    try {
      await _firestore!
          .collection('voice_profiles')
          .doc(userId)
          .set(_profile!.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to save voice profile to Firestore: $e');
    }
  }

  /// Start calibration process
  Future<void> startCalibration({
    required PronunciationDictionaryService pronunciationService,
    required VoiceRecognitionService recognitionService,
  }) async {
    if (_isCalibrating) return;

    _isCalibrating = true;
    _calibrationStep = 0;
    _calibrationResults.clear();

    // CRITICAL: Validate pronunciation service is loaded before accessing words
    if (!pronunciationService.isLoaded) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ Warning: Pronunciation service not loaded, using default calibration words',
        );
      }
      _calibrationWords = ['serendipity', 'ephemeral', 'eloquent'];
    } else {
      // Select 3 random words from dictionary for calibration
      final allWords = pronunciationService.getAllWords();
      if (allWords.length < 3) {
        // Use default words if dictionary is small
        _calibrationWords = ['serendipity', 'ephemeral', 'eloquent'];
      } else {
        allWords.shuffle();
        _calibrationWords = allWords.take(3).toList();
      }
    }

    notifyListeners();
  }

  /// Record calibration sample for current word
  Future<bool> recordCalibrationSample({
    required String word,
    required String recognizedText,
    required VoiceRecognitionService recognitionService,
  }) async {
    if (!_isCalibrating) return false;

    final normalizedWord = word.trim().toLowerCase();
    final normalizedRecognized = recognizedText.trim().toLowerCase();

    // Store the recognized pronunciation
    _calibrationResults
        .putIfAbsent(normalizedWord, () => [])
        .add(normalizedRecognized);

    return true;
  }

  /// Complete calibration for current word (user speaks it 3 times)
  Future<void> completeWordCalibration(String word) async {
    if (!_isCalibrating) return;

    _calibrationStep++;

    if (_calibrationStep >= _calibrationWords.length) {
      // All words calibrated, finish calibration
      await _finishCalibration();
    } else {
      notifyListeners();
    }
  }

  /// Finish calibration and create voice profile
  Future<void> _finishCalibration() async {
    if (_calibrationResults.isEmpty) {
      _isCalibrating = false;
      notifyListeners();
      return;
    }

    final userId = _userId ?? 'local_user';

    // Calculate accuracy score (simple: how many words were recognized correctly)
    int correctRecognitions = 0;
    int totalRecognitions = 0;

    for (final entry in _calibrationResults.entries) {
      final word = entry.key;
      final recognitions = entry.value;
      totalRecognitions += recognitions.length;

      // Check if at least one recognition matches the word
      if (recognitions.any((r) => r.contains(word) || word.contains(r))) {
        correctRecognitions++;
      }
    }

    final accuracyScore = totalRecognitions > 0
        ? correctRecognitions / _calibrationWords.length
        : 0.0;

    // Create voice profile
    _profile = VoiceProfile(
      userId: userId,
      pronunciationPatterns: _calibrationResults,
      accuracyScore: accuracyScore,
      calibratedAt: DateTime.now(),
      isActive: accuracyScore >= 0.6, // Require at least 60% accuracy
    );

    _isCalibrating = false;
    _calibrationStep = 0;
    _calibrationResults.clear();
    _calibrationWords.clear();

    await _saveLocal();
    await _saveToFirestore();

    notifyListeners();
  }

  /// Cancel calibration
  void cancelCalibration() {
    _isCalibrating = false;
    _calibrationStep = 0;
    _calibrationResults.clear();
    _calibrationWords.clear();
    notifyListeners();
  }

  /// Get current calibration word
  String? getCurrentCalibrationWord() {
    if (!_isCalibrating || _calibrationStep >= _calibrationWords.length) {
      return null;
    }
    return _calibrationWords[_calibrationStep];
  }

  /// Get calibration progress (0.0 to 1.0)
  double getCalibrationProgress() {
    if (!_isCalibrating || _calibrationWords.isEmpty) return 0.0;
    return _calibrationStep / _calibrationWords.length;
  }

  /// Check if word matches user's pronunciation pattern
  bool matchesUserPattern(String word, String spokenText) {
    if (_profile == null) return false;

    final normalizedWord = word.trim().toLowerCase();
    final normalizedSpoken = spokenText.trim().toLowerCase();

    // Check if we have a pattern for this word
    final patterns = _profile!.pronunciationPatterns[normalizedWord];
    if (patterns != null) {
      return patterns.any((pattern) {
        final normalizedPattern = pattern.trim().toLowerCase();
        return normalizedSpoken.contains(normalizedPattern) ||
            normalizedPattern.contains(normalizedSpoken);
      });
    }

    // Fallback: check if spoken text contains the word or vice versa
    return normalizedSpoken.contains(normalizedWord) ||
        normalizedWord.contains(normalizedSpoken);
  }
}
