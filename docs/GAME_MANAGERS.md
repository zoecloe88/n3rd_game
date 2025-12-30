# Game Managers Pattern

## Overview

The Game Managers pattern is used to extract complex logic from `GameService` into focused, single-responsibility manager classes. This improves maintainability, testability, and code organization.

**Last Updated:** January 2025

## Manager Pattern

### Design Principles

1. **Single Responsibility**: Each manager handles one specific aspect of game logic
2. **Stateless or Minimal State**: Managers contain only state relevant to their responsibility
3. **Callback-Based Integration**: Managers use callbacks to interact with GameService
4. **Testability**: Managers can be tested independently
5. **Composition Over Inheritance**: GameService composes managers rather than inheriting behavior

### Manager Structure

```dart
class GameXxxManager {
  // State relevant to this manager's responsibility
  
  /// Method that handles specific logic
  ResultType handleXxx({
    required GamePhase phase,
    required GameMode currentMode,
    required VoidCallback onNotifyListeners,
    // Other dependencies via callbacks
  }) {
    // Manager logic
    // Use callbacks for GameService interactions
  }
  
  /// Reset manager state
  void reset() {
    // Clear manager-specific state
  }
}
```

## Available Managers

### GameTriviaManager

**Purpose**: Manages trivia pool and category tracking

**Responsibilities**:
- Trivia pool storage and management
- Recent category tracking
- Trivia selection logic

**Key Methods**:
- `setTriviaPool(List<TriviaItem> pool)`
- `findTriviaByCategory(String category)`
- `addRecentCategory(String category)`

**State**:
- `_currentTriviaPool`: List of available trivia items
- `_recentTriviaCategories`: List of recently used categories

---

### GamePowerupManager

**Purpose**: Manages all power-up functionality

**Responsibilities**:
- Power-up use tracking
- Power-up activation logic
- Power-up state management

**Key Methods**:
- `revealAllWords(...)`
- `clearSelections(...)`
- `activateHint(...)`
- `activateTimeFreeze(...)`
- `activateDoubleScore(...)`

**State**:
- Power-up uses (revealAllUses, clearUses, skipUses, etc.)
- Active power-up states (isTimeFrozen, hasDoubleScore, etc.)
- Hint tracking

---

### GamePersistenceManager

**Purpose**: Handles game state persistence and restoration

**Responsibilities**:
- Save game state to SharedPreferences
- Load game state from SharedPreferences
- State serialization/deserialization

**Key Methods**:
- `saveState(...)`
- `loadState(...)`
- `clearState()`

---

### GameSelectionManager

**Purpose**: Manages tile selection logic

**Responsibilities**:
- Tile selection/deselection
- Selection validation
- Precision mode feedback
- Flip mode selection delegation

**Key Methods**:
- `toggleTileSelection(...)`

**State**:
- Selection validation logic

---

### GameCompetitiveChallengeManager

**Purpose**: Manages competitive challenge tracking

**Responsibilities**:
- Challenge state tracking
- Challenge score submission
- Challenge validation

**Key Methods**:
- `setCompetitiveChallenge(...)`
- `submitCompetitiveChallengeScore(...)`

**State**:
- Challenge ID and metadata
- Challenge submission status

---

### GameFlipModeManager

**Purpose**: Manages flip mode functionality

**Responsibilities**:
- Flip sequence timing
- Tile state management
- Selection order tracking
- Reveal mode settings

**Key Methods**:
- `startFlipSequence(...)`
- `handleFlipModeSelection(...)`
- `revealFlipModeResults(...)`
- `setFlipRevealMode(...)`

**State**:
- `_flippedTiles`: Tile flip states
- `_flipModeSelectedOrder`: Selection order tracking
- `_flipRevealMode`: Reveal mode setting ('instant', 'blind', 'random')
- Flip timers

---

### GameModeSpecificManager

**Purpose**: Manages mode-specific state and logic

**Responsibilities**:
- Streak mode multiplier tracking
- Survival mode perfect count tracking
- Precision mode error messages
- Mode-specific scoring calculations

**Key Methods**:
- `handlePerfectRound(...)`
- `handleNonPerfectRound(...)`
- `getScoringMultiplier(...)`
- `applyModeScoring(...)`

**State**:
- `_streakMultiplier`: Streak mode multiplier (1-5x)
- `_survivalPerfectCount`: Survival mode perfect count
- `_precisionError`: Precision mode error message

---

### GameStateManager

**Purpose**: Manages core game state transitions

**Responsibilities**:
- Game state updates
- State validation
- State transitions

