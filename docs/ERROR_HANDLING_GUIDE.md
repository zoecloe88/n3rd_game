# Error Handling Guide

## Overview

This document describes the comprehensive error handling strategy used throughout the N3RD Trivia Game application.

> **Related**: See [ADR-007: Error Handling Strategy](./ADRs/007-error-handling-strategy.md) for the architectural decision that established this error handling approach.

## Error Handling Philosophy

### Defense in Depth
The application uses multiple layers of error handling:
1. **Input Validation** - Prevent invalid data from entering the system
2. **State Validation** - Ensure game state remains consistent
3. **Exception Handling** - Catch and handle errors gracefully
4. **User Feedback** - Inform users of errors in a friendly way
5. **Recovery Mechanisms** - Allow users to recover from errors

## Utility Classes for Error Prevention

The application provides utility classes to prevent common crash scenarios:

### ListHelper

Prevents crashes from unsafe list access (IndexOutOfRangeException, StateError).

**Location**: `lib/utils/list_helper.dart`

**Methods:**
- `static T? safeFirst<T>(List<T>? list)` - Safely get first element (returns null if empty/null)
- `static T? safeLast<T>(List<T>? list)` - Safely get last element (returns null if empty/null)
- `static T? safeElementAt<T>(List<T>? list, int index)` - Safely get element at index (returns null if out of bounds)
- `static T? safeSingle<T>(List<T>? list)` - Safely get single element (returns null if not exactly one element)
- `static bool isNotEmpty<T>(List<T>? list)` - Safely check if list is not empty
- `static bool isEmpty<T>(List<T>? list)` - Safely check if list is empty

**Usage:**
```dart
// Safe first element access
final item = ListHelper.safeFirst(list);
if (item == null) {
  LoggerService.warning('List is empty, cannot get first element');
  return;
}

// Safe last element access
final last = ListHelper.safeLast(items);
if (last == null) {
  LoggerService.warning('List is empty, cannot get last element');
  return;
}

// Safe index access
final element = ListHelper.safeElementAt(list, 0);
if (element == null) {
  LoggerService.warning('Index 0 is out of bounds or list is null');
  return;
}
```

**Benefits:**
- Prevents IndexOutOfRangeException from empty lists
- Prevents StateError from calling .single on lists with != 1 element
- Returns null on failure instead of crashing
- Handles null lists gracefully

### FirebaseHelper

Prevents crashes from accessing Firebase before initialization.

**Location**: `lib/utils/firebase_helper.dart`

**Methods:**
- `static bool isInitialized()` - Check if Firebase is initialized (never throws)
- `static User? getCurrentUser()` - Safely get current Firebase user (never throws)

**Usage:**
```dart
if (FirebaseHelper.isInitialized()) {
  final user = FirebaseHelper.getCurrentUser();
  // Safe Firebase operations
}
```

**Benefits:**
- Prevents crashes from accessing Firebase services before initialization
- Centralized Firebase access pattern
- Never throws exceptions

### ProviderHelper

Prevents crashes from missing providers in widget tree.

**Location**: `lib/utils/provider_helper.dart`

**Methods:**
- `static T? safeGet<T>(BuildContext context, {bool listen = false})` - Safe get, returns null if not found
- `static T safeGetOrThrow<T>(BuildContext context, {bool listen = false})` - Get or throw with better error message

**Usage:**
```dart
// Optional provider
final service = ProviderHelper.safeGet<GameService>(context);
if (service != null) {
  // Use service
}

// Required provider
final requiredService = ProviderHelper.safeGetOrThrow<GameService>(context);
requiredService.doSomething(); // Guaranteed non-null
```

**Benefits:**
- Prevents crashes from missing providers
- Better error messages for debugging
- Supports both optional and required provider patterns

### JsonHelper

Prevents TypeError crashes from unsafe JSON type casts.

**Location**: `lib/utils/json_helper.dart`

