import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:n3rd_game/models/trivia_item.dart';
import 'package:n3rd_game/models/difficulty_level.dart';
import 'package:n3rd_game/services/trivia_generator_service.dart';
import 'package:n3rd_game/services/trivia_personalization_service.dart';
import 'package:n3rd_game/data/trivia_templates_consolidated.dart';
import 'package:n3rd_game/config/app_config.dart';
import 'package:n3rd_game/utils/input_sanitizer.dart';

/// Custom exception types for AI Edition
enum AIEditionErrorType {
  validationFailed,
  rateLimitExceeded,
  networkError,
  generationFailed,
  contentModerationFailed,
  offlineMode,
  unknownError,
}

class AIEditionException implements Exception {
  final AIEditionErrorType type;
  final String message;

  AIEditionException(this.type, this.message);

  @override
  String toString() => message;
}

/// Service for AI-powered edition generation
/// Allows users to create custom trivia content on any topic/theme
/// Premium users only, with safety guardrails for youth editions
class AIEditionService extends ChangeNotifier {
  static const String _collectionName = 'ai_edition_generations';
  static const String _localStorageKey = 'ai_edition_generations_local';
  static const String _cacheKey = 'ai_edition_cache';
  static const String _rateLimitKey = 'ai_edition_rate_limit';

  // Rate limiting: Premium users get 20 generations per day
  static const int _dailyGenerationLimit = AppConfig.dailyGenerationLimit;

  SharedPreferences? _prefs;
  bool _isGenerating = false;
  String? _lastError;
  AIEditionErrorType? _lastErrorType;
  bool _isOfflineMode = false;
  TriviaPersonalizationService? _personalizationService;
  TriviaGeneratorService?
  _generatorService; // Cache generator service for fallback

  // Youth safety parameters - expanded list
  static const List<String> _prohibitedTopics = [
    'violence',
    'weapons',
    'drugs',
    'alcohol',
    'gambling',
    'tobacco',
    'explicit',
    'adult',
    'mature',
    'inappropriate',
    'offensive',
    'hate',
    'discrimination',
    'racism',
    'sexism',
    'harassment',
    'suicide',
    'self-harm',
    'gore',
    'torture',
    'murder',
    'kill',
    'porn',
    'sexual',
    'nude',
    'nudity',
    'erotic',
    'xxx',
  ];

  static const List<String> _ageAppropriateTopics = [
    'animals',
    'nature',
    'science',
    'space',
    'geography',
    'history',
    'math',
    'reading',
    'art',
    'music',
    'sports',
    'food',
    'colors',
    'shapes',
    'numbers',
    'letters',
    'weather',
    'seasons',
    'plants',
    'ocean',
    'dinosaurs',
    'transportation',
    'community',
    'family',
    'friends',
    'school',
    'books',
    'games',
    'toys',
    'hobbies',
  ];

  // Semantic similarity keywords for better matching
  static const Map<String, List<String>> _semanticKeywords = {
    'science': [
      'biology',
      'chemistry',
      'physics',
      'astronomy',
      'geology',
      'experiment',
      'research',
      'discovery',
    ],
    'history': [
      'ancient',
      'medieval',
      'war',
      'civilization',
      'empire',
      'revolution',
      'historical',
      'past',
    ],
    'art': [
      'painting',
      'sculpture',
      'drawing',
      'design',
      'creative',
      'artist',
      'gallery',
      'museum',
    ],
    'music': [
      'song',
      'instrument',
      'composer',
      'melody',
      'rhythm',
      'band',
      'orchestra',
      'concert',
    ],
    'sports': [
      'game',
      'team',
      'player',
      'championship',
      'olympic',
      'athlete',
      'competition',
      'match',
    ],
    'geography': [
      'country',
      'city',
      'mountain',
      'river',
      'ocean',
      'continent',
      'capital',
      'landmark',
    ],
    'literature': [
      'book',
      'author',
      'novel',
      'poem',
      'story',
      'character',
      'writing',
      'literary',
    ],
    'technology': [
      'computer',
      'software',
      'internet',
      'digital',
      'programming',
      'code',
      'app',
      'device',
    ],
  };

  bool get isGenerating => _isGenerating;
  String? get lastError => _lastError;
  AIEditionErrorType? get lastErrorType => _lastErrorType;
  bool get isOfflineMode => _isOfflineMode;

