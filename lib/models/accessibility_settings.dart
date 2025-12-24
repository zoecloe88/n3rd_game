class AccessibilitySettings {
  final bool highContrastMode;
  final String
      colorblindPalette; // 'none', 'protanopia', 'deuteranopia', 'tritanopia'
  final double fontSizeMultiplier; // 1.0 = normal, 1.2 = 20% larger, etc.
  final bool largerTouchTargets;
  final bool screenReaderEnabled;
  final bool reducedMotion;
  final bool extendedTimeLimits;
  final bool visualAudioIndicators;

  AccessibilitySettings({
    this.highContrastMode = false,
    this.colorblindPalette = 'none',
    this.fontSizeMultiplier = 1.0,
    this.largerTouchTargets = false,
    this.screenReaderEnabled = false,
    this.reducedMotion = false,
    this.extendedTimeLimits = false,
    this.visualAudioIndicators = true,
  });

  Map<String, dynamic> toJson() => {
        'highContrastMode': highContrastMode,
        'colorblindPalette': colorblindPalette,
        'fontSizeMultiplier': fontSizeMultiplier,
        'largerTouchTargets': largerTouchTargets,
        'screenReaderEnabled': screenReaderEnabled,
        'reducedMotion': reducedMotion,
        'extendedTimeLimits': extendedTimeLimits,
        'visualAudioIndicators': visualAudioIndicators,
      };

  factory AccessibilitySettings.fromJson(Map<String, dynamic> json) =>
      AccessibilitySettings(
        highContrastMode: json['highContrastMode'] as bool? ?? false,
        colorblindPalette: json['colorblindPalette'] as String? ?? 'none',
        fontSizeMultiplier:
            (json['fontSizeMultiplier'] as num?)?.toDouble() ?? 1.0,
        largerTouchTargets: json['largerTouchTargets'] as bool? ?? false,
        screenReaderEnabled: json['screenReaderEnabled'] as bool? ?? false,
        reducedMotion: json['reducedMotion'] as bool? ?? false,
        extendedTimeLimits: json['extendedTimeLimits'] as bool? ?? false,
        visualAudioIndicators: json['visualAudioIndicators'] as bool? ?? true,
      );

  AccessibilitySettings copyWith({
    bool? highContrastMode,
    String? colorblindPalette,
    double? fontSizeMultiplier,
    bool? largerTouchTargets,
    bool? screenReaderEnabled,
    bool? reducedMotion,
    bool? extendedTimeLimits,
    bool? visualAudioIndicators,
  }) {
    return AccessibilitySettings(
      highContrastMode: highContrastMode ?? this.highContrastMode,
      colorblindPalette: colorblindPalette ?? this.colorblindPalette,
      fontSizeMultiplier: fontSizeMultiplier ?? this.fontSizeMultiplier,
      largerTouchTargets: largerTouchTargets ?? this.largerTouchTargets,
      screenReaderEnabled: screenReaderEnabled ?? this.screenReaderEnabled,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      extendedTimeLimits: extendedTimeLimits ?? this.extendedTimeLimits,
      visualAudioIndicators:
          visualAudioIndicators ?? this.visualAudioIndicators,
    );
  }
}
