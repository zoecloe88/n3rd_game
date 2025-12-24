import 'package:n3rd_game/models/difficulty_level.dart';

/// Represents a single trivia question item
///
/// A TriviaItem contains:
/// - A category/question prompt
/// - A list of words (correct answers + distractors)
/// - The correct answers subset
/// - Optional difficulty and theme for personalization
///
/// This is the core data structure for all trivia questions in the game.
class TriviaItem {
  /// The category/question prompt (e.g., "These are capital cities")
  final String category;

  /// All available words (correct answers + distractors, typically 6 total)
  final List<String> words;

  /// The subset of words that are correct answers (typically 3)
  final List<String> correctAnswers;

  /// Optional difficulty level for adaptive gameplay
  final DifficultyLevel? difficulty;

  /// Optional theme for content personalization (e.g., 'geography', 'science', 'arts')
  final String? theme;

  /// Timestamp when this trivia item was generated/created
  /// Used for content freshness tracking
  final DateTime? createdAt;

  /// Timestamp when this trivia item was last used
  /// Used for content rotation and freshness tracking
  final DateTime? lastUsedAt;

  /// Usage count - how many times this trivia item has been used
  /// Used for content rotation and freshness tracking
  final int usageCount;

  /// Creates a new TriviaItem
  ///
  /// Required parameters:
  /// - [category]: The question/category text (must not be empty)
  /// - [words]: List of all words (must not be empty)
  /// - [correctAnswers]: List of correct answers (must not be empty)
  ///
  /// Optional parameters:
  /// - [difficulty]: Difficulty level (default: null)
  /// - [theme]: Theme for personalization (default: null)
  ///
  /// Throws:
  /// - AssertionError if required fields are empty
  TriviaItem({
    required this.category,
    required this.words,
    required this.correctAnswers,
    this.difficulty,
    this.theme,
    this.createdAt,
    this.lastUsedAt,
    this.usageCount = 0,
  });

  /// Serializes this TriviaItem to JSON
  ///
  /// Returns a Map suitable for JSON encoding.
  /// Used for persistence and data transfer.
  Map<String, dynamic> toJson() => {
        'category': category,
        'words': words,
        'correctAnswers': correctAnswers,
        if (difficulty != null) 'difficulty': difficulty!.name,
        if (theme != null) 'theme': theme,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (lastUsedAt != null) 'lastUsedAt': lastUsedAt!.toIso8601String(),
        'usageCount': usageCount,
      };

  /// Deserializes a TriviaItem from JSON
  ///
  /// Parameters:
  /// - [json]: Map containing serialized TriviaItem data
  ///
  /// Returns:
  /// - A new TriviaItem instance
  ///
  /// Throws:
  /// - FormatException if required fields are missing or empty
  factory TriviaItem.fromJson(Map<String, dynamic> json) {
    DifficultyLevel? difficulty;
    if (json['difficulty'] != null) {
      difficulty = DifficultyLevel.values.firstWhere(
        (d) => d.name == json['difficulty'],
        orElse: () => DifficultyLevel.medium,
      );
    }

    // Validate category is not empty
    final category = json['category'] as String? ?? '';
    if (category.isEmpty) {
      throw const FormatException(
        'TriviaItem.fromJson: category cannot be empty',
      );
    }

    // Validate words list is not empty
    final words = List<String>.from(json['words'] as List? ?? []);
    if (words.isEmpty) {
      throw const FormatException(
        'TriviaItem.fromJson: words list cannot be empty',
      );
    }

    // Validate correctAnswers list is not empty
    final correctAnswers = List<String>.from(
      json['correctAnswers'] as List? ?? [],
    );
    if (correctAnswers.isEmpty) {
      throw const FormatException(
        'TriviaItem.fromJson: correctAnswers list cannot be empty',
      );
    }

    DateTime? createdAt;
    if (json['createdAt'] != null) {
      try {
        createdAt = DateTime.parse(json['createdAt'] as String);
      } catch (e) {
        // Invalid date format, ignore
      }
    }

    DateTime? lastUsedAt;
    if (json['lastUsedAt'] != null) {
      try {
        lastUsedAt = DateTime.parse(json['lastUsedAt'] as String);
      } catch (e) {
        // Invalid date format, ignore
      }
    }

    return TriviaItem(
      category: category,
      words: words,
      correctAnswers: correctAnswers,
      difficulty: difficulty,
      theme: json['theme'] as String?,
      createdAt: createdAt,
      lastUsedAt: lastUsedAt,
      usageCount: (json['usageCount'] as int?) ?? 0,
    );
  }

  /// Creates a copy of this TriviaItem with updated freshness tracking
  TriviaItem copyWith({
    String? category,
    List<String>? words,
    List<String>? correctAnswers,
    DifficultyLevel? difficulty,
    String? theme,
    DateTime? createdAt,
    DateTime? lastUsedAt,
    int? usageCount,
  }) {
    return TriviaItem(
      category: category ?? this.category,
      words: words ?? this.words,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      difficulty: difficulty ?? this.difficulty,
      theme: theme ?? this.theme,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      usageCount: usageCount ?? this.usageCount,
    );
  }

  /// Marks this trivia item as used (updates lastUsedAt and increments usageCount)
  TriviaItem markAsUsed() {
    return copyWith(
      lastUsedAt: DateTime.now(),
      usageCount: usageCount + 1,
      createdAt:
          createdAt ?? DateTime.now(), // Set createdAt if not already set
    );
  }

  /// Gets the age of this trivia item in days
  int get ageInDays {
    if (createdAt == null) return 0;
    return DateTime.now().difference(createdAt!).inDays;
  }

  /// Gets the time since last use in days
  int get daysSinceLastUse {
    if (lastUsedAt == null) return 999; // Never used, prioritize
    return DateTime.now().difference(lastUsedAt!).inDays;
  }

  /// Checks if this trivia item is stale (not used in X days)
  bool isStale({int staleDays = 30}) {
    return daysSinceLastUse > staleDays;
  }
}
