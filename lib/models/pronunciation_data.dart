class PronunciationData {
  final String word;
  final String phonetic; // IPA or phonetic spelling
  final List<String> alternativePronunciations; // Common variations
  final List<String> homophones; // Words that sound the same
  final String? language; // Default: 'en'

  PronunciationData({
    required this.word,
    required this.phonetic,
    this.alternativePronunciations = const [],
    this.homophones = const [],
    this.language,
  });

  Map<String, dynamic> toJson() => {
        'word': word.toLowerCase(),
        'phonetic': phonetic,
        'alternativePronunciations': alternativePronunciations,
        'homophones': homophones,
        'language': language ?? 'en',
      };

  factory PronunciationData.fromJson(Map<String, dynamic> json) {
    final word = json['word'] as String? ?? '';
    final phonetic = json['phonetic'] as String? ?? '';

    // CRITICAL: Validate required fields to prevent invalid objects from corrupted data
    if (word.trim().isEmpty) {
      throw const FormatException('PronunciationData word cannot be empty');
    }
    if (phonetic.trim().isEmpty) {
      throw const FormatException('PronunciationData phonetic cannot be empty');
    }

    return PronunciationData(
      word: word,
      phonetic: phonetic,
      alternativePronunciations: List<String>.from(
        json['alternativePronunciations'] ?? [],
      ),
      homophones: List<String>.from(json['homophones'] ?? []),
      language: json['language'] as String?,
    );
  }

  /// Check if a spoken word matches this pronunciation
  bool matches(String spokenWord) {
    final normalizedSpoken = spokenWord.trim().toLowerCase();
    final normalizedWord = word.trim().toLowerCase();

    // Exact match
    if (normalizedSpoken == normalizedWord) return true;

    // Homophone match
    if (homophones.any((h) => h.trim().toLowerCase() == normalizedSpoken)) {
      return true;
    }

    // Phonetic similarity (simple string similarity for now)
    // In production, use proper phonetic matching library
    return _phoneticSimilarity(normalizedSpoken, normalizedWord) > 0.7;
  }

  double _phoneticSimilarity(String a, String b) {
    // Simple Levenshtein distance-based similarity
    final distance = _levenshteinDistance(a, b);
    final maxLen = a.length > b.length ? a.length : b.length;
    if (maxLen == 0) return 1.0;
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
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[a.length][b.length];
  }
}