**Key Methods**:
- State update methods
- State validation methods

---

### GameRoundManager

**Purpose**: Manages game round logic

**Responsibilities**:
- Round progression
- Round initialization
- Round completion

**Key Methods**:
- Round management methods

---

### GameTimerManager

**Purpose**: Manages game timers

**Responsibilities**:
- Timer creation and management
- Timer cancellation
- Timer state tracking

**Key Methods**:
- Timer management methods

---

### GameValidationManager

**Purpose**: Manages validation logic for game trivia items and game state

**Responsibilities**:
- Trivia item validation (word count, correct answers, duplicates)
- Game state validation (shuffled words, flipped tiles, selected/revealed words)
- Valid trivia selection from pools
- State restoration validation

**Key Methods**:
- `validateTriviaItem(TriviaItem item)` - Validates a trivia item for game use
- `validateGameState(...)` - Validates entire game state for consistency
- `findValidTriviaFromPool(...)` - Finds a valid trivia item from a pool
- `validateRestoredState(...)` - Validates restored game state

**State**:
- Validation logic (stateless, pure functions)

**Location**: `lib/services/game/game_validation_manager.dart`

**Integration Status**: ✅ Fully integrated into GameService

---

## Integration Pattern

### GameService Integration

Managers are integrated into GameService via composition:

```dart
class GameService extends ChangeNotifier {
  final GameTriviaManager _triviaManager = GameTriviaManager();
  final GamePowerupManager _powerupManager = GamePowerupManager();
  final GameFlipModeManager _flipModeManager = GameFlipModeManager();
  final GameModeSpecificManager _modeSpecificManager = GameModeSpecificManager();
  
  // Delegate methods to managers
  void handleFlipModeSelection(String word) {
    final result = _flipModeManager.handleFlipModeSelection(
      word: word,
      // Pass required dependencies via callbacks
      onAddToFlipModeSelectedOrder: (w) => _flipModeSelectedOrder.add(w),
      onSubmitFlipModeAnswers: (isPerfect) => _submitFlipModeAnswers(isPerfect),
      // ... other callbacks
    );
    
    // Handle result
    switch (result.action) {
      case FlipModeSelectionAction.submitPerfect:
        _submitFlipModeAnswers(true);
        break;
      // ... other cases
    }
  }
}
```

### Callback Pattern

Managers use callbacks to interact with GameService:

```dart
// In manager
void doSomething({
  required VoidCallback onNotifyListeners,
  required Function(GameState) onStateUpdate,
  required Function(String) onAddToSelection,
}) {
  // Manager logic
  onAddToSelection('word');
  onStateUpdate(newState);
  onNotifyListeners();
}
```

## Best Practices

### 1. Keep Managers Focused

Each manager should handle one specific responsibility. If a manager grows too large (>300 lines), consider splitting it further.

### 2. Use Callbacks for Integration

Managers should use callbacks rather than direct service dependencies. This keeps managers decoupled and testable.

### 3. Minimize State

Managers should only maintain state directly relevant to their responsibility. Shared state should remain in GameService.

### 4. Return Result Objects

For complex operations, return result objects rather than void:

```dart
class FlipModeSelectionResult {
  final FlipModeSelectionAction action;
  // ... other data
}
```

### 5. Provide Reset Methods

All managers should provide reset methods to clear their state:

```dart
void reset() {
  // Clear all manager state
}
```

## Adding New Managers

### Steps

1. **Identify Responsibility**: Determine what specific aspect of game logic needs extraction
2. **Create Manager Class**: Create new manager following the pattern
3. **Define State**: Identify what state the manager needs to maintain
4. **Define Methods**: Create methods that handle the manager's logic
5. **Use Callbacks**: Use callbacks for GameService interactions
6. **Write Tests**: Create comprehensive tests for the manager
7. **Integrate**: Integrate manager into GameService
8. **Document**: Update this document with manager details

### Example

```dart
class GameNewManager {
  // State
  String _state = '';
  
  // Methods
  ResultType handleSomething({
    required VoidCallback onNotifyListeners,
  }) {
    // Logic
    _state = 'new value';
    onNotifyListeners();
    return ResultType.success();
  }
  
  void reset() {
    _state = '';
  }
}
```

## Testing Managers

Managers should be tested independently:

```dart
test('manager handles operation correctly', () {
  final manager = GameXxxManager();
  var notified = false;
  
  manager.handleSomething(
    onNotifyListeners: () => notified = true,
  );
  
  expect(notified, isTrue);
  expect(manager.state, equals('expected'));
});
```

