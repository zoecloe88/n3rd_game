import 'package:cloud_firestore/cloud_firestore.dart';

enum RoomStatus {
  waiting, // Waiting for players
  starting, // Game is starting
  inProgress, // Game in progress
  finished, // Game finished
}

enum MultiplayerMode {
  battleRoyale, // NERD BATTLE ROYALE (Versus)
  squadShowdown, // NERD SQUAD SHOWDOWN (Team)
}

class Player {
  final String userId;
  final String email;
  final String? displayName;
  final int score;
  final int correctAnswers;
  final int wrongAnswers;
  final bool isReady;
  final DateTime? lastActive;
  final String? role; // Optional role for team members
  final DateTime? lastPing; // Last ping time

  Player({
    required this.userId,
    required this.email,
    this.displayName,
    this.score = 0,
    this.correctAnswers = 0,
    this.wrongAnswers = 0,
    this.isReady = false,
    this.lastActive,
    this.role,
    this.lastPing,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'email': email,
    'displayName': displayName,
    'score': score,
    'correctAnswers': correctAnswers,
    'wrongAnswers': wrongAnswers,
    'isReady': isReady,
    'lastActive': lastActive?.toIso8601String(),
    'role': role,
    'lastPing': lastPing?.toIso8601String(),
  };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
    userId: json['userId'] as String,
    email: json['email'] as String,
    displayName: json['displayName'] as String?,
    score: json['score'] as int? ?? 0,
    correctAnswers: json['correctAnswers'] as int? ?? 0,
    wrongAnswers: json['wrongAnswers'] as int? ?? 0,
    isReady: json['isReady'] as bool? ?? false,
    lastActive: json['lastActive'] != null
        ? DateTime.parse(json['lastActive'] as String)
        : null,
    role: json['role'] as String?,
    lastPing: json['lastPing'] != null
        ? DateTime.parse(json['lastPing'] as String)
        : null,
  );

  Player copyWith({
    String? userId,
    String? email,
    String? displayName,
    int? score,
    int? correctAnswers,
    int? wrongAnswers,
    bool? isReady,
    DateTime? lastActive,
    String? role,
    DateTime? lastPing,
  }) {
    return Player(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      score: score ?? this.score,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      wrongAnswers: wrongAnswers ?? this.wrongAnswers,
      isReady: isReady ?? this.isReady,
      lastActive: lastActive ?? this.lastActive,
      role: role ?? this.role,
      lastPing: lastPing ?? this.lastPing,
    );
  }
}

class Team {
  final String id;
  final String name;
  final List<Player> players;
  final int score;
  final String? role; // Optional role for team members

  Team({
    required this.id,
    required this.name,
    required this.players,
    this.score = 0,
    this.role,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'players': players.map((p) => p.toJson()).toList(),
    'score': score,
    'role': role,
  };

  factory Team.fromJson(Map<String, dynamic> json) => Team(
    id: json['id'] as String,
    name: json['name'] as String,
    players:
        (json['players'] as List<dynamic>?)
            ?.map((p) => Player.fromJson(p as Map<String, dynamic>))
            .toList() ??
        [],
    score: json['score'] as int? ?? 0,
    role: json['role'] as String?,
  );
}

class GameRoom {
  final String id;
  final String hostId;
  final MultiplayerMode mode;
  final RoomStatus status;
  final List<Player> players;
  final List<Team>? teams; // For squad showdown
  final int maxPlayers;
  final int currentRound;
  final int totalRounds;
  final String? selectedGameMode; // Classic, Speed, etc.
  final String? selectedDifficulty;
  final String? currentPlayerId; // Whose turn it is (for battle royale)
  final Map<String, bool>?
  playerSubmissions; // Track which players have submitted (battle royale)
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final DateTime? expiresAt; // For cleanup of abandoned rooms

  GameRoom({
    required this.id,
    required this.hostId,
    required this.mode,
    this.status = RoomStatus.waiting,
    List<Player>? players,
    this.teams,
    required this.maxPlayers,
    this.currentRound = 0,
    this.totalRounds = 12,
    this.selectedGameMode,
    this.selectedDifficulty,
    this.currentPlayerId,
    this.playerSubmissions,
    DateTime? createdAt,
    this.startedAt,
    this.finishedAt,
    DateTime? expiresAt,
  }) : players = players ?? [],
       createdAt = createdAt ?? DateTime.now(),
       expiresAt =
           expiresAt ??
           (createdAt ?? DateTime.now()).add(const Duration(hours: 1));

