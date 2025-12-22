import 'dart:math';

/// Trivia template model (extracted for reuse)
class TriviaTemplate {
  final String categoryPattern;
  final List<String> correctPool;
  final List<String> distractorPool;
  final String theme;
  final Map<String, List<String>>? distractorPools;
  final String difficulty;

  TriviaTemplate({
    required this.categoryPattern,
    required this.correctPool,
    required this.distractorPool,
    required this.theme,
    this.distractorPools,
    this.difficulty = 'medium',
  });
}

/// Utility class for selecting trivia templates
/// Extracted from TriviaGeneratorService to improve maintainability
class TemplateSelector {
  final Random _random;

  TemplateSelector({Random? random}) : _random = random ?? Random();

  /// Select a random template from the available templates
  /// Filters by theme if provided, otherwise uses all templates
  TriviaTemplate? selectTemplate(
    List<TriviaTemplate> templates, {
    String? theme,
  }) {
    if (templates.isEmpty) return null;

    // Filter by theme if provided
    final filteredTemplates = theme != null
        ? templates.where((t) => t.theme == theme).toList()
        : templates;

    if (filteredTemplates.isEmpty) {
      // Fallback to all templates if theme filter returns empty
      filteredTemplates.addAll(templates);
    }

    // Select random template
    return filteredTemplates[_random.nextInt(filteredTemplates.length)];
  }

  /// Select multiple templates ensuring variety
  List<TriviaTemplate> selectTemplates(
    List<TriviaTemplate> templates, {
    required int count,
    String? theme,
  }) {
    if (templates.isEmpty || count <= 0) return [];

    // Filter by theme if provided
    var availableTemplates = theme != null
        ? templates.where((t) => t.theme == theme).toList()
        : List<TriviaTemplate>.from(templates);

    if (availableTemplates.isEmpty) {
      availableTemplates = List<TriviaTemplate>.from(templates);
    }

    // Select templates ensuring variety
    final selected = <TriviaTemplate>[];
    final usedIndices = <int>{};

    while (selected.length < count && usedIndices.length < availableTemplates.length) {
      final index = _random.nextInt(availableTemplates.length);
      if (!usedIndices.contains(index)) {
        selected.add(availableTemplates[index]);
        usedIndices.add(index);
      }
    }

    return selected;
  }
}