## Manager Interaction

Managers are independent and don't interact directly with each other. All coordination happens through GameService. This ensures:

- Clear separation of concerns
- Easy testing
- Flexible composition
- No circular dependencies

## Benefits

1. **Maintainability**: Smaller, focused classes are easier to understand and modify
2. **Testability**: Managers can be tested independently
3. **Reusability**: Managers can potentially be reused in other contexts
4. **Clarity**: Clear separation of responsibilities
5. **Scalability**: Easy to add new managers as game logic grows

## Integration Status

**Last Updated**: January 2025

### Integration Complete ✅

GameFlipModeManager and GameModeSpecificManager have been **fully integrated** into GameService. This integration:
- Reduced GameService from 5,358 lines to 4,705 lines (653 lines removed via manager integration, including GameValidationManager)
- Improved code organization and maintainability
- Maintained full backward compatibility
- All tests passing

### Previously Available Managers

#### 1. GameFlipModeManager

**Location**: `lib/services/game/game_flip_mode_manager.dart`

**State Variables to Replace**:
- `_flippedTiles` → `_flipModeManager.flippedTiles`
- `_flipModeSelectedOrder` → `_flipModeManager.flipModeSelectedOrder`
- `_flipCurrentIndex` → `_flipModeManager.flipCurrentIndex`
- `_flipRevealMode` → `_flipModeManager.flipRevealMode`
- `_flipRevealModeIsInstant` → `_flipModeManager.flipRevealModeIsInstant`
- `_flipSequenceId` → Internal to manager
- `_flipInitialTimer` → Internal to manager
- `_flipPeriodicTimer` → Internal to manager

**Methods to Replace**:
- `setFlipRevealMode()` → `_flipModeManager.setFlipRevealMode()`
- `_loadFlipRevealMode()` → `_flipModeManager.loadFlipRevealMode()`
- `_startFlipSequence()` → `_flipModeManager.startFlipSequence()`
- `_handleFlipModeSelection()` → `_flipModeManager.handleFlipModeSelection()`

**Getters to Update**:
- `flippedTiles` → delegate to manager
- `flipModeSelectedOrder` → delegate to manager
- `flipCurrentIndex` → delegate to manager
- `flipRevealMode` → delegate to manager

#### 2. GameModeSpecificManager

**Location**: `lib/services/game/game_mode_specific_manager.dart`

**State Variables to Replace**:
- `_streakMultiplier` → `_modeSpecificManager.streakMultiplier`
- `_survivalPerfectCount` → `_modeSpecificManager.survivalPerfectCount`
- `_precisionError` → `_modeSpecificManager.precisionError`

**Methods to Replace**:
- Mode-specific scoring logic → `_modeSpecificManager.applyModeScoring()`
- Perfect round handling → `_modeSpecificManager.handlePerfectRound()`
- Non-perfect round handling → `_modeSpecificManager.handleNonPerfectRound()`

**Getters to Update**:
- `streakMultiplier` → delegate to manager
- `survivalPerfectCount` → delegate to manager
- `precisionError` → delegate to manager

### Integration Steps

#### Step 1: Add Imports

```dart
import 'package:n3rd_game/services/game/game_flip_mode_manager.dart';
import 'package:n3rd_game/services/game/game_mode_specific_manager.dart';
```

#### Step 2: Create Manager Instances

Add to GameService class:

```dart
// Manager instances
late final GameFlipModeManager _flipModeManager;
late final GameModeSpecificManager _modeSpecificManager;
```

#### Step 3: Initialize Managers in Constructor

```dart
GameService() {
  // Initialize managers
  _flipModeManager = GameFlipModeManager();
  _modeSpecificManager = GameModeSpecificManager();
  
  // Load flip reveal mode (now via manager)
  _flipModeManager.loadFlipRevealMode().catchError((e) {
    LoggerService.debug('Failed to load flip reveal mode', error: e);
  });
  
  // ... existing initialization code
}
```

#### Step 4: Replace State Variable Declarations

Remove these variable declarations:
- All flip mode variables (lines ~743-755)
- All mode-specific variables (lines ~717-728, but keep competitive challenge vars)

#### Step 5: Replace Getter Methods

Update getters to delegate to managers:

```dart
// Old
List<bool> get flippedTiles => _flippedTiles;

// New
List<bool> get flippedTiles => _flipModeManager.flippedTiles;
```

#### Step 6: Replace Method Implementations

Replace method implementations with manager calls:

