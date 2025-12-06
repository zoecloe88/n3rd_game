# API Documentation

This document provides API documentation for public service methods in the N3RD Game application.

## Table of Contents

- [GameService](#gameservice)
- [AnalyticsService](#analyticsservice)
- [NetworkService](#networkservice)
- [MultiplayerService](#multiplayerservice)
- [SubscriptionService](#subscriptionservice)

---

## GameService

Core game logic and state management service.

### Methods

#### `void startNewRound(List<TriviaItem> triviaPool, {GameMode? mode, String? difficulty, int recursionDepth = 0})`

Starts a new game round with the provided trivia pool.

**Parameters:**
- `triviaPool` (required): List of trivia items for the round
- `mode` (optional): Game mode to use (defaults to current mode)
- `difficulty` (optional): Difficulty level for shuffle mode
- `recursionDepth` (optional): Internal parameter for recursive calls

**Throws:**
- `GameException`: If trivia pool is invalid or round cannot be started

**Example:**
```dart
final triviaPool = gameService.generateTriviaPool(triviaGenerator);
gameService.startNewRound(triviaPool, mode: GameMode.classic);
```

#### `Future<void> loadState()`

Loads game state from persistent storage. Automatically resumes gameplay if state exists.

**Throws:**
- `StorageException`: If state loading fails critically

**Performance:**
- Tracked via `AnalyticsService.logGameStateLoad()`

**Example:**
```dart
await gameService.loadState();
```

#### `void toggleTileSelection(String word)`

Toggles selection of a word tile during play phase.

**Parameters:**
- `word` (required): The word to toggle selection for

**Behavior:**
- Only works during `GamePhase.play`
- Handles special modes (Flip, Precision) with mode-specific logic
- Updates UI via `notifyListeners()`

**Example:**
```dart
gameService.toggleTileSelection('example');
```

#### `void revealWord(String word)`

Reveals a word tile (double-tap functionality).

**Parameters:**
- `word` (required): The word to reveal

**Behavior:**
- Only works during `GamePhase.play`
- Validates word exists in current trivia
- Updates UI via `notifyListeners()`

**Example:**
```dart
gameService.revealWord('example');
```

#### `List<TriviaItem> generateTriviaPool(TriviaGeneratorService generator, {String? theme, int count = 50, bool usePersonalization = true})`

Generates a pool of trivia items for gameplay.

**Parameters:**
- `generator` (required): Trivia generator service instance
- `theme` (optional): Theme filter for trivia selection
- `count` (optional): Number of items to generate (default: 50)
- `usePersonalization` (optional): Whether to use personalization (default: true)

**Returns:**
- `List<TriviaItem>`: Generated trivia pool

**Throws:**
- `GameException`: If generation fails

**Example:**
```dart
final pool = gameService.generateTriviaPool(
  triviaGenerator,
  theme: 'science',
  count: 100,
);
```

---

## AnalyticsService

Analytics and performance tracking service.

### Methods

#### `Future<void> logPerformanceMetric({required String metricName, required Duration duration, Map<String, dynamic>? additionalParams, bool success = true})`

Logs a generic performance metric.

**Parameters:**
- `metricName` (required): Name of the metric
- `duration` (required): Duration of the operation
- `additionalParams` (optional): Additional parameters to log
- `success` (optional): Whether operation succeeded (default: true)

**Example:**
```dart
await analyticsService.logPerformanceMetric(
  metricName: 'custom_operation',
  duration: Duration(milliseconds: 150),
  additionalParams: {'operation_type': 'data_processing'},
);
```

#### `Future<void> logGameStateSave(Duration duration, {bool success = true, int retryCount = 0})`

Logs game state save performance.

**Parameters:**
- `duration` (required): Save operation duration
- `success` (optional): Whether save succeeded (default: true)
- `retryCount` (optional): Number of retries needed (default: 0)

**Example:**
```dart
final startTime = DateTime.now();
// ... save operation ...
await analyticsService.logGameStateSave(
  DateTime.now().difference(startTime),
  success: true,
  retryCount: 1,
);
```

#### `Future<void> logGameStateLoad(Duration duration, {bool success = true})`

Logs game state load performance.

**Parameters:**
- `duration` (required): Load operation duration
- `success` (optional): Whether load succeeded (default: true)

**Example:**
```dart
final startTime = DateTime.now();
// ... load operation ...
await analyticsService.logGameStateLoad(
  DateTime.now().difference(startTime),
  success: true,
);
```

#### `Future<void> logTriviaGenerationPerformance(Duration duration, {required String mode, bool success = true, int poolSize = 0})`

Logs trivia generation performance.

**Parameters:**
- `duration` (required): Generation duration
- `mode` (required): Game mode for which trivia was generated
- `success` (optional): Whether generation succeeded (default: true)
- `poolSize` (optional): Size of generated pool (default: 0)

**Example:**
```dart
await analyticsService.logTriviaGenerationPerformance(
  Duration(milliseconds: 200),
  mode: 'classic',
  poolSize: 50,
);
```

#### `Future<void> logNetworkReachabilityCheck(Duration duration, {bool success = true, bool hasInternet = false, int retryCount = 0})`

Logs network reachability check performance.

**Parameters:**
- `duration` (required): Check duration
- `success` (optional): Whether check succeeded (default: true)
- `hasInternet` (optional): Whether internet is available (default: false)
- `retryCount` (optional): Number of retries needed (default: 0)

**Example:**
```dart
await analyticsService.logNetworkReachabilityCheck(
  Duration(milliseconds: 500),
  success: true,
  hasInternet: true,
  retryCount: 0,
);
```

#### `Future<void> logTemplateInitialization(Duration duration, {bool success = true, int templateCount = 0, int retryCount = 0})`

Logs trivia template initialization performance.

**Parameters:**
- `duration` (required): Initialization duration
- `success` (optional): Whether initialization succeeded (default: true)
- `templateCount` (optional): Number of templates loaded (default: 0)
- `retryCount` (optional): Number of retries needed (default: 0)

**Example:**
```dart
await analyticsService.logTemplateInitialization(
  Duration(milliseconds: 100),
  success: true,
  templateCount: 1500,
  retryCount: 0,
);
```

---

## NetworkService

Network connectivity and reachability service.

### Methods

#### `Future<bool> checkInternetReachability()`

Forces a fresh internet reachability check, bypassing cache.

**Returns:**
- `bool`: `true` if internet is reachable, `false` otherwise

**Performance:**
- Tracked via `AnalyticsService.logNetworkReachabilityCheck()`

**Example:**
```dart
final hasInternet = await networkService.checkInternetReachability();
if (hasInternet) {
  // Proceed with online operations
}
```

#### `void setAnalyticsService(dynamic analyticsService)`

Sets the analytics service for performance tracking.

**Parameters:**
- `analyticsService`: AnalyticsService instance

**Note:** Call this after both services are initialized to enable performance tracking.

**Example:**
```dart
networkService.setAnalyticsService(analyticsService);
```

---

## MultiplayerService

Multiplayer game room management service.

### Methods

#### `Future<bool> validatePlayerMembership(String roomId, String userId) async`

Validates if a user is a member of a game room (host or player).

**Parameters:**
- `roomId` (required): ID of the game room
- `userId` (required): ID of the user to validate

**Returns:**
- `bool`: `true` if user is a member, `false` otherwise

**Security:**
- This is a critical security method - always call before room operations
- Part of defense-in-depth security model (see ADR-002)

**Example:**
```dart
final isValid = await multiplayerService.validatePlayerMembership(roomId, userId);
if (isValid) {
  // Proceed with room operation
}
```

---

## SubscriptionService

Subscription tier and access management service.

### Methods

#### `Future<bool> hasAccessWithGracePeriod({required SubscriptionTier requiredTier, String? featureName})`

Checks if user has access to a feature, considering grace period for active games.

**Parameters:**
- `requiredTier` (required): Minimum tier required for access
- `featureName` (optional): Name of feature for logging

**Returns:**
- `bool`: `true` if user has access (including grace period), `false` otherwise

**Grace Period:**
- 30 minutes for active game sessions
- Only applies to features accessible when game started
- Persists across app restarts

**Example:**
```dart
final hasAccess = await subscriptionService.hasAccessWithGracePeriod(
  requiredTier: SubscriptionTier.premium,
  featureName: 'ai_mode',
);
```

---

## Error Handling

All services follow consistent error handling patterns:

1. **Non-Critical Operations**: Use `unawaited()` for fire-and-forget analytics
2. **Critical Operations**: Proper try-catch with user notifications
3. **Retry Logic**: Exponential backoff for transient failures
4. **Analytics**: All errors logged to Firebase Crashlytics and Analytics

## Performance Considerations

- Performance tracking is non-blocking (uses `unawaited()` where appropriate)
- Operations track their own duration automatically
- Metrics logged to Firebase Analytics for monitoring
- Warnings logged for operations > 1000ms


