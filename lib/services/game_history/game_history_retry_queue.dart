import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/models/game_history_entry.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Persistent retry queue for failed game history saves
///
/// Queues failed Firestore saves and retries them in the background.
/// Persists queue to SharedPreferences for reliability across app restarts.
class GameHistoryRetryQueue {
  static const String _storageKey = 'game_history_retry_queue';
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 5);
  static const Duration _maxRetryAge = Duration(days: 7);

  final List<_QueuedGame> _queue = [];
  Timer? _retryTimer;
  bool _isProcessing = false;

  /// Add a game to the retry queue
  Future<void> enqueue(GameHistoryEntry game) async {
    final queuedGame = _QueuedGame(
      game: game,
      attempts: 0,
      firstAttempt: DateTime.now(),
    );

    _queue.add(queuedGame);
    await _persistQueue();
    _scheduleRetry();
  }

  /// Process the retry queue
  ///
  /// [saveFunction] - Function to call for each game save
  Future<void> processQueue(
    Future<void> Function(String userId, GameHistoryEntry game) saveFunction,
    String userId,
  ) async {
    if (_isProcessing || _queue.isEmpty) return;

    _isProcessing = true;

    try {
      final now = DateTime.now();
      final gamesToRetry = <_QueuedGame>[];

      // Collect games that need retrying
      for (final queuedGame in _queue) {
        // Remove old entries
        if (now.difference(queuedGame.firstAttempt) > _maxRetryAge) {
          LoggerService.warning(
            'Removing old queued game from retry queue: ${queuedGame.game.gameId}',
          );
          continue;
        }

        // Skip if max retries reached
        if (queuedGame.attempts >= _maxRetries) {
          LoggerService.warning(
            'Max retries reached for game: ${queuedGame.game.gameId}',
          );
          continue;
        }

        gamesToRetry.add(queuedGame);
      }

      // Remove processed/expired games
      _queue.removeWhere((q) => !gamesToRetry.contains(q));

      // Retry each game
      for (final queuedGame in gamesToRetry) {
        try {
          await saveFunction(userId, queuedGame.game);

          // Success - remove from queue
          _queue.remove(queuedGame);
          LoggerService.info(
            'Successfully saved queued game: ${queuedGame.game.gameId}',
          );
        } catch (e) {
          // Failed - increment attempts
          queuedGame.attempts++;
          LoggerService.warning(
            'Retry failed for game ${queuedGame.game.gameId} (attempt ${queuedGame.attempts}/$_maxRetries);',
            error: e,
          );
        }
      }

      await _persistQueue();
    } finally {
      _isProcessing = false;
    }
  }

  /// Schedule next retry
  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(_retryDelay, () {
      // Retry will be triggered by service when it calls processQueue
    });
  }

  /// Load queue from SharedPreferences
  Future<void> loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        final queueList = json['queue'] as List<dynamic>?;
        if (queueList != null) {
          _queue.clear();
          for (final item in queueList) {
            final map = item as Map<String, dynamic>;
            _queue.add(_QueuedGame.fromJson(map));
          }
        }
      }
    } catch (e) {
      LoggerService.error('Failed to load retry queue', error: e);
      _queue.clear();
    }
  }

  /// Persist queue to SharedPreferences
  Future<void> _persistQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = {
        'queue': _queue.map((q) => q.toJson()).toList(),
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_storageKey, jsonEncode(json));
    } catch (e) {
      LoggerService.error('Failed to persist retry queue', error: e);
    }
  }

  /// Get queue size
  int get queueSize => _queue.length;

  /// Clear the queue
  Future<void> clear() async {
    _queue.clear();
    await _persistQueue();
  }

  /// Dispose resources
  void dispose() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }
}

/// Internal class for queued games
class _QueuedGame {

  _QueuedGame({
    required this.game,
    required this.attempts,
    required this.firstAttempt,
  });

  factory _QueuedGame.fromJson(Map<String, dynamic> json) {
    return _QueuedGame(
      game: GameHistoryEntry.fromJson(json['game'] as Map<String, dynamic>),
      attempts: json['attempts'] as int,
      firstAttempt: DateTime.parse(json['firstAttempt'] as String),
    );
  }
  final GameHistoryEntry game;
  int attempts;
  final DateTime firstAttempt;

  Map<String, dynamic> toJson() {
    return {
      'game': game.toJson(),
      'attempts': attempts,
      'firstAttempt': firstAttempt.toIso8601String(),
    };
  }
}
