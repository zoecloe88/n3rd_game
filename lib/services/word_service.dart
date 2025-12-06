import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/config/app_config.dart';

class WordOfTheDay {
  final String word;
  final String definition;
  final String example;
  final String? phonetic;
  final String? partOfSpeech;
  final List<String>? synonyms;
  final DateTime date;

  WordOfTheDay({
    required this.word,
    required this.definition,
    required this.example,
    this.phonetic,
    this.partOfSpeech,
    this.synonyms,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'word': word,
    'definition': definition,
    'example': example,
    'phonetic': phonetic,
    'partOfSpeech': partOfSpeech,
    'synonyms': synonyms,
    'date': date.toIso8601String(),
  };

  factory WordOfTheDay.fromJson(Map<String, dynamic> json) => WordOfTheDay(
    word: json['word'] as String,
    definition: json['definition'] as String,
    example: json['example'] as String,
    phonetic: json['phonetic'] as String?,
    partOfSpeech: json['partOfSpeech'] as String?,
    synonyms: json['synonyms'] != null
        ? List<String>.from(json['synonyms'] as List)
        : null,
    date: DateTime.parse(json['date'] as String),
  );
}

class WordService extends ChangeNotifier {
  static const String _storageKey = 'word_of_the_day';
  static const int _apiTimeoutSeconds = 15;
  static const int _maxRetries = 2;
  static final List<String> _wordList = [
    'serendipity',
    'ephemeral',
    'eloquent',
    'resilient',
    'pragmatic',
    'ambiguous',
    'benevolent',
    'cognitive',
    'diligent',
    'euphoria',
    'facetious',
    'gregarious',
    'harmonious',
    'ingenious',
    'jubilant',
    'kinetic',
    'luminous',
    'meticulous',
    'nostalgic',
    'optimistic',
    'paradox',
    'quintessential',
    'robust',
    'subtle',
    'tenacious',
    'ubiquitous',
    'vivid',
    'whimsical',
    'zealous',
    'aesthetic',
  ];

  // Cache SharedPreferences instance
  SharedPreferences? _prefs;

  // Get or initialize SharedPreferences
  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // Create fallback word of the day
  WordOfTheDay _createFallbackWord(String word, DateTime date) {
    return WordOfTheDay(
      word: word,
      definition: 'A fascinating word to explore today.',
      example: 'Use this word in your daily conversation.',
      date: date,
    );
  }

  // Extract the best definition from API response
  String? _extractBestDefinition(List<dynamic> meanings) {
    // Prefer noun or verb definitions first, then others
    final preferredPartsOfSpeech = ['noun', 'verb', 'adjective', 'adverb'];

    for (final pos in preferredPartsOfSpeech) {
      for (final meaning in meanings) {
        if (meaning is Map<String, dynamic>) {
          final partOfSpeech = meaning['partOfSpeech'] as String?;
          if (partOfSpeech == pos) {
            final definitions = meaning['definitions'] as List?;
            if (definitions != null && definitions.isNotEmpty) {
              final firstDef = definitions[0] as Map<String, dynamic>;
              return firstDef['definition'] as String?;
            }
          }
        }
      }
    }

    // If no preferred part of speech found, use first available
    if (meanings.isNotEmpty) {
      final firstMeaning = meanings[0] as Map<String, dynamic>;
      final definitions = firstMeaning['definitions'] as List?;
      if (definitions != null && definitions.isNotEmpty) {
        final firstDef = definitions[0] as Map<String, dynamic>;
        return firstDef['definition'] as String?;
      }
    }

    return null;
  }

  // Extract the best example from API response
  String? _extractBestExample(List<dynamic> meanings) {
    for (final meaning in meanings) {
      if (meaning is Map<String, dynamic>) {
        final definitions = meaning['definitions'] as List?;
        if (definitions != null) {
          for (final def in definitions) {
            if (def is Map<String, dynamic>) {
              final example = def['example'] as String?;
              if (example != null && example.isNotEmpty) {
                return example;
              }
            }
          }
        }
      }
    }
    return null;
  }

  // Extract part of speech
  String? _extractPartOfSpeech(List<dynamic> meanings) {
    if (meanings.isNotEmpty) {
      final firstMeaning = meanings[0] as Map<String, dynamic>;
      return firstMeaning['partOfSpeech'] as String?;
    }
    return null;
  }

  // Extract synonyms
  List<String>? _extractSynonyms(List<dynamic> meanings) {
    final synonyms = <String>[];
    for (final meaning in meanings) {
      if (meaning is Map<String, dynamic>) {
        final syns = meaning['synonyms'] as List?;
        if (syns != null) {
          for (final syn in syns) {
            if (syn is String && syn.isNotEmpty) {
              synonyms.add(syn);
            }
          }
        }
      }
    }
    return synonyms.isNotEmpty ? synonyms.take(5).toList() : null;
  }

  // Check if cached word is for today (using UTC for consistency)
  bool _isToday(DateTime date1, DateTime date2) {
    // Convert both to UTC for consistent comparison across timezones
    final utc1 = date1.toUtc();
    final utc2 = date2.toUtc();
    return utc1.year == utc2.year &&
        utc1.month == utc2.month &&
        utc1.day == utc2.day;
  }