**Methods:**
- `static Map<String, dynamic>? safeDecodeMap(String jsonString)` - Safe decode as Map
- `static List<dynamic>? safeDecodeList(String jsonString)` - Safe decode as List

**Usage:**
```dart
// Decode as Map
final data = JsonHelper.safeDecodeMap(jsonString);
if (data != null) {
  final value = data['key'];
}

// Decode as List
final list = JsonHelper.safeDecodeList(jsonString);
if (list != null) {
  for (final item in list) {
    // Process item
  }
}
```

**Benefits:**
- Prevents TypeError from unsafe type casts
- Proper type checking before casting
- Returns null on failure instead of crashing

### ListHelper

Prevents IndexOutOfRangeException and StateError crashes from unsafe list access.

**Location**: `lib/utils/list_helper.dart`

**Methods:**
- `static T? safeFirst<T>(List<T>? list)` - Safely get first element
- `static T? safeLast<T>(List<T>? list)` - Safely get last element
- `static T? safeElementAt<T>(List<T>? list, int index)` - Safely get element at index
- `static T? safeSingle<T>(List<T>? list)` - Safely get single element
- `static bool isNotEmpty<T>(List<T>? list)` - Safely check if list is not empty
- `static bool isEmpty<T>(List<T>? list)` - Safely check if list is empty

**Usage:**
```dart
// Safe first element access
final item = ListHelper.safeFirst(list);
if (item == null) {
  LoggerService.warning('List is empty, cannot get first element');
  return;
}

// Safe last element access
final last = ListHelper.safeLast(items);
if (last == null) {
  LoggerService.warning('List is empty, cannot get last element');
  return;
}

// Safe element at index
final element = ListHelper.safeElementAt(list, 0);
if (element == null) {
  LoggerService.warning('Index 0 is out of bounds or list is null');
  return;
}

// Safe single element
final single = ListHelper.safeSingle(list);
if (single == null) {
  LoggerService.warning('List does not have exactly one element');
  return;
}
```

**Benefits:**
- Prevents IndexOutOfRangeException from accessing empty lists
- Prevents StateError from calling .single on lists without exactly one element
- Returns null on failure instead of crashing
- Handles null lists gracefully

## Error Types

### 1. Network Errors
**Location**: `lib/exceptions/app_exceptions.dart` - `NetworkException`

**Handling Strategy**:
- Automatic retry with exponential backoff
- Offline fallback when possible
- User-friendly error messages
- Connectivity monitoring

**Example**:
```dart
try {
  await firestore.collection('data').get();
} on NetworkException catch (e) {
  // Show user-friendly message
  ErrorHandler.showError(context, 'Connection failed. Please check your internet.');
  // Retry logic
  await _retryWithBackoff();
}
```

### 2. Authentication Errors
**Location**: `lib/exceptions/app_exceptions.dart` - `AuthenticationException`

**Handling Strategy**:
- Clear error messages
- Automatic logout on critical failures
- Session validation

**Example**:
```dart
try {
  await authService.signIn(email, password);
} on AuthenticationException catch (e) {
  ErrorHandler.showError(context, e.message);
}
```

### 3. Validation Errors
**Location**: `lib/exceptions/app_exceptions.dart` - `ValidationException`

**Handling Strategy**:
- Input sanitization
- Real-time validation feedback
- Clear validation messages

**Example**:
```dart
try {
  validateTriviaItem(item);
} on ValidationException catch (e) {
  ErrorHandler.showWarning(context, e.message);
}
```

### 4. Game Errors
**Location**: `lib/exceptions/app_exceptions.dart` - `GameException`

**Handling Strategy**:
- State recovery
- Game restart options
- Progress preservation when possible

**Example**:
```dart
try {
  gameService.startNewRound(triviaPool);
} on GameException catch (e) {
  ErrorHandler.showError(context, 'Game error: ${e.message}');
  // Offer to restart game
}
```

### 5. Storage Errors
**Location**: `lib/exceptions/app_exceptions.dart` - `StorageException`

