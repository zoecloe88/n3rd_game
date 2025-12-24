import 'package:flutter/material.dart';

class AppTheme {
  final String id;
  final String name;
  final String description;
  final Map<String, Color> colors;
  final bool isPremium;
  final bool isSeasonal;
  final String?
      season; // 'winter', 'spring', 'summer', 'fall', null for permanent

  AppTheme({
    required this.id,
    required this.name,
    required this.description,
    required this.colors,
    this.isPremium = false,
    this.isSeasonal = false,
    this.season,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'colors': colors.map(
          (k, v) => MapEntry(
            k,
            ((v.a * 255.0).round().clamp(0, 255) << 24 |
                    (v.r * 255.0).round().clamp(0, 255) << 16 |
                    (v.g * 255.0).round().clamp(0, 255) << 8 |
                    (v.b * 255.0).round().clamp(0, 255))
                .toString(),
          ),
        ),
        'isPremium': isPremium,
        'isSeasonal': isSeasonal,
        'season': season,
      };

  factory AppTheme.fromJson(Map<String, dynamic> json) {
    final colorMap = <String, Color>{};
    if (json['colors'] != null) {
      (json['colors'] as Map<String, dynamic>).forEach((key, value) {
        colorMap[key] = Color(int.parse(value as String));
      });
    }

    return AppTheme(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      colors: colorMap,
      isPremium: json['isPremium'] as bool? ?? false,
      isSeasonal: json['isSeasonal'] as bool? ?? false,
      season: json['season'] as String?,
    );
  }
}

// Predefined themes
class AppThemes {
  static final List<AppTheme> themes = [
    // Default theme
    AppTheme(
      id: 'default',
      name: 'Classic',
      description: 'The original N3RD Trivia theme',
      colors: {
        'primary': const Color(0xFF1A1A1A),
        'secondary': const Color(0xFFFFFFFF),
        'accent': const Color(0xFF00D9FF),
      },
      isPremium: false,
    ),

    // Premium themes
    AppTheme(
      id: 'dark_blue',
      name: 'Midnight Blue',
      description: 'Deep blue tones for night play',
      colors: {
        'primary': const Color(0xFF0A1929),
        'secondary': const Color(0xFF1E3A5F),
        'accent': const Color(0xFF4A90E2),
      },
      isPremium: true,
    ),

    AppTheme(
      id: 'forest_green',
      name: 'Forest Green',
      description: 'Natural green palette',
      colors: {
        'primary': const Color(0xFF1B4332),
        'secondary': const Color(0xFF2D6A4F),
        'accent': const Color(0xFF52B788),
      },
      isPremium: true,
    ),

    AppTheme(
      id: 'sunset',
      name: 'Sunset',
      description: 'Warm orange and pink tones',
      colors: {
        'primary': const Color(0xFF2D1B3D),
        'secondary': const Color(0xFF8B4A6B),
        'accent': const Color(0xFFFF6B6B),
      },
      isPremium: true,
    ),

    AppTheme(
      id: 'ocean',
      name: 'Ocean',
      description: 'Cool blue and teal palette',
      colors: {
        'primary': const Color(0xFF003D5B),
        'secondary': const Color(0xFF006494),
        'accent': const Color(0xFF00A8CC),
      },
      isPremium: true,
    ),

    // Seasonal themes
    AppTheme(
      id: 'winter',
      name: 'Winter Wonderland',
      description: 'Cool whites and blues',
      colors: {
        'primary': const Color(0xFF1A1F2E),
        'secondary': const Color(0xFF2D3748),
        'accent': const Color(0xFF90CDF4),
      },
      isPremium: true,
      isSeasonal: true,
      season: 'winter',
    ),

    AppTheme(
      id: 'spring',
      name: 'Spring Bloom',
      description: 'Fresh greens and pinks',
      colors: {
        'primary': const Color(0xFF2D5016),
        'secondary': const Color(0xFF4A7C59),
        'accent': const Color(0xFFFFB6C1),
      },
      isPremium: true,
      isSeasonal: true,
      season: 'spring',
    ),

    AppTheme(
      id: 'summer',
      name: 'Summer Vibes',
      description: 'Bright yellows and oranges',
      colors: {
        'primary': const Color(0xFF3D2817),
        'secondary': const Color(0xFF8B6914),
        'accent': const Color(0xFFFFD700),
      },
      isPremium: true,
      isSeasonal: true,
      season: 'summer',
    ),

    AppTheme(
      id: 'fall',
      name: 'Autumn Leaves',
      description: 'Warm oranges and reds',
      colors: {
        'primary': const Color(0xFF3D2817),
        'secondary': const Color(0xFF8B4513),
        'accent': const Color(0xFFFF6B35),
      },
      isPremium: true,
      isSeasonal: true,
      season: 'fall',
    ),
  ];
}
