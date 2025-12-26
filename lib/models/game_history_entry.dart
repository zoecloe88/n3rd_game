import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:n3rd_game/services/game_service.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Represents a single game history entry
///
/// This model stores complete information about a finished game session,
/// including all metrics, performance data, and trivia categories used.
class GameHistoryEntry {
  /// Unique game ID (Firestore document ID)
  final String gameId;

  /// Timestamp when the game was completed
  final DateTime completedAt;

  /// Game mode played
  final GameMode mode;

  /// Difficulty level (if applicable)
  final String? difficulty;

  /// Final score achieved
  final int score;

  /// Number of rounds completed
  final int rounds;

  /// Number of correct answers
  final int correctAnswers;

  /// Number of wrong answers
  final int wrongAnswers;

  /// Game duration in seconds
  final int durationSeconds;

  /// Accuracy percentage (0-100)
  final double accuracy;

  /// Perfect streak achieved
  final int perfectStreak;

  /// Lives remaining at game end
  final int livesRemaining;

  /// Trivia categories used in this game
  final List<String> triviaCategories;

  /// Whether this was a multiplayer game
  final bool isMultiplayer;

  /// Room ID if multiplayer
  final String? roomId;

  /// Whether the game was won (for modes with win conditions)
  final bool? isWon;

  /// Additional performance metrics
  final Map<String, dynamic>? additionalMetrics;

  GameHistoryEntry({
    required this.gameId,
    required this.completedAt,
    required this.mode,
    this.difficulty,
    required this.score,
    required this.rounds,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.durationSeconds,
    required this.accuracy,
    this.perfectStreak = 0,
    this.livesRemaining = 0,
    this.triviaCategories = const [],
    this.isMultiplayer = false,
    this.roomId,
    this.isWon,
    this.additionalMetrics,
  });

  /// Create from Firestore document
  factory GameHistoryEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Parse GameMode from string
    GameMode mode;
    try {
      mode = GameMode.values.firstWhere(
        (m) => m.toString().split('.').last == data['mode'],
      );
    } catch (e) {
      LoggerService.warning(
        'Failed to parse GameMode: ${data['mode']}, defaulting to classic',
        error: e,
      );
      mode = GameMode.classic;
    }

    // Parse completedAt timestamp
    DateTime completedAt;
    try {
      if (data['completedAt'] is Timestamp) {
        completedAt = (data['completedAt'] as Timestamp).toDate();
      } else if (data['completedAt'] is String) {
        completedAt = DateTime.parse(data['completedAt'] as String);
      } else {
        completedAt = DateTime.now();
      }
    } catch (e) {
      LoggerService.warning(
        'Failed to parse completedAt timestamp, using current time',
        error: e,
      );
      completedAt = DateTime.now();
    }

    return GameHistoryEntry(
      gameId: doc.id,
      completedAt: completedAt,
      mode: mode,
      difficulty: data['difficulty'] as String?,
      score: (data['score'] as int?) ?? 0,
      rounds: (data['rounds'] as int?) ?? 0,
      correctAnswers: (data['correctAnswers'] as int?) ?? 0,
      wrongAnswers: (data['wrongAnswers'] as int?) ?? 0,
      durationSeconds: (data['durationSeconds'] as int?) ?? 0,
      accuracy: (data['accuracy'] as num?)?.toDouble() ?? 0.0,
      perfectStreak: (data['perfectStreak'] as int?) ?? 0,
      livesRemaining: (data['livesRemaining'] as int?) ?? 0,
      triviaCategories: List<String>.from(data['triviaCategories'] ?? []),
      isMultiplayer: (data['isMultiplayer'] as bool?) ?? false,
      roomId: data['roomId'] as String?,
      isWon: data['isWon'] as bool?,
      additionalMetrics: data['additionalMetrics'] as Map<String, dynamic>?,
    );
  }

  /// Convert to Firestore-compatible map
  Map<String, dynamic> toFirestore() {
    return {
      'completedAt': Timestamp.fromDate(completedAt),
      'mode': mode.toString().split('.').last,
      if (difficulty != null) 'difficulty': difficulty,
      'score': score,
      'rounds': rounds,
      'correctAnswers': correctAnswers,
      'wrongAnswers': wrongAnswers,
      'durationSeconds': durationSeconds,
      'accuracy': accuracy,
      'perfectStreak': perfectStreak,
      'livesRemaining': livesRemaining,
      'triviaCategories': triviaCategories,
      'isMultiplayer': isMultiplayer,
      if (roomId != null) 'roomId': roomId,
      if (isWon != null) 'isWon': isWon,
      if (additionalMetrics != null) 'additionalMetrics': additionalMetrics,
    };
  }

  /// Convert to JSON for local storage
  Map<String, dynamic> toJson() {
    return {
      'gameId': gameId,
      'completedAt': completedAt.toIso8601String(),
      'mode': mode.toString().split('.').last,
      if (difficulty != null) 'difficulty': difficulty,
      'score': score,
      'rounds': rounds,
      'correctAnswers': correctAnswers,
      'wrongAnswers': wrongAnswers,
      'durationSeconds': durationSeconds,
      'accuracy': accuracy,
      'perfectStreak': perfectStreak,
      'livesRemaining': livesRemaining,
      'triviaCategories': triviaCategories,
      'isMultiplayer': isMultiplayer,
      if (roomId != null) 'roomId': roomId,
      if (isWon != null) 'isWon': isWon,
      if (additionalMetrics != null) 'additionalMetrics': additionalMetrics,
    };
  }

  /// Create from JSON (for local storage)
  factory GameHistoryEntry.fromJson(Map<String, dynamic> json) {
    // Parse GameMode from string
    GameMode mode;
    try {
      mode = GameMode.values.firstWhere(
        (m) => m.toString().split('.').last == json['mode'],
      );
    } catch (e) {
      LoggerService.warning(
        'Failed to parse GameMode: ${json['mode']}, defaulting to classic',
        error: e,
      );
      mode = GameMode.classic;
    }

    // Parse completedAt timestamp
    DateTime completedAt;
    try {
      completedAt = DateTime.parse(json['completedAt'] as String);
    } catch (e) {
      LoggerService.warning(
        'Failed to parse completedAt timestamp, using current time',
        error: e,
      );
      completedAt = DateTime.now();
    }

    return GameHistoryEntry(
      gameId: json['gameId'] as String,
      completedAt: completedAt,
      mode: mode,
      difficulty: json['difficulty'] as String?,
      score: (json['score'] as int?) ?? 0,
      rounds: (json['rounds'] as int?) ?? 0,
      correctAnswers: (json['correctAnswers'] as int?) ?? 0,
      wrongAnswers: (json['wrongAnswers'] as int?) ?? 0,
      durationSeconds: (json['durationSeconds'] as int?) ?? 0,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0.0,
      perfectStreak: (json['perfectStreak'] as int?) ?? 0,
      livesRemaining: (json['livesRemaining'] as int?) ?? 0,
      triviaCategories: List<String>.from(json['triviaCategories'] ?? []),
      isMultiplayer: (json['isMultiplayer'] as bool?) ?? false,
      roomId: json['roomId'] as String?,
      isWon: json['isWon'] as bool?,
      additionalMetrics: json['additionalMetrics'] as Map<String, dynamic>?,
    );
  }

  /// Create a copy with updated values
  GameHistoryEntry copyWith({
    String? gameId,
    DateTime? completedAt,
    GameMode? mode,
    String? difficulty,
    int? score,
    int? rounds,
    int? correctAnswers,
    int? wrongAnswers,
    int? durationSeconds,
    double? accuracy,
    int? perfectStreak,
    int? livesRemaining,
    List<String>? triviaCategories,
    bool? isMultiplayer,
    String? roomId,
    bool? isWon,
    Map<String, dynamic>? additionalMetrics,
  }) {
    return GameHistoryEntry(
      gameId: gameId ?? this.gameId,
      completedAt: completedAt ?? this.completedAt,
      mode: mode ?? this.mode,
      difficulty: difficulty ?? this.difficulty,
      score: score ?? this.score,
      rounds: rounds ?? this.rounds,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      wrongAnswers: wrongAnswers ?? this.wrongAnswers,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      accuracy: accuracy ?? this.accuracy,
      perfectStreak: perfectStreak ?? this.perfectStreak,
      livesRemaining: livesRemaining ?? this.livesRemaining,
      triviaCategories: triviaCategories ?? this.triviaCategories,
      isMultiplayer: isMultiplayer ?? this.isMultiplayer,
      roomId: roomId ?? this.roomId,
      isWon: isWon ?? this.isWon,
      additionalMetrics: additionalMetrics ?? this.additionalMetrics,
    );
  }
}


