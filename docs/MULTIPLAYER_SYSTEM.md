# Multiplayer System Documentation

## Overview

The multiplayer system enables real-time competitive gameplay between multiple players. It supports two game modes: **NERD BATTLE ROYALE** (versus) and **NERD SQUAD SHOWDOWN** (team-based).

## Architecture

### Core Components

1. **MultiplayerService** (`lib/services/multiplayer_service.dart`)
   - Main service for managing multiplayer game rooms
   - Handles room creation, joining, leaving, and game state management
   - Implements automatic reconnection on network restoration
   - Manages offline operation queuing

2. **MultiplayerRetryQueue** (`lib/services/multiplayer/multiplayer_retry_queue.dart`)
   - Persistent queue for failed multiplayer operations
   - Retries operations with exponential backoff
   - Survives app restarts via SharedPreferences

3. **RoomDiscoveryService** (`lib/services/room_discovery_service.dart`)
   - Enhanced room search and filtering
   - Room recommendations based on user preferences
   - Search by room code

4. **SpectatorService** (`lib/services/spectator_service.dart`)
   - Watch ongoing games without participating
   - Read-only access to room state
   - Real-time updates via Firestore snapshots

5. **GameRoom Model** (`lib/models/game_room.dart`)
   - Data structure for game rooms
   - Supports players, teams, spectators, and room state

## Features

### Room Management

- **Create Room**: Host creates a room with specified mode and player limit
- **Join Room**: Players can join available rooms or use room codes
- **Leave Room**: Players can leave at any time; host transfer is automatic
- **Room Discovery**: Search and filter available rooms
- **Friends-Only Rooms**: Restrict access to friends only

### Game Modes

#### NERD BATTLE ROYALE (Versus)
- Turn-based competition
- Players take turns answering questions
- Score tracking per player
- Submission tracking for each round

#### NERD SQUAD SHOWDOWN (Team)
- Team-based gameplay (2v2 or 3v3)
- Role assignments (Leader, Strategist, Analyst)
- Team score aggregation
- Ping system for coordination

### Offline Support

- **Automatic Retry Queue**: Failed operations are queued and retried when network is restored
- **Persistent Storage**: Queue survives app restarts
- **Exponential Backoff**: Retry delays increase with each attempt
- **Max Retries**: Operations are dropped after 3 failed attempts

### Security

- **Rate Limiting**: Answer submissions limited to 30 per minute
- **Input Sanitization**: All inputs are sanitized before processing
- **Server-Side Validation**: Score validation via Cloud Functions
- **Permission Checks**: Host-only operations are validated
- **Firestore Security Rules**: Defense-in-depth security model

### Error Handling

- **Comprehensive Error Types**: Specific exceptions for different error scenarios
- **Error Recovery**: User-friendly error messages with recovery suggestions
- **Crashlytics Integration**: All errors are reported for monitoring
- **Automatic Reconnection**: Network failures trigger automatic reconnection attempts

## Usage Examples

### Creating a Room

```dart
final multiplayerService = MultiplayerService();
await multiplayerService.init();

final room = await multiplayerService.createRoom(
  mode: MultiplayerMode.battleRoyale,
  maxPlayers: 4,
  friendsOnly: false,
);
```

### Joining a Room

```dart
final room = await multiplayerService.joinRoom(roomId);
```

### Submitting an Answer

```dart
await multiplayerService.submitRoundAnswer(
  score: 100,
  correctAnswers: 5,
  wrongAnswers: 2,
);
```

### Spectating a Game

```dart
final spectatorService = SpectatorService();
await spectatorService.init();

await spectatorService.joinAsSpectator(roomId);
```

## Data Flow

1. **Room Creation**: Host creates room → Firestore → Other players see room
2. **Joining**: Player joins → Firestore transaction → Room state updated
3. **Gameplay**: Player actions → Firestore → Real-time updates to all players
4. **Offline**: Operations queued → Network restored → Queue processed

## Performance Considerations

- **Caching**: Room state is cached locally
- **Pagination**: Room discovery supports pagination
- **Batch Operations**: Multiple updates use Firestore batches
- **Connection Monitoring**: Automatic detection of network issues

## Error Codes

- `MULTIPLAYER_001`: Rate limit exceeded
- `MULTIPLAYER_002`: Room not found
- `MULTIPLAYER_003`: Room is full
- `MULTIPLAYER_004`: Not a member of room
- `MULTIPLAYER_005`: Invalid score submission
- `MULTIPLAYER_006`: Score validation failed
- `MULTIPLAYER_007`: Host-only operation
- `MULTIPLAYER_008`: Not all players ready
- `MULTIPLAYER_009`: Reconnection failed
- `MULTIPLAYER_010`: Spectator limit reached

## Testing

See test files in `test/services/multiplayer/` for unit tests and integration tests.















