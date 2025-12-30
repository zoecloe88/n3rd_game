import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:n3rd_game/models/trivia_item.dart';
import 'package:n3rd_game/services/ai_edition_service.dart';

/// ViewModel for TriviaCreatorScreen
///
/// Manages form state, validation, and debouncing for AI suggestions.
class TriviaCreatorViewModel extends ChangeNotifier {
  // Form fields
  String _category = '';
  String _question = '';
  final List<String> _words = List.filled(6, '');
  final List<String> _correctAnswers = List.filled(3, '');

  // Validation state
  final Map<String, String?> _fieldErrors = {};

  // Loading states
  bool _isGeneratingAI = false;
  String? _aiGenerationError;

  // Debouncing for AI suggestions
  Timer? _aiDebounceTimer;
  static const Duration _aiDebounceDelay = Duration(milliseconds: 500);

  // Getters
  String get category => _category;
  String get question => _question;
  List<String> get words => List.unmodifiable(_words);
  List<String> get correctAnswers => List.unmodifiable(_correctAnswers);
  bool get isGeneratingAI => _isGeneratingAI;
  String? get aiGenerationError => _aiGenerationError;
  Map<String, String?> get fieldErrors => Map.unmodifiable(_fieldErrors);
  bool get hasErrors => _fieldErrors.values.any((error) => error != null);

  /// Update category
  void updateCategory(String value) {
    _category = value;
    _clearFieldError('category');
    notifyListeners();
  }

  /// Update question
  void updateQuestion(String value) {
    _question = value;
    _clearFieldError('question');
    notifyListeners();
  }

  /// Update word at index
  void updateWord(int index, String value) {
    if (index >= 0 && index < _words.length) {
      _words[index] = value;
      _clearFieldError('word_$index');
      notifyListeners();
    }
  }

  /// Update correct answer at index
  void updateCorrectAnswer(int index, String value) {
    if (index >= 0 && index < _correctAnswers.length) {
      _correctAnswers[index] = value;
      _clearFieldError('correctAnswer_$index');
      notifyListeners();
    }
  }

  /// Set field error
  void setFieldError(String field, String? error) {
    if (error == null) {
      _fieldErrors.remove(field);
    } else {
      _fieldErrors[field] = error;
    }
    notifyListeners();
  }

  /// Clear field error
  void _clearFieldError(String field) {
    _fieldErrors.remove(field);
  }

  /// Clear all errors
  void clearAllErrors() {
    _fieldErrors.clear();
    notifyListeners();
  }

  /// Get AI suggestion with debouncing
  ///
  /// [aiService] - AIEditionService instance
  /// [type] - Type of suggestion: 'question', 'words', or 'answers'
  /// [onSuccess] - Callback with the generated TriviaItem
  /// [onError] - Callback with error message
  void getAISuggestion({
    required AIEditionService aiService,
    required String type,
    required void Function(TriviaItem) onSuccess,
    required void Function(String) onError,
  }) {
    // Cancel previous debounce timer
    _aiDebounceTimer?.cancel();

    // Check if category is provided
    if (_category.trim().isEmpty) {
      onError('Please enter a category first');
      return;
    }

    // Debounce the request
    _aiDebounceTimer = Timer(_aiDebounceDelay, () async {
      _isGeneratingAI = true;
      _aiGenerationError = null;
      notifyListeners();

      try {
        final triviaItems = await aiService.generateTriviaForTopic(
          topic: _category.trim(),
          isYouthEdition: false,
          count: 1,
        );

        if (triviaItems.isNotEmpty) {
          final item = triviaItems.first;
          _applyAISuggestion(item, type);
          onSuccess(item);
        } else {
          _aiGenerationError = 'No suggestions generated';
          onError('No suggestions generated');
        }
      } catch (e) {
        _aiGenerationError = e.toString();
        onError(e.toString());
      } finally {
        _isGeneratingAI = false;
        notifyListeners();
      }
    });
  }

  /// Apply AI suggestion to form fields
  void _applyAISuggestion(TriviaItem item, String type) {
    if (type == 'question') {
      _question = item.category;
      _clearFieldError('question');
    } else if (type == 'words') {
      for (int i = 0; i < _words.length && i < item.words.length; i++) {
        _words[i] = item.words[i];
        _clearFieldError('word_$i');
      }
    } else if (type == 'answers') {
      for (int i = 0;
          i < _correctAnswers.length && i < item.correctAnswers.length;
          i++) {
        _correctAnswers[i] = item.correctAnswers[i];
        _clearFieldError('correctAnswer_$i');
      }
    }
    notifyListeners();
  }

  /// Clear form
  void clearForm() {
    _category = '';
    _question = '';
    _words.fillRange(0, _words.length, '');
    _correctAnswers.fillRange(0, _correctAnswers.length, '');
    _fieldErrors.clear();
    _aiGenerationError = null;
    notifyListeners();
  }

  /// Get form data as map
  Map<String, dynamic> getFormData() {
    return {
      'category': _category.trim(),
      'question': _question.trim(),
      'words': _words.map((w) => w.trim()).where((w) => w.isNotEmpty).toList(),
      'correctAnswers': _correctAnswers
          .map((a) => a.trim())
          .where((a) => a.isNotEmpty)
          .toList(),
    };
  }

  @override
  void dispose() {
    _aiDebounceTimer?.cancel();
    super.dispose();
  }
}







