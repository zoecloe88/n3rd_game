# Leaderboard System Documentation

## Overview

The leaderboard system provides competitive rankings for all game modes with support for multiple timeframes (daily, weekly, monthly, all-time) and friend comparisons.

## Architecture

### Core Components

1. **GlobalLeaderboardService** (`lib/services/global_leaderboard_service.dart`)
   - Main service for global leaderboards
   - Supports all game modes
   - Multiple timeframes
   - Friend comparisons

2. **DailyChallengeLeaderboardService** (`lib/services/daily_challenge_leaderboard_service.dart`)
   - Specialized service for daily challenge leaderboards
   - Attempt tracking
   - Score improvement validation

3. **LeaderboardRepository** (`lib/services/leaderboard/leaderboard_repository.dart`)
   - Abstract interface for leaderboard operations
   - Supports pagination

4. **FirestoreLeaderboardRepository** (`lib/services/leaderboard/firestore_leaderboard_repository.dart`)
   - Firestore implementation
   - Efficient queries with indexes
   - Batch operations

## Features

### Global Leaderboards

- **All Game Modes**: Leaderboards for every game mode (classic, timeAttack, streak, etc.)
- **Timeframes**: Daily, weekly, monthly, and all-time rankings
- **Pagination**: Efficient loading of large leaderboards
- **Caching**: 5-minute cache for performance

### Daily Challenge Leaderboards

- **Attempt Tracking**: Maximum 5 attempts per challenge
- **Score Improvement**: Only improved scores are accepted
- **Pagination**: Support for large leaderboards
- **Retry Queue**: Failed submissions are queued for retry

### Friend Leaderboards

- **Friend Comparisons**: Compare scores with friends only
- **Ranking**: See your rank among friends
- **Filtering**: Filter leaderboards by friend list

## Usage Examples

### Submitting a Score

```dart
final leaderboardService = GlobalLeaderboardService();
await leaderboardService.init();

await leaderboardService.submitScore(
  score: 1500,
  gameMode: GameMode.timeAttack,
  timeframe: LeaderboardTimeframe.allTime,
);
```

### Getting Leaderboard

```dart
final result = await leaderboardService.getLeaderboard(
  gameMode: GameMode.classic,
  timeframe: LeaderboardTimeframe.weekly,
  pageSize: 20,
  startAfter: lastDocument, // For pagination
);
```

### Getting User Rank

```dart
final rank = await leaderboardService.getUserRank(
  gameMode: GameMode.streak,
  timeframe: LeaderboardTimeframe.monthly,
);
```

### Friend Leaderboard

```dart
final friends = await friendsService.getFriends();
final friendIds = friends.map((f) => f.userId).toList();

final friendLeaderboard = await leaderboardService.getFriendsLeaderboard(
  friendUserIds: friendIds,
  gameMode: GameMode.classic,
  timeframe: LeaderboardTimeframe.allTime,
);
```

## Data Structure

### Firestore Collections

- `global_leaderboards/{gameMode}/{timeframe}/scores/{userId}`: Global leaderboard scores
- `daily_challenge_leaderboard/{dateKey}/{challengeId}/scores/{userId}`: Daily challenge scores
- `daily_challenge_leaderboard/{dateKey}/{challengeId}/attempts/{attemptId}`: Attempt tracking

## Performance

- **Pagination**: Limits data transfer
- **Caching**: Reduces Firestore queries
- **Indexes**: Composite indexes for efficient queries
- **Batch Operations**: Multiple updates in single transaction

## Security

- **Score Validation**: Server-side validation via Cloud Functions
- **Rate Limiting**: Prevents abuse
- **Input Sanitization**: All inputs are sanitized

## Error Handling

- **Network Errors**: Automatic retry with exponential backoff
- **Validation Errors**: Clear error messages
- **Rate Limiting**: User-friendly rate limit messages















