import 'package:flutter/foundation.dart';
import 'package:n3rd_game/services/trivia_generator_service.dart';
import 'package:n3rd_game/data/trivia_templates_consolidated.dart' deferred as templates; // Deferred to reduce kernel size
import 'package:n3rd_game/models/trivia_item.dart';

/// Service to load trivia content for specific editions
class EditionContentService extends ChangeNotifier {
  static final EditionContentService _instance =
      EditionContentService._internal();
  factory EditionContentService() => _instance;
  EditionContentService._internal() {
    _initialize();
  }

  final Map<String, List<TriviaTemplate>> _editionTemplates = {};
  bool _initialized = false;

  void _initialize() {
    if (_initialized) return;

    // Templates are already initialized in main.dart before this service is created
    // If not initialized, it means initialization failed in main.dart and we can't recover here
    if (!templates.EditionTriviaTemplates.isInitialized) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ Warning: EditionTriviaTemplates not initialized. This should not happen - templates are initialized in main.dart.',
        );
        debugPrint(
          '   Last validation error: ${templates.EditionTriviaTemplates.lastValidationError}',
        );
      }
      // Don't attempt to initialize here - it would fail with the same error
      // Rely on main.dart initialization and log the issue
    }

    // Load templates for each edition
    _loadEditionTemplates();

    _initialized = true;
  }

  void _loadEditionTemplates() {
    // Get all edition IDs from editions catalog
    final editionIds = [
      'black',
      'latino',
      'spanish',
      'asian',
      'indigenous',
      'caribbean',
      'middle_eastern',
      'african',
      'european',
      'pacific_islander',
      'french',
      'german',
      'italian',
      'japanese',
      'chinese',
      'nursing',
      'medicine',
      'anatomy',
      'surgery',
      'emergency_medicine',
      'mental_health',
      'veterinary',
      'public_health',
      'pharmacy',
      'dentistry',
      'biology',
      'chemistry',
      'physics',
      'geology',
      'environmental_science',
      'marine_biology',
      'microbiology',
      'genetics',
      'neuroscience',
      'geography',
      'usa_geography',
      'world_capitals',
      'mountains_rivers',
      'islands',
      'national_parks',
      'cities',
      'oceans',
      'psychology',
      'sociology',
      'anthropology',
      'linguistics',
      'astronomy',
      'meteorology',
      'oceanography',
      'botany',
      'zoology',
      'paleontology',
      'business',
      'finance',
      'law',
      'engineering',
      'computer_science',
      'marketing',
      'real_estate',
      'agriculture',
      'aviation',
      'military',
      'music',
      'movies',
      'tv',
      'art',
      'literature',
      'theater',
      'dance',
      'photography',
      'fashion',
      'architecture',
      'video_games',
      'anime_manga',
      'comics',
      'classical_music',
      'hip_hop',
      'sports_general',
      'football',
      'basketball',
      'baseball',
      'soccer',
      'olympics',
      'fitness',
      'extreme_sports',
      'food',
      'wine',
      'beer',
      'coffee',
      'cooking',
      'baking',
      'religion',
      'mythology',
      'philosophy',
      'technology',
      'nature_wildlife',
      'space_exploration',
    ];

    for (final editionId in editionIds) {
      _editionTemplates[editionId] =
          templates.EditionTriviaTemplates.getTemplatesForEdition(editionId);
    }
  }

  /// Get trivia templates for a specific edition
  List<TriviaTemplate> getTemplatesForEdition(String editionId) {
    return _editionTemplates[editionId] ?? [];
  }

  /// Check if an edition has content available
  bool hasContentForEdition(String editionId) {
    final templates = _editionTemplates[editionId] ?? [];
    return templates.isNotEmpty;
  }

  /// Get count of templates for an edition
  int getTemplateCountForEdition(String editionId) {
    return _editionTemplates[editionId]?.length ?? 0;
  }

  /// Generate trivia items for a specific edition
  ///
  /// **Important**: If `existingGenerator` is null, a new instance is created without
  /// analytics or personalization services. Always pass an existing generator when possible.
  List<TriviaItem> generateTriviaForEdition(
    String editionId,
    int count,
    TriviaGeneratorService? existingGenerator,
  ) {
    final templates = getTemplatesForEdition(editionId);
    if (templates.isEmpty) {
      debugPrint('Warning: No templates found for edition $editionId');
      return [];
    }

    // Use existing generator or create new one
    // Note: New instance won't have analytics/personalization services
    // This is acceptable for edition-specific content but analytics won't be tracked
    final generator = existingGenerator ?? TriviaGeneratorService();

    // Add edition-specific templates to generator
    generator.addTemplates(templates);

    try {
      return generator.generateBatch(
        count,
        theme: _getThemeForEdition(editionId),
        usePersonalization: true,
      );
    } catch (e) {
      debugPrint('Error generating trivia for edition $editionId: $e');
      // Return empty list on error (caller should handle empty result)
      return [];
    }
  }

  String? _getThemeForEdition(String editionId) {
    // Map edition IDs to their primary theme
    final themeMap = {
      'black': 'black_culture',
      'latino': 'latino_culture',
      'spanish': 'latino_culture',
      'asian': 'asian_american_culture',
      'indigenous': 'indigenous_culture',
      'caribbean': 'caribbean_culture',
      'middle_eastern': 'middle_eastern_culture',
      'african': 'african_culture',
      'nursing': 'medicine',
      'medicine': 'medicine',
      'anatomy': 'medicine',
      'surgery': 'medicine',
      'emergency_medicine': 'medicine',
      'mental_health': 'medicine',
      'veterinary': 'medicine',
      'public_health': 'medicine',
      'pharmacy': 'medicine',
      'dentistry': 'medicine',
      'biology': 'science',
      'chemistry': 'science',
      'physics': 'science',
      'geology': 'science',
      'environmental_science': 'science',
      'marine_biology': 'science',
      'microbiology': 'science',
      'genetics': 'science',
      'neuroscience': 'science',
      'geography': 'geography',
      'usa_geography': 'geography',
      'world_capitals': 'geography',
      'mountains_rivers': 'geography',
      'islands': 'geography',
      'national_parks': 'geography',
      'cities': 'geography',
      'oceans': 'geography',
      'astronomy': 'astronomy',
      'meteorology': 'weather',
      'oceanography': 'science',
      'botany': 'science',
      'zoology': 'science',
      'paleontology': 'science',
      'business': 'business',
      'finance': 'business',
      'law': 'business',
      'engineering': 'business',
      'computer_science': 'technology',
      'marketing': 'business',
      'real_estate': 'business',
      'agriculture': 'agriculture',
      'aviation': 'aviation',
      'military': 'military',
      'music': 'arts',
      'movies': 'arts',
      'tv': 'arts',
      'art': 'arts',
      'literature': 'literature',
      'theater': 'arts',
      'dance': 'arts',
      'photography': 'arts',
      'fashion': 'arts',
      'architecture': 'arts',
      'video_games': 'arts',
      'anime_manga': 'arts',
      'comics': 'arts',
      'classical_music': 'arts',
      'hip_hop': 'arts',
      'sports_general': 'sports',
      'football': 'sports',
      'basketball': 'sports',
      'baseball': 'sports',
      'soccer': 'sports',
      'olympics': 'sports',
      'fitness': 'sports',
      'extreme_sports': 'sports',
      'food': 'food',
      'wine': 'food',
      'beer': 'food',
      'coffee': 'food',
      'cooking': 'food',
      'baking': 'food',
      'religion': 'religion',
      'mythology': 'religion',
      'philosophy': 'philosophy',
      'technology': 'technology',
      'nature_wildlife': 'science',
      'space_exploration': 'astronomy',
    };

    return themeMap[editionId];
  }
}
