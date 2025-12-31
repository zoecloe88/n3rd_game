import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:n3rd_game/services/friends_service.dart';
import 'package:n3rd_game/services/friend_score_service.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';

/// ViewModel for FriendsMoreScreen
///
/// Manages the UI state, interacts with FriendsService and FriendScoreService,
/// handles loading/error states, and debounces operations.
class FriendsMoreViewModel extends ChangeNotifier {

  FriendsMoreViewModel({
    FriendsService? friendsService,
    FriendScoreService? friendScoreService,
  })  : _friendsService = friendsService ?? FriendsService(),
        _friendScoreService = friendScoreService ?? FriendScoreService() {
    _loadFriendScores();
  }
  final FriendsService _friendsService;
  final FriendScoreService _friendScoreService;

  // State
  bool _isLoading = false;
  bool _isLoadingScores = false;
  String? _errorMessage;
  String? _scoresErrorMessage;
  List<FriendScore> _friendScores = [];
  int? _currentUserScore;

  // Debouncing
  Timer? _searchDebounceTimer;
  static const Duration _searchDebounceDelay = Duration(milliseconds: 500);

  bool get isLoading => _isLoading;
  bool get isLoadingScores => _isLoadingScores;
  String? get errorMessage => _errorMessage;
  String? get scoresErrorMessage => _scoresErrorMessage;
  List<FriendScore> get friendScores => List.unmodifiable(_friendScores);
  int? get currentUserScore => _currentUserScore;

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  /// Load friend scores
  Future<void> _loadFriendScores() async {
    _isLoadingScores = true;
    _scoresErrorMessage = null;
    notifyListeners();

    try {
      final scores = await _friendScoreService.getFriendScores();
      _friendScores = scores;
      _currentUserScore = await _friendScoreService.getCurrentUserScore();
    } on AuthenticationException catch (e) {
      _scoresErrorMessage = 'Please sign in to view friend scores';
      LoggerService.error(
        'FriendsMoreViewModel: Authentication error loading scores',
        error: e,
      );
    } on NetworkException catch (e) {
      _scoresErrorMessage =
          e.recoverySuggestion ?? 'Failed to load friend scores';
      LoggerService.error(
        'FriendsMoreViewModel: Network error loading scores',
        error: e,
      );
    } catch (e, stack) {
      _scoresErrorMessage = 'An unexpected error occurred';
      LoggerService.error(
        'FriendsMoreViewModel: Error loading friend scores',
        error: e,
        stack: stack,
      );
    } finally {
      _isLoadingScores = false;
      notifyListeners();
    }
  }

  /// Refresh friend scores
  Future<void> refreshFriendScores() async {
    _friendScoreService.invalidateCache();
    await _loadFriendScores();
  }

  /// Search users with debouncing
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.isEmpty) return [];

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await _friendsService.searchUsers(query);
      _isLoading = false;
      notifyListeners();
      return results;
    } on ValidationException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return [];
    } on NetworkException catch (e) {
      _errorMessage = e.recoverySuggestion ?? e.message;
      _isLoading = false;
      notifyListeners();
      return [];
    } catch (e, stack) {
      _errorMessage = 'An unexpected error occurred';
      LoggerService.error(
        'FriendsMoreViewModel: Error searching users',
        error: e,
        stack: stack,
      );
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  /// Debounced search
  void debounceSearch(
      String query, Function(List<Map<String, dynamic>>) onResults,) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(_searchDebounceDelay, () async {
      final results = await searchUsers(query);
      onResults(results);
    });
  }

  /// Send friend request
  Future<bool> sendFriendRequest(
    String friendUserId, {
    String? friendEmail,
    String? friendDisplayName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _friendsService.sendFriendRequest(
        friendUserId,
        friendEmail: friendEmail,
        friendDisplayName: friendDisplayName,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } on ValidationException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } on NetworkException catch (e) {
      _errorMessage = e.recoverySuggestion ?? e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e, stack) {
      _errorMessage = 'An unexpected error occurred';
      LoggerService.error(
        'FriendsMoreViewModel: Error sending friend request',
        error: e,
        stack: stack,
      );
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Get friend suggestions
  Future<List<Map<String, dynamic>>> getFriendSuggestions() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final suggestions = await _friendsService.getFriendSuggestions();
      _isLoading = false;
      notifyListeners();
      return suggestions;
    } catch (e, stack) {
      _errorMessage = 'Failed to load suggestions';
      LoggerService.error(
        'FriendsMoreViewModel: Error getting friend suggestions',
        error: e,
        stack: stack,
      );
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  /// Send invitation
  Future<bool> sendInvitation(String? email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _friendsService.sendInvitation(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ValidationException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } on NetworkException catch (e) {
      _errorMessage = e.recoverySuggestion ?? e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e, stack) {
      _errorMessage = 'An unexpected error occurred';
      LoggerService.error(
        'FriendsMoreViewModel: Error sending invitation',
        error: e,
        stack: stack,
      );
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Block user
  Future<bool> blockUser(String userIdToBlock) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _friendsService.blockUser(userIdToBlock);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ValidationException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } on NetworkException catch (e) {
      _errorMessage = e.recoverySuggestion ?? e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e, stack) {
      _errorMessage = 'An unexpected error occurred';
      LoggerService.error(
        'FriendsMoreViewModel: Error blocking user',
        error: e,
        stack: stack,
      );
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Report user
  Future<bool> reportUser(String reportedUserId, String reason) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _friendsService.reportUser(reportedUserId, reason);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ValidationException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } on NetworkException catch (e) {
      _errorMessage = e.recoverySuggestion ?? e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e, stack) {
      _errorMessage = 'An unexpected error occurred';
      LoggerService.error(
        'FriendsMoreViewModel: Error reporting user',
        error: e,
        stack: stack,
      );
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
