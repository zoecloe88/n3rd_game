import 'package:n3rd_game/models/trivia_item.dart';

/// Validates trivia content structure and quality
///
/// Ensures trivia items meet the required format:
/// - Exactly 3 correct answers
/// - Exactly 6 total words (3 correct + 3 incorrect)
/// - No duplicate words
/// - Valid category and question
class TriviaValidator {
  /// Validates a single trivia item
  /// Returns null if valid, error message if invalid
  static String? validateTriviaItem(TriviaItem item) {
    // Check category (question)
    if (item.category.isEmpty || item.category.trim().isEmpty) {
      return 'Category cannot be empty';
    }

    // Check words
    if (item.words.length != 6) {
      return 'Must have exactly 6 words (3 correct + 3 incorrect)';
    }

    // Check for duplicate words
    final uniqueWords = item.words.toSet();
    if (uniqueWords.length != item.words.length) {
      return 'Duplicate words found in words list';
    }

    // Check correctAnswers
    if (item.correctAnswers.length != 3) {
      return 'Must have exactly 3 correct answers';
    }

    // Check that all correct answers are in words
    for (final correctAnswer in item.correctAnswers) {
      if (!item.words.contains(correctAnswer)) {
        return 'Correct answer "$correctAnswer" not found in words list';
      }
    }

    // Check for duplicate correct answers
    final uniqueCorrectAnswers = item.correctAnswers.toSet();
    if (uniqueCorrectAnswers.length != item.correctAnswers.length) {
      return 'Duplicate correct answers found';
    }

    // Check that correct answers are not empty
    for (final answer in item.correctAnswers) {
      if (answer.isEmpty || answer.trim().isEmpty) {
        return 'Correct answer cannot be empty';
      }
    }

    // Check that all words are not empty
    for (final word in item.words) {
      if (word.isEmpty || word.trim().isEmpty) {
        return 'Word cannot be empty';
      }
    }

    return null; // Valid
  }

  /// Validates a list of trivia items
  /// Returns list of validation errors (empty if all valid)
  static List<String> validateTriviaList(List<TriviaItem> items) {
    final errors = <String>[];

    for (int i = 0; i < items.length; i++) {
      final error = validateTriviaItem(items[i]);
      if (error != null) {
        errors.add('Item $i: $error');
      }
    }

    // Check for duplicate categories
    final categories = <String>{};
    for (int i = 0; i < items.length; i++) {
      final category = items[i].category.trim().toLowerCase();
      if (categories.contains(category)) {
        errors.add('Item $i: Duplicate category found');
      }
      categories.add(category);
    }

    // Check for semantically similar categories (warnings, not errors)
    for (int i = 0; i < items.length; i++) {
      for (int j = i + 1; j < items.length; j++) {
        final category1 = items[i].category.trim().toLowerCase();
        final category2 = items[j].category.trim().toLowerCase();
        final similarity = _calculateSimilarity(category1, category2);
        if (similarity > 0.85) {
          errors.add(
            'Item $i and $j: Categories are very similar ("${items[i].category}" and "${items[j].category}")',
          );
        }
      }
    }

    return errors;
  }

