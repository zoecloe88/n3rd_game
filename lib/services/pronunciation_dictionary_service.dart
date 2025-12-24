import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:n3rd_game/models/pronunciation_data.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';

class PronunciationDictionaryService extends ChangeNotifier {
  static const String _storageKey = 'pronunciation_dictionary';
  static const int _maxDictionarySize = 10000; // Maximum number of entries
  static const int _maxWordLength = 100; // Maximum word length
  static const int _maxPhoneticLength = 200; // Maximum phonetic spelling length
  Map<String, PronunciationData> _dictionary = {};
  bool _isLoaded = false;
  bool _isSaving = false; // Mutex to prevent concurrent saves

  Map<String, PronunciationData> get dictionary => _dictionary;
  bool get isLoaded => _isLoaded;

  /// Initialize and load dictionary
  Future<void> init() async {
    if (_isLoaded) return;

    // Load from local storage first
    await _loadFromLocal();

    // If empty, initialize with common words
    if (_dictionary.isEmpty) {
      await _initializeDefaultDictionary();
    }

    _isLoaded = true;
    notifyListeners();
  }

  /// Load dictionary from local storage
  /// CRITICAL: Handles partial failures gracefully - skips corrupted entries but keeps valid ones
  Future<void> _loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        final validEntries = <String, PronunciationData>{};
        int corruptedCount = 0;

        // Load entries one by one, skipping corrupted ones
        for (final entry in data.entries) {
          try {
            final pronunciationData = PronunciationData.fromJson(
              entry.value as Map<String, dynamic>,
            );
            validEntries[entry.key] = pronunciationData;
          } catch (e) {
            corruptedCount++;
            if (kDebugMode) {
              debugPrint(
                '⚠️ Warning: Skipping corrupted pronunciation entry "${entry.key}": $e',
              );
            }
          }
        }

        _dictionary = validEntries;