```dart
// Old
Future<void> setFlipRevealMode(String mode) async {
  // ... implementation
}

// New
Future<void> setFlipRevealMode(String mode) async {
  await _flipModeManager.setFlipRevealMode(
    mode,
    currentMode: _currentMode,
    phase: _phase,
    isGameOver: _state.isGameOver,
    onNotifyListeners: _safeNotifyListeners,
  );
}
```

#### Step 7: Wire Up Callbacks

Managers need callbacks to interact with GameService. Key callbacks:

**GameFlipModeManager callbacks needed**:
- `onNotifyListeners`: `_safeNotifyListeners`
- `onAddToFlipModeSelectedOrder`: Add to internal list
- `onSubmitFlipModeAnswers`: Submit answers logic
- `onStateUpdate`: Update game state
- `onLifeLost`: Handle life loss
- `onNextRound`: Advance to next round
- `onSaveState`: Save game state
- `onLogAnalyticsEvent`: Log analytics events

**GameModeSpecificManager callbacks needed**:
- `onStateUpdate`: Update game state (for survival mode life grants)
- `onNotifyListeners`: `_safeNotifyListeners`

#### Step 8: Update All References

Search and replace all references throughout GameService:
- `_flippedTiles` → `_flipModeManager.flippedTiles`
- `_flipModeSelectedOrder` → `_flipModeManager.flipModeSelectedOrder`
- `_streakMultiplier` → `_modeSpecificManager.streakMultiplier`
- `_survivalPerfectCount` → `_modeSpecificManager.survivalPerfectCount`
- `_precisionError` → `_modeSpecificManager.precisionError`

#### Step 9: Update Dispose Method

```dart
@override
void dispose() {
  _disposed = true;
  _flipModeManager.dispose();
  _modeSpecificManager.dispose();
  // ... existing dispose code
}
```

#### Step 10: Update State Persistence

Update `_saveState()` and `loadState()` to include manager state:

```dart
// In _saveState()
final stateMap = {
  // ... existing state
  ..._modeSpecificManager.getStateForPersistence(),
  // ... other state
};

// In loadState()
_modeSpecificManager.restoreState(
  extendedStateMap: extendedStateMap,
  currentMode: _currentMode,
);
```

### Key Integration Points

#### Flip Mode Integration Points

1. **Constructor**: Initialize manager and load settings
2. **setFlipRevealMode()**: Delegate to manager
3. **startNewRound()**: Call `_flipModeManager.startFlipSequence()`
4. **toggleTileSelection()**: For flip mode, delegate to `_flipModeManager.handleFlipModeSelection()`
5. **getters**: Delegate all flip mode getters to manager
6. **dispose()**: Call manager dispose

#### Mode-Specific Integration Points

1. **Scoring calculations**: Use `_modeSpecificManager.applyModeScoring()`
2. **Perfect round handling**: Use `_modeSpecificManager.handlePerfectRound()`
3. **Non-perfect round handling**: Use `_modeSpecificManager.handleNonPerfectRound()`
4. **State persistence**: Include manager state in save/load
5. **getters**: Delegate all mode-specific getters to manager
6. **Precision error handling**: Use `_modeSpecificManager.setPrecisionError()`

### Testing Strategy

After integration:

1. **Unit Tests**: Run existing manager tests (already passing ✅)
2. **Integration Tests**: Test GameService with integrated managers
3. **Manual Testing**: Test all game modes (especially Flip, Streak, Survival, Precision)
4. **State Persistence**: Verify save/load works correctly
5. **Edge Cases**: Test mode switching, disposal, error handling

### Estimated Impact

- **Lines Removed**: ~900-1000 lines from GameService
- **Lines Added**: ~100-200 lines (manager initialization, delegation)
- **Net Reduction**: ~700-900 lines
- **Final Size**: ~4400-4600 lines (target <5000 lines)

### Risks and Considerations

1. **Callback Complexity**: Managers need many callbacks - ensure all are properly wired
2. **State Synchronization**: Ensure manager state stays in sync with GameService
3. **Breaking Changes**: Changes to manager interfaces will require GameService updates
4. **Testing**: Extensive testing required to ensure no regressions

### Integration Status

**Note**: Integration is an **optional optimization**, not a requirement. The managers are complete, fully functional, and comprehensively tested. GameService works fine without integration. This guide is available for when/if integration is desired in the future.

**Status**: Integration optional ⏭️  
**Managers**: Created, tested, and available as standalone utilities ✅  
**Integration**: Optional optimization - can be done when needed (large refactoring task)

---

**Last Updated:** January 2025

