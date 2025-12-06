class VoiceProfile {
  final String userId;
  final Map<String, List<String>>
  pronunciationPatterns; // word -> list of recognized pronunciations
  final double accuracyScore; // 0.0 to 1.0
  final DateTime calibratedAt;
  final DateTime? lastUpdated;
  final bool isActive;

  VoiceProfile({
    required this.userId,
    required this.pronunciationPatterns,
    this.accuracyScore = 0.0,
    required this.calibratedAt,
    this.lastUpdated,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'pronunciationPatterns': pronunciationPatterns.map(
      (k, v) => MapEntry(k, v),
    ),
    'accuracyScore': accuracyScore,
    'calibratedAt': calibratedAt.toIso8601String(),
    'lastUpdated': lastUpdated?.toIso8601String(),
    'isActive': isActive,
  };

  factory VoiceProfile.fromJson(Map<String, dynamic> json) => VoiceProfile(
    userId: json['userId'] as String,
    pronunciationPatterns:
        (json['pronunciationPatterns'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, List<String>.from(v as List)),
        ) ??
        {},
    accuracyScore: (json['accuracyScore'] as num?)?.toDouble() ?? 0.0,
    calibratedAt: DateTime.parse(json['calibratedAt'] as String),
    lastUpdated: json['lastUpdated'] != null
        ? DateTime.parse(json['lastUpdated'] as String)
        : null,
    isActive: json['isActive'] as bool? ?? true,
  );

  VoiceProfile copyWith({
    String? userId,
    Map<String, List<String>>? pronunciationPatterns,
    double? accuracyScore,
    DateTime? calibratedAt,
    DateTime? lastUpdated,
    bool? isActive,
  }) {
    return VoiceProfile(
      userId: userId ?? this.userId,
      pronunciationPatterns:
          pronunciationPatterns ?? this.pronunciationPatterns,
      accuracyScore: accuracyScore ?? this.accuracyScore,
      calibratedAt: calibratedAt ?? this.calibratedAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isActive: isActive ?? this.isActive,
    );
  }
}