**Handling Strategy**:
- Fallback to memory
- Retry logic
- Data corruption detection

**Example**:
```dart
try {
  await saveGameState(state);
} on StorageException catch (e) {
  // Fallback to memory cache
  _memoryCache.save(state);
}
```

### 6. Navigation Errors
**Location**: `lib/utils/navigation_helper.dart` - `NavigationHelper`

**Handling Strategy**:
- Automatic retry with exponential backoff (max 2 retries)
- Route argument validation before navigation
- User-friendly error messages
- Analytics tracking of navigation failures
- Fallback to safe routes on persistent failures

**Automatic Error Recovery**:
```dart
// NavigationHelper automatically retries failed navigations
NavigationHelper.safeNavigate(
  context,
  '/game',
  arguments: {'mode': GameMode.classic},
  maxRetries: 2, // Default: 2 retries with exponential backoff
  source: NavigationSource.buttonTap,
);
// If navigation fails after retries, user sees friendly error message
```

**Error Handling Flow**:
1. Validate route arguments using `RouteRegistry.validateRouteArguments()`
2. Save navigation state before attempting navigation
3. Attempt navigation with automatic retry (100ms, 200ms delays)
4. Track navigation analytics (success/failure, duration)
5. Show user-friendly error message if all retries fail
6. Log navigation error for debugging

**Example Scenarios**:

**Invalid Route Arguments**:
```dart
// RouteRegistry validates arguments before navigation
final isValid = RouteRegistry.validateRouteArguments(
  '/multiplayer-loading',
  'invalid_argument', // Should be MultiplayerMode
);
if (!isValid) {
  LoggerService.warning('Invalid route arguments');
  // Navigation will fail gracefully
}
```

**Route Not Found**:
```dart
// NavigationHelper handles unknown routes gracefully
NavigationHelper.safeNavigate(context, '/unknown-route');
// Shows user-friendly error: "Unable to navigate. Please try again."
// Error tracked in analytics
```

**Navigation During Widget Disposal**:
```dart
// NavigationHelper checks context.mounted before navigating
if (context.mounted) {
  NavigationHelper.safeNavigate(context, '/route');
}
// Prevents navigation errors on disposed widgets
```

**Deep Link Restoration After Auth**:
```dart
// NavigationStateService saves deep links for post-auth navigation
final stateService = NavigationStateService();
await stateService.savePendingDeepLink('/family-invitation?groupId=abc123');

// After authentication completes:
final deepLink = await stateService.getAndClearPendingDeepLink();
if (deepLink != null) {
  NavigationHelper.safeNavigate(
    context,
    deepLink,
    source: NavigationSource.deepLink,
  );
}
```

## Error Recovery Patterns

### 1. Retry with Exponential Backoff
```dart
Future<T> retryWithBackoff<T>(
  Future<T> Function() operation, {
  int maxRetries = 3,
  Duration initialDelay = const Duration(seconds: 1),
}) async {
  int retryCount = 0;
  Duration delay = initialDelay;
  
  while (retryCount < maxRetries) {
    try {
      return await operation();
    } catch (e) {
      if (retryCount == maxRetries - 1) rethrow;
      await Future.delayed(delay);
      delay *= 2; // Exponential backoff
      retryCount++;
    }
  }
  throw Exception('Max retries exceeded');
}
```

### 2. Graceful Degradation
```dart
Future<TriviaItem> loadTrivia() async {
  try {
    // Try online first
    return await _loadFromFirestore();
  } on NetworkException {
    // Fallback to cache
    return await _loadFromCache();
  } catch (e) {
    // Final fallback to default
    return _getDefaultTrivia();
  }
}
```

### 3. State Validation and Recovery
```dart
void _validateRestoredState() {
  // Validate state consistency
  if (_currentTrivia != null && _shuffledWords.isNotEmpty) {
    final triviaWords = Set.from(_currentTrivia!.words);
    final shuffledWordsSet = Set.from(_shuffledWords);
    
    if (!triviaWords.containsAll(shuffledWordsSet)) {
      // State corrupted - reset to safe state
      _resetToSafeState();
    }
  }
}
```

