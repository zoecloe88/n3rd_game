import 'package:flutter/material.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Application configuration for MaterialApp
///
/// Centralizes MaterialApp configuration including theme, localization,
/// and accessibility settings.
class AppConfiguration {
  /// Create theme configuration for MaterialApp
  static ThemeData createTheme({required bool isDarkMode}) {
    return ThemeData(
      brightness: isDarkMode ? Brightness.dark : Brightness.light,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: isDarkMode
            ? AppColors.darkPrimaryButton
            : AppColors.primaryButton,
        brightness: isDarkMode ? Brightness.dark : Brightness.light,
      ),
      scaffoldBackgroundColor: isDarkMode
          ? AppColors.darkCardBackground
          : AppColors.cardBackground,
      cardColor: isDarkMode
          ? AppColors.darkCardBackground
          : AppColors.cardBackground,
    );
  }

  /// Create dark theme configuration
  static ThemeData createDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.darkPrimaryButton,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: AppColors.darkCardBackground,
      cardColor: AppColors.darkCardBackground,
    );
  }

  /// Get localization delegates
  static List<LocalizationsDelegate<dynamic>> getLocalizationDelegates() {
    return const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ];
  }

  /// Get supported locales
  static List<Locale> getSupportedLocales() {
    return const [
      Locale('en', ''), // English
      Locale('es', ''), // Spanish
      Locale('fr', ''), // French
      Locale('de', ''), // German
    ];
  }

  /// Create MediaQuery builder with accessibility text scaling
  static Widget Function(BuildContext, Widget?) createAccessibilityBuilder({
    required double fontSizeMultiplier,
  }) {
    return (BuildContext context, Widget? child) {
      final systemTextScaler = MediaQuery.textScalerOf(context);
      final combinedScaler = TextScaler.linear(
        systemTextScaler.scale(1.0) * fontSizeMultiplier,
      );
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: combinedScaler,
        ),
        child: child!,
      );
    };
  }

  /// Get theme mode based on theme service
  static ThemeMode getThemeMode({required bool isDarkMode}) {
    return isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }
}