  /// Get or initialize SharedPreferences
  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Check rate limit for user
  Future<(bool, int)> checkRateLimit() async {
    try {
      final prefs = await _getPrefs();
      final today = DateTime.now().toUtc();
      final todayKey = '${today.year}-${today.month}-${today.day}';
      final rateLimitData = prefs.getString(_rateLimitKey);

      if (rateLimitData != null) {
        try {
          final data = jsonDecode(rateLimitData) as Map<String, dynamic>;
          final lastDate = data['date'] as String;
          final count = data['count'] as int;

          if (lastDate == todayKey) {
            return (
              count < _dailyGenerationLimit,
              _dailyGenerationLimit - count,
            );
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error parsing rate limit data: $e');
          }
          // If parsing fails, treat as no rate limit data and allow generation
        }
      }

      return (true, _dailyGenerationLimit);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error checking rate limit: $e');
      }
      return (true, _dailyGenerationLimit); // Allow on error
    }
  }

  /// Record generation for rate limiting
  Future<void> _recordGeneration() async {
    try {
      final prefs = await _getPrefs();
      final today = DateTime.now().toUtc();
      final todayKey = '${today.year}-${today.month}-${today.day}';
      final rateLimitData = prefs.getString(_rateLimitKey);

      int count = 1;
      if (rateLimitData != null) {
        try {
          final data = jsonDecode(rateLimitData) as Map<String, dynamic>;
          final lastDate = data['date'] as String;
          if (lastDate == todayKey) {
            count = (data['count'] as int) + 1;
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error parsing rate limit data for increment: $e');
          }
          // If parsing fails, start fresh with count = 1
        }
      }

      await prefs.setString(
        _rateLimitKey,
        jsonEncode({'date': todayKey, 'count': count}),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error recording generation: $e');
      }
    }
  }

  /// Enhanced content moderation with multiple checks
  (bool, String?) _moderateContent(String topic, bool isYouth) {
    final topicLower = topic.toLowerCase();

    // Check for prohibited topics
    for (final prohibited in _prohibitedTopics) {
      if (topicLower.contains(prohibited)) {
        return (
          false,
          'This topic contains inappropriate content. Please choose a different topic.',
        );
      }
    }

    // Additional checks for youth
    if (isYouth) {
      // Check for adult themes
      final adultThemes = [
        'dating',
        'romance',
        'relationship',
        'marriage',
        'divorce',
      ];
      for (final theme in adultThemes) {
        if (topicLower.contains(theme)) {
          return (
            false,
            'This topic is not suitable for youth editions. Please choose an age-appropriate topic.',
          );
        }
      }
    }

    // Check for empty or too short topics
    if (topic.trim().length < 2) {
      return (false, 'Topic must be at least 2 characters long.');
    }

    // Check for too long topics
    if (topic.length > 100) {
      return (false, 'Topic must be less than 100 characters.');
    }

    return (true, null);
  }

  /// Validate topic for youth edition (safety guardrails)
  /// Returns (isValid, errorMessage)
  (bool, String?) validateTopicForYouth(String topic) {
    return _moderateContent(topic, true);
  }

  /// Validate topic for regular edition (less strict)
  /// Returns (isValid, errorMessage)
  (bool, String?) validateTopicForRegular(String topic) {
    return _moderateContent(topic, false);
  }

  /// Calculate semantic similarity score between topic and template
  double _calculateSimilarity(String topic, TriviaTemplate template) {
    final topicLower = topic.toLowerCase();
    final categoryLower = template.categoryPattern.toLowerCase();
    final themeLower = template.theme.toLowerCase();

    double score = 0.0;

    // Exact match
    if (categoryLower.contains(topicLower) || themeLower.contains(topicLower)) {
      score += 1.0;
    }

    // Word matching
    final topicWords = topicLower
        .split(' ')
        .where((w) => w.length > 2)
        .toList();
    for (final word in topicWords) {
      if (categoryLower.contains(word)) score += 0.3;
      if (themeLower.contains(word)) score += 0.2;
    }

    // Semantic keyword matching
    for (final entry in _semanticKeywords.entries) {
      if (topicLower.contains(entry.key)) {
        for (final keyword in entry.value) {
          if (categoryLower.contains(keyword) || themeLower.contains(keyword)) {
            score += 0.2;
          }
        }
      }
    }

    // Theme matching bonus
    if (themeLower.contains(topicLower) || topicLower.contains(themeLower)) {
      score += 0.5;
    }

    return score;
  }

  /// Find templates relevant to the topic with similarity scoring
  List<TriviaTemplate> _findRelevantTemplates(String topic, bool isYouth) {
    final allTemplates = EditionTriviaTemplates.getAvailableThemes()
        .expand((theme) => EditionTriviaTemplates.getTemplatesForEdition(theme))
        .toList();

    // Calculate similarity scores
    final scoredTemplates = allTemplates.map((template) {
      final similarity = _calculateSimilarity(topic, template);
      return (template, similarity);
    }).toList();

    // Filter and sort by similarity
    var relevant =
        scoredTemplates
            .where((entry) => entry.$2 > 0.1) // Minimum similarity threshold
            .toList()
          ..sort((a, b) => b.$2.compareTo(a.$2)); // Sort by score descending

    // For youth, filter out inappropriate content
    if (isYouth) {
      relevant = relevant.where((entry) {
        return _isAgeAppropriate(entry.$1);
      }).toList();
    }

    // Return top 20 most relevant templates
    return relevant.take(20).map((entry) => entry.$1).toList();
  }

  /// Check if template is age-appropriate for youth
  bool _isAgeAppropriate(TriviaTemplate template) {
    final categoryLower = template.categoryPattern.toLowerCase();
    final themeLower = template.theme.toLowerCase();

    // Check for inappropriate content
    for (final prohibited in _prohibitedTopics) {
      if (categoryLower.contains(prohibited) ||
          themeLower.contains(prohibited)) {
        return false;
      }
    }

    // Prefer age-appropriate topics
    for (final appropriate in _ageAppropriateTopics) {
      if (categoryLower.contains(appropriate) ||
          themeLower.contains(appropriate)) {
        return true;
      }
    }

    // Default: allow if not explicitly prohibited
    return true;
  }

  /// Set personalization service for personalized AI generation
  void setPersonalizationService(TriviaPersonalizationService service) {
    _personalizationService = service;
  }

  /// Set generator service for fallback generation (with personalization injected)
  void setGeneratorService(TriviaGeneratorService service) {
    _generatorService = service;
  }

  /// Normalize theme name to match standard theme names
  /// Maps common variations (e.g., "Science" -> "science", "sciences" -> "science")
  /// Uses word boundary matching for compound themes to avoid false positives
  String _normalizeTheme(String theme) {
    final themeLower = theme.toLowerCase().trim();

    if (themeLower.isEmpty) {
      if (kDebugMode) {
        debugPrint('🎨 Theme normalization: Empty theme, returning "general"');
      }
      return 'general';
    }

    // Check for compound themes FIRST (before simple variations) to avoid false positives
    // Use word boundary matching for more precise detection
    final compoundThemeMap = <String, String>{
      'science fiction': 'science',
      'sci-fi': 'science',
      'world history': 'history',
      'art history': 'art',
      'music history': 'music',
      'sports history': 'sport',
      'african history': 'african_culture',
      'african art': 'african_culture',
      'african music': 'african_culture',
      'natural science': 'science',
      'social science': 'science',
      'political science': 'science',
      'computer science': 'science',
      'earth science': 'science',
      'life science': 'science',
      'physical science': 'science',
      'world geography': 'geography',
      'human geography': 'geography',
      'physical geography': 'geography',
      'ancient history': 'history',
      'modern history': 'history',
      'world art': 'art',
      'visual art': 'art',
      'performing art': 'art',
      'classical music': 'music',
      'popular music': 'music',
      'world music': 'music',
      'team sports': 'sport',
      'water sports': 'sport',
      'winter sports': 'sport',
    };

    // Check compound themes using word boundary matching
    // Match if theme equals compound or contains it as a complete phrase
    for (final entry in compoundThemeMap.entries) {
      final compoundKey = entry.key;
      // Exact match
      if (themeLower == compoundKey) {
        if (kDebugMode) {
          debugPrint(
            '🎨 Theme normalization: "$theme" -> "${entry.value}" (compound exact match)',
          );
        }
        return entry.value;
      }
      // Word boundary match: theme contains compound as a complete phrase
      // Handle hyphens specially: word boundaries don't work well with hyphens
      // For hyphenated terms like "sci-fi", use a more flexible pattern
      RegExp pattern;
      if (compoundKey.contains('-')) {
        // For hyphenated terms, match the phrase with optional word boundaries
        // This handles "sci-fi", "science fiction", "sci fi" variations
        final escapedKey = RegExp.escape(compoundKey);
        // Replace hyphens with optional spaces/hyphens for flexibility
        final flexibleKey = escapedKey.replaceAll(r'\-', r'[\s\-]+');
        pattern = RegExp(flexibleKey, caseSensitive: false);
      } else {
        // For non-hyphenated terms, use word boundaries for precise matching
        pattern = RegExp(
          r'\b' + RegExp.escape(compoundKey) + r'\b',
          caseSensitive: false,
        );
      }

      if (pattern.hasMatch(themeLower)) {
        if (kDebugMode) {
          debugPrint(
            '🎨 Theme normalization: "$theme" -> "${entry.value}" (compound phrase match)',
          );
        }
        return entry.value;
      }
    }

    // Map common variations to standard themes
    final themeMap = <String, String>{
      'sciences': 'science',
      'scientific': 'science',
      'geographies': 'geography',
      'geographic': 'geography',
      'geographical': 'geography',
      'histories': 'history',
      'historical': 'history',
      'arts': 'art',
      'artistic': 'art',
      'musics': 'music',
      'musical': 'music',
      'sports': 'sport',
      'sporting': 'sport',
      'athletic': 'sport',
      'athletics': 'sport',
      'african_cultures': 'african_culture',
      'african': 'african_culture',
      'literature': 'art',
      'literary': 'art',
      'mathematics': 'science',
      'math': 'science',
      'maths': 'science',
      'biology': 'science',
      'chemistry': 'science',
      'physics': 'science',
      'astronomy': 'science',
      'technology': 'science',
      'tech': 'science',
      'engineering': 'science',
    };

    // Check if theme matches a variation exactly
    if (themeMap.containsKey(themeLower)) {
      if (kDebugMode) {
        debugPrint(
          '🎨 Theme normalization: "$theme" -> "${themeMap[themeLower]!}" (exact variation match)',
        );
      }
      return themeMap[themeLower]!;
    }

    // Check if theme starts with a known variation (for partial matches)
    for (final entry in themeMap.entries) {
      if (themeLower.startsWith(entry.key) ||
          entry.key.startsWith(themeLower)) {
        if (kDebugMode) {
          debugPrint(
            '🎨 Theme normalization: "$theme" -> "${entry.value}" (prefix match)',
          );
        }
        return entry.value;
      }
    }

    // Return normalized theme (lowercase, trimmed) as-is if no mapping found
    if (kDebugMode && themeLower != theme.toLowerCase().trim()) {
      debugPrint(
        '🎨 Theme normalization: "$theme" -> "$themeLower" (normalized case/trim only)',
      );
    }
    return themeLower;
  }

  /// Generate trivia using AI API via Firebase Cloud Functions
  Future<List<TriviaItem>?> _generateWithAIAPI({
    required String topic,
    required bool isYouthEdition,
    required int count,
  }) async {
    try {
      // Check connectivity first
      final connectivityResults = await Connectivity().checkConnectivity();
      if (connectivityResults.contains(ConnectivityResult.none) ||
          connectivityResults.isEmpty) {
        if (kDebugMode) {
          debugPrint('No internet connection for AI generation');
        }
        _lastError =
            'No internet connection. Please check your network and try again.';
        _lastErrorType = AIEditionErrorType.offlineMode;
        notifyListeners();
        return null;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (kDebugMode) {
          debugPrint('User not authenticated for AI generation');
        }
        _lastError = 'Please sign in to use AI generation.';
        _lastErrorType = AIEditionErrorType.validationFailed;
        notifyListeners();
        return null;
      }

      // Sanitize input before sending
      final sanitizedTopic = InputSanitizer.sanitizeText(topic.trim());
      if (sanitizedTopic.length < AppConfig.minTopicLength ||
          sanitizedTopic.length > AppConfig.maxTopicLength) {
        _lastError =
            'Topic must be between ${AppConfig.minTopicLength} and ${AppConfig.maxTopicLength} characters.';
        _lastErrorType = AIEditionErrorType.validationFailed;
        notifyListeners();
        return null;
      }

      // Get ID token for authentication
      final idToken = await user.getIdToken();

      // Get personalization preferences if available
      String? preferredDifficulty;
      List<String>? themesToAvoid;
      if (_personalizationService != null) {
        preferredDifficulty = _personalizationService!.preferredDifficulty.name;
        // Get themes user performs poorly in (to avoid)
        final worstThemes = _personalizationService!.getBestPerformingThemes(
          limit: 3,
          ascending: true,
        );
        if (worstThemes.isNotEmpty) {
          themesToAvoid = worstThemes;
        }
      }

      // Use config for Cloud Function URL
      final functionUrl = AppConfig.cloudFunctionUrl;

      // Build request body with personalization preferences
      final requestBody = <String, dynamic>{
        'topic': sanitizedTopic,
        'isYouthEdition': isYouthEdition,
        'count': count.clamp(
          AppConfig.minTriviaCount,
          AppConfig.maxTriviaCount,
        ),
      };

      // Add personalization preferences if available
      if (preferredDifficulty != null) {
        requestBody['preferredDifficulty'] = preferredDifficulty;
      }
      if (themesToAvoid != null && themesToAvoid.isNotEmpty) {
        requestBody['themesToAvoid'] = themesToAvoid;
      }

      final response = await http
          .post(
            Uri.parse(functionUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(AppConfig.cloudFunctionTimeout);

      if (response.statusCode == 200) {
        try {
          final responseData =
              jsonDecode(response.body) as Map<String, dynamic>;

          // Callable functions return { result: {...} }
          final result = responseData['result'] as Map<String, dynamic>?;
          if (result != null && result['success'] == true) {
            final triviaList = (result['trivia'] as List)
                .map((item) {
                  try {
                    // Ensure theme is never null or empty, and normalize to lowercase
                    // Normalize theme to match existing theme names (e.g., "Science" -> "science")
                    final itemTheme = item['theme'] as String?;
                    final rawTheme = (itemTheme != null && itemTheme.isNotEmpty)
                        ? itemTheme.toLowerCase().trim()
                        : 'general';
                    // Map common variations to standard theme names
                    final validTheme = _normalizeTheme(rawTheme);

                    return TriviaItem(
                      category: item['category'] as String? ?? 'Unknown',
                      words: List<String>.from((item['words'] as List?) ?? []),
                      correctAnswers: List<String>.from(
                        (item['correctAnswers'] as List?) ?? [],
                      ),
                      difficulty: item['difficulty'] != null
                          ? DifficultyLevel.values.firstWhere(
                              (d) => d.name == item['difficulty'],
                              orElse: () => DifficultyLevel.medium,
                            )
                          : null,
                      theme: validTheme, // Always non-null and non-empty
                    );
                  } catch (e) {
                    if (kDebugMode) {
                      debugPrint('Error parsing trivia item: $e');
                    }
                    return null;
                  }
                })
                .whereType<TriviaItem>()
                .where((item) {
                  // Validate trivia item quality
                  // 1. Category must not be empty
                  if (item.category.isEmpty || item.category == 'Unknown') {
                    if (kDebugMode) {
                      debugPrint(
                        '⚠️ Invalid AI trivia: empty or unknown category',
                      );
                    }
                    return false;
                  }

                  // 2. Words list must have exactly 6 words (3 correct + 3 distractors - no more, no less)
                  if (item.words.length != 6) {
                    if (kDebugMode) {
                      debugPrint(
                        '⚠️ Invalid AI trivia: incorrect word count (${item.words.length} != 6, expected exactly 6)',
                      );
                    }
                    return false;
                  }

                  // 3. Correct answers must have exactly 3 items
                  if (item.correctAnswers.length != 3) {
                    if (kDebugMode) {
                      debugPrint(
                        '⚠️ Invalid AI trivia: incorrect correct answers count (${item.correctAnswers.length} != 3, expected exactly 3)',
                      );
                    }
                    return false;
                  }

                  // 4. All correct answers must be in words list
                  final wordsSet = item.words
                      .map((w) => w.toLowerCase().trim())
                      .toSet();
                  final allCorrectInWords = item.correctAnswers.every(
                    (answer) => wordsSet.contains(answer.toLowerCase().trim()),
                  );
                  if (!allCorrectInWords) {
                    if (kDebugMode) {
                      debugPrint(
                        '⚠️ Invalid AI trivia: correct answers not in words list',
                      );
                    }
                    return false;
                  }

                  // 5. Words list must have exactly 3 items that are NOT correct answers (distractors)
                  final correctSet = item.correctAnswers
                      .map((a) => a.toLowerCase().trim())
                      .toSet();
                  final distractorCount = item.words
                      .where(
                        (w) => !correctSet.contains(w.toLowerCase().trim()),
                      )
                      .length;
                  if (distractorCount != 3) {
                    if (kDebugMode) {
                      debugPrint(
                        '⚠️ Invalid AI trivia: incorrect distractor count ($distractorCount != 3, expected exactly 3)',
                      );
                    }
                    return false;
                  }

                  return true;
                })
                .toList();

            if (triviaList.isEmpty) {
              _lastError = 'No valid trivia items generated. Please try again.';
              _lastErrorType = AIEditionErrorType.generationFailed;
              notifyListeners();
              return null;
            }

            return triviaList;
          } else {
            // Function returned but with error - fallback to templates
            final errorMessage = result?['error'] as String? ?? 'Unknown error';
            if (kDebugMode) {
              debugPrint('Cloud Function returned error: $errorMessage');
            }
            _lastError = 'AI generation failed: $errorMessage';
            _lastErrorType = AIEditionErrorType.generationFailed;
            notifyListeners();
            return null;
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error parsing Cloud Function response: $e');
          }
          _lastError = 'Error processing AI response. Please try again.';
          _lastErrorType = AIEditionErrorType.generationFailed;
          notifyListeners();
          return null;
        }
      } else if (response.statusCode == 401) {
        if (kDebugMode) {
          debugPrint('Authentication failed for Cloud Function');
        }
        _lastError = 'Authentication failed. Please sign in again.';
        _lastErrorType = AIEditionErrorType.validationFailed;
        notifyListeners();
        return null;
      } else if (response.statusCode == 403) {
        if (kDebugMode) {
          debugPrint('Permission denied for Cloud Function');
        }
        _lastError =
            'Permission denied. Please check your subscription status.';
        _lastErrorType = AIEditionErrorType.validationFailed;
        notifyListeners();
        return null;
      } else if (response.statusCode == 429) {
        if (kDebugMode) {
          debugPrint('Rate limit exceeded for Cloud Function');
        }
        _lastError = 'Rate limit exceeded. Please try again later.';
        _lastErrorType = AIEditionErrorType.rateLimitExceeded;
        notifyListeners();
        return null;
      } else {
        // For other errors, try to parse error response
        String errorMessage = 'Unknown error';
        try {
          final errorData = jsonDecode(response.body) as Map<String, dynamic>;
          final error = errorData['error'] as Map<String, dynamic>?;
          errorMessage = error?['message'] as String? ?? response.body;
          if (kDebugMode) {
            debugPrint('Cloud Function error: $errorMessage');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              'Cloud Function request failed: ${response.statusCode} - ${response.body}',
            );
          }
          errorMessage =
              'Server error (${response.statusCode}). Please try again.';
        }
        _lastError = errorMessage;
        _lastErrorType = AIEditionErrorType.networkError;
        notifyListeners();
        return null;
      }
    } on http.ClientException catch (e) {
      if (kDebugMode) {
        debugPrint('Network error during AI generation: $e');
      }
      _lastError = 'Network error. Please check your connection and try again.';
      _lastErrorType = AIEditionErrorType.networkError;
      notifyListeners();
      return null;
    } on TimeoutException catch (e) {
      if (kDebugMode) {
        debugPrint('Timeout during AI generation: $e');
      }
      _lastError = 'Request timed out. Please try again.';
      _lastErrorType = AIEditionErrorType.networkError;
      notifyListeners();
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AI API generation failed: $e');
      }
      _lastError = 'An unexpected error occurred. Please try again.';
      _lastErrorType = AIEditionErrorType.unknownError;
      notifyListeners();
      return null; // Fallback to template-based
    }
  }

  /// Cache generated trivia for offline play
  Future<void> _cacheGeneratedTrivia(
    String topic,
    bool isYouth,
    List<TriviaItem> trivia,
  ) async {
    try {
      final prefs = await _getPrefs();
      final cacheKey =
          '${_cacheKey}_${topic.toLowerCase()}_${isYouth ? 'youth' : 'regular'}';
      final cacheData = {
        'topic': topic,
        'isYouth': isYouth,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'trivia': trivia
            .map(
              (item) => {
                'category': item.category,
                'words': item.words,
                'correctAnswers': item.correctAnswers,
                'difficulty': item.difficulty?.name,
                'theme': item.theme, // Store theme for consistency
              },
            )
            .toList(),
      };

      await prefs.setString(cacheKey, jsonEncode(cacheData));

      // Keep only last 10 cached topics, using timestamps to find oldest
      final allKeys = prefs
          .getKeys()
          .where((k) => k.startsWith(_cacheKey))
          .toList();
      if (allKeys.length > 10 && allKeys.isNotEmpty) {
        // Read all cache entries to find oldest by timestamp
        final cacheEntries = <MapEntry<String, DateTime>>[];
        for (final key in allKeys) {
          try {
            final cachedData = prefs.getString(key);
            if (cachedData != null) {
              final decoded = jsonDecode(cachedData) as Map<String, dynamic>;
              final timestampStr = decoded['timestamp'] as String?;
              if (timestampStr != null) {
                final timestamp = DateTime.parse(timestampStr);
                cacheEntries.add(MapEntry(key, timestamp));
              }
            }
          } catch (e) {
            // If parsing fails, treat as very old (will be removed first)
            cacheEntries.add(
              MapEntry(key, DateTime.fromMillisecondsSinceEpoch(0)),
            );
          }
        }

        // Sort by timestamp (oldest first) and remove oldest entries
        cacheEntries.sort((a, b) => a.value.compareTo(b.value));
        final entriesToRemove = cacheEntries.length - 10;
        if (entriesToRemove > 0) {
          for (int i = 0; i < entriesToRemove; i++) {
            await prefs.remove(cacheEntries[i].key);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error caching trivia: $e');
      }
    }
  }

  /// Get cached trivia if available
  Future<List<TriviaItem>?> _getCachedTrivia(String topic, bool isYouth) async {
    try {
      final prefs = await _getPrefs();
      final cacheKey =
          '${_cacheKey}_${topic.toLowerCase()}_${isYouth ? 'youth' : 'regular'}';
      final cacheData = prefs.getString(cacheKey);

      if (cacheData != null) {
        try {
          final data = jsonDecode(cacheData) as Map<String, dynamic>;
          final triviaList = (data['trivia'] as List)
              .map((item) {
                try {
                  // Normalize theme from cached data (ensure consistency)
                  final cachedTheme = item['theme'] as String?;
                  final normalizedCachedTheme =
                      (cachedTheme != null && cachedTheme.isNotEmpty)
                      ? _normalizeTheme(cachedTheme)
                      : 'general';

                  return TriviaItem(
                    category: item['category'] as String? ?? 'Unknown',
                    words: List<String>.from((item['words'] as List?) ?? []),
                    correctAnswers: List<String>.from(
                      (item['correctAnswers'] as List?) ?? [],
                    ),
                    difficulty: item['difficulty'] != null
                        ? DifficultyLevel.values.firstWhere(
                            (d) => d.name == item['difficulty'],
                            orElse: () => DifficultyLevel.medium,
                          )
                        : null,
                    theme: normalizedCachedTheme,
                  );
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint('Error parsing cached trivia item: $e');
                  }
                  return null;
                }
              })
              .whereType<TriviaItem>()
              .where((item) {
                // Validate cached trivia items with same checks as AI-generated items
                // 1. Category must not be empty
                if (item.category.isEmpty || item.category == 'Unknown') {
                  if (kDebugMode) {
                    debugPrint(
                      '⚠️ Invalid cached trivia: empty or unknown category',
                    );
                  }
                  return false;
                }

                // 2. Words list must have exactly 6 words (3 correct + 3 distractors - no more, no less)
                if (item.words.length != 6) {
                  if (kDebugMode) {
                    debugPrint(
                      '⚠️ Invalid cached trivia: incorrect word count (${item.words.length} != 6, expected exactly 6)',
                    );
                  }
                  return false;
                }

                // 3. Correct answers must have exactly 3 items
                if (item.correctAnswers.length != 3) {
                  if (kDebugMode) {
                    debugPrint(
                      '⚠️ Invalid cached trivia: incorrect correct answers count (${item.correctAnswers.length} != 3, expected exactly 3)',
                    );
                  }
                  return false;
                }

                // 4. All correct answers must be in words list
                final wordsSet = item.words
                    .map((w) => w.toLowerCase().trim())
                    .toSet();
                final allCorrectInWords = item.correctAnswers.every(
                  (answer) => wordsSet.contains(answer.toLowerCase().trim()),
                );
                if (!allCorrectInWords) {
                  if (kDebugMode) {
                    debugPrint(
                      '⚠️ Invalid cached trivia: correct answers not in words list',
                    );
                  }
                  return false;
                }

                // 5. Words list must have exactly 3 items that are NOT correct answers (distractors)
                final correctSet = item.correctAnswers
                    .map((a) => a.toLowerCase().trim())
                    .toSet();
                final distractorCount = item.words
                    .where((w) => !correctSet.contains(w.toLowerCase().trim()))
                    .length;
                if (distractorCount != 3) {
                  if (kDebugMode) {
                    debugPrint(
                      '⚠️ Invalid cached trivia: incorrect distractor count ($distractorCount != 3, expected exactly 3)',
                    );
                  }
                  return false;
                }

                return true;
              })
              .toList();

          if (triviaList.isNotEmpty) {
            return triviaList;
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error parsing cached trivia data: $e');
          }
          // If parsing fails, return null to fetch fresh data
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading cached trivia: $e');
      }
    }
    return null;
  }

  /// Generate trivia content for a custom topic/theme
  Future<List<TriviaItem>> generateTriviaForTopic({
    required String topic,
    required bool isYouthEdition,
    int count = 50,
  }) async {
    _isGenerating = true;
    _lastError = null;
    _lastErrorType = null;
    notifyListeners();

    try {
      // Check rate limit
      final (canGenerate, remaining) = await checkRateLimit();
      if (!canGenerate) {
        _lastError =
            'Daily generation limit reached. You have used all $_dailyGenerationLimit generations today. Try again tomorrow!';
        _lastErrorType = AIEditionErrorType.rateLimitExceeded;
        _isGenerating = false;
        notifyListeners();
        throw AIEditionException(
          AIEditionErrorType.rateLimitExceeded,
          _lastError!,
        );
      }

      // Validate topic
      final (isValid, errorMessage) = isYouthEdition
          ? validateTopicForYouth(topic)
          : validateTopicForRegular(topic);

      if (!isValid) {
        _lastError = errorMessage;
        _lastErrorType = AIEditionErrorType.validationFailed;
        _isGenerating = false;
        notifyListeners();
        throw AIEditionException(
          AIEditionErrorType.validationFailed,
          errorMessage!,
        );
      }

      // Try to get cached trivia first
      final cachedTrivia = await _getCachedTrivia(topic, isYouthEdition);
      if (cachedTrivia != null && cachedTrivia.length >= count) {
        _isGenerating = false;
        notifyListeners();
        return cachedTrivia.take(count).toList();
      }

      // Try AI generation via Cloud Function
      List<TriviaItem>? aiGeneratedTrivia;
      try {
        aiGeneratedTrivia = await _generateWithAIAPI(
          topic: topic,
          isYouthEdition: isYouthEdition,
          count: count,
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('AI API generation failed, falling back to templates: $e');
        }
      }

      // Fallback to template-based generation
      // Use cached generator service if available (has personalization injected), otherwise create new
      // Add null check to prevent errors if service not yet initialized
      TriviaGeneratorService generator;
      if (_generatorService != null) {
        generator = _generatorService!;
      } else {
        generator = TriviaGeneratorService();
        // If we have personalization service, inject it
        if (_personalizationService != null) {
          generator.setPersonalizationService(_personalizationService!);
        }
        // If we have generator service (from Provider) with analytics, preserve it
        // Otherwise, analytics will be injected by Provider when available
        // Note: Analytics tracking for AI Edition is handled at the service level
      }
      final relevantTemplates = _findRelevantTemplates(topic, isYouthEdition);

      List<TriviaItem> triviaItems;
      if (aiGeneratedTrivia != null && aiGeneratedTrivia.isNotEmpty) {
        triviaItems = aiGeneratedTrivia;
      } else if (relevantTemplates.isEmpty) {
        // Fallback: Use general templates with topic-based category names
        triviaItems = await _generateFallbackTrivia(topic, count, generator);
      } else {
        // Add relevant templates to generator
        generator.addTemplates(relevantTemplates);

        // Use retry logic for better reliability
        triviaItems = await _generateTriviaWithRetry(
          generator,
          count,
          usePersonalization: true,
        );

        // Customize category names to include the topic
        triviaItems = triviaItems.map((item) {
          return TriviaItem(
            category: '${topic.capitalize()}: ${item.category}',
            words: item.words,
            correctAnswers: item.correctAnswers,
            difficulty: item.difficulty, // Preserve difficulty
            theme: item.theme, // Preserve theme
          );
        }).toList();
      }

      // Cache the generated trivia
      await _cacheGeneratedTrivia(topic, isYouthEdition, triviaItems);

      // Record generation for rate limiting
      await _recordGeneration();

      // Save generation to history (async, don't wait)
      _saveGenerationHistory(topic, isYouthEdition, triviaItems.length);

      _isGenerating = false;
      notifyListeners();
      return triviaItems;
    } on AIEditionException {
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error generating AI edition trivia: $e');
      }

      // Determine error type
      if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        _lastErrorType = AIEditionErrorType.networkError;
        _lastError =
            'Network error. Please check your connection and try again.';
      } else if (e.toString().contains('timeout')) {
        _lastErrorType = AIEditionErrorType.networkError;
        _lastError = 'Request timed out. Please try again.';
      } else {
        _lastErrorType = AIEditionErrorType.generationFailed;
        _lastError =
            'Failed to generate trivia. Please try a different topic or try again later.';
      }

      _isGenerating = false;
      notifyListeners();
      throw AIEditionException(_lastErrorType!, _lastError!);
    }
  }

  /// Generate fallback trivia when no templates match
  Future<List<TriviaItem>> _generateFallbackTrivia(
    String topic,
    int count,
    TriviaGeneratorService generator,
  ) async {
    // Ensure generator has personalization service if available
    if (_personalizationService != null) {
      generator.setPersonalizationService(_personalizationService!);
    }
    // Use general templates but customize category names
    // Enable personalization for better user experience
    // Use retry logic for better reliability
    final generalTrivia = await _generateTriviaWithRetry(
      generator,
      count,
      usePersonalization: true,
    );

    return generalTrivia.map((item) {
      // Ensure theme is always set (fallback to 'general' if null/empty)
      final itemTheme = (item.theme != null && item.theme!.isNotEmpty)
          ? item.theme!
          : 'general';

      return TriviaItem(
        category: '${topic.capitalize()}: ${item.category}',
        words: item.words,
        correctAnswers: item.correctAnswers,
        difficulty: item.difficulty, // Preserve difficulty
        theme: itemTheme, // Ensure theme is always set
      );
    }).toList();
  }

  /// Generate trivia with retry logic and fallback themes
  /// Similar to game_screen.dart implementation for consistency
  Future<List<TriviaItem>> _generateTriviaWithRetry(
    TriviaGeneratorService generator,
    int count, {
    String? theme,
    bool usePersonalization = false,
  }) async {
    int attempts = 0;
    const maxAttempts = 3;
    String? lastError;

    while (attempts < maxAttempts) {
      try {
        final triviaPool = generator.generateBatch(
          count,
          theme: theme,
          usePersonalization: usePersonalization,
        );
        if (triviaPool.isNotEmpty) {
          return triviaPool;
        }
        lastError = 'Empty trivia pool';
      } catch (e) {
        lastError = e.toString();
        if (kDebugMode) {
          debugPrint(
            'AI Edition trivia generation attempt ${attempts + 1}/$maxAttempts failed: $e',
          );
        }

        attempts++;
        if (attempts < maxAttempts) {
          // On failure, try a different theme or fallback to general
          if (theme != null && theme != 'general') {
            theme = 'general'; // Fallback to general theme
            if (kDebugMode) {
              debugPrint('Retrying with general theme...');
            }
          } else {
            // If already on general theme or no specific theme, try a random theme
            final availableThemes = generator.getAvailableThemes();
            if (availableThemes.isNotEmpty) {
              theme =
                  availableThemes[DateTime.now().millisecondsSinceEpoch %
                      availableThemes.length];
              if (kDebugMode) {
                debugPrint('Retrying with random theme: $theme...');
              }
            } else {
              if (kDebugMode) {
                debugPrint('No available themes for retry.');
              }
              break; // No more themes to try
            }
          }
          await Future.delayed(
            Duration(milliseconds: 100 * (attempts + 1)),
          ); // Exponential backoff
        }
      }
    }

    // If all retries failed, throw exception with last error
    throw AIEditionException(
      AIEditionErrorType.generationFailed,
      'Failed to generate trivia after $maxAttempts attempts: $lastError',
    );
  }

  /// Save generation history
  Future<void> _saveGenerationHistory(
    String topic,
    bool isYouth,
    int itemCount,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final history = {
        'userId': user.uid,
        'topic': topic,
        'isYouth': isYouth,
        'itemCount': itemCount,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      };

      // Save to Firestore (async, don't wait)
      if (!_isOfflineMode) {
        try {
          await FirebaseFirestore.instance
              .collection(_collectionName)
              .add(history)
              .timeout(const Duration(seconds: 5));
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error saving to Firestore: $e');
          }
          _isOfflineMode = true;
        }
      }

      // Always save to local storage
      await _saveToLocalStorage(history);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving generation history: $e');
      }
    }
  }

  /// Save to local storage
  Future<void> _saveToLocalStorage(Map<String, dynamic> history) async {
    try {
      final prefs = await _getPrefs();
      final existing = prefs.getStringList(_localStorageKey) ?? [];
      existing.add(jsonEncode(history));
      // Keep only last 50 generations
      if (existing.length > 50) {
        existing.removeRange(0, existing.length - 50);
      }
      await prefs.setStringList(_localStorageKey, existing);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving to local storage: $e');
      }
    }
  }

  /// Get generation history
  Future<List<Map<String, dynamic>>> getGenerationHistory({
    int limit = 20,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      // Try Firestore first
      if (!_isOfflineMode) {
        try {
          final snapshot = await FirebaseFirestore.instance
              .collection(_collectionName)
              .where('userId', isEqualTo: user.uid)
              .orderBy('timestamp', descending: true)
              .limit(limit)
              .get()
              .timeout(const Duration(seconds: 5));

          return snapshot.docs.map((doc) => doc.data()).toList();
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error loading from Firestore: $e');
          }
          _isOfflineMode = true;
        }
      }

      // Fallback to local storage
      final prefs = await _getPrefs();
      final stored = prefs.getStringList(_localStorageKey) ?? [];
      final history =
          stored
              .map((json) => jsonDecode(json) as Map<String, dynamic>)
              .where((item) => item['userId'] == user.uid)
              .toList()
            ..sort(
              (a, b) => (b['timestamp'] as String).compareTo(
                a['timestamp'] as String,
              ),
            );

      return history.take(limit).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading generation history: $e');
      }
      return [];
    }
  }

  /// Get cached trivia for a topic
  Future<List<TriviaItem>?> getCachedTriviaForTopic(
    String topic,
    bool isYouth,
  ) async {
    return await _getCachedTrivia(topic, isYouth);
  }

  /// Clear cache
  Future<void> clearCache() async {
    try {
      final prefs = await _getPrefs();
      final allKeys = prefs
          .getKeys()
          .where((k) => k.startsWith(_cacheKey))
          .toList();
      for (final key in allKeys) {
        await prefs.remove(key);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error clearing cache: $e');
      }
    }
  }

  @override
  void dispose() {
    // AIEditionService uses inline Connectivity() and http.Client calls that don't require cleanup
    // but dispose for consistency with other services
    super.dispose();
  }
}

/// Extension to capitalize first letter
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
