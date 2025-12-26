import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage app language settings
class LanguageService extends ChangeNotifier {
  static const String _languageKey = 'app_language_code';
  Locale _currentLocale = const Locale('en', '');

  LanguageService() {
    _loadLanguage();
  }

  Locale get currentLocale => _currentLocale;

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_languageKey);
    if (languageCode != null) {
      _currentLocale = _getLocaleFromLanguageCode(languageCode);
      notifyListeners();
    }
  }

  Future<void> setLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = _getLanguageCodeFromLanguage(language);
    await prefs.setString(_languageKey, languageCode);
    _currentLocale = _getLocaleFromLanguageCode(languageCode);
    notifyListeners();
  }

  String _getLanguageCodeFromLanguage(String language) {
    switch (language.toLowerCase()) {
      case 'spanish':
        return 'es';
      case 'french':
        return 'fr';
      case 'german':
        return 'de';
      case 'english':
      default:
        return 'en';
    }
  }

  Locale _getLocaleFromLanguageCode(String languageCode) {
    switch (languageCode.toLowerCase()) {
      case 'es':
        return const Locale('es', '');
      case 'fr':
        return const Locale('fr', '');
      case 'de':
        return const Locale('de', '');
      case 'en':
      default:
        return const Locale('en', '');
    }
  }

}

