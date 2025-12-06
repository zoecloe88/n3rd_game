import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:convert';
import 'package:n3rd_game/models/accessibility_settings.dart';

class AccessibilityService extends ChangeNotifier {
  static const String _storageKey = 'accessibility_settings';
  AccessibilitySettings _settings = AccessibilitySettings();
  bool _firebaseAvailable = false;

  AccessibilitySettings get settings => _settings;

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

    await _loadSettings();
  }

  Future<void> _loadSettings() async {
    // Try Firestore first
    if (_firebaseAvailable) {
      final userId = _userId;
      if (userId != null) {
        try {
          final doc = await _firestore!
              .collection('user_preferences')
              .doc(userId)
              .get();
          if (doc.exists && doc.data() != null) {
            final docData = doc.data();
            final data = docData?['accessibility'] as Map<String, dynamic>?;
            if (data != null) {
              _settings = AccessibilitySettings.fromJson(data);
              notifyListeners();
              await _saveLocal();
              return;
            }
          }
        } catch (e) {
          debugPrint(
            'Failed to load accessibility settings from Firestore: $e',
          );
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
        _settings = AccessibilitySettings.fromJson(data);
        notifyListeners();
      }
    } catch (e) {
      debugPrint(
        'Failed to load accessibility settings from local storage: $e',
      );
    }
  }

  Future<void> _saveLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_settings.toJson()));
    } catch (e) {
      debugPrint('Failed to save accessibility settings to local storage: $e');
    }
  }

  Future<void> _saveToFirestore() async {
    if (!_firebaseAvailable) return;
    final userId = _userId;
    if (userId == null) return;

    try {
      await _firestore!.collection('user_preferences').doc(userId).set({
        'accessibility': _settings.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to save accessibility settings to Firestore: $e');
    }
  }

  Future<void> updateSettings(AccessibilitySettings newSettings) async {
    _settings = newSettings;
    notifyListeners();
    await _saveLocal();
    await _saveToFirestore();
  }

  // Convenience methods
  Future<void> setHighContrastMode(bool enabled) async {
    _settings = _settings.copyWith(highContrastMode: enabled);
    notifyListeners();
    await _saveLocal();
    await _saveToFirestore();
  }

  Future<void> setColorblindPalette(String palette) async {
    _settings = _settings.copyWith(colorblindPalette: palette);
    notifyListeners();
    await _saveLocal();
    await _saveToFirestore();
  }

  Future<void> setFontSizeMultiplier(double multiplier) async {
    _settings = _settings.copyWith(
      fontSizeMultiplier: multiplier.clamp(0.8, 2.0),
    );
    notifyListeners();
    await _saveLocal();
    await _saveToFirestore();
  }

  Future<void> setLargerTouchTargets(bool enabled) async {
    _settings = _settings.copyWith(largerTouchTargets: enabled);
    notifyListeners();
    await _saveLocal();
    await _saveToFirestore();
  }

  Future<void> setReducedMotion(bool enabled) async {
    _settings = _settings.copyWith(reducedMotion: enabled);
    notifyListeners();
    await _saveLocal();
    await _saveToFirestore();
  }

  Future<void> setExtendedTimeLimits(bool enabled) async {
    _settings = _settings.copyWith(extendedTimeLimits: enabled);
    notifyListeners();
    await _saveLocal();
    await _saveToFirestore();
  }
}