  /// Checks if trivia item has quality issues (warnings, not errors)
  /// Returns list of warnings (empty if no issues)
  static List<String> checkTriviaQuality(TriviaItem item) {
    final warnings = <String>[];

    // Check category (question) length
    if (item.category.length < 10) {
      warnings.add('Category is very short (may be unclear)');
    }
    if (item.category.length > 200) {
      warnings.add('Category is very long (may be hard to read)');
    }

    // Check word lengths
    for (final word in item.words) {
      if (word.length > 30) {
        warnings.add('Word "$word" is very long');
      }
      if (word.length < 2) {
        warnings.add('Word "$word" is very short (may be unclear)');
      }
    }

    // Check for semantic similarity between correct answers and distractors
    // If all words are too similar, the question may be too easy or confusing
    final allWordsLower = item.words
        .map((w) => w.toLowerCase().trim())
        .toList();
    final correctAnswersLower = item.correctAnswers
        .map((w) => w.toLowerCase().trim())
        .toList();

    // Check if correct answers are too similar to each other
    for (int i = 0; i < correctAnswersLower.length; i++) {
      for (int j = i + 1; j < correctAnswersLower.length; j++) {
        final similarity = _calculateSimilarity(
          correctAnswersLower[i],
          correctAnswersLower[j],
        );
        if (similarity > 0.8) {
          warnings.add(
            'Correct answers "${item.correctAnswers[i]}" and "${item.correctAnswers[j]}" are very similar',
          );
        }
      }
    }

    // Check if distractors are too similar to correct answers
    final distractors = allWordsLower
        .where((w) => !correctAnswersLower.contains(w))
        .toList();
    for (final distractor in distractors) {
      for (final correct in correctAnswersLower) {
        final similarity = _calculateSimilarity(distractor, correct);
        if (similarity > 0.7) {
          warnings.add(
            'Distractor "$distractor" is very similar to correct answer "$correct" (may be confusing)',
          );
        }
      }
    }

    // Check for proper capitalization (all lowercase or all uppercase may indicate issues)
    final allLowercase = item.words.every((w) => w == w.toLowerCase());
    final allUppercase = item.words.every((w) => w == w.toUpperCase());
    if (allLowercase || allUppercase) {
      warnings.add(
        'All words have the same capitalization (may indicate formatting issues)',
      );
    }

    // Check for special characters that might indicate formatting issues
    final hasExcessiveSpecialChars = item.words.any(
      (w) => RegExp(r'[!@#$%^&*(),.?":{}|<>]').allMatches(w).length > 2,
    );
    if (hasExcessiveSpecialChars) {
      warnings.add('Some words contain excessive special characters');
    }

    return warnings;
  }

  /// Get content freshness metrics for trivia list
  /// Returns map with freshness statistics
  static Map<String, dynamic> getContentFreshnessMetrics(
    List<TriviaItem> items,
  ) {
    final now = DateTime.now();
    final categories = <String, int>{};
    final difficulties = <String, int>{};

    for (final item in items) {
      // Count categories
      categories[item.category] = (categories[item.category] ?? 0) + 1;

      // Count difficulties
      final difficulty = item.difficulty?.toString() ?? 'unknown';
      difficulties[difficulty] = (difficulties[difficulty] ?? 0) + 1;
    }

    return {
      'totalItems': items.length,
      'uniqueCategories': categories.length,
      'categoryDistribution': categories,
      'difficultyDistribution': difficulties,
      'averageCategoryLength': items.isEmpty
          ? 0.0
          : items.map((i) => i.category.length).reduce((a, b) => a + b) /
                items.length,
      'timestamp': now.toIso8601String(),
    };
  }

  /// Check difficulty distribution across trivia list
  /// Returns warnings if distribution is unbalanced
  static List<String> checkDifficultyDistribution(List<TriviaItem> items) {
    final warnings = <String>[];

    if (items.isEmpty) {
      warnings.add('Empty trivia list');
      return warnings;
    }

    final difficultyCounts = <String, int>{};
    for (final item in items) {
      final difficulty = item.difficulty?.toString() ?? 'unknown';
      difficultyCounts[difficulty] = (difficultyCounts[difficulty] ?? 0) + 1;
    }

    final total = items.length;

    // Warn if any difficulty has less than 10% or more than 50% of items
    for (final entry in difficultyCounts.entries) {
      final percentage = (entry.value / total) * 100;
      if (percentage < 10) {
        warnings.add(
          'Difficulty "${entry.key}" has only ${percentage.toStringAsFixed(1)}% of items (may be underrepresented)',
        );
      } else if (percentage > 50) {
        warnings.add(
          'Difficulty "${entry.key}" has ${percentage.toStringAsFixed(1)}% of items (may be overrepresented)',
        );
      }
    }

    return warnings;
  }

  /// Calculate simple string similarity (0.0 to 1.0)
  /// Uses Levenshtein distance normalized by max length
  static double _calculateSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final maxLen = a.length > b.length ? a.length : b.length;
    final distance = _levenshteinDistance(a, b);
    return 1.0 - (distance / maxLen);
  }

  /// Calculate Levenshtein distance between two strings
  static int _levenshteinDistance(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final matrix = List.generate(
      a.length + 1,
      (_) => List<int>.filled(b.length + 1, 0),
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
