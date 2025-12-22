import 'dart:math';
import 'package:n3rd_game/models/difficulty_level.dart';
import 'package:n3rd_game/services/trivia_generator_service.dart';

/// Service to intelligently create tiered distractor pools from existing templates
/// Works 100% with existing data - no AI or placeholders required
class TriviaEnhancementService {
  final Random _random = Random();

  /// Enhance a template by creating tiered distractor pools from existing data
  /// This intelligently splits the existing distractorPool into easy/medium/hard tiers
  TriviaTemplate enhanceTemplate(TriviaTemplate template) {
    // If template already has tiered pools, return as-is
    if (template.distractorPools != null &&
        template.distractorPools!.isNotEmpty) {
      return template;
    }

    // Create tiered pools from existing distractorPool
    final tieredPools = _createTieredPools(
      template.distractorPool,
      template.correctPool,
      template.categoryPattern,
    );

    // Return enhanced template
    return TriviaTemplate(
      categoryPattern: template.categoryPattern,
      correctPool: template.correctPool,
      distractorPool: template.distractorPool,
      theme: template.theme,
      distractorPools: tieredPools,
      difficulty: template.difficulty,
    );
  }

  /// Intelligently split distractor pool into tiers based on similarity to correct answers
  Map<DistractorTier, List<String>> _createTieredPools(
    List<String> distractorPool,
    List<String> correctPool,
    String categoryPattern,
  ) {
    final pools = <DistractorTier, List<String>>{
      DistractorTier.obvious: [],
      DistractorTier.related: [],
      DistractorTier.subtle: [],
    };

    // Analyze each distractor to determine its tier
    for (final distractor in distractorPool) {
      final tier = _classifyDistractor(
        distractor,
        correctPool,
        categoryPattern,
      );
      pools[tier]!.add(distractor);
    }

    // Ensure each tier has at least some items (redistribute if needed)
    _balanceTiers(pools, distractorPool);

    return pools;
  }

  /// Classify a distractor into a tier based on how obvious it is
  DistractorTier _classifyDistractor(
    String distractor,
    List<String> correctPool,
    String categoryPattern,
  ) {
    final distractorLower = distractor.toLowerCase();
    final categoryLower = categoryPattern.toLowerCase();

    // Check if distractor shares significant word overlap with category
    final categoryWords = categoryLower.split(RegExp(r'\s+'));
    final distractorWords = distractorLower.split(RegExp(r'\s+'));

    int overlapCount = 0;
    for (final word in categoryWords) {
      if (word.length > 3 && distractorWords.contains(word)) {
        overlapCount++;
      }
    }

    // Check similarity to correct answers
    bool hasSimilarCorrect = false;
    for (final correct in correctPool) {
      final correctLower = correct.toLowerCase();
      if (_calculateSimilarity(distractorLower, correctLower) > 0.3) {
        hasSimilarCorrect = true;
        break;
      }
    }

    // Classification logic:
    // - Obvious: Very different from category and correct answers (clearly wrong)
    // - Related: Some similarity to category or correct answers (plausible but wrong)
    // - Subtle: High similarity but still wrong (requires deeper knowledge)

    if (overlapCount >= 2 || hasSimilarCorrect) {
      // High overlap or similarity - could be subtle or related
      if (overlapCount >= 3) {
        return DistractorTier.subtle; // Very similar, requires deep knowledge
      }
      return DistractorTier.related; // Some similarity, plausible
    } else {
      return DistractorTier.obvious; // Clearly different, obviously wrong
    }
  }

  /// Calculate simple similarity between two strings (0.0 to 1.0)
  double _calculateSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    // Check for substring matches
    if (a.contains(b) || b.contains(a)) {
      return 0.5;
    }

    // Check for common words
    final aWords = a.split(RegExp(r'\s+'));
    final bWords = b.split(RegExp(r'\s+'));
    int commonWords = 0;
    for (final word in aWords) {
      if (word.length > 3 && bWords.contains(word)) {
        commonWords++;
      }
    }

    if (commonWords > 0) {
      return (commonWords / (aWords.length + bWords.length - commonWords))
          .clamp(0.0, 1.0);
    }

    return 0.0;
  }

  /// Balance tiers to ensure each has reasonable distribution
  void _balanceTiers(
    Map<DistractorTier, List<String>> pools,
    List<String> allDistractors,
  ) {
    final total = allDistractors.length;
    if (total < 3) return; // Too few to balance

    // Target distribution: 40% obvious, 40% related, 20% subtle
    final targetObvious = (total * 0.4).round();
    final targetRelated = (total * 0.4).round();
    final targetSubtle = total - targetObvious - targetRelated;

    // Redistribute if any tier is too small
    if (pools[DistractorTier.obvious]!.length < targetObvious * 0.5) {
      _redistributeFrom(
        pools,
        DistractorTier.related,
        DistractorTier.obvious,
        targetObvious,
      );
    }

    if (pools[DistractorTier.related]!.length < targetRelated * 0.5) {
      _redistributeFrom(
        pools,
        DistractorTier.subtle,
        DistractorTier.related,
        targetRelated,
      );
    }

    if (pools[DistractorTier.subtle]!.length < targetSubtle * 0.5) {
      _redistributeFrom(
        pools,
        DistractorTier.related,
        DistractorTier.subtle,
        targetSubtle,
      );
    }
  }

  /// Redistribute items from one tier to another
  void _redistributeFrom(
    Map<DistractorTier, List<String>> pools,
    DistractorTier fromTier,
    DistractorTier toTier,
    int targetCount,
  ) {
    final fromList = pools[fromTier]!;
    final toList = pools[toTier]!;

    while (toList.length < targetCount && fromList.isNotEmpty) {
      // CRITICAL: Re-check isNotEmpty inside loop to prevent index errors
      // Defensive check in case list becomes empty during iteration
      if (fromList.isEmpty) break;
      final index = _random.nextInt(fromList.length);
      final item = fromList.removeAt(index);
      toList.add(item);
    }
  }

  /// Batch enhance multiple templates
  List<TriviaTemplate> enhanceTemplates(List<TriviaTemplate> templates) {
    return templates.map((t) => enhanceTemplate(t)).toList();
  }
}
