import 'dart:async' hide unawaited;
import 'package:flutter/foundation.dart';
import 'package:n3rd_game/utils/unawaited_helper.dart';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:n3rd_game/models/daily_challenge.dart';
import 'package:n3rd_game/services/challenge/challenge_repository.dart';
import 'package:n3rd_game/services/challenge/firestore_challenge_repository.dart';
import 'package:n3rd_game/services/challenge/local_challenge_repository.dart';
import 'package:n3rd_game/services/challenge/challenge_retry_queue.dart';
import 'package:n3rd_game/services/challenge/challenge_validator.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/utils/input_sanitizer.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/exceptions/error_codes.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Service for managing daily challenges
///
/// Handles generating, loading, saving, and updating daily challenges with:
/// - Repository pattern for storage abstraction
/// - Firestore integration for cloud storage
/// - Local storage for offline support
/// - Error handling and retry logic
/// - Rate limiting
/// - Proper disposal of resources
class ChallengeService extends ChangeNotifier {
  static const int _maxChallengeGenerationPerDay = 10;
  static const int _maxProgressUpdatesPerMinute = 20;
  static const Duration _rateLimitWindow = Duration(minutes: 1);

  ChallengeRepository? _firestoreRepository;
  final LocalChallengeRepository _localRepository = LocalChallengeRepository();
  final ChallengeRetryQueue _retryQueue = ChallengeRetryQueue();

  List<DailyChallenge> _challenges = [];
  bool _isInitialized = false;
  bool _isInitializing = false; // Mutex to prevent concurrent initialization
  bool _disposed = false;

  // Rate limiting
  final List<DateTime> _generationTimestamps = [];
  final List<DateTime> _progressUpdateTimestamps = [];

  // Cache for challenges
  DateTime? _lastCacheUpdate;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  // Cached challenges (for offline access)
  List<DailyChallenge> get challenges => List.unmodifiable(_challenges);
  bool get isInitialized => _isInitialized;

  List<DailyChallenge> get todayChallenges => _challenges.where((c) {
        // Use UTC for consistency with leaderboard service
        final today = DateTime.now().toUtc();
        final challengeDate = c.date.toUtc();
        return challengeDate.year == today.year &&
            challengeDate.month == today.month &&
            challengeDate.day == today.day;
      }).toList();

  /// Get current user ID for Firestore
  String? get _userId {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (e) {
      return null;
    }
  }

