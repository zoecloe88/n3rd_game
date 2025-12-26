import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/models/game_history_entry.dart';
import 'package:n3rd_game/services/game_service.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/utils/input_sanitizer.dart';

/// Service for managing game history records
///
/// Handles saving, retrieving, and querying game history with:
/// - Firestore integration for cloud storage
/// - SharedPreferences for offline caching
/// - Error handling and retry logic
/// - Proper disposal of resources
class GameHistoryService extends ChangeNotifier {
  static const String _storageKey = 'game_history_cache';
  static const int _maxCachedGames = 100; // Limit local cache size

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isInitialized = false;
  bool _isInitializing = false; // Mutex to prevent concurrent initialization
  bool _firebaseAvailable = false;
  bool _disposed = false;

  // Cached game history (for offline access)
  List<GameHistoryEntry> _cachedGames = [];

  // Stream subscription for real-time updates
  StreamSubscription<QuerySnapshot>? _historySubscription;

  List<GameHistoryEntry> get cachedGames => List.unmodifiable(_cachedGames);
  bool get isInitialized => _isInitialized;

  /// Get Firestore instance if Firebase is available
  FirebaseFirestore? get _firestoreInstance {
    if (!_firebaseAvailable || _disposed) return null;
    try {
      Firebase.app();
      return _firestore;
    } catch (e) {
      _firebaseAvailable = false;
      return null;
    }
  }

