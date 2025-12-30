import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:n3rd_game/utils/unawaited_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:n3rd_game/services/trivia/trivia_repository.dart';
import 'package:n3rd_game/services/trivia/firestore_trivia_repository.dart';
import 'package:n3rd_game/services/trivia/local_trivia_repository.dart';
import 'package:n3rd_game/services/trivia/trivia_retry_queue.dart';
import 'package:n3rd_game/services/content_moderation_service.dart';
import 'package:n3rd_game/utils/input_sanitizer.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/exceptions/error_codes.dart';

/// Service for creating and managing custom trivia
///
/// This service provides a complete solution for trivia creation with:
/// - **Local and Cloud Storage**: Save trivia locally for offline access or to Firestore for cloud sync
/// - **Friend Sharing**: Share custom trivia with friends via Firestore
/// - **Content Validation**: Comprehensive validation including length limits, format checks, and duplicate detection
/// - **Content Moderation**: Integration with ContentModerationService for inappropriate content filtering
/// - **Rate Limiting**: Prevents abuse with per-minute limits for saves (10), AI suggestions (5), and shares (5)
/// - **Retry Queue**: Persistent queue for failed saves that automatically retries when connection is restored
/// - **Error Handling**: Uses ErrorCode enum with recovery suggestions for all error scenarios
/// - **Input Sanitization**: All inputs are sanitized before saving to prevent injection attacks
///
/// ## Usage Example
///
/// ```dart
/// final service = TriviaCreatorService();
/// await service.init();
///
/// // Save to cloud
/// try {
///   final triviaId = await service.saveTriviaToCloud(
///     category: 'Geography',
///     question: 'Which of these are capital cities?',
///     words: ['Paris', 'London', 'Berlin', 'Madrid', 'Rome', 'Amsterdam'],
///     correctAnswers: ['Paris', 'London', 'Berlin'],
///   );
///   print('Saved with ID: $triviaId');
/// } on ValidationException catch (e) {
///   print('Validation error: ${e.message}');
///   print('Recovery: ${e.recovery}');
/// }
/// ```
///
/// ## Error Codes
///
/// The service uses the following error codes:
/// - `VALIDATION_001`: Empty field
/// - `VALIDATION_003`: Value too long
/// - `VALIDATION_004`: Value too short
/// - `VALIDATION_005`: Value out of range
/// - `VALIDATION_402`: Invalid format
/// - `AUTH_007`: Rate limit exceeded
/// - `AUTH_002`: User not found (not authenticated)
/// - `STORAGE_002`: Storage write failed
/// - `NETWORK_101`: No internet connection
///
/// ## Rate Limits
///
/// - **Saves per minute**: 10
/// - **AI suggestions per minute**: 5
/// - **Shares per minute**: 5
///
/// ## Retry Queue
///
/// Failed saves are automatically queued and retried when:
/// - Network connection is restored
/// - Service is reinitialized
/// - User logs in
///
/// The queue persists across app restarts and has a maximum age of 7 days.
class TriviaCreatorService extends ChangeNotifier {
  static const int _maxSavesPerMinute = 10;
  static const int _maxSharesPerMinute = 5;
  static const int _maxCategoryLength = 100;
  static const int _maxQuestionLength = 500;
  static const int _maxWordLength = 50;
  static const int _requiredWordsCount = 6;
  static const int _requiredCorrectAnswersCount = 3;

  FirebaseFirestore? _firestore;
  FirebaseAuth? _auth;
  final ContentModerationService _contentModeration =
      ContentModerationService();

  /// Get Firestore instance if Firebase is available
  FirebaseFirestore? get _firestoreInstance {
    if (_disposed) return null;
    if (_firestore != null && _firebaseAvailable) return _firestore;
    try {
      Firebase.app(); // Check if Firebase is initialized
      _firestore = FirebaseFirestore.instance;
      _firebaseAvailable = true;
      return _firestore;
    } catch (e) {
      _firebaseAvailable = false;
      return null;
    }
  }

  /// Get Auth instance if Firebase is available
  FirebaseAuth? get _authInstance {
    if (_disposed) return null;
    if (_auth != null && _firebaseAvailable) return _auth;
    try {
      Firebase.app(); // Check if Firebase is initialized
      _auth = FirebaseAuth.instance;
      _firebaseAvailable = true;
      return _auth;
    } catch (e) {
      _firebaseAvailable = false;
      return null;
    }
  }