  Map<String, dynamic> toJson() => {
    'id': id,
    'hostId': hostId,
    'mode': mode.name,
    'status': status.name,
    'players': players.map((p) => p.toJson()).toList(),
    'teams': teams?.map((t) => t.toJson()).toList(),
    'maxPlayers': maxPlayers,
    'currentRound': currentRound,
    'totalRounds': totalRounds,
    'selectedGameMode': selectedGameMode,
    'selectedDifficulty': selectedDifficulty,
    'currentPlayerId': currentPlayerId,
    'playerSubmissions': playerSubmissions,
    'createdAt': createdAt.toIso8601String(),
    'startedAt': startedAt?.toIso8601String(),
    'finishedAt': finishedAt?.toIso8601String(),
    'expiresAt': expiresAt?.toIso8601String(),
  };

  factory GameRoom.fromJson(Map<String, dynamic> json) => GameRoom(
    id: json['id'] as String,
    hostId: json['hostId'] as String,
    mode: MultiplayerMode.values.firstWhere(
      (e) => e.name == json['mode'],
      orElse: () => MultiplayerMode.battleRoyale,
    ),
    status: RoomStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => RoomStatus.waiting,
    ),
    players:
        (json['players'] as List<dynamic>?)
            ?.map((p) => Player.fromJson(p as Map<String, dynamic>))
            .toList() ??
        [],
    teams: (json['teams'] as List<dynamic>?)
        ?.map((t) => Team.fromJson(t as Map<String, dynamic>))
        .toList(),
    maxPlayers: json['maxPlayers'] as int? ?? 2,
    currentRound: json['currentRound'] as int? ?? 0,
    totalRounds: json['totalRounds'] as int? ?? 12,
    selectedGameMode: json['selectedGameMode'] as String?,
    selectedDifficulty: json['selectedDifficulty'] as String?,
    currentPlayerId: json['currentPlayerId'] as String?,
    playerSubmissions: json['playerSubmissions'] != null
        ? Map<String, bool>.from(json['playerSubmissions'] as Map)
        : null,
    createdAt: DateTime.parse(json['createdAt'] as String),
    startedAt: json['startedAt'] != null
        ? DateTime.parse(json['startedAt'] as String)
        : null,
    finishedAt: json['finishedAt'] != null
        ? DateTime.parse(json['finishedAt'] as String)
        : null,
  );

  factory GameRoom.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GameRoom.fromJson({...data, 'id': doc.id});
  }

  GameRoom copyWith({
    String? id,
    String? hostId,
    MultiplayerMode? mode,
    RoomStatus? status,
    List<Player>? players,
    List<Team>? teams,
    int? maxPlayers,
    int? currentRound,
    int? totalRounds,
    String? selectedGameMode,
    String? selectedDifficulty,
    String? currentPlayerId,
    Map<String, bool>? playerSubmissions,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? finishedAt,
    DateTime? expiresAt,
  }) {
    return GameRoom(
      id: id ?? this.id,
      hostId: hostId ?? this.hostId,
      mode: mode ?? this.mode,
      status: status ?? this.status,
      players: players ?? this.players,
      teams: teams ?? this.teams,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      currentRound: currentRound ?? this.currentRound,
      totalRounds: totalRounds ?? this.totalRounds,
      selectedGameMode: selectedGameMode ?? this.selectedGameMode,
      selectedDifficulty: selectedDifficulty ?? this.selectedDifficulty,
      currentPlayerId: currentPlayerId ?? this.currentPlayerId,
      playerSubmissions: playerSubmissions ?? this.playerSubmissions,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  bool get isFull => players.length >= maxPlayers;
  bool get canStart => players.length >= 2 && players.every((p) => p.isReady);
  Player? get currentPlayer => players.firstWhere(
    (p) => p.userId == currentPlayerId,
    orElse: () => players.first,
  );
}