  Future<WordOfTheDay> getWordOfTheDay() async {
    // Use UTC for consistency with daily challenges and leaderboards
    final today = DateTime.now().toUtc();

    // Try to load from cache first (works offline)
    try {
      final prefs = await _getPrefs();
      final cachedJson = prefs.getString(_storageKey);

      if (cachedJson != null) {
        try {
          final cached = WordOfTheDay.fromJson(jsonDecode(cachedJson));
          if (_isToday(cached.date, today)) {
            return cached; // Return cached word if it's for today
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Failed to parse cached word: $e');
          }
          // Continue to fetch new word if cache is invalid
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to load cached word: $e');
      }
      // Continue to fetch new word if cache read fails
    }

    // Check connectivity before attempting API call
    // If offline, return fallback word immediately (faster, better UX)
    try {
      final connectivityResults = await Connectivity().checkConnectivity();
      final isOffline =
          connectivityResults.contains(ConnectivityResult.none) ||
          connectivityResults.isEmpty;

      if (isOffline) {
        if (kDebugMode) {
          debugPrint(
            'Device is offline - returning fallback word without API call',
          );
        }
        // Return fallback word immediately when offline
        final wordIndex = today.day % _wordList.length;
        final word = _wordList[wordIndex];
        final fallbackWord = _createFallbackWord(word, today);

        // Try to cache fallback word (works even offline - local storage)
        try {
          final prefs = await _getPrefs();
          await prefs.setString(_storageKey, jsonEncode(fallbackWord.toJson()));
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Failed to cache fallback word: $e');
          }
        }

        return fallbackWord;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'Failed to check connectivity: $e - continuing with API attempt',
        );
      }
      // Continue with API call if connectivity check fails (assume online)
    }

    // Get word for today
    final wordIndex = today.day % _wordList.length;
    final word = _wordList[wordIndex];

    // Try to fetch from API with retry logic (only if online)
    WordOfTheDay? apiWord;
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        // Try current word first
        final currentWord = attempt == 0
            ? word
            : _wordList[(wordIndex + attempt) % _wordList.length];

        final response = await http
            .get(
              Uri.parse('${AppConfig.dictionaryApiUrl}/$currentWord'),
              headers: {'Accept': 'application/json'},
            )
            .timeout(
              const Duration(seconds: _apiTimeoutSeconds),
              onTimeout: () {
                throw NetworkException('Request timeout');
              },
            );

        if (response.statusCode == 200) {
          try {
            final data = jsonDecode(response.body);
            if (data is List && data.isNotEmpty) {
              final wordData = data[0] as Map<String, dynamic>;

              // Extract word (may have different capitalization)
              final apiWordText = wordData['word'] as String? ?? currentWord;

              // Extract phonetic pronunciation
              String? phonetic = wordData['phonetic'] as String?;
              if (phonetic == null) {
                final phonetics = wordData['phonetics'] as List?;
                if (phonetics != null && phonetics.isNotEmpty) {
                  final firstPhonetic = phonetics[0] as Map<String, dynamic>?;
                  phonetic = firstPhonetic?['text'] as String?;
                }
              }

              // Extract meanings
              final meanings = wordData['meanings'] as List?;
              if (meanings != null && meanings.isNotEmpty) {
                // Extract best definition
                final definition = _extractBestDefinition(meanings);
                if (definition == null || definition.isEmpty) {
                  throw ValidationException(
                    'No definition found in API response',
                  );
                }

                // Extract best example
                final example =
                    _extractBestExample(meanings) ?? 'No example available.';

                // Extract part of speech
                final partOfSpeech = _extractPartOfSpeech(meanings);

                // Extract synonyms
                final synonyms = _extractSynonyms(meanings);

                final wordOfDay = WordOfTheDay(
                  word: apiWordText,
                  definition: definition,
                  example: example,
                  phonetic: phonetic,
                  partOfSpeech: partOfSpeech,
                  synonyms: synonyms,
                  date: today,
                );

                // Save to cache
                try {
                  final prefs = await _getPrefs();
                  await prefs.setString(
                    _storageKey,
                    jsonEncode(wordOfDay.toJson()),
                  );
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint('Failed to cache word: $e');
                  }
                  // Continue even if caching fails
                }

                apiWord = wordOfDay;
                break; // Success, exit retry loop
              } else {
                if (kDebugMode) {
                  debugPrint('No meanings found in API response');
                }
                // Continue to next attempt
              }
            } else {
              if (kDebugMode) {
                debugPrint('API returned empty or invalid data');
              }
              // Continue to next attempt
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint(
                'Failed to parse API response (attempt ${attempt + 1}): $e',
              );
            }
            // Continue to next attempt
          }
        } else if (response.statusCode == 404) {
          if (kDebugMode) {
            debugPrint(
              'Word not found in dictionary API: $currentWord (attempt ${attempt + 1})',
            );
          }
          // Try next word in next attempt
          continue;
        } else {
          if (kDebugMode) {
            debugPrint(
              'API returned status code: ${response.statusCode} (attempt ${attempt + 1})',
            );
          }
          // Continue to next attempt
        }

        // If we got here, this attempt failed - wait before retry (except last attempt)
        if (attempt < _maxRetries) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } catch (e) {
        if (e is NetworkException) {
          if (kDebugMode) {
            debugPrint('Network error (attempt ${attempt + 1}): $e');
          }
        } else {
          if (kDebugMode) {
            debugPrint('Error fetching word (attempt ${attempt + 1}): $e');
          }
        }
        // Continue to next attempt
        if (attempt < _maxRetries) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }

    // If we successfully got a word from API, return it
    if (apiWord != null) {
      return apiWord;
    }

    // Return fallback word if all else fails
    final fallbackWord = _createFallbackWord(word, today);

    // Try to cache fallback word
    try {
      final prefs = await _getPrefs();
      await prefs.setString(_storageKey, jsonEncode(fallbackWord.toJson()));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to cache fallback word: $e');
      }
    }

    return fallbackWord;
  }
}