  /// Initialize the service
  Future<void> init() async {
    if (_isInitialized || _isInitializing || _disposed) return;

    _isInitializing = true;

    try {
      // Try to initialize Firebase
      try {
        Firebase.app();
        _firestoreRepository =
            FirestoreChallengeRepository(FirebaseFirestore.instance);
      } catch (e) {
        LoggerService.warning('Firebase not available for challenges',
            error: e,);
      }

      // Load cached challenges from local storage
      await _loadLocal();

      // Load retry queue
      await _retryQueue.loadQueue();

      // If user is logged in and Firebase is available, try to sync from Firestore
      final userId = _userId;
      if (userId != null &&
          _firestoreRepository != null &&
          _firestoreRepository!.isAvailable) {
        // Check cache first
        if (_lastCacheUpdate != null &&
            DateTime.now().difference(_lastCacheUpdate!) < _cacheExpiry &&
            _challenges.isNotEmpty) {
          // Use cached data
          LoggerService.debug('Using cached challenges');
        } else {
          try {
            final firestoreChallenges =
                await _firestoreRepository!.loadChallenges(userId);
            if (firestoreChallenges.isNotEmpty) {
              _challenges = firestoreChallenges;
              _lastCacheUpdate = DateTime.now();
              notifyListeners();
              await _localRepository.saveChallenges(
                  userId: userId, challenges: _challenges,);
            }
          } on NetworkException catch (e) {
            LoggerService.warning(
                'Failed to load challenges from Firestore, using local cache',
                error: e,);
          } on StorageException catch (e) {
            LoggerService.warning(
                'Failed to load challenges from Firestore, using local cache',
                error: e,);
          } catch (e, stack) {
            LoggerService.error(
                'Unexpected error loading challenges from Firestore',
                error: e,
                stack: stack,);
          }
        }
      }

      // Generate daily challenges if needed
      await _generateDailyChallenges();

      // Process retry queue in background
      unawaited(_processRetryQueue());

      _isInitialized = true;
    } catch (e, stack) {
      LoggerService.error('Failed to initialize ChallengeService',
          error: e, stack: stack,);
      unawaited(FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'ChallengeService init failed',
        fatal: false,
      ) as Future<dynamic>,);
    } finally {
      _isInitializing = false;
    }
  }

  /// Load challenges from local storage
  Future<void> _loadLocal() async {
    try {
      final userId = _userId ?? 'anonymous';
      final localChallenges = await _localRepository.loadChallenges(userId);
      if (localChallenges.isNotEmpty) {
        _challenges = localChallenges;
        notifyListeners();
      }
    } catch (e, stack) {
      LoggerService.error('Failed to load challenges from local storage',
          error: e, stack: stack,);
    }
  }

  /// Save challenges to both local and Firestore
  Future<void> _saveChallenges() async {
    final userId = _userId;
    if (userId == null) {
      LoggerService.warning('Cannot save challenges: user not logged in');
      return;
    }

    try {
      // Validate all challenges before saving
      for (final challenge in _challenges) {
        ChallengeValidator.validateChallenge(challenge);
      }

      // Save to local storage first (faster, always available)
      await _localRepository.saveChallenges(
          userId: userId, challenges: _challenges,);

      // Try to save to Firestore if available
      if (_firestoreRepository != null && _firestoreRepository!.isAvailable) {
        try {
          await _firestoreRepository!.saveChallenges(
            userId: userId,
            challenges: _challenges,
          );
        } on NetworkException catch (e) {
          LoggerService.warning(
              'Failed to save challenges to Firestore, queuing for retry',
              error: e,);
          // Queue for retry
          await _retryQueue.enqueue(userId: userId, challenges: _challenges);
        } on StorageException catch (e) {
          LoggerService.warning(
              'Failed to save challenges to Firestore, queuing for retry',
              error: e,);
          // Queue for retry
          await _retryQueue.enqueue(userId: userId, challenges: _challenges);
        } catch (e, stack) {
          LoggerService.error('Unexpected error saving challenges to Firestore',
              error: e, stack: stack,);
          // Queue for retry
          await _retryQueue.enqueue(userId: userId, challenges: _challenges);
        }
      } else {
        // Firebase not available, queue for retry
        await _retryQueue.enqueue(userId: userId, challenges: _challenges);
      }
    } catch (e, stack) {
      LoggerService.error('Failed to save challenges', error: e, stack: stack);
      unawaited(FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'ChallengeService save failed',
        fatal: false,
      ) as Future<dynamic>,);
      rethrow;
    }
  }

  /// Process retry queue
  Future<void> _processRetryQueue() async {
    if (_firestoreRepository == null || !_firestoreRepository!.isAvailable) {
      return;
    }

    try {
      await _retryQueue.processQueue((userId, challenges) async {
        await _firestoreRepository!.saveChallenges(
          userId: userId,
          challenges: challenges,
        );
      });
    } catch (e, stack) {
      LoggerService.error('Error processing retry queue',
          error: e, stack: stack,);
    }
  }

  /// Check rate limit for challenge generation
  bool _checkGenerationRateLimit() {
    final now = DateTime.now();
    _generationTimestamps.removeWhere(
      (timestamp) => now.difference(timestamp) > _rateLimitWindow,
    );

    if (_generationTimestamps.length >= _maxChallengeGenerationPerDay) {
      LoggerService.warning('Challenge generation rate limit exceeded');
      return false;
    }

    _generationTimestamps.add(now);
    return true;
  }

  /// Check rate limit for progress updates
  bool _checkProgressUpdateRateLimit() {
    final now = DateTime.now();
    _progressUpdateTimestamps.removeWhere(
      (timestamp) => now.difference(timestamp) > _rateLimitWindow,
    );

    if (_progressUpdateTimestamps.length >= _maxProgressUpdatesPerMinute) {
      LoggerService.warning('Progress update rate limit exceeded');
      return false;
    }

    _progressUpdateTimestamps.add(now);
    return true;
  }

  /// Generate daily challenges for today
  Future<void> _generateDailyChallenges() async {
    // Check rate limit
    if (!_checkGenerationRateLimit()) {
      LoggerService.warning(
          'Challenge generation rate limit exceeded, skipping',);
      return;
    }

    // Use UTC for consistency with leaderboard service
    final today = DateTime.now().toUtc();
    final todayChallenges = _challenges.where((c) {
      final challengeDate = c.date.toUtc();
      return challengeDate.year == today.year &&
          challengeDate.month == today.month &&
          challengeDate.day == today.day;
    }).toList();

    // If we already have challenges for today, don't regenerate
    if (todayChallenges.isNotEmpty) {
      return;
    }

    try {
      // Generate 3-5 random challenges for today + 1 competitive challenge
      final random = Random();
      final challengeCount = 3 + random.nextInt(3); // 3-5 challenges
      final newChallenges = <DailyChallenge>[];

      // Add one competitive challenge first
      newChallenges.add(_generateDailyCompetitiveChallenge(today));

      // Generate regular challenges (exclude competitive from random pool)
      for (int i = 0; i < challengeCount; i++) {
        final challenge = _generateRandomChallenge(today);
        newChallenges.add(challenge);
      }

      // Validate all new challenges
      for (final challenge in newChallenges) {
        ChallengeValidator.validateChallenge(challenge);
      }

      _challenges.addAll(newChallenges);
      _lastCacheUpdate = DateTime.now(); // Update cache timestamp
      notifyListeners();
      await _saveChallenges();
    } catch (e, stack) {
      LoggerService.error('Failed to generate daily challenges',
          error: e, stack: stack,);
      unawaited(FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'Challenge generation failed',
        fatal: false,
      ) as Future<dynamic>,);
    }
  }

  /// Generate daily competitive challenge (one per day)
  DailyChallenge _generateDailyCompetitiveChallenge(DateTime date) {
    final random = Random();
    final modes = ['Blitz', 'Speed', 'Classic', 'Streak', 'Shuffle'];
    final mode = modes[random.nextInt(modes.length)];
    final rounds = 5 + random.nextInt(3); // 5-7 rounds

    return DailyChallenge(
      id: '${date.millisecondsSinceEpoch}_competitive',
      title: 'Daily Challenge: $mode Mode',
      description:
          'Compete in $mode Mode - $rounds rounds. Top 5 players on leaderboard!',
      type: ChallengeType.dailyCompetitive,
      target: {'mode': mode, 'rounds': rounds},
      date: date,
      rewardPoints: 300, // Higher reward for competitive
    );
  }

  DailyChallenge _generateRandomChallenge(DateTime date) {
    final random = Random();
    // Exclude competitive from random pool
    final types = ChallengeType.values
        .where((t) => t != ChallengeType.dailyCompetitive)
        .toList();
    final type = types[random.nextInt(types.length)];

    switch (type) {
      case ChallengeType.perfectScore:
        return DailyChallenge(
          id: '${date.millisecondsSinceEpoch}_perfect',
          title: 'Perfect Performance',
          description:
              'Get ${2 + random.nextInt(3)} perfect scores (3/3 correct)',
          type: type,
          target: {'count': 2 + random.nextInt(3)},
          date: date,
          rewardPoints: 150,
        );
      case ChallengeType.streak:
        return DailyChallenge(
          id: '${date.millisecondsSinceEpoch}_streak',
          title: 'Streak Master',
          description:
              'Maintain a ${3 + random.nextInt(3)} game winning streak',
          type: type,
          target: {'streak': 3 + random.nextInt(3)},
          date: date,
          rewardPoints: 200,
        );
      case ChallengeType.gamesPlayed:
        return DailyChallenge(
          id: '${date.millisecondsSinceEpoch}_games',
          title: 'Daily Grind',
          description: 'Play ${5 + random.nextInt(6)} games today',
          type: type,
          target: {'count': 5 + random.nextInt(6)},
          date: date,
          rewardPoints: 100,
        );
      case ChallengeType.accuracy:
        return DailyChallenge(
          id: '${date.millisecondsSinceEpoch}_accuracy',
          title: 'Precision Expert',
          description:
              'Achieve ${70 + random.nextInt(21)}% accuracy in 5 games',
          type: type,
          target: {'accuracy': 70 + random.nextInt(21), 'games': 5},
          date: date,
          rewardPoints: 180,
        );
      case ChallengeType.timeAttack:
        return DailyChallenge(
          id: '${date.millisecondsSinceEpoch}_timeattack',
          title: 'Time Warrior',
          description:
              'Score ${100 + random.nextInt(100)} points in Time Attack mode',
          type: type,
          target: {'score': 100 + random.nextInt(100)},
          date: date,
          rewardPoints: 250,
        );
      case ChallengeType.category:
        final categories = [
          'History',
          'Science',
          'Geography',
          'Sports',
          'Entertainment',
        ];
        final category = categories[random.nextInt(categories.length)];
        return DailyChallenge(
          id: '${date.millisecondsSinceEpoch}_category',
          title: 'Category Specialist',
          description: 'Play 3 games in $category category',
          type: type,
          target: {'category': category, 'count': 3},
          date: date,
          rewardPoints: 120,
        );
      case ChallengeType.modeSpecific:
        final modes = ['Classic', 'Speed', 'Shuffle', 'Challenge'];
        final mode = modes[random.nextInt(modes.length)];
        return DailyChallenge(
          id: '${date.millisecondsSinceEpoch}_mode',
          title: 'Mode Master',
          description: 'Play 2 games in $mode mode',
          type: type,
          target: {'mode': mode, 'count': 2},
          date: date,
          rewardPoints: 130,
        );
      case ChallengeType.dailyCompetitive:
        // This should not be called in random generation
        // Competitive challenges are generated separately
        return _generateDailyCompetitiveChallenge(date);
    }
  }

  /// Update challenge progress
  Future<void> updateChallengeProgress(String challengeId, int progress) async {
    if (_disposed) return;

    // Sanitize and validate inputs
    final sanitizedChallengeId = InputSanitizer.sanitizeText(challengeId);
    if (sanitizedChallengeId.isEmpty) {
      throw ValidationException(
        'Challenge ID cannot be empty',
        errorCode: ErrorCode.validationEmptyField,
      );
    }

    ChallengeValidator.validateProgress(progress);

    // Check rate limit
    if (!_checkProgressUpdateRateLimit()) {
      throw ValidationException(
        'Too many progress updates. Please wait a moment.',
        errorCode: ErrorCode.authTooManyRequests,
      );
    }

    try {
      final index = _challenges.indexWhere((c) => c.id == sanitizedChallengeId);
      if (index == -1) {
        throw ValidationException(
          'Challenge not found: $sanitizedChallengeId',
          errorCode: ErrorCode.validationMissingRequired,
        );
      }

      final challenge = _challenges[index];
      final newProgress = challenge.progress + progress;
      final targetValue = challenge.target['count'] ??
          challenge.target['streak'] ??
          challenge.target['score'] ??
          1;
      final isCompleted = newProgress >= targetValue;

      _challenges[index] = challenge.copyWith(
        progress: newProgress,
        isCompleted: isCompleted,
      );

      _lastCacheUpdate = DateTime.now(); // Invalidate cache
      notifyListeners();
      await _saveChallenges();
    } on ValidationException {
      rethrow;
    } catch (e, stack) {
      LoggerService.error('Failed to update challenge progress',
          error: e, stack: stack,);
      unawaited(FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'Challenge progress update failed',
        fatal: false,
      ) as Future<dynamic>,);
      throw StorageException(
        'Failed to update challenge progress',
        errorCode: ErrorCode.storageWriteFailed,
        recoverySuggestion: 'Please try again later.',
      );
    }
  }

  /// Mark challenge as completed
  Future<void> completeChallenge(String challengeId) async {
    if (_disposed) return;

    // Sanitize and validate inputs
    final sanitizedChallengeId = InputSanitizer.sanitizeText(challengeId);
    if (sanitizedChallengeId.isEmpty) {
      throw ValidationException(
        'Challenge ID cannot be empty',
        errorCode: ErrorCode.validationEmptyField,
      );
    }

    try {
      final index = _challenges.indexWhere((c) => c.id == sanitizedChallengeId);
      if (index == -1) {
        throw ValidationException(
          'Challenge not found: $sanitizedChallengeId',
          errorCode: ErrorCode.validationMissingRequired,
        );
      }

      _challenges[index] = _challenges[index].copyWith(isCompleted: true);
      _lastCacheUpdate = DateTime.now(); // Invalidate cache
      notifyListeners();
      await _saveChallenges();
    } on ValidationException {
      rethrow;
    } catch (e, stack) {
      LoggerService.error('Failed to complete challenge',
          error: e, stack: stack,);
      unawaited(FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'Challenge completion failed',
        fatal: false,
      ) as Future<dynamic>,);
      throw StorageException(
        'Failed to complete challenge',
        errorCode: ErrorCode.storageWriteFailed,
        recoverySuggestion: 'Please try again later.',
      );
    }
  }

  /// Dispose resources
  @override
  void dispose() {
    _disposed = true;
    _retryQueue.dispose();
    super.dispose();
  }
}