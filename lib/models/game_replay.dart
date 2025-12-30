import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:n3rd_game/models/game_mode_config.dart';

/// Game replay data structure
///
/// Stores game state snapshots, player actions, and timing information
/// for replaying game sessions.
class GameReplay { // Additional metadata

  GameReplay({
    required this.id,
    required this.userId,
    this.displayName,
    required this.gameMode,
    this.isMultiplayer = false,
    this.roomId,
    required this.createdAt,
    required this.gameStartedAt,
    this.gameFinishedAt,
    required this.finalScore,
    required this.totalRounds,
    List<ReplaySnapshot>? snapshots,
    List<ReplayAction>? actions,
    Map<String, dynamic>? metadata,
  })  : snapshots = snapshots ?? [],
        actions = actions ?? [],
        metadata = metadata ?? {};

  factory GameReplay.fromJson(Map<String, dynamic> json) => GameReplay(
        id: json['id'] as String,
        userId: json['userId'] as String,
        displayName: json['displayName'] as String?,
        gameMode: GameMode.values.firstWhere(
          (e) => e.name == json['gameMode'],
          orElse: () => GameMode.classic,
        ),
        isMultiplayer: json['isMultiplayer'] as bool? ?? false,
        roomId: json['roomId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        gameStartedAt: DateTime.parse(json['gameStartedAt'] as String),
        gameFinishedAt: json['gameFinishedAt'] != null
            ? DateTime.parse(json['gameFinishedAt'] as String)
            : null,
        finalScore: json['finalScore'] as int? ?? 0,
        totalRounds: json['totalRounds'] as int? ?? 0,
        snapshots: (json['snapshots'] as List<dynamic>?)
                ?.map((s) => ReplaySnapshot.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
        actions: (json['actions'] as List<dynamic>?)
                ?.map((a) => ReplayAction.fromJson(a as Map<String, dynamic>))
                .toList() ??
            [],
        metadata: json['metadata'] != null
            ? Map<String, dynamic>.from(json['metadata'])
            : {},
      );

  factory GameReplay.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GameReplay.fromJson({...data, 'id': doc.id});
  }
  final String id;
  final String userId;
  final String? displayName;
  final GameMode gameMode;
  final bool isMultiplayer;
  final String? roomId; // For multiplayer replays
  final DateTime createdAt;
  final DateTime gameStartedAt;
  final DateTime? gameFinishedAt;
  final int finalScore;
  final int totalRounds;
  final List<ReplaySnapshot> snapshots; // Game state snapshots
  final List<ReplayAction> actions; // Player actions
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'displayName': displayName,
        'gameMode': gameMode.name,
        'isMultiplayer': isMultiplayer,
        'roomId': roomId,
        'createdAt': createdAt.toIso8601String(),
        'gameStartedAt': gameStartedAt.toIso8601String(),
        'gameFinishedAt': gameFinishedAt?.toIso8601String(),
        'finalScore': finalScore,
        'totalRounds': totalRounds,
        'snapshots': snapshots.map((s) => s.toJson()).toList(),
        'actions': actions.map((a) => a.toJson()).toList(),
        'metadata': metadata,
      };

  GameReplay copyWith({
    String? id,
    String? userId,
    String? displayName,
    GameMode? gameMode,
    bool? isMultiplayer,
    String? roomId,
    DateTime? createdAt,
    DateTime? gameStartedAt,
    DateTime? gameFinishedAt,
    int? finalScore,
    int? totalRounds,
    List<ReplaySnapshot>? snapshots,
    List<ReplayAction>? actions,
    Map<String, dynamic>? metadata,
  }) {
    return GameReplay(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      gameMode: gameMode ?? this.gameMode,
      isMultiplayer: isMultiplayer ?? this.isMultiplayer,
      roomId: roomId ?? this.roomId,
      createdAt: createdAt ?? this.createdAt,
      gameStartedAt: gameStartedAt ?? this.gameStartedAt,
      gameFinishedAt: gameFinishedAt ?? this.gameFinishedAt,
      finalScore: finalScore ?? this.finalScore,
      totalRounds: totalRounds ?? this.totalRounds,
      snapshots: snapshots ?? this.snapshots,
      actions: actions ?? this.actions,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Game state snapshot at a specific point in time
class ReplaySnapshot { // Additional game state

  ReplaySnapshot({
    required this.round,
    required this.score,
    required this.lives,
    required this.timestamp,
    Map<String, dynamic>? state,
  }) : state = state ?? {};

  factory ReplaySnapshot.fromJson(Map<String, dynamic> json) => ReplaySnapshot(
        round: json['round'] as int? ?? 0,
        score: json['score'] as int? ?? 0,
        lives: json['lives'] as int? ?? 3,
        timestamp: DateTime.parse(json['timestamp'] as String),
        state: json['state'] != null
            ? Map<String, dynamic>.from(json['state'])
            : {},
      );
  final int round;
  final int score;
  final int lives;
  final DateTime timestamp;
  final Map<String, dynamic> state;

  Map<String, dynamic> toJson() => {
        'round': round,
        'score': score,
        'lives': lives,
        'timestamp': timestamp.toIso8601String(),
        'state': state,
      };
}

/// Player action during the game
class ReplayAction { // Action-specific data

  ReplayAction({
    required this.actionType,
    required this.round,
    required this.timestamp,
    Map<String, dynamic>? data,
  }) : data = data ?? {};

  factory ReplayAction.fromJson(Map<String, dynamic> json) => ReplayAction(
        actionType: json['actionType'] as String,
        round: json['round'] as int? ?? 0,
        timestamp: DateTime.parse(json['timestamp'] as String),
        data:
            json['data'] != null ? Map<String, dynamic>.from(json['data']) : {},
      );
  final String actionType; // e.g., 'select_word', 'submit_answer', 'use_hint'
  final int round;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() => {
        'actionType': actionType,
        'round': round,
        'timestamp': timestamp.toIso8601String(),
        'data': data,
      };
}













