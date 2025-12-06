# Error Handling Guide

## Overview
This document describes the comprehensive error handling strategy used throughout the N3RD Trivia Game application.

## Error Handling Philosophy

### Defense in Depth
The application uses multiple layers of error handling:
1. **Input Validation** - Prevent invalid data from entering the system
2. **State Validation** - Ensure game state remains consistent
3. **Exception Handling** - Catch and handle errors gracefully
4. **User Feedback** - Inform users of errors in a friendly way
5. **Recovery Mechanisms** - Allow users to recover from errors

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

### 3. Use Safe Navigation
```dart
// Good
NavigationHelper.safeNavigate(context, '/route');

// Bad
Navigator.of(context).pushNamed('/route');
```

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

