import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:convert';
import 'package:n3rd_game/models/voice_profile.dart';
import 'package:n3rd_game/services/voice_recognition_service.dart';
import 'package:n3rd_game/services/pronunciation_dictionary_service.dart';
import 'package:n3rd_game/services/logger_service.dart';

class VoiceCalibrationService extends ChangeNotifier {
  static const String _storageKey = 'voice_profile';
  VoiceProfile? _profile;
  bool _isCalibrating = false;
  int _calibrationStep = 0;
  List<String> _calibrationWords = [];
  final Map<String, List<String>> _calibrationResults =
      {}; // word -> list of recognized pronunciations
  final Map<String, List<double>> _calibrationConfidences =
      {}; // word -> list of confidence scores
  bool _firebaseAvailable = false;

  // Cache SharedPreferences instance for better performance
  SharedPreferences? _prefs;

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

  // Get or initialize SharedPreferences
  Future<SharedPreferences> _getPrefs() async {
    if (_prefs != null) return _prefs!;
    try {
      _prefs = await SharedPreferences.getInstance();
      return _prefs!;
    } catch (e) {
      LoggerService.error(
        'VoiceCalibrationService: Failed to initialize SharedPreferences',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
      rethrow;
    }
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
          LoggerService.error(
            'VoiceCalibrationService: Failed to load voice profile from Firestore',
            error: e,
            stack: StackTrace.current,
            fatal: false,
          );
        }
      }
    }

    // Load from local storage
    await _loadLocal();
  }

  Future<void> _loadLocal() async {
    try {
      final prefs = await _getPrefs();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        _profile = VoiceProfile.fromJson(data);
        notifyListeners();
      }
    } catch (e) {
      LoggerService.error(
        'VoiceCalibrationService: Failed to load voice profile from local storage',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
    }
  }

  Future<void> _saveLocal() async {
    if (_profile == null) return;
    try {
      final prefs = await _getPrefs();
      await prefs.setString(_storageKey, jsonEncode(_profile!.toJson()));
    } catch (e) {
      LoggerService.error(
        'VoiceCalibrationService: Failed to save voice profile to local storage',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
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
      LoggerService.error(
        'VoiceCalibrationService: Failed to save voice profile to Firestore',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
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
      LoggerService.warning(
        'VoiceCalibrationService: Pronunciation service not loaded, using default calibration words',
      );
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

    // Store confidence score for weighted accuracy calculation
    final confidence = recognitionService.confidence;
    _calibrationConfidences
        .putIfAbsent(normalizedWord, () => [])
        .add(confidence);

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

    // Enhanced accuracy calculation with fuzzy matching and confidence weighting
    double totalWeightedScore = 0.0;
    double totalWeight = 0.0;

    for (final entry in _calibrationResults.entries) {
      final word = entry.key;
      final recognitions = entry.value;
      final confidences = _calibrationConfidences[word] ?? [];

      // Calculate best match score for this word across all samples
      double bestWordScore = 0.0;
      double bestWordWeight = 0.0;

      for (int i = 0; i < recognitions.length; i++) {
        final recognition = recognitions[i];
        final confidence = i < confidences.length ? confidences[i] : 0.5;

        // Use fuzzy matching (Levenshtein distance) for better accuracy
        final similarity = _calculateSimilarity(word, recognition);

        // Weight the score by confidence
        final weightedScore = similarity * confidence;
        final weight = confidence;

        if (weightedScore > bestWordScore) {
          bestWordScore = weightedScore;
          bestWordWeight = weight;
        }
      }

      // If no confidence data, use simple matching
      if (bestWordWeight == 0.0) {
        final hasMatch = recognitions.any((r) {
          final similarity = _calculateSimilarity(word, r);
          return similarity > 0.7; // 70% similarity threshold
        });
        bestWordScore = hasMatch ? 1.0 : 0.0;
        bestWordWeight = 1.0;
      }

      totalWeightedScore += bestWordScore * bestWordWeight;
      totalWeight += bestWordWeight;
    }

    // Calculate final accuracy score
    final accuracyScore = totalWeight > 0
        ? totalWeightedScore / totalWeight
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
    _calibrationConfidences.clear();
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

  /// Calculate similarity between two strings using Levenshtein distance
  double _calculateSimilarity(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    // Check if one contains the other (exact substring match)
    if (a.contains(b) || b.contains(a)) {
      return 0.9; // High score for substring match
    }

    // Calculate Levenshtein distance
    final distance = _levenshteinDistance(a, b);
    final maxLen = a.length > b.length ? a.length : b.length;
    return 1.0 - (distance / maxLen);
  }

  /// Calculate Levenshtein distance between two strings
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
    // Cancel any ongoing calibration
    if (_isCalibrating) {
      cancelCalibration();
    }
    super.dispose();
  }
}