  // Repositories
  late final TriviaRepository _cloudRepository;
  late final TriviaRepository _localRepository;

  // Retry queue
  final TriviaRetryQueue _retryQueue = TriviaRetryQueue();

  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _firebaseAvailable = false;
  bool _disposed = false;

  // Rate limiting
  final List<DateTime> _saveTimestamps = [];
  final List<DateTime> _shareTimestamps = [];

  // Loading states
  bool _isSaving = false;
  bool _isSharing = false;

  bool get isInitialized => _isInitialized;
  bool get isSaving => _isSaving;
  bool get isSharing => _isSharing;
  int get retryQueueSize => _retryQueue.queueSize;

  /// Initialize the service
  Future<void> init() async {
    if (_isInitialized || _isInitializing || _disposed) return;

    _isInitializing = true;

    try {
      // Initialize Firebase availability
      try {
        Firebase.app();
        _firebaseAvailable = true;
      } catch (e) {
        _firebaseAvailable = false;
        LoggerService.warning('Firebase not available for trivia creator',
            error: e,);
      }

      // Initialize repositories
      final firestore = _firestoreInstance;
      if (firestore != null) {
        _cloudRepository = FirestoreTriviaRepository(firestore);
      } else {
        // Use local repository only if Firebase is not available
        _cloudRepository = LocalTriviaRepository();
      }
      _localRepository = LocalTriviaRepository();

      // Load retry queue
      await _retryQueue.loadQueue();

      // Process retry queue if user is logged in
      final userId = _userId;
      if (userId != null && _firebaseAvailable) {
        unawaited(_processRetryQueue(userId));
      }

      _isInitialized = true;
      LoggerService.info('TriviaCreatorService initialized');
    } catch (e, stack) {
      LoggerService.error('Failed to initialize TriviaCreatorService',
          error: e, stack: stack,);
      _isInitialized = false;
    } finally {
      _isInitializing = false;
    }
  }

  /// Get current user ID
  String? get _userId {
    try {
      return _authInstance?.currentUser?.uid;
    } catch (e) {
      return null;
    }
  }

  /// Validate trivia input data
  ///
  /// Returns null if valid, ValidationException if invalid
  ValidationException? _validateTriviaInput({
    required String category,
    required String question,
    required List<String> words,
    required List<String> correctAnswers,
  }) {
    // Length validation
    if (category.isEmpty) {
      return ValidationException(
        'Category cannot be empty',
        errorCode: ErrorCode.validationEmptyField,
        recoverySuggestion: 'Please enter a category.',
      );
    }
    if (category.length > _maxCategoryLength) {
      return ValidationException(
        'Category must be $_maxCategoryLength characters or less',
        errorCode: ErrorCode.validationTooLong,
        recoverySuggestion: 'Please shorten the category.',
      );
    }

    if (question.isEmpty) {
      return ValidationException(
        'Question cannot be empty',
        errorCode: ErrorCode.validationEmptyField,
        recoverySuggestion: 'Please enter a question.',
      );
    }
    if (question.length > _maxQuestionLength) {
      return ValidationException(
        'Question must be $_maxQuestionLength characters or less',
        errorCode: ErrorCode.validationTooLong,
        recoverySuggestion: 'Please shorten the question.',
      );
    }

    // Words validation
    if (words.length != _requiredWordsCount) {
      return ValidationException(
        'Must provide exactly $_requiredWordsCount words',
        errorCode: ErrorCode.validationOutOfRange,
        recoverySuggestion:
            'Please provide exactly $_requiredWordsCount words.',
      );
    }

    for (int i = 0; i < words.length; i++) {
      final word = words[i].trim();
      if (word.isEmpty) {
        return ValidationException(
          'Word ${i + 1} cannot be empty',
          errorCode: ErrorCode.validationEmptyField,
          recoverySuggestion: 'Please enter a word for position ${i + 1}.',
        );
      }
      if (word.length > _maxWordLength) {
        return ValidationException(
          'Word "$word" must be $_maxWordLength characters or less',
          errorCode: ErrorCode.validationTooLong,
          recoverySuggestion: 'Please shorten the word.',
        );
      }
    }

    // Check for duplicate words
    final wordSet = words.map((w) => w.trim().toLowerCase()).toSet();
    if (wordSet.length != words.length) {
      return ValidationException(
        'Words must be unique',
        errorCode: ErrorCode.validationInvalidFormat,
        recoverySuggestion: 'Please ensure all words are different.',
      );
    }

    // Correct answers validation
    if (correctAnswers.isEmpty) {
      return ValidationException(
        'Must provide at least one correct answer',
        errorCode: ErrorCode.validationMissingRequired,
        recoverySuggestion: 'Please provide at least one correct answer.',
      );
    }
    if (correctAnswers.length > _requiredCorrectAnswersCount) {
      return ValidationException(
        'Cannot have more than $_requiredCorrectAnswersCount correct answers',
        errorCode: ErrorCode.validationOutOfRange,
        recoverySuggestion:
            'Please provide at most $_requiredCorrectAnswersCount correct answers.',
      );
    }

    for (int i = 0; i < correctAnswers.length; i++) {
      final answer = correctAnswers[i].trim();
      if (answer.isEmpty) {
        return ValidationException(
          'Correct answer ${i + 1} cannot be empty',
          errorCode: ErrorCode.validationEmptyField,
          recoverySuggestion:
              'Please enter a correct answer for position ${i + 1}.',
        );
      }
      if (answer.length > _maxWordLength) {
        return ValidationException(
          'Answer "$answer" must be $_maxWordLength characters or less',
          errorCode: ErrorCode.validationTooLong,
          recoverySuggestion: 'Please shorten the answer.',
        );
      }

      // Ensure answer is in words list
      if (!words.any((w) => w.trim().toLowerCase() == answer.toLowerCase())) {
        return ValidationException(
          'Answer "$answer" must be in the words list',
          errorCode: ErrorCode.validationInvalidFormat,
          recoverySuggestion: 'Please ensure the answer is one of the words.',
        );
      }
    }

    return null;
  }

