import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:n3rd_game/services/friends_service.dart';
import 'package:n3rd_game/services/stats/stats_repository.dart';
import 'package:n3rd_game/services/stats/firestore_stats_repository.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/exceptions/error_codes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for friend score comparison
///
/// Represents a friend's score with ranking information for display
/// in the friend scores section.
class FriendScore {

  FriendScore({
    required this.userId,
    this.displayName,
    this.email,
    required this.score,
    required this.rank,
  });
  final String userId;
  final String? displayName;
  final String? email;
  final int score;
  final int rank;
}

/// Service for fetching and comparing friend scores
///
/// Provides functionality to fetch friend scores from the `user_stats` collection,
/// compare them with the current user's score, and display rankings.
///
/// **Features:**
/// - Fetches highest scores for all friends
/// - Calculates rankings with tie handling
/// - Caches scores for 5 minutes
/// - Provides top N friends by score
///
/// **Usage:**
/// ```dart
/// final service = FriendScoreService();
/// final scores = await service.getFriendScores();
/// final topFriends = await service.getTopFriends(limit: 5);
/// ```
///
/// **Caching:**
/// Scores are cached for 5 minutes to reduce Firestore queries.
/// Call `invalidateCache()` to force a refresh.
class FriendScoreService extends ChangeNotifier {
  /// Default constructor
  FriendScoreService()
      : _friendsService = FriendsService();

  /// Private constructor for dependency injection
  FriendScoreService.private({
    required StatsRepository statsRepository,
    required FriendsService friendsService,
  })  : _statsRepository = statsRepository,
        _friendsService = friendsService;

  FirebaseFirestore? _firestore;
  StatsRepository? _statsRepository;
  final FriendsService _friendsService;

  /// Get Firestore instance if Firebase is available
  FirebaseFirestore? get _firestoreInstance {
    if (_firestore != null) return _firestore;
    try {
      Firebase.app(); // Check if Firebase is initialized
      _firestore = FirebaseFirestore.instance;
      return _firestore;
    } catch (e) {
      LoggerService.debug('Firebase not available for FriendScoreService', error: e);
      return null;
    }
  }

  /// Get stats repository, initializing it lazily if needed
  StatsRepository get _statsRepo {
    if (_statsRepository != null) return _statsRepository!;
    final firestore = _firestoreInstance;
    if (firestore == null) {
      throw NetworkException(
        'Firebase not available',
        errorCode: ErrorCode.networkServerError,
      );
    }
    _statsRepository = FirestoreStatsRepository(firestore);
    return _statsRepository!;
  }

  // Caching
  Map<String, FriendScore>? _friendScoresCache;
  DateTime? _cacheTimestamp;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String? get _userId {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (e) {
      return null;
    }
  }

  /// Get friend scores with comparison to current user
  Future<List<FriendScore>> getFriendScores() async {
    final userId = _userId;
    if (userId == null) {
      throw AuthenticationException(
        'User not authenticated',
        errorCode: ErrorCode.authUserNotFound,
      );
    }

    // Check cache
    if (_friendScoresCache != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheExpiry) {
      return _friendScoresCache!.values.toList()
        ..sort((a, b) => b.score.compareTo(a.score));
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Get current user's friends
      final friends = _friendsService.friends;
      if (friends.isEmpty) {
        _friendScoresCache = {};
        _cacheTimestamp = DateTime.now();
        _isLoading = false;
        notifyListeners();
        return [];
      }

      // Get friend user IDs
      final friendIds = friends.map((f) => f.userId).toList();

      // Fetch scores for all friends
      final scoresMap = await _statsRepo.getFriendScores(friendIds);

      // Get current user's score for comparison
      final currentUserScore =
          await _statsRepo.getHighestScore(userId) ?? 0;

      // Build friend scores list
      final friendScores = <FriendScore>[];
      final allScores = <int>[];

      // Add current user score
      allScores.add(currentUserScore);

      for (final friend in friends) {
        final score = scoresMap[friend.userId] ?? 0;
        allScores.add(score);
      }

      // Sort scores to determine ranks (descending)
      allScores.sort((a, b) => b.compareTo(a));

      // Create FriendScore objects with ranks
      for (final friend in friends) {
        final score = scoresMap[friend.userId] ?? 0;
        // Find rank (handle ties - same score gets same rank)
        // Count how many scores are higher than this score
        int rank = 1;
        for (final s in allScores) {
          if (s > score) {
            rank++;
          } else {
            break; // Since scores are sorted descending
          }
        }
        friendScores.add(
          FriendScore(
            userId: friend.userId,
            displayName: friend.displayName,
            email: friend.email,
            score: score,
            rank: rank,
          ),
        );
      }

      // Sort by score descending
      friendScores.sort((a, b) => b.score.compareTo(a.score));

      // Cache results
      _friendScoresCache = {
        for (final fs in friendScores) fs.userId: fs,
      };
      _cacheTimestamp = DateTime.now();

      _isLoading = false;
      notifyListeners();
      return friendScores;
    } on AuthenticationException {
      rethrow;
    } on NetworkException {
      rethrow;
    } on StorageException {
      rethrow;
    } catch (e, stack) {
      LoggerService.error(
        'FriendScoreService: Error getting friend scores',
        error: e,
        stack: stack,
      );
      _errorMessage = 'Failed to load friend scores';
      _isLoading = false;
      notifyListeners();
      throw NetworkException(
        'Failed to get friend scores',
        errorCode: ErrorCode.storageReadFailed,
        recoverySuggestion: 'Please check your connection and try again.',
      );
    }
  }

  /// Get current user's score
  Future<int?> getCurrentUserScore() async {
    final userId = _userId;
    if (userId == null) {
      return null;
    }

    try {
      return await _statsRepo.getHighestScore(userId);
    } catch (e) {
      LoggerService.error(
        'FriendScoreService: Error getting current user score',
        error: e,
      );
      return null;
    }
  }

  /// Invalidate cache
  void invalidateCache() {
    _friendScoresCache = null;
    _cacheTimestamp = null;
    notifyListeners();
  }

  /// Get top N friends by score
  Future<List<FriendScore>> getTopFriends({int limit = 5}) async {
    final allScores = await getFriendScores();
    return allScores.take(limit).toList();
  }
}