## User-Facing Error Messages

### Principles
1. **Clear and Actionable** - Tell users what happened and what they can do
2. **Non-Technical** - Avoid technical jargon
3. **Recovery Options** - Provide ways to fix the issue
4. **Consistent Tone** - Friendly and helpful

### Examples

**Good**:
- "Connection failed. Please check your internet and try again."
- "Game data couldn't be saved. Your progress is safe in memory."
- "Invalid answer. Please select from the available options."

**Bad**:
- "NetworkException: Connection timeout"
- "Error 500"
- "State corruption detected"

## Error Logging

### Debug Mode
- Detailed error information
- Stack traces
- State dumps

### Production Mode
- User-friendly messages only
- Analytics tracking
- Crashlytics integration

### Example
```dart
try {
  await operation();
} catch (e, stackTrace) {
  if (kDebugMode) {
    debugPrint('Error: $e\n$stackTrace');
  }
  
  // Log to Crashlytics
  FirebaseCrashlytics.instance.recordError(
    e,
    stackTrace,
    reason: 'Operation failed',
    fatal: false,
  );
  
  // Show user-friendly message
  ErrorHandler.showError(context, 'Something went wrong. Please try again.');
}
```

## Best Practices

### 1. Always Validate Input
```dart
void submitAnswer(String answer) {
  if (answer.isEmpty) {
    throw ValidationException('Answer cannot be empty');
  }
  // ... proceed
}
```

### 2. Check State Before Operations
```dart
void startGame() {
  if (_isGameActive) {
    throw GameException('Game already in progress');
  }
  // ... proceed
}
```

### 3. Use Safe Navigation with Error Recovery
```dart
// Good - Automatic error recovery and analytics
NavigationHelper.safeNavigate(
  context,
  '/game',
  arguments: {'mode': GameMode.classic},
  source: NavigationSource.buttonTap,
);

// Bad - No error recovery, no analytics
Navigator.of(context).pushNamed('/route');
```

**Navigation Error Recovery Features**:
- Automatic retry with exponential backoff (default: 2 retries)
- Route argument validation before navigation
- User-friendly error messages on failure
- Analytics tracking of navigation events
- Navigation state persistence
- Context validation (checks `context.mounted`)

**Note**: As of the latest build, all navigation has been migrated to `NavigationHelper`. 
There are 0 remaining direct `Navigator.of(context)` calls in the codebase.

### 4. Dispose Resources Properly
```dart
@override
void dispose() {
  _timer?.cancel();
  _subscription?.cancel();
  super.dispose();
}
```

### 5. Handle Async Errors
```dart
Future<void> loadData() async {
  try {
    await operation();
  } catch (e) {
    if (mounted) {
      ErrorHandler.showError(context, 'Failed to load data');
    }
  }
}
```

## Testing Error Handling

### Unit Tests
```dart
test('should throw ValidationException for invalid input', () {
  expect(
    () => validateTriviaItem(invalidItem),
    throwsA(isA<ValidationException>()),
  );
});
```

### Integration Tests
```dart
test('should recover from network error', () async {
  // Simulate network failure
  when(mockNetwork.isOnline).thenReturn(false);
  
  // Should fallback to cache
  final result = await loadTrivia();
  expect(result, isNotNull);
});
```

## Error Monitoring

### Analytics
- Track error rates
- Monitor error types
- Identify patterns

### Crashlytics
- Automatic crash reporting
- Non-fatal error tracking
- User impact analysis

## Conclusion

Comprehensive error handling ensures:
- **Reliability** - App continues working even when errors occur
- **User Experience** - Users understand what happened and can recover
- **Debugging** - Developers can identify and fix issues quickly
- **Stability** - App doesn't crash on unexpected errors