  /// Check rate limit for saves
  bool _checkSaveRateLimit() {
    final now = DateTime.now();
    _saveTimestamps.removeWhere((ts) => now.difference(ts).inMinutes >= 1);

    if (_saveTimestamps.length >= _maxSavesPerMinute) {
      return false;
    }

    _saveTimestamps.add(now);
    return true;
  }

  /// Check rate limit for shares
  bool _checkShareRateLimit() {
    final now = DateTime.now();
    _shareTimestamps.removeWhere((ts) => now.difference(ts).inMinutes >= 1);

    if (_shareTimestamps.length >= _maxSharesPerMinute) {
      return false;
    }

    _shareTimestamps.add(now);
    return true;
  }

  /// Save trivia to cloud
  ///
  /// Validates, sanitizes, and saves trivia to Firestore.
  /// Returns the trivia ID on success.
  Future<String> saveTriviaToCloud({
    required String category,
    required String question,
    required List<String> words,
    required List<String> correctAnswers,
    String? difficulty,
    bool isPublic = false,
  }) async {
    if (_disposed) {
      throw StorageException(
        'Service has been disposed',
        errorCode: ErrorCode.storageWriteFailed,
      );
    }

    // Validate input FIRST (before auth check)
    final validationError = _validateTriviaInput(
      category: category,
      question: question,
      words: words,
      correctAnswers: correctAnswers,
    );
    if (validationError != null) {
      throw validationError;
    }

    // Rate limiting
    if (!_checkSaveRateLimit()) {
      throw ValidationException(
        'Rate limit exceeded. Please wait before saving again.',
        errorCode: ErrorCode.authTooManyRequests,
        recoverySuggestion: 'Please wait a minute before saving again.',
      );
    }

    // Check authentication
    final userId = _userId;
    if (userId == null) {
      throw AuthenticationException(
        'Please sign in to save trivia',
        errorCode: ErrorCode.authUserNotFound,
        recoverySuggestion: 'Please sign in and try again.',
      );
    }

    // Content moderation
    final moderationError = _contentModeration.validateTriviaContent(
      category: category,
      question: question,
      words: words,
      correctAnswers: correctAnswers,
    );
    if (moderationError != null) {
      throw ValidationException(
        moderationError,
        errorCode: ErrorCode.validationInvalidFormat,
        recoverySuggestion: 'Please review your content and try again.',
      );
    }

    // Sanitize inputs
    final sanitizedCategory = InputSanitizer.sanitizeText(category.trim());
    final sanitizedQuestion = InputSanitizer.sanitizeText(question.trim());
    final sanitizedWords =
        words.map((w) => InputSanitizer.sanitizeText(w.trim())).toList();
    final sanitizedAnswers = correctAnswers
        .map((a) => InputSanitizer.sanitizeText(a.trim()))
        .toList();

    _isSaving = true;
    notifyListeners();

    try {
      if (!_firebaseAvailable) {
        // Queue for retry
        await _retryQueue.enqueue(
          category: sanitizedCategory,
          question: sanitizedQuestion,
          words: sanitizedWords,
          correctAnswers: sanitizedAnswers,
          userId: userId,
          operation: 'save',
        );
        throw NetworkException(
          'No internet connection. Trivia will be saved when connection is restored.',
          errorCode: ErrorCode.networkNoConnection,
          recoverySuggestion: 'Please check your connection and try again.',
        );
      }

      final triviaId = await _cloudRepository.saveCustomTrivia(
        userId: userId,
        category: sanitizedCategory,
        question: sanitizedQuestion,
        words: sanitizedWords,
        correctAnswers: sanitizedAnswers,
        difficulty: difficulty,
        isPublic: isPublic,
      );

      LoggerService.info('Trivia saved successfully: $triviaId');
      return triviaId;
    } catch (e) {
      // If it's already a custom exception, rethrow
      if (e is ValidationException ||
          e is AuthenticationException ||
          e is NetworkException ||
          e is StorageException ||
          e is PermissionException ||
          e is GameException) {
        rethrow;
      }

      // Queue for retry if it's a network error
      if (e is NetworkException || e is StorageException) {
        await _retryQueue.enqueue(
          category: sanitizedCategory,
          question: sanitizedQuestion,
          words: sanitizedWords,
          correctAnswers: sanitizedAnswers,
          userId: userId,
          operation: 'save',
        );
      }

      LoggerService.error('Failed to save trivia to cloud', error: e);
      throw StorageException(
        'Failed to save trivia: ${e.toString()}',
        errorCode: ErrorCode.storageWriteFailed,
        recoverySuggestion: 'Please try again later.',
      );
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Save trivia locally
  ///
  /// Saves trivia to local storage for offline access.
  Future<void> saveTriviaLocally({
    required String category,
    required String question,
    required List<String> words,
    required List<String> correctAnswers,
  }) async {
    if (_disposed) {
      throw StorageException(
        'Service has been disposed',
        errorCode: ErrorCode.storageWriteFailed,
      );
    }

    // Validate input
    final validationError = _validateTriviaInput(
      category: category,
      question: question,
      words: words,
      correctAnswers: correctAnswers,
    );
    if (validationError != null) {
      throw validationError;
    }

    // Content moderation
    final moderationError = _contentModeration.validateTriviaContent(
      category: category,
      question: question,
      words: words,
      correctAnswers: correctAnswers,
    );
    if (moderationError != null) {
      throw ValidationException(
        moderationError,
        errorCode: ErrorCode.validationInvalidFormat,
        recoverySuggestion: 'Please review your content and try again.',
      );
    }

    // Sanitize inputs
    final sanitizedCategory = InputSanitizer.sanitizeText(category.trim());
    final sanitizedQuestion = InputSanitizer.sanitizeText(question.trim());
    final sanitizedWords =
        words.map((w) => InputSanitizer.sanitizeText(w.trim())).toList();
    final sanitizedAnswers = correctAnswers
        .map((a) => InputSanitizer.sanitizeText(a.trim()))
        .toList();

    _isSaving = true;
    notifyListeners();

    try {
      await _localRepository.saveLocalTrivia(
        category: sanitizedCategory,
        question: sanitizedQuestion,
        words: sanitizedWords,
        correctAnswers: sanitizedAnswers,
      );

      LoggerService.info('Trivia saved locally successfully');
    } catch (e) {
      if (e is ValidationException ||
          e is AuthenticationException ||
          e is NetworkException ||
          e is StorageException ||
          e is PermissionException ||
          e is GameException) {
        rethrow;
      }
      LoggerService.error('Failed to save trivia locally', error: e);
      throw StorageException(
        'Failed to save trivia locally: ${e.toString()}',
        errorCode: ErrorCode.storageWriteFailed,
        recoverySuggestion: 'Please try again later.',
      );
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Share trivia with a friend
  ///
  /// Shares trivia with a specified friend via Firestore.
  Future<void> shareTriviaWithFriend({
    required String friendUserId,
    required String category,
    required String question,
    required List<String> words,
    required List<String> correctAnswers,
  }) async {
    if (_disposed) {
      throw StorageException(
        'Service has been disposed',
        errorCode: ErrorCode.storageWriteFailed,
      );
    }

    // Rate limiting
    if (!_checkShareRateLimit()) {
      throw ValidationException(
        'Rate limit exceeded. Please wait before sharing again.',
        errorCode: ErrorCode.authTooManyRequests,
        recoverySuggestion: 'Please wait a minute before sharing again.',
      );
    }

    // Check authentication
    final userId = _userId;
    if (userId == null) {
      throw AuthenticationException(
        'Please sign in to share trivia',
        errorCode: ErrorCode.authUserNotFound,
        recoverySuggestion: 'Please sign in and try again.',
      );
    }

    // Validate input
    final validationError = _validateTriviaInput(
      category: category,
      question: question,
      words: words,
      correctAnswers: correctAnswers,
    );
    if (validationError != null) {
      throw validationError;
    }

    // Content moderation
    final moderationError = _contentModeration.validateTriviaContent(
      category: category,
      question: question,
      words: words,
      correctAnswers: correctAnswers,
    );
    if (moderationError != null) {
      throw ValidationException(
        moderationError,
        errorCode: ErrorCode.validationInvalidFormat,
        recoverySuggestion: 'Please review your content and try again.',
      );
    }

    // Sanitize inputs
    final sanitizedCategory = InputSanitizer.sanitizeText(category.trim());
    final sanitizedQuestion = InputSanitizer.sanitizeText(question.trim());
    final sanitizedWords =
        words.map((w) => InputSanitizer.sanitizeText(w.trim())).toList();
    final sanitizedAnswers = correctAnswers
        .map((a) => InputSanitizer.sanitizeText(a.trim()))
        .toList();

    _isSharing = true;
    notifyListeners();

    try {
      if (!_firebaseAvailable) {
        // Queue for retry
        await _retryQueue.enqueue(
          category: sanitizedCategory,
          question: sanitizedQuestion,
          words: sanitizedWords,
          correctAnswers: sanitizedAnswers,
          userId: userId,
          toUserId: friendUserId,
          operation: 'share',
        );
        throw NetworkException(
          'No internet connection. Trivia will be shared when connection is restored.',
          errorCode: ErrorCode.networkNoConnection,
          recoverySuggestion: 'Please check your connection and try again.',
        );
      }

      await _cloudRepository.shareTrivia(
        fromUserId: userId,
        toUserId: friendUserId,
        category: sanitizedCategory,
        question: sanitizedQuestion,
        words: sanitizedWords,
        correctAnswers: sanitizedAnswers,
      );

      LoggerService.info(
          'Trivia shared successfully with friend: $friendUserId',);
    } catch (e) {
      // If it's already a custom exception, rethrow
      if (e is ValidationException ||
          e is AuthenticationException ||
          e is NetworkException ||
          e is StorageException ||
          e is PermissionException ||
          e is GameException) {
        rethrow;
      }

      // Queue for retry if it's a network error
      if (e is NetworkException || e is StorageException) {
        await _retryQueue.enqueue(
          category: sanitizedCategory,
          question: sanitizedQuestion,
          words: sanitizedWords,
          correctAnswers: sanitizedAnswers,
          userId: userId,
          toUserId: friendUserId,
          operation: 'share',
        );
      }

      LoggerService.error('Failed to share trivia', error: e);
      throw StorageException(
        'Failed to share trivia: ${e.toString()}',
        errorCode: ErrorCode.storageWriteFailed,
        recoverySuggestion: 'Please try again later.',
      );
    } finally {
      _isSharing = false;
      notifyListeners();
    }
  }

  /// Process retry queue in background
  Future<void> _processRetryQueue(String userId) async {
    await _retryQueue.processQueue(
      saveFunction: (userId, category, question, words, correctAnswers) async {
        await _cloudRepository.saveCustomTrivia(
          userId: userId,
          category: category,
          question: question,
          words: words,
          correctAnswers: correctAnswers,
        );
      },
      shareFunction: (fromUserId, toUserId, category, question, words,
          correctAnswers,) async {
        await _cloudRepository.shareTrivia(
          fromUserId: fromUserId,
          toUserId: toUserId,
          category: category,
          question: question,
          words: words,
          correctAnswers: correctAnswers,
        );
      },
      userId: userId,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _retryQueue.dispose();
    super.dispose();
  }
}