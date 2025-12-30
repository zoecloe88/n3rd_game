import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/models/trivia_item.dart';
import 'package:n3rd_game/services/trivia/trivia_repository.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/exceptions/error_codes.dart';

/// Local storage implementation of TriviaRepository
class LocalTriviaRepository implements TriviaRepository {
  static const String _storageKey = 'saved_trivia';
  static const int _maxLocalTrivia = 100; // Limit local storage size

  @override
  Future<String> saveCustomTrivia({
    required String userId,
    required String category,
    required String question,
    required List<String> words,
    required List<String> correctAnswers,
    String? difficulty,
    bool isPublic = false,
  }) async {
    // For local repository, we save locally and return a local ID
    await saveLocalTrivia(
      category: category,
      question: question,
      words: words,
      correctAnswers: correctAnswers,
    );
    // Return a local ID (timestamp-based)
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  @override
  Future<void> saveLocalTrivia({
    required String category,
    required String question,
    required List<String> words,
    required List<String> correctAnswers,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTriviaList = prefs.getStringList(_storageKey) ?? [];

      final triviaData = {
        'category': category,
        'question': question,
        'words': words,
        'correctAnswers': correctAnswers,
        'savedAt': DateTime.now().toIso8601String(),
      };

      savedTriviaList.add(jsonEncode(triviaData));

      // Limit storage size
      if (savedTriviaList.length > _maxLocalTrivia) {
        savedTriviaList.removeRange(
            0, savedTriviaList.length - _maxLocalTrivia,);
      }

      await prefs.setStringList(_storageKey, savedTriviaList);
    } catch (e, stack) {
      LoggerService.error('Failed to save local trivia',
          error: e, stack: stack,);
      throw StorageException(
        'Failed to save trivia locally',
        errorCode: ErrorCode.storageWriteFailed,
        recoverySuggestion: 'Please try again later.',
      );
    }
  }

  @override
  Future<void> shareTrivia({
    required String fromUserId,
    required String toUserId,
    required String category,
    required String question,
    required List<String> words,
    required List<String> correctAnswers,
  }) async {
    // Local repository doesn't support sharing
    throw UnimplementedError('Use FirestoreTriviaRepository for sharing');
  }

  @override
  Future<List<TriviaItem>> getCustomTrivia({
    required String userId,
    int limit = 20,
  }) async {
    // For local repository, return local trivia
    return getLocalTrivia();
  }

  @override
  Future<List<TriviaItem>> getLocalTrivia() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTriviaList = prefs.getStringList(_storageKey) ?? [];

      final triviaItems = <TriviaItem>[];

      for (final jsonString in savedTriviaList) {
        try {
          final json = jsonDecode(jsonString) as Map<String, dynamic>;
          final item = TriviaItem(
            category: json['category'] as String? ??
                json['question'] as String? ??
                '',
            words: List<String>.from(json['words'] as List? ?? []),
            correctAnswers:
                List<String>.from(json['correctAnswers'] as List? ?? []),
            createdAt: json['savedAt'] != null
                ? DateTime.tryParse(json['savedAt'] as String)
                : null,
          );
          triviaItems.add(item);
        } catch (e) {
          LoggerService.warning('Failed to parse local trivia item', error: e);
          // Skip invalid items
        }
      }

      return triviaItems;
    } catch (e, stack) {
      LoggerService.error('Failed to load local trivia',
          error: e, stack: stack,);
      throw StorageException(
        'Failed to load local trivia',
        errorCode: ErrorCode.storageReadFailed,
        recoverySuggestion: 'Please try again later.',
      );
    }
  }

  @override
  Future<List<TriviaItem>> getSharedTrivia({
    required String userId,
    int limit = 20,
  }) async {
    // Local repository doesn't support shared trivia
    return [];
  }

  @override
  Future<bool> deleteCustomTrivia({
    required String userId,
    required String triviaId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTriviaList = prefs.getStringList(_storageKey) ?? [];

      // Find and remove the trivia item
      // Since we use timestamp-based IDs, we can match by savedAt
      savedTriviaList.removeWhere((jsonString) {
        try {
          final json = jsonDecode(jsonString) as Map<String, dynamic>;
          final savedAt = json['savedAt'] as String?;
          if (savedAt != null) {
            final timestamp =
                DateTime.tryParse(savedAt)?.millisecondsSinceEpoch.toString();
            return timestamp == triviaId;
          }
        } catch (e) {
          // Skip invalid items
        }
        return false;
      });

      await prefs.setStringList(_storageKey, savedTriviaList);
      return true;
    } catch (e, stack) {
      LoggerService.error('Failed to delete local trivia',
          error: e, stack: stack,);
      throw StorageException(
        'Failed to delete trivia',
        errorCode: ErrorCode.storageDeleteFailed,
        recoverySuggestion: 'Please try again later.',
      );
    }
  }
}













