# Code Complexity Metrics

## Overview

This document describes code complexity metrics, thresholds, and refactoring recommendations for the N3RD Game application.

## Complexity Metrics

### Cyclomatic Complexity

Cyclomatic complexity measures the number of linearly independent paths through code.

**Thresholds:**
- **1-10**: Simple (acceptable)
- **11-20**: Moderate (review recommended)
- **21-50**: Complex (refactor recommended)
- **50+**: Very complex (refactor required)

### File Size

**Thresholds:**
- **< 500 lines**: Small (ideal)
- **500-1000 lines**: Medium (acceptable)
- **1000-2000 lines**: Large (review recommended)
- **> 2000 lines**: Very large (refactor required)

### Class Complexity

**Thresholds:**
- **< 20 methods**: Simple (ideal)
- **20-50 methods**: Moderate (acceptable)
- **50-100 methods**: Complex (review recommended)
- **> 100 methods**: Very complex (refactor required)

### Method Length

**Thresholds:**
- **< 20 lines**: Short (ideal)
- **20-50 lines**: Medium (acceptable)
- **50-100 lines**: Long (review recommended)
- **> 100 lines**: Very long (refactor required)

## Current Complexity Status

### High Complexity Areas

1. **GameService** (4,705 lines)
   - **Status**: Refactored into modular services
   - **Action**: Split into focused managers
   - **Progress**: GameTriviaManager, GamePowerupManager, GamePersistenceManager, GameSelectionManager, GameCompetitiveChallengeManager, GameFlipModeManager, GameModeSpecificManager, and GameValidationManager integrated
   - **Reduction**: Reduced from 5,358 lines to 4,705 lines (653 lines reduced via manager integration, including GameValidationManager)
   - **Note**: Further refactoring opportunities exist for additional complexity reduction

2. **main.dart** (256 lines)
   - **Status**: Refactored
   - **Action**: Extract initialization logic
   - **Progress**: RouteBuilder, DeepLinkHandler, and AppErrorHandler created

## Refactoring Recommendations

### 1. Extract Methods

**Before:**
```dart
void complexMethod() {
  // 100+ lines of code
  if (condition1) {
    if (condition2) {
      if (condition3) {
        // Complex nested logic
      }
    }
  }
}
```

**After:**
```dart
void complexMethod() {
  if (!shouldProcess()) return;
  processData();
  handleResults();
}

bool shouldProcess() {
  return condition1 && condition2 && condition3;
}
```

### 2. Extract Classes

**Before:**
```dart
class LargeService {
  // 2000+ lines
  // Many responsibilities
}
```

**After:**
```dart
class LargeService {
  final _stateManager = StateManager();
  final _timerManager = TimerManager();
  // Delegate to focused services
}
```

### 3. Use Composition

**Before:**
```dart
class ServiceA extends ServiceB {
  // Inheritance creates tight coupling
}
```

**After:**
```dart
class ServiceA {
  final ServiceB _serviceB;
  // Composition provides flexibility
}
```

## Complexity Analysis Tools

### Automated Analysis

```bash
# Run complexity analysis
./scripts/analyze_complexity.sh

# Run Dart analyzer
dart analyze

# Check file sizes
find lib/ -name "*.dart" -exec wc -l {} \; | sort -n
```

### Manual Review

- Review code during PR process
- Identify complex methods
- Suggest refactoring opportunities
- Track complexity trends

## Complexity Reduction Strategies

### 1. Single Responsibility Principle

Each class/method should have one reason to change.

### 2. Extract Common Patterns

Identify repeated patterns and extract them.

### 3. Use Design Patterns

- **Strategy**: For interchangeable algorithms
- **Factory**: For object creation
- **Observer**: For event handling
- **Facade**: For simplifying complex subsystems

### 4. Reduce Nesting

Use early returns and guard clauses.

### 5. Break Large Methods

Split large methods into smaller, focused methods.

## Monitoring Complexity

### Regular Reviews

- **Weekly**: Review new code for complexity
- **Monthly**: Analyze complexity trends
- **Quarterly**: Refactor high-complexity areas

### CI/CD Integration

- Run complexity analysis on every PR
- Fail PR if complexity exceeds thresholds
- Track complexity metrics over time

## Complexity Goals

### Short-term (3 months)

- Reduce GameService to < 2000 lines
- Reduce main.dart to < 500 lines
- All new code < 20 cyclomatic complexity

### Long-term (6 months)

- All files < 1000 lines
- All classes < 50 methods
- All methods < 50 lines
- Average cyclomatic complexity < 10

---

**Last Updated:** January 2025