        if (corruptedCount > 0 && kDebugMode) {
          debugPrint(
            '⚠️ Warning: Skipped $corruptedCount corrupted pronunciation entries, loaded ${validEntries.length} valid entries',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to load pronunciation dictionary: $e');
      }
      // Keep empty dictionary on critical failure (e.g., JSON parse error)
      _dictionary = {};
    }
  }

  /// Save dictionary to local storage
  /// CRITICAL: Protected by mutex to prevent concurrent saves that could cause data loss
  Future<void> _saveToLocal() async {
    // Skip if already saving to prevent race conditions
    if (_isSaving) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ Warning: Pronunciation dictionary save already in progress, skipping duplicate save',
        );
      }
      return;
    }

    _isSaving = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _dictionary.map(
        (key, value) => MapEntry(key, value.toJson()),
      );
      await prefs.setString(_storageKey, jsonEncode(data));
    } catch (e) {
      debugPrint('Failed to save pronunciation dictionary: $e');
    } finally {
      _isSaving = false;
    }
  }

  /// Initialize with default common words
  Future<void> _initializeDefaultDictionary() async {
    // Common trivia words with phonetic spellings
    final defaultWords = [
      PronunciationData(
        word: 'serendipity',
        phonetic: 'ser-uhn-dip-i-tee',
        alternativePronunciations: ['ser-en-dip-i-tee'],
      ),
      PronunciationData(
        word: 'ephemeral',
        phonetic: 'ih-fem-er-uhl',
        alternativePronunciations: ['ee-fem-er-uhl'],
      ),
      PronunciationData(word: 'eloquent', phonetic: 'el-uh-kwuhnt'),
      PronunciationData(word: 'resilient', phonetic: 'ri-zil-yuhnt'),
      PronunciationData(word: 'pragmatic', phonetic: 'prag-mat-ik'),
      PronunciationData(word: 'ambiguous', phonetic: 'am-big-yoo-uhs'),
      PronunciationData(word: 'benevolent', phonetic: 'buh-nev-uh-luhnt'),
      PronunciationData(word: 'cognitive', phonetic: 'kog-ni-tiv'),
      PronunciationData(word: 'diligent', phonetic: 'dil-i-juhnt'),
      PronunciationData(word: 'euphoria', phonetic: 'yoo-for-ee-uh'),
      // Add more common words as needed
    ];

    for (final word in defaultWords) {
      _dictionary[word.word.toLowerCase()] = word;
    }

    await _saveToLocal();
  }

  /// Get pronunciation data for a word
  PronunciationData? getPronunciation(String word) {
    return _dictionary[word.trim().toLowerCase()];
  }

  /// Add or update pronunciation data
  /// CRITICAL: Validates input data to prevent invalid entries and dictionary size limits
  Future<void> addPronunciation(PronunciationData data) async {
    // Validate word
    final word = data.word.trim();
    if (word.isEmpty) {
      throw ValidationException('Word cannot be empty');
    }
    if (word.length > _maxWordLength) {
      throw ValidationException(
        'Word too long (max $_maxWordLength characters)',
      );
    }

    // Validate phonetic
    final phonetic = data.phonetic.trim();
    if (phonetic.isEmpty) {
      throw ValidationException('Phonetic spelling cannot be empty');
    }
    if (phonetic.length > _maxPhoneticLength) {
      throw ValidationException(
        'Phonetic spelling too long (max $_maxPhoneticLength characters)',
      );
    }

    // Check dictionary size limit
    final wordKey = word.toLowerCase();
    final isNewEntry = !_dictionary.containsKey(wordKey);
    if (isNewEntry && _dictionary.length >= _maxDictionarySize) {
      throw ValidationException(
        'Dictionary size limit reached (max $_maxDictionarySize entries)',
      );
    }

    // Create validated entry (use trimmed values)
    final validatedData = PronunciationData(
      word: word,
      phonetic: phonetic,
      alternativePronunciations: data.alternativePronunciations
          .where(
            (alt) => alt.trim().isNotEmpty && alt.length <= _maxPhoneticLength,
          )
          .toList(),
      homophones: data.homophones
          .where(
            (homo) => homo.trim().isNotEmpty && homo.length <= _maxWordLength,
          )
          .toList(),
      language: data.language,
    );

    _dictionary[wordKey] = validatedData;
    await _saveToLocal();
    notifyListeners();
  }

  /// Add multiple pronunciations
  /// CRITICAL: Validates all entries before adding to prevent partial updates
  Future<void> addPronunciations(List<PronunciationData> dataList) async {
    // Validate all entries first before adding any (atomic operation)
    final validatedEntries = <String, PronunciationData>{};

    for (final data in dataList) {
      final word = data.word.trim();
      if (word.isEmpty) {
        throw ValidationException('Word cannot be empty in batch add');
      }
      if (word.length > _maxWordLength) {
        throw ValidationException(
          'Word "${word.substring(0, 20)}..." too long (max $_maxWordLength characters)',
        );
      }

      final phonetic = data.phonetic.trim();
      if (phonetic.isEmpty) {
        throw ValidationException(
          'Phonetic spelling cannot be empty for word "$word"',
        );
      }
      if (phonetic.length > _maxPhoneticLength) {
        throw ValidationException(
          'Phonetic spelling too long for word "$word" (max $_maxPhoneticLength characters)',
        );
      }

      final wordKey = word.toLowerCase();

      // Check dictionary size limit (only count new entries)
      final isNewEntry = !_dictionary.containsKey(wordKey) &&
          !validatedEntries.containsKey(wordKey);
      if (isNewEntry &&
          (_dictionary.length + validatedEntries.length) >=
              _maxDictionarySize) {
        throw ValidationException(
          'Dictionary size limit would be exceeded (max $_maxDictionarySize entries)',
        );
      }

      validatedEntries[wordKey] = PronunciationData(
        word: word,
        phonetic: phonetic,
        alternativePronunciations: data.alternativePronunciations
            .where(
              (alt) =>
                  alt.trim().isNotEmpty && alt.length <= _maxPhoneticLength,
            )
            .toList(),
        homophones: data.homophones
            .where(
              (homo) => homo.trim().isNotEmpty && homo.length <= _maxWordLength,
            )
            .toList(),
        language: data.language,
      );
    }

    // Add all validated entries
    _dictionary.addAll(validatedEntries);
    await _saveToLocal();
    notifyListeners();
  }

  /// Check if word exists in dictionary
  bool hasPronunciation(String word) {
    return _dictionary.containsKey(word.trim().toLowerCase());
  }

  /// Get all words in dictionary
  List<String> getAllWords() {
    return _dictionary.keys.toList();
  }

  /// Match spoken text to word
  String? matchWord(String spokenText, List<String> availableWords) {
    final normalizedSpoken = spokenText.trim().toLowerCase();

    // Try exact match first
    for (final word in availableWords) {
      if (word.trim().toLowerCase() == normalizedSpoken) {
        return word;
      }
    }

    // Try pronunciation matching
    for (final word in availableWords) {
      final pronunciation = getPronunciation(word);
      if (pronunciation != null && pronunciation.matches(normalizedSpoken)) {
        return word;
      }
    }

    return null;
  }

  @override
  void dispose() {
    // SharedPreferences doesn't require explicit cleanup, but dispose for consistency
    super.dispose();
  }
}