  /// Get current user ID for Firestore
  String? get _userId {
    try {
      return _auth.currentUser?.uid;
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
        _firebaseAvailable = true;
      } catch (e) {
        _firebaseAvailable = false;
        LoggerService.warning('Firebase not available for game history', error: e);
      }

      // Load cached games from local storage
      await _loadCachedGames();

      // If user is logged in and Firebase is available, set up real-time listener
      final userId = _userId;
      if (userId != null && _firebaseAvailable) {
        _setupHistoryListener(userId);
      }

      _isInitialized = true;
      LoggerService.info('GameHistoryService initialized');
    } catch (e, stackTrace) {
      LoggerService.error(
        'Error initializing GameHistoryService',
        error: e,
        stack: stackTrace,
      );
      _isInitialized = false;
    } finally {
      _isInitializing = false;
    }
  }

  /// Load cached games from SharedPreferences
  Future<void> _loadCachedGames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        final gamesList = json['games'] as List<dynamic>?;
        if (gamesList != null) {
          _cachedGames = gamesList
              .map((g) => GameHistoryEntry.fromJson(g as Map<String, dynamic>))
              .toList();
          notifyListeners();
        }
      }
    } catch (e) {
      LoggerService.error('Failed to load cached game history', error: e);
      _cachedGames = [];
    }
  }

  /// Save cached games to SharedPreferences
  Future<void> _saveCachedGames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = {
        'games': _cachedGames.take(_maxCachedGames).map((g) => g.toJson()).toList(),
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_storageKey, jsonEncode(json));
    } catch (e) {
      LoggerService.error('Failed to save cached game history', error: e);
    }
  }

  /// Set up real-time listener for game history
  void _setupHistoryListener(String userId) {
    // Cancel existing subscription
    _historySubscription?.cancel();

    try {
      _historySubscription = _firestore
          .collection('users')
          .doc(userId)
          .collection('game_history')
          .orderBy('completedAt', descending: true)
          .limit(100) // Limit to most recent 100 games
          .snapshots()
          .listen(
        (snapshot) {
          if (_disposed) return;

          try {
            _cachedGames = snapshot.docs
                .map((doc) => GameHistoryEntry.fromFirestore(doc))
                .toList();

            // Save to local cache
            _saveCachedGames().catchError((e) {
              LoggerService.warning('Failed to save cached games after update', error: e);
            });

            notifyListeners();
          } catch (e, stackTrace) {
            LoggerService.error(
              'Error processing game history snapshot',
              error: e,
              stack: stackTrace,
            );
          }
        },
        onError: (error) {
          if (_disposed) return;

          if (error is FirebaseException && error.code == 'permission-denied') {
            LoggerService.error(
              'GameHistoryService: Permission denied accessing game history. User may not be authenticated or lacks required permissions.',
              error: error,
              reason: 'Firestore permission-denied error',
              fatal: false,
            );
            _cachedGames.clear();
            notifyListeners();
          } else {
            LoggerService.error(
              'GameHistoryService: Error listening to game history',
              error: error,
              reason: 'Firestore stream error',
              fatal: false,
            );
          }
        },
      );
    } catch (e, stackTrace) {
      LoggerService.error(
        'Error setting up game history listener',
        error: e,
        stack: stackTrace,
      );
    }
  }

  /// Record a completed game
  ///
  /// Saves the game record to Firestore and local cache.
  /// Handles errors gracefully and doesn't block game completion.
  Future<void> recordGame(GameHistoryEntry game) async {
    if (_disposed) return;

    // Validate input
    if (game.gameId.isEmpty) {
      LoggerService.warning('Cannot record game with empty gameId');
      return;
    }

    // Sanitize input
    final sanitizedGame = _sanitizeGameEntry(game);
    if (sanitizedGame == null) {
      LoggerService.warning('Game entry failed validation, not recording');
      return;
    }

    // Add to local cache immediately (for offline support)
    _cachedGames.insert(0, sanitizedGame);
    if (_cachedGames.length > _maxCachedGames) {
      _cachedGames = _cachedGames.take(_maxCachedGames).toList();
    }
    await _saveCachedGames();
    notifyListeners();

    // Try to save to Firestore (non-blocking)
    final userId = _userId;
    if (userId != null && _firebaseAvailable) {
      _saveToFirestore(userId, sanitizedGame).catchError((e) {
        LoggerService.error(
          'Failed to save game to Firestore (will retry on next sync)',
          error: e,
        );
      });
    }
  }

  /// Sanitize and validate game entry
  GameHistoryEntry? _sanitizeGameEntry(GameHistoryEntry game) {
    try {
      // Validate required fields
      if (game.score < 0) {
        LoggerService.warning('Invalid score: ${game.score}');
        return null;
      }
      if (game.rounds < 0) {
        LoggerService.warning('Invalid rounds: ${game.rounds}');
        return null;
      }
      if (game.correctAnswers < 0 || game.wrongAnswers < 0) {
        LoggerService.warning('Invalid answer counts');
        return null;
      }
      if (game.durationSeconds < 0) {
        LoggerService.warning('Invalid duration: ${game.durationSeconds}');
        return null;
      }

      // Sanitize trivia categories
      final sanitizedCategories = game.triviaCategories
          .map((cat) => InputSanitizer.sanitizeText(cat))
          .where((cat) => cat.isNotEmpty)
          .toList();

      // Sanitize difficulty if present
      String? sanitizedDifficulty;
      if (game.difficulty != null && game.difficulty!.isNotEmpty) {
        sanitizedDifficulty = InputSanitizer.sanitizeText(game.difficulty!);
        if (sanitizedDifficulty.isEmpty) {
          sanitizedDifficulty = null;
        }
      }

      return game.copyWith(
        triviaCategories: sanitizedCategories,
        difficulty: sanitizedDifficulty,
      );
    } catch (e) {
      LoggerService.error('Error sanitizing game entry', error: e);
      return null;
    }
  }

  /// Save game to Firestore with retry logic
  Future<void> _saveToFirestore(String userId, GameHistoryEntry game) async {
    if (_disposed) return;

    const maxRetries = 3;
    const timeoutDuration = Duration(seconds: 10);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final firestore = _firestoreInstance;
        if (firestore == null) {
          throw Exception('Firestore not available');
        }

        await firestore
            .collection('users')
            .doc(userId)
            .collection('game_history')
            .doc(game.gameId)
            .set(game.toFirestore(), SetOptions(merge: true))
            .timeout(
          timeoutDuration,
          onTimeout: () {
            throw TimeoutException(
              'Firestore save timeout after ${timeoutDuration.inSeconds}s',
            );
          },
        );

        if (attempt > 1) {
          LoggerService.info('Game saved to Firestore on attempt $attempt');
        }
        return; // Success
      } catch (e) {
        final isLastAttempt = attempt == maxRetries;
        if (isLastAttempt) {
          LoggerService.error(
            'Failed to save game to Firestore after $maxRetries attempts',
            error: e,
          );
          rethrow;
        } else {
          // Wait before retry (exponential backoff)
          final delayMs = 500 * attempt;
          LoggerService.warning(
            'Game Firestore save failed (attempt $attempt/$maxRetries): $e. Retrying in ${delayMs}ms...',
            error: e,
          );
          await Future.delayed(Duration(milliseconds: delayMs));
        }
      }
    }
  }

  /// Get game history with filters and pagination
  ///
  /// Parameters:
  /// - [limit]: Maximum number of games to return (default: 20, max: 100)
  /// - [startAfter]: Document snapshot to start after (for pagination)
  /// - [mode]: Filter by game mode (optional)
  /// - [startDate]: Filter games after this date (optional)
  /// - [endDate]: Filter games before this date (optional)
  /// - [minScore]: Minimum score filter (optional)
  /// - [maxScore]: Maximum score filter (optional)
  Future<List<GameHistoryEntry>> getGameHistory({
    int limit = 20,
    DocumentSnapshot? startAfter,
    GameMode? mode,
    DateTime? startDate,
    DateTime? endDate,
    int? minScore,
    int? maxScore,
  }) async {
    if (_disposed) return [];

    final userId = _userId;
    if (userId == null) {
      // Return cached games if not logged in
      return _applyFilters(_cachedGames, mode: mode, startDate: startDate, endDate: endDate, minScore: minScore, maxScore: maxScore)
          .take(limit)
          .toList();
    }

    final firestore = _firestoreInstance;
    if (firestore == null) {
      // Return cached games if Firestore not available
      return _applyFilters(_cachedGames, mode: mode, startDate: startDate, endDate: endDate, minScore: minScore, maxScore: maxScore)
          .take(limit)
          .toList();
    }

    try {
      Query query = firestore
          .collection('users')
          .doc(userId)
          .collection('game_history');

      // Apply filters
      if (mode != null) {
        query = query.where('mode', isEqualTo: mode.toString().split('.').last);
      }
      if (startDate != null) {
        query = query.where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        query = query.where('completedAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }
      if (minScore != null) {
        query = query.where('score', isGreaterThanOrEqualTo: minScore);
      }
      if (maxScore != null) {
        query = query.where('score', isLessThanOrEqualTo: maxScore);
      }

      // Order and paginate
      query = query.orderBy('completedAt', descending: true);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final clampedLimit = limit.clamp(1, 100);
      final snapshot = await query.limit(clampedLimit).get().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Firestore query timeout');
        },
      );

      return snapshot.docs
          .map((doc) => GameHistoryEntry.fromFirestore(doc))
          .toList();
    } catch (e, stackTrace) {
      LoggerService.error(
        'Error fetching game history',
        error: e,
        stack: stackTrace,
      );
      // Fallback to cached games
      return _applyFilters(_cachedGames, mode: mode, startDate: startDate, endDate: endDate, minScore: minScore, maxScore: maxScore)
          .take(limit)
          .toList();
    }
  }

  /// Apply filters to a list of games
  List<GameHistoryEntry> _applyFilters(
    List<GameHistoryEntry> games, {
    GameMode? mode,
    DateTime? startDate,
    DateTime? endDate,
    int? minScore,
    int? maxScore,
  }) {
    var filtered = games;

    if (mode != null) {
      filtered = filtered.where((g) => g.mode == mode).toList();
    }
    if (startDate != null) {
      filtered = filtered.where((g) => g.completedAt.isAfter(startDate)).toList();
    }
    if (endDate != null) {
      filtered = filtered.where((g) => g.completedAt.isBefore(endDate)).toList();
    }
    if (minScore != null) {
      filtered = filtered.where((g) => g.score >= minScore).toList();
    }
    if (maxScore != null) {
      filtered = filtered.where((g) => g.score <= maxScore).toList();
    }

    return filtered;
  }

  /// Get a specific game by ID
  Future<GameHistoryEntry?> getGameById(String gameId) async {
    if (_disposed || gameId.isEmpty) return null;

    // Check cache first
    try {
      final cached = _cachedGames.firstWhere((g) => g.gameId == gameId);
      return cached;
    } catch (_) {
      // Not found in cache, continue to Firestore
    }

    final userId = _userId;
    if (userId == null) return null;

    final firestore = _firestoreInstance;
    if (firestore == null) return null;

    try {
      final doc = await firestore
          .collection('users')
          .doc(userId)
          .collection('game_history')
          .doc(gameId)
          .get()
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Firestore get timeout');
        },
      );

      if (doc.exists) {
        return GameHistoryEntry.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      LoggerService.error('Error fetching game by ID', error: e);
      return null;
    }
  }

  /// Delete a game record
  Future<bool> deleteGame(String gameId) async {
    if (_disposed || gameId.isEmpty) return false;

    // Remove from cache
    _cachedGames.removeWhere((g) => g.gameId == gameId);
    await _saveCachedGames();
    notifyListeners();

    final userId = _userId;
    if (userId == null) return true; // Already removed from cache

    final firestore = _firestoreInstance;
    if (firestore == null) return true; // Already removed from cache

    try {
      await firestore
          .collection('users')
          .doc(userId)
          .collection('game_history')
          .doc(gameId)
          .delete()
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Firestore delete timeout');
        },
      );
      return true;
    } catch (e) {
      LoggerService.error('Error deleting game', error: e);
      return false;
    }
  }

  /// Get statistics from game history
  Future<Map<String, dynamic>> getStatistics() async {
    if (_disposed) return {};

    final games = _cachedGames.isNotEmpty ? _cachedGames : await getGameHistory(limit: 1000);

    if (games.isEmpty) {
      return {
        'totalGames': 0,
        'totalScore': 0,
        'averageScore': 0.0,
        'highestScore': 0,
        'totalRounds': 0,
        'averageAccuracy': 0.0,
        'modeBreakdown': <String, int>{},
      };
    }

    final totalGames = games.length;
    final totalScore = games.fold<int>(0, (acc, g) => acc + g.score);
    final averageScore = totalScore / totalGames;
    final highestScore = games.map((g) => g.score).reduce((a, b) => a > b ? a : b);
    final totalRounds = games.fold<int>(0, (acc, g) => acc + g.rounds);
    final totalAccuracy = games.fold<double>(0.0, (acc, g) => acc + g.accuracy);
    final averageAccuracy = totalAccuracy / totalGames;

    final modeBreakdown = <String, int>{};
    for (final game in games) {
      final modeName = game.mode.toString().split('.').last;
      modeBreakdown[modeName] = (modeBreakdown[modeName] ?? 0) + 1;
    }

    return {
      'totalGames': totalGames,
      'totalScore': totalScore,
      'averageScore': averageScore,
      'highestScore': highestScore,
      'totalRounds': totalRounds,
      'averageAccuracy': averageAccuracy,
      'modeBreakdown': modeBreakdown,
    };
  }

  @override
  void dispose() {
    _disposed = true;
    _historySubscription?.cancel();
    _historySubscription = null;
    super.dispose();
  }
}

