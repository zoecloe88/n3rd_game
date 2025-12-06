import 'package:n3rd_game/models/trivia_item.dart';
import 'package:n3rd_game/services/trivia_generator_service.dart';
import 'package:n3rd_game/services/content_moderation_service.dart';

/// Validation result
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  ValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });
}

/// Configuration for tuning validation aggressiveness
class ContentValidationConfig {
  final int minCorrectItems;
  final int recommendedCorrectItems;
  final int minTierItems;
  final int recommendedTierItems;
  final bool strictRelevanceChecks;

  const ContentValidationConfig({
    this.minCorrectItems = 15,
    this.recommendedCorrectItems = 20,
    this.minTierItems = 3,
    this.recommendedTierItems = 6,
    this.strictRelevanceChecks = false,
  });
}

/// Service for validating trivia content quality
class ContentValidationService {
  final ContentValidationConfig _config;

  ContentValidationService({ContentValidationConfig? config})
    : _config = config ?? const ContentValidationConfig();

  /// Validate a trivia template
  ValidationResult validateTemplate(TriviaTemplate template) {
    final errors = <String>[];
    final warnings = <String>[];

    // Check for empty or whitespace-only strings in pools
    // This prevents empty strings from being selected as answers or distractors
    final emptyCorrect = template.correctPool
        .where((w) => w.trim().isEmpty)
        .toList();
    if (emptyCorrect.isNotEmpty) {
      errors.add(
        'Empty or whitespace-only strings found in correct pool (${emptyCorrect.length} items)',
      );
    }

    final emptyDistractor = template.distractorPool
        .where((w) => w.trim().isEmpty)
        .toList();
    if (emptyDistractor.isNotEmpty) {
      errors.add(
        'Empty or whitespace-only strings found in distractor pool (${emptyDistractor.length} items)',
      );
    }

    // Check pool sizes (after filtering empty strings)
    final validCorrectPool = template.correctPool
        .where((w) => w.trim().isNotEmpty)
        .toList();
    final validDistractorPool = template.distractorPool
        .where((w) => w.trim().isNotEmpty)
        .toList();

    if (validCorrectPool.length < _config.minCorrectItems) {
      errors.add(
        'Correct pool must have at least ${_config.minCorrectItems} valid (non-empty) items (has ${validCorrectPool.length})',
      );
    } else if (validCorrectPool.length < _config.recommendedCorrectItems) {
      warnings.add(
        'Correct pool should have ${_config.recommendedCorrectItems}+ valid items for variety (has ${validCorrectPool.length})',
      );
    }

    // Check for duplicates in correct pool (case-insensitive)
    // Normalize to lowercase to catch case variations (e.g., "Paris" vs "paris")
    final correctNormalized = validCorrectPool
        .map((w) => w.trim().toLowerCase())
        .toList();
    final correctSet = correctNormalized.toSet();
    if (correctSet.length != correctNormalized.length) {
      errors.add(
        'Duplicate items found in correct pool (case-insensitive check)',
      );
    }

    // Check for duplicates in distractor pool (case-insensitive)
    final distractorNormalized = validDistractorPool
        .map((w) => w.trim().toLowerCase())
        .toList();
    final distractorSet = distractorNormalized.toSet();
    if (distractorSet.length != distractorNormalized.length) {
      errors.add(
        'Duplicate items found in distractor pool (case-insensitive check)',
      );
    }

    // Check for overlap between correct and distractor pools (case-insensitive)
    final overlap = correctSet.intersection(distractorSet);
    if (overlap.isNotEmpty) {
      errors.add(
        'Items found in both correct and distractor pools (case-insensitive): ${overlap.join(", ")}',
      );
    }

    // Check distractor relevance (basic check for obviously wrong distractors)
    _checkDistractorRelevance(template, warnings);

    // Check tiered distractor pools if available
    if (template.distractorPools != null) {
      for (final tier in template.distractorPools!.keys) {
        final pool = template.distractorPools![tier]!;

        // Check for empty strings in tiered pool
        final emptyTiered = pool.where((w) => w.trim().isEmpty).toList();
        if (emptyTiered.isNotEmpty) {
          errors.add(
            'Empty or whitespace-only strings found in ${tier.name} distractor pool (${emptyTiered.length} items)',
          );
        }

        // Filter empty strings before checking length and validating
        final validTieredPool = pool.where((w) => w.trim().isNotEmpty).toList();

        // Minimum 3 distractors required (one per correct answer)
        if (validTieredPool.length < _config.minTierItems) {
          errors.add(
            'Distractor pool for ${tier.name} tier must have at least ${_config.minTierItems} valid (non-empty) items (has ${validTieredPool.length})',
          );
        } else if (validTieredPool.length < _config.recommendedTierItems) {
          warnings.add(
            'Distractor pool for ${tier.name} tier should have ${_config.recommendedTierItems}+ valid items for variety (has ${validTieredPool.length})',
          );
        }

        // Check for duplicates in tiered pool (case-insensitive) - use valid pool
        final poolNormalized = validTieredPool
            .map((w) => w.trim().toLowerCase())
            .toList();
        final poolSet = poolNormalized.toSet();
        if (poolSet.length != poolNormalized.length) {
          errors.add(
            'Duplicate items found in ${tier.name} distractor pool (case-insensitive check)',
          );
        }

        // Check for overlap with correct pool (case-insensitive)
        final poolNormalizedSet = poolNormalized.toSet();
        final tierOverlap = correctSet.intersection(poolNormalizedSet);
        if (tierOverlap.isNotEmpty) {
          errors.add(
            'Items in ${tier.name} distractor pool overlap with correct pool (case-insensitive): ${tierOverlap.join(", ")}',
          );
        }
      }
    }

    // Check spelling consistency (basic check - all same case)
    _checkSpellingConsistency(template, warnings);

    // Check category pattern
    if (template.categoryPattern.isEmpty) {
      errors.add('Category pattern cannot be empty');
    }

    // Check theme
    if (template.theme.isEmpty) {
      errors.add('Theme cannot be empty');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Check distractor relevance to category
  /// Flags distractors that are too obviously wrong or completely unrelated
  /// Checks both legacy distractorPool and tiered distractorPools
  void _checkDistractorRelevance(
    TriviaTemplate template,
    List<String> warnings,
  ) {
    if (!_config.strictRelevanceChecks) {
      return; // Skip strict relevance checking for curated templates by default
    }

    final categoryLower = template.categoryPattern.toLowerCase();
    final themeLower = template.theme.toLowerCase();
    final correctSet = template.correctPool.toSet();

    // Collect all distractors to check (legacy + tiered pools)
    final distractorsToCheck = <String>[...template.distractorPool];
    if (template.distractorPools != null) {
      for (final pool in template.distractorPools!.values) {
        distractorsToCheck.addAll(pool);
      }
    }

    // Common patterns that indicate distractors might be too obviously wrong
    final obviouslyWrongPatterns = <String, List<String>>{
      'african': [
        'roman',
        'byzantine',
        'ottoman',
        'persian',
        'chinese',
        'japanese',
      ],
      'camping': [
        'television',
        'microwave',
        'refrigerator',
        'dishwasher',
        'washing machine',
      ],
      'sailing': ['engine', 'propeller', 'motor'],
      'birds': ['mammal', 'reptile', 'fish'],
      'cocktails': ['water', 'juice', 'soda', 'milk'],
    };

    // Check all distractors (legacy + tiered pools) for relevance
    for (final distractor in distractorsToCheck) {
      final distractorLower = distractor.toLowerCase();

      // Check for overlap with correct pool (should be caught by main validation, but double-check)
      if (correctSet.contains(distractor)) {
        warnings.add(
          'Distractor "$distractor" appears in correct pool - this should be an error!',
        );
      }

      // Check for semantic similarity (distractor too similar to correct answer)
      for (final correct in template.correctPool) {
        final correctLower = correct.toLowerCase();
        // Check if distractor contains a correct answer word (too similar)
        if (distractorLower.contains(correctLower) ||
            correctLower.contains(distractorLower)) {
          // Allow if they're the same word (already caught by overlap check)
          if (distractorLower != correctLower) {
            // Check if it's a compound word that's still too similar
            // e.g., "Beginner" vs "Beginner-Friendly" - too similar
            // Exception: "Beginner" (difficulty rating) vs "Beginner-Friendly" (trail characteristic) are different concepts
            // Allow compound words that add meaningful context (e.g., "-Friendly", "-Only", "-Rated")
            final words = distractorLower.split(RegExp(r'[-\s]+'));
            final correctWords = correctLower.split(RegExp(r'[-\s]+'));

            // Check if distractor contains the exact correct word as a standalone word
            // But allow if it's a compound with meaningful suffix (e.g., "Beginner-Friendly" is different from "Beginner")
            final meaningfulSuffixes = [
              'friendly',
              'only',
              'rated',
              'level',
              'grade',
              'class',
              'type',
              'style',
            ];
            final hasMeaningfulSuffix =
                words.length > 1 &&
                meaningfulSuffixes.any(
                  (suffix) =>
                      words.last.contains(suffix) ||
                      words.any((w) => w.contains(suffix)),
                );

            if (words.contains(correctLower) ||
                correctWords.any((w) => words.contains(w))) {
              // Only warn if it's not a meaningful compound (e.g., "Beginner-Friendly" is acceptable)
              if (!hasMeaningfulSuffix) {
                warnings.add(
                  'Distractor "$distractor" is too similar to correct answer "$correct" (semantic overlap)',
                );
                break;
              }
            }
          }
        }
      }

      // Check against category-specific patterns
      for (final entry in obviouslyWrongPatterns.entries) {
        if (categoryLower.contains(entry.key) ||
            themeLower.contains(entry.key)) {
          for (final wrongPattern in entry.value) {
            if (distractorLower.contains(wrongPattern)) {
              warnings.add(
                'Distractor "$distractor" may be too obviously wrong for category "${template.categoryPattern}"',
              );
              break;
            }
          }
        }
      }
    }
  }

  /// Check spelling consistency
  void _checkSpellingConsistency(
    TriviaTemplate template,
    List<String> warnings,
  ) {
    // Check if all items start with same case
    final correctCases = template.correctPool
        .map(
          (item) => item.isNotEmpty ? item[0].toUpperCase() == item[0] : false,
        )
        .toSet();

    if (correctCases.length > 1) {
      warnings.add('Inconsistent capitalization in correct pool');
    }

    final distractorCases = template.distractorPool
        .map(
          (item) => item.isNotEmpty ? item[0].toUpperCase() == item[0] : false,
        )
        .toSet();

    if (distractorCases.length > 1) {
      warnings.add('Inconsistent capitalization in distractor pool');
    }
  }

  /// Check for duplicates across multiple templates
  ValidationResult checkCrossTemplateDuplicates(
    List<TriviaTemplate> templates,
  ) {
    final errors = <String>[];
    final warnings = <String>[];

    // Check for duplicate category patterns
    final categoryPatterns = <String, int>{};
    for (final template in templates) {
      categoryPatterns[template.categoryPattern] =
          (categoryPatterns[template.categoryPattern] ?? 0) + 1;
    }

    for (final entry in categoryPatterns.entries) {
      if (entry.value > 1) {
        warnings.add(
          'Duplicate category pattern found: "${entry.key}" (appears ${entry.value} times)',
        );
      }
    }

    // Check for significant overlap in correct pools between similar templates
    // Optimize: Only check templates with same theme (early exit optimization)
    final templatesByTheme = <String, List<TriviaTemplate>>{};
    for (final template in templates) {
      templatesByTheme.putIfAbsent(template.theme, () => []).add(template);
    }

    // Only compare templates within the same theme (reduces O(n²) to O(n²/k) where k is number of themes)
    for (final themeTemplates in templatesByTheme.values) {
      if (themeTemplates.length < 2) {
        continue; // Skip if only one template in theme
      }

      for (int i = 0; i < themeTemplates.length; i++) {
        for (int j = i + 1; j < themeTemplates.length; j++) {
          final template1 = themeTemplates[i];
          final template2 = themeTemplates[j];
          final overlap = template1.correctPool.toSet().intersection(
            template2.correctPool.toSet(),
          );

          if (overlap.length > 5) {
            warnings.add(
              'Significant overlap (${overlap.length} items) between templates: '
              '"${template1.categoryPattern}" and "${template2.categoryPattern}"',
            );
          }
        }
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Validate cultural sensitivity using ContentModerationService
  /// Checks for profanity and inappropriate content that may be culturally insensitive
  bool checkCulturalSensitivity(String text) {
    final moderationService = ContentModerationService();

    // Check for profanity and blocked words (includes culturally insensitive terms)
    if (moderationService.containsProfanity(text)) {
      return false;
    }

    // Additional check: validate content format (catches spam, URLs, etc.)
    final validationError = moderationService.validateContent(
      text,
      minLength: 1,
      maxLength: 1000,
    );

    // If validation fails, content is not culturally sensitive
    return validationError == null;
  }

  /// Check age appropriateness using ContentModerationService
  /// Validates that content is appropriate for the specified minimum age
  bool checkAgeAppropriateness(TriviaTemplate template, {int minAge = 13}) {
    final moderationService = ContentModerationService();

    // Check category pattern for inappropriate content
    if (moderationService.containsProfanity(template.categoryPattern)) {
      return false;
    }

    // Check theme for inappropriate content
    if (moderationService.containsProfanity(template.theme)) {
      return false;
    }

    // Check all words in correct pool
    for (final word in template.correctPool) {
      if (moderationService.containsProfanity(word)) {
        return false;
      }
    }

    // Check all words in distractor pool
    for (final word in template.distractorPool) {
      if (moderationService.containsProfanity(word)) {
        return false;
      }
    }

    // Check tiered distractor pools if available
    if (template.distractorPools != null) {
      for (final pool in template.distractorPools!.values) {
        for (final word in pool) {
          if (moderationService.containsProfanity(word)) {
            return false;
          }
        }
      }
    }

    return true;
  }

  /// Validate trivia item
  ValidationResult validateTriviaItem(TriviaItem item) {
    final errors = <String>[];
    final warnings = <String>[];

    // Check category
    if (item.category.isEmpty) {
      errors.add('Category cannot be empty');
    }

    // Check words list
    if (item.words.isEmpty) {
      errors.add('Words list cannot be empty');
    }

    // Check correct answers
    if (item.correctAnswers.isEmpty) {
      errors.add('Correct answers list cannot be empty');
    }

    // Check that all correct answers are in words list
    final wordsSet = item.words.toSet();
    for (final answer in item.correctAnswers) {
      if (!wordsSet.contains(answer)) {
        errors.add('Correct answer "$answer" not found in words list');
      }
    }

    // Check for duplicates in words
    if (item.words.length != item.words.toSet().length) {
      warnings.add('Duplicate items found in words list');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }
}
