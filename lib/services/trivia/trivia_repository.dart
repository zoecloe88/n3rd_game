import 'package:n3rd_game/models/trivia_item.dart';

/// Abstract repository interface for trivia storage
///
/// Allows for easier testing and potential future storage backends.
abstract class TriviaRepository {
  /// Save a custom trivia item
  Future<String> saveCustomTrivia({
    required String userId,
    required String category,
    required String question,
    required List<String> words,
    required List<String> correctAnswers,
    String? difficulty,
    bool isPublic = false,
  });

  /// Save trivia to local storage
  Future<void> saveLocalTrivia({
    required String category,
    required String question,
    required List<String> words,
    required List<String> correctAnswers,
  });

  /// Share trivia with a friend
  Future<void> shareTrivia({
    required String fromUserId,
    required String toUserId,
    required String category,
    required String question,
    required List<String> words,
    required List<String> correctAnswers,
  });

  /// Get custom trivia items for a user
  Future<List<TriviaItem>> getCustomTrivia({
    required String userId,
    int limit = 20,
  });

  /// Get local trivia items
  Future<List<TriviaItem>> getLocalTrivia();

  /// Get shared trivia items for a user
  Future<List<TriviaItem>> getSharedTrivia({
    required String userId,
    int limit = 20,
  });

  /// Delete a custom trivia item
  Future<bool> deleteCustomTrivia({
    required String userId,
    required String triviaId,
  });
}













