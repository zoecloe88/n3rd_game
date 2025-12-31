# API Documentation

This document provides API documentation for public service methods in the N3RD Game application.

## Table of Contents

- [GameService](#gameservice)
- [Game State Manager](#game-state-manager)
- [Game Timer Manager](#game-timer-manager)
- [Game Mode Handler](#game-mode-handler)
- [Game Scoring Service](#game-scoring-service)
- [Game Round Manager](#game-round-manager)
- [AnalyticsService](#analyticsservice)
- [NetworkService](#networkservice)
- [MultiplayerService](#multiplayerservice)
- [SubscriptionService](#subscriptionservice)
- [NavigationHelper](#navigationhelper)
- [NavigationStateService](#navigationstateservice)
- [RouteRegistry](#routeregistry)
- [SecureHttpClient](#securehttpclient)
- [FirebaseHelper](#firebasehelper)
- [ProviderHelper](#providerhelper)
- [JsonHelper](#jsonhelper)

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

---

## NavigationHelper

Centralized navigation utility providing safe navigation with analytics tracking, error recovery, and state management.

**Location**: `lib/utils/navigation_helper.dart`

### Methods

#### `static Future<void> safeNavigate(BuildContext context, String route, {Object? arguments, bool replace = false, NavigationSource source = NavigationSource.programmatic, int maxRetries = 2})`

Safely navigate to a route with error handling, analytics tracking, and automatic retry.

**Parameters:**
- `context` (required): BuildContext for navigation
- `route` (required): Route path (e.g., '/game', '/settings')
- `arguments` (optional): Route arguments (Map or single value)
- `replace` (optional): Replace current route instead of pushing (default: false)
- `source` (optional): Navigation source for analytics (default: programmatic)
- `maxRetries` (optional): Maximum retry attempts on failure (default: 2)

**Behavior:**
- Validates route arguments using RouteRegistry
- Saves navigation state to NavigationStateService
- Tracks screen view and navigation transition analytics
- Automatic retry with exponential backoff on failure
- User-friendly error messages on failure

**Example:**
```dart
NavigationHelper.safeNavigate(
  context,
  '/game',
  arguments: {'mode': GameMode.classic, 'difficulty': 'medium'},
  source: NavigationSource.buttonTap,
);
```

#### `static void safePop(BuildContext context, [Object? result, NavigationSource source = NavigationSource.backButton])`

Safely pop the current route with analytics tracking.

**Parameters:**
- `context` (required): BuildContext for navigation
- `result` (optional): Result value to return
- `source` (optional): Navigation source for analytics (default: backButton)

**Example:**
```dart
NavigationHelper.safePop(context);
NavigationHelper.safePop(context, {'success': true});
```

#### `static Future<T?> safePush<T>(BuildContext context, Route<T> route, {NavigationSource source = NavigationSource.programmatic})`

Safely push a Route object with analytics tracking.

**Parameters:**
- `context` (required): BuildContext for navigation
- `route` (required): Route to push
- `source` (optional): Navigation source for analytics

**Returns:**
- `Future<T?>`: Result from popped route

**Example:**
```dart
final result = await NavigationHelper.safePush(
  context,
  MaterialPageRoute(builder: (_) => CustomScreen()),
  source: NavigationSource.buttonTap,
);
```

#### `static Future<void> safePushReplacementNamed(BuildContext context, String route, {Object? arguments, NavigationSource source = NavigationSource.programmatic})`

Safely replace current route with new route.

**Parameters:**
- `context` (required): BuildContext for navigation
- `route` (required): Route path
- `arguments` (optional): Route arguments
- `source` (optional): Navigation source for analytics

**Example:**
```dart
NavigationHelper.safePushReplacementNamed(
  context,
  '/login',
  source: NavigationSource.programmatic,
);
```

#### `static Future<void> safeNavigateAndRemoveUntil(BuildContext context, String route, bool Function(Route<dynamic>) predicate, {Object? arguments, NavigationSource source = NavigationSource.programmatic})`

Safely navigate and remove routes from stack until predicate returns true.

**Parameters:**
- `context` (required): BuildContext for navigation
- `route` (required): Route path
- `predicate` (required): Predicate function for route removal
- `arguments` (optional): Route arguments
- `source` (optional): Navigation source for analytics

**Example:**
```dart
NavigationHelper.safeNavigateAndRemoveUntil(
  context,
  '/title',
  (route) => route.isFirst,
  source: NavigationSource.programmatic,
);
```

#### `static void switchToTab(BuildContext context, int tabIndex, {NavigationSource source = NavigationSource.tabSwitch})`

Switch to a main navigation tab (0-4).

**Parameters:**
- `context` (required): BuildContext for navigation
- `tabIndex` (required): Tab index (0: Title, 1: Modes, 2: Stats, 3: Friends, 4: More)
- `source` (optional): Navigation source for analytics

**Behavior:**
- Detects if already inside MainNavigationWrapper and uses internal switch
- Prevents navigation loops and state loss
- Tracks tab switch analytics

**Example:**
```dart
NavigationHelper.switchToTab(context, 0); // Switch to Title tab
```

---

## NavigationStateService

Service for persisting and restoring navigation state, tracking navigation history, and managing deep link restoration.

**Location**: `lib/services/navigation_state_service.dart`

### Methods

#### `Future<void> saveNavigationState(List<String> routeStack)`

Save navigation stack state for restoration.

**Parameters:**
- `routeStack` (required): List of route names in order from root to current

**Example:**
```dart
final stateService = NavigationStateService();
await stateService.saveNavigationState(['/title', '/modes', '/game']);
```

#### `Future<List<String>?> restoreNavigationState()`

Restore saved navigation stack state.

**Returns:**
- `Future<List<String>?>`: Saved route stack or null if none exists

**Example:**
```dart
final stack = await stateService.restoreNavigationState();
if (stack != null) {
  // Restore navigation stack
}
```

#### `Future<void> saveLastRoute(String route, Map<String, dynamic>? arguments)`

Save last visited route with optional arguments.

**Parameters:**
- `route` (required): Route path
- `arguments` (optional): Route arguments map

**Example:**
```dart
await stateService.saveLastRoute('/game', {'mode': 'classic'});
```

#### `Future<(String?, Map<String, dynamic>?)> getLastRoute()`

Get last visited route with arguments.

**Returns:**
- `Future<(String?, Map<String, dynamic>?)>`: Tuple of (route, arguments)

**Example:**
```dart
final (route, args) = await stateService.getLastRoute();
if (route != null) {
  // Navigate to last route
}
```

#### `Future<void> addToHistory(String route, {Map<String, dynamic>? arguments})`

Add route to navigation history (max 50 entries).

**Parameters:**
- `route` (required): Route path
- `arguments` (optional): Route arguments

**Example:**
```dart
await stateService.addToHistory('/game', arguments: {'mode': 'classic'});
```

#### `Future<List<Map<String, dynamic>>> getHistory({int? limit})`

Get navigation history.

**Parameters:**
- `limit` (optional): Maximum number of entries to return

**Returns:**
- `Future<List<Map<String, dynamic>>>`: List of history entries with route, arguments, and timestamp

**Example:**
```dart
final history = await stateService.getHistory(limit: 10);
```

#### `Future<void> savePendingDeepLink(String deepLink)`

Save pending deep link for restoration after authentication.

**Parameters:**
- `deepLink` (required): Deep link URL

**Example:**
```dart
await stateService.savePendingDeepLink('/family-invitation?groupId=abc123');
```

#### `Future<String?> getAndClearPendingDeepLink()`

Get and clear pending deep link.

**Returns:**
- `Future<String?>`: Deep link URL or null

**Example:**
```dart
final deepLink = await stateService.getAndClearPendingDeepLink();
if (deepLink != null) {
  // Navigate to deep link
}
```

#### `Future<void> clearNavigationState()`

Clear all navigation state and history.

**Example:**
```dart
await stateService.clearNavigationState();
```

---

## RouteRegistry

Centralized route configuration registry providing route metadata, validation, and route creation with consistent transitions.

**Location**: `lib/config/route_config.dart`

### Static Methods

#### `static RouteConfig? getRouteConfig(String? path)`

Get route configuration by path.

**Parameters:**
- `path` (required): Route path

**Returns:**
- `RouteConfig?`: Route configuration or null if not found

**Example:**
```dart
final config = RouteRegistry.getRouteConfig('/game');
if (config != null) {
  // Use config metadata
}
```

#### `static bool requiresAuth(String? path)`

Check if route requires authentication.

**Parameters:**
- `path` (required): Route path

**Returns:**
- `bool`: True if route requires authentication

**Example:**
```dart
if (RouteRegistry.requiresAuth('/game')) {
  // Check authentication
}
```

#### `static bool requiresPremium(String? path)`

Check if route requires premium subscription.

**Parameters:**
- `path` (required): Route path

**Returns:**
- `bool`: True if route requires premium

**Example:**
```dart
if (RouteRegistry.requiresPremium('/analytics')) {
  // Check subscription tier
}
```

#### `static bool requiresOnlineAccess(String? path)`

Check if route requires online access.

**Parameters:**
- `path` (required): Route path

**Returns:**
- `bool`: True if route requires online access

**Example:**
```dart
if (RouteRegistry.requiresOnlineAccess('/multiplayer-lobby')) {
  // Check network connectivity
}
```

#### `static RouteTransitionType getTransitionType(String? path)`

Get transition type for route.

**Parameters:**
- `path` (required): Route path

**Returns:**
- `RouteTransitionType`: Transition type (smooth, scale, fade, none)

**Example:**
```dart
final transition = RouteRegistry.getTransitionType('/game');
```

#### `static Route<T> createRoute<T>({required String path, required Widget page, RouteSettings? settings, Object? arguments})`

Create a Route with appropriate transition based on route configuration.

**Parameters:**
- `path` (required): Route path
- `page` (required): Widget to display
- `settings` (optional): RouteSettings
- `arguments` (optional): Route arguments

**Returns:**
- `Route<T>`: Configured route with proper transition

**Example:**
```dart
final route = RouteRegistry.createRoute(
  path: '/game',
  page: const GameScreen(),
  settings: settings,
  arguments: {'mode': GameMode.classic},
);
```

#### `static String getDocumentation(String? path)`

Get formatted documentation for a route.

**Parameters:**
- `path` (required): Route path

**Returns:**
- `String`: Formatted documentation with parameters

**Example:**
```dart
final docs = RouteRegistry.getDocumentation('/game');
print(docs);
```

#### `static bool validateRouteArguments(String? path, Object? arguments)`

Validate route arguments against parameter schema.

**Parameters:**
- `path` (required): Route path
- `arguments` (required): Arguments to validate

**Returns:**
- `bool`: True if arguments are valid

**Example:**
```dart
final isValid = RouteRegistry.validateRouteArguments(
  '/game',
  {'mode': GameMode.classic},
);
```

#### `static List<String> getAllRoutes()`

Get all registered route paths.

**Returns:**
- `List<String>`: List of all route paths

**Example:**
```dart
final allRoutes = RouteRegistry.getAllRoutes();
```

---

## Game State Manager

Manages game state transitions, persistence, and restoration.

### Methods

#### `GameState get state`

Gets the current game state.

**Returns:** Current `GameState` instance

#### `GamePhase get phase`

Gets the current game phase.

**Returns:** Current `GamePhase` (memorize, play, or result)

#### `void updateState(GameState newState)`

Updates the game state.

**Parameters:**
- `newState` (required): New game state to set

#### `void updatePhase(GamePhase newPhase)`

Updates the game phase.

**Parameters:**
- `newPhase` (required): New game phase

#### `void resetState()`

Resets game state to initial values.

#### `Future<void> saveState()`

Saves game state to SharedPreferences.

**Throws:**
- Storage errors if save fails

#### `Future<bool> loadState()`

Loads game state from SharedPreferences.

**Returns:** `true` if state was loaded, `false` otherwise

---

## Game Timer Manager

Manages all game timers (memorize, play, shuffle, flip, time attack).

### Methods

#### `void cancelAllTimers()`

Cancels all active timers to prevent memory leaks.

#### `void startMemorizeTimer(Duration duration)`

Starts the memorize phase timer.

**Parameters:**
- `duration` (required): Duration of memorize phase

#### `void startPlayTimer(Duration duration)`

Starts the play phase timer.

**Parameters:**
- `duration` (required): Duration of play phase

#### `void startTimeAttackTimer({required int totalSeconds, required Duration tickInterval})`

Starts the time attack timer.

**Parameters:**
- `totalSeconds` (required): Total seconds for time attack
- `tickInterval` (required): Interval between ticks

#### `void startShuffleTimer({required Duration interval, required VoidCallback onTick})`

Starts the shuffle timer for shuffle mode.

**Parameters:**
- `interval` (required): Interval between shuffles
- `onTick` (required): Callback for each shuffle tick

#### `void dispose()`

Disposes of all timers and resources.

---

## Game Mode Handler

Handles mode-specific game logic (shuffle, flip, time attack, etc.).

### Methods

#### `int get shuffleCount`

Gets the current shuffle count.

#### `bool get isShuffling`

Gets whether shuffling is active.

#### `List<String> get shuffledWords`

Gets the shuffled words list.

#### `List<bool> get flippedTiles`

Gets the flipped tiles state.

#### `void initializeShuffle({required List<String> words, required VoidCallback onShuffle, required VoidCallback onComplete})`

Initializes shuffle sequence.

**Parameters:**
- `words` (required): Words to shuffle
- `onShuffle` (required): Callback when shuffle occurs
- `onComplete` (required): Callback when shuffle completes

#### `Timer startShuffleSequence({required VoidCallback onShuffleTick, required VoidCallback onComplete})`

Starts shuffle sequence.

**Returns:** Timer instance for cancellation

#### `({Timer initialTimer, Timer? periodicTimer}) startFlipSequence({required ModeConfig config, required ValueChanged<int> onTileFlip})`

Starts flip sequence for flip mode.

**Returns:** Tuple with initial timer and periodic timer

---

## Game Scoring Service

Handles all scoring calculations, multipliers, and bonuses.

### Methods

#### `int calculateBasePoints(int numCorrect, [int expectedCorrect = 3])`

Calculates base points for a round.

**Parameters:**
- `numCorrect` (required): Number of correct answers
- `expectedCorrect` (optional): Expected number of correct answers (default: 3)

**Returns:** Base points (10 per correct answer)

#### `ScoreCalculationResult calculateScore({required int basePoints, required int numCorrect, required int expectedCorrect, required TriviaItem currentTrivia, required GameMode currentMode, required bool isPerfect})`

Calculates final score with all multipliers applied.

**Returns:** `ScoreCalculationResult` with final score and calculation details

#### `void activateDoubleScore()`

Activates double score power-up.

#### `void activateStreakShield()`

Activates streak shield power-up.

#### `bool shouldPreventLifeLoss()`

Checks if streak shield should prevent life loss.

**Returns:** `true` if life loss should be prevented

---

## Game Round Manager

Manages game round progression, trivia selection, and answer validation.

### Methods

#### `TriviaItem selectTriviaForRound({required GameMode mode, int recursionDepth = 0})`

Selects trivia item for new round.

**Parameters:**
- `mode` (required): Current game mode
- `recursionDepth` (optional): Recursion depth for validation retries

**Returns:** Selected trivia item

**Throws:**
- `GameException`: If no valid trivia found

#### `void addSelectedAnswer(String answer)`

Adds selected answer.

**Parameters:**
- `answer` (required): Answer to add

#### `void removeSelectedAnswer(String answer)`

Removes selected answer.

**Parameters:**
- `answer` (required): Answer to remove

#### `int validateAnswers()`

Validates selected answers.

**Returns:** Number of correct answers

---

## SecureHttpClient

Secure HTTP client with certificate pinning support.

### Methods

#### `Future<http.Response> get(Uri url, {Map<String, String>? headers, Duration? timeout})`

Performs GET request with certificate pinning.

**Parameters:**
- `url` (required): Request URL
- `headers` (optional): Request headers
- `timeout` (optional): Request timeout

**Returns:** HTTP response

#### `Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body, Duration? timeout})`

Performs POST request with certificate pinning.

**Parameters:**
- `url` (required): Request URL
- `headers` (optional): Request headers
- `body` (optional): Request body
- `timeout` (optional): Request timeout

**Returns:** HTTP response

**Example:**
```dart
final response = await SecureHttpClient.instance.get(
  Uri.parse('https://api.example.com/data'),
);
```

---

## FirebaseHelper

Centralized utility for safe Firebase access with initialization checks.

**Location**: `lib/utils/firebase_helper.dart`

### Methods

#### `static bool isInitialized()`

Check if Firebase is initialized.

**Returns:** `true` if Firebase is initialized, `false` otherwise. This method never throws - it catches all exceptions.

**Example:**
```dart
if (FirebaseHelper.isInitialized()) {
  final user = FirebaseHelper.getCurrentUser();
  // Safe to use Firebase services
}
```

#### `static User? getCurrentUser()`

Safely get current Firebase user.

**Returns:** The current Firebase user if Firebase is initialized and a user is logged in. Returns `null` otherwise. This method never throws - it catches all exceptions.

**Example:**
```dart
final user = FirebaseHelper.getCurrentUser();
if (user != null) {
  // User is logged in
}
```

---

## ProviderHelper

Utility for safe provider access with error handling.

**Location**: `lib/utils/provider_helper.dart`

### Methods

#### `static T? safeGet<T>(BuildContext context, {bool listen = false})`

Safely get a provider, returning null if not found.

Use this when the provider is optional and the code can handle its absence.

**Parameters:**
- `context` (required): BuildContext for provider access
- `listen` (optional): Whether to listen to provider changes (default: false)

**Returns:** The provider instance if found, `null` otherwise.

**Example:**
```dart
final service = ProviderHelper.safeGet<GameService>(context);
if (service != null) {
  service.doSomething();
}
```

#### `static T safeGetOrThrow<T>(BuildContext context, {bool listen = false})`

Get a provider or throw with better error message.

Use this when the provider is required and its absence indicates a bug.

**Parameters:**
- `context` (required): BuildContext for provider access
- `listen` (optional): Whether to listen to provider changes (default: false)

**Returns:** The provider instance (guaranteed non-null).

**Throws:** ProviderNotFoundException with detailed error message if provider not found.

**Example:**
```dart
final service = ProviderHelper.safeGetOrThrow<GameService>(context);
service.doSomething(); // Guaranteed to be non-null
```

---

## JsonHelper

Utility for safe JSON decoding with type checking.

**Location**: `lib/utils/json_helper.dart`

### Methods

#### `static Map<String, dynamic>? safeDecodeMap(String jsonString)`

Safely decode a JSON string as a Map.

Returns null if the JSON is not a Map or if decoding fails.

**Parameters:**
- `jsonString` (required): JSON string to decode

**Returns:** Decoded Map if successful, `null` otherwise.

**Example:**
```dart
final data = JsonHelper.safeDecodeMap(jsonString);
if (data != null) {
  final value = data['key'];
}
```

#### `static List<dynamic>? safeDecodeList(String jsonString)`

Safely decode a JSON string as a List.

Returns null if the JSON is not a List or if decoding fails.

**Parameters:**
- `jsonString` (required): JSON string to decode

**Returns:** Decoded List if successful, `null` otherwise.

**Example:**
```dart
final list = JsonHelper.safeDecodeList(jsonString);
if (list != null) {
  for (final item in list) {
    // Process item
  }
}
```

---

**Last Updated:** January 2025

