import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:n3rd_game/models/app_theme.dart';

class ThemeService extends ChangeNotifier {
  static const String _storageKey = 'selected_theme';
  static const String _darkModeKey = 'dark_mode_enabled';
  AppTheme _currentTheme = AppThemes.themes.first; // Default theme
  bool _firebaseAvailable = false;
  bool _isDarkMode = false; // Dark mode toggle

  AppTheme get currentTheme => _currentTheme;
  bool get isDarkMode => _isDarkMode;
  Brightness get brightness => _isDarkMode ? Brightness.dark : Brightness.light;

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

    await _loadTheme();
    await _loadDarkMode();
  }

  Future<void> _loadDarkMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool(_darkModeKey) ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load dark mode preference: $e');
    }
  }

  Future<void> _loadTheme() async {
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
            final data = doc.data();
            final themeId = data?['themeId'] as String?;
            if (themeId != null) {
              final theme = AppThemes.themes.firstWhere(
                (t) => t.id == themeId,
                orElse: () => AppThemes.themes.first,
              );
              _currentTheme = theme;
              notifyListeners();
              await _saveLocal();
              return;
            }
          }
        } catch (e) {
          debugPrint('Failed to load theme from Firestore: $e');
        }
      }
    }

    // Load from local storage
    await _loadLocal();
  }

  Future<void> _loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeId = prefs.getString(_storageKey);
      if (themeId != null) {
        final theme = AppThemes.themes.firstWhere(
          (t) => t.id == themeId,
          orElse: () => AppThemes.themes.first,
        );
        _currentTheme = theme;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to load theme from local storage: $e');
    }
  }

  Future<void> _saveLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, _currentTheme.id);
    } catch (e) {
      debugPrint('Failed to save theme to local storage: $e');
    }
  }

  Future<void> _saveToFirestore() async {
    if (!_firebaseAvailable) return;
    final userId = _userId;
    if (userId == null) return;

    try {
      await _firestore!.collection('user_preferences').doc(userId).set(
        {
          'themeId': _currentTheme.id,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Failed to save theme to Firestore: $e');
    }
  }

  Future<void> setTheme(AppTheme theme) async {
    _currentTheme = theme;
    notifyListeners();
    await _saveLocal();
    await _saveToFirestore();
  }

  Future<void> setDarkMode(bool enabled) async {
    _isDarkMode = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_darkModeKey, enabled);
    } catch (e) {
      debugPrint('Failed to save dark mode preference: $e');
    }
  }

  Future<void> toggleDarkMode() async {
    await setDarkMode(!_isDarkMode);
  }

  List<AppTheme> getAvailableThemes({bool? premiumOnly}) {
    if (premiumOnly == null) {
      return AppThemes.themes;
    } else if (premiumOnly) {
      return AppThemes.themes.where((t) => t.isPremium).toList();
    } else {
      return AppThemes.themes.where((t) => !t.isPremium).toList();
    }
  }

  List<AppTheme> getSeasonalThemes() {
    return AppThemes.themes.where((t) => t.isSeasonal).toList();
  }

  AppTheme? getThemeById(String id) {
    try {
      if (AppThemes.themes.isEmpty) return null;
      final theme = AppThemes.themes.firstWhere(
        (t) => t.id == id,
        orElse: () => AppThemes.themes.first, // Safe fallback to default theme
      );
      // Only return theme if it actually matches the requested ID
      return theme.id == id ? theme : null;
    } catch (e) {
      // Additional safety: if firstWhere throws or themes list is empty, return null
      return null;
    }
  }
}
