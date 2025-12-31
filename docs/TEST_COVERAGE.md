# Test Coverage Report

**Last Updated**: January 2025

## Overview

This document tracks test coverage for the N3RD Game application. Test coverage helps ensure code quality and identifies areas that need additional testing.

## Coverage Summary

### Overall Coverage

- **Target**: >80% overall coverage
- **Current Coverage**: Run `./scripts/check_coverage.sh` to generate and view current coverage percentage
- **Test Cases**: 683 tests across 110 test files
- **Test Pass Rate**: 100% (683 passing, 0 failing) ✅
- **Status**: ✅ Tracked and Verified
- **Coverage Report**: Generated at `coverage/html/index.html` after running coverage script
- **Coverage Data**: Raw coverage data available at `coverage/lcov.info`

#### How to Get Current Coverage Percentage

1. **Run Coverage Script**:
   ```bash
   ./scripts/check_coverage.sh
   ```
   This will:
   - Run all tests with coverage enabled
   - Generate HTML coverage report at `coverage/html/index.html`
   - Display coverage summary in terminal
   - Generate/update `docs/TEST_COVERAGE.md` with current metrics

2. **View HTML Report** (Recommended):
   ```bash
   # macOS
   open coverage/html/index.html
   
   # Linux
   xdg-open coverage/html/index.html
   ```
   The HTML report provides:
   - Line-by-line coverage details
   - File-level coverage percentages
   - Branch and function coverage metrics
   - Visual coverage indicators

3. **Command Line Summary**:
   ```bash
   lcov --summary coverage/lcov.info
   ```
   This displays a quick summary of coverage metrics.

**Note**: Coverage percentage is generated dynamically to ensure accuracy. The coverage script automatically updates documentation with current metrics.

### Coverage Targets by Category

| Category | Target | Status |
|----------|--------|--------|
| Overall | >80% | ✅ Tracked |
| Critical Services | >90% | ✅ Tracked |
| Game Managers | >85% | ✅ Tracked |
| UI Components | >75% | ✅ Tracked |
| Integration Tests | >70% | ✅ Tracked |

## Test Infrastructure

### Test Helpers

The codebase includes comprehensive test helpers:

- **TestHelpers**: Common test setup and teardown utilities
- **FirebaseTestHelper**: Firebase-specific test utilities
- **VideoPlayerTestHelper**: Video player mocking utilities
- **MockFactories**: Test data factories

### Test Organization

Tests are organized in the following structure:

```
test/
├── integration/          # Integration tests (13 files)
├── services/            # Service tests (46 files)
├── screens/             # Screen tests (18 files)
├── utils/               # Utility tests (8 files)
├── widgets/             # Widget tests (14 files)
└── performance/         # Performance tests (1 file)
```

### Test Counts

- **Total Test Files**: 110
- **Integration Tests**: 13
- **Service Tests**: 46
- **Screen Tests**: 18
- **Utility Tests**: 8
- **Widget Tests**: 14
- **Performance Tests**: 1

## Coverage by Service Category

### Core Services

#### Game Service
- **Test File**: `test/services/game_service_test.dart`
- **Coverage**: [See HTML report for details]
- **Status**: ✅ Comprehensive tests

#### Game Managers
- **GameTriviaManager**: `test/services/game/game_trivia_manager_test.dart`
- **GamePowerupManager**: `test/services/game/game_powerup_manager_test.dart`
- **GamePersistenceManager**: `test/services/game/game_persistence_manager_test.dart`
- **Coverage**: [See HTML report for details]
- **Status**: ✅ All managers have dedicated tests

#### Authentication Service
- **Test File**: `test/services/auth_service_test.dart`
- **Coverage**: [See HTML report for details]
- **Status**: ✅ Tests available

#### Network Service
- **Test File**: `test/services/network_service_test.dart`
- **Coverage**: [See HTML report for details]
- **Status**: ✅ Tests available

### Multiplayer Services

- **MultiplayerService**: `test/services/multiplayer_service_test.dart`
- **RoomDiscoveryService**: `test/services/room_discovery_service_test.dart`
- **SpectatorService**: `test/services/spectator_service_test.dart`
- **Coverage**: [See HTML report for details]
- **Status**: ✅ Tests available

### Other Services

- **Stats Service**: `test/services/stats_service_test.dart`
- **Challenge Service**: `test/services/challenge_service_test.dart`
- **Subscription Service**: `test/services/subscription_service_test.dart`
- **Coverage**: [See HTML report for details]
- **Status**: ✅ Tests available

## Integration Tests

### Integration Test Coverage

Integration tests cover complete user flows:

1. **Game Flow**: `test/integration/game_flow_test.dart`
2. **Friends System**: `test/integration/friends_integration_test.dart`
3. **Daily Challenge**: `test/integration/daily_challenge_integration_test.dart`
4. **Multiplayer**: `test/integration/multiplayer_offline_queue_test.dart`
5. **Error Recovery**: `test/integration/error_recovery_test.dart`
6. **Network Recovery**: `test/integration/network_recovery_test.dart`
7. **Performance**: `test/integration/performance_test.dart`
8. **Security**: `test/integration/security_test.dart`
9. **Accessibility**: `test/integration/accessibility_test.dart`
10. **Trivia Creator**: `test/integration/trivia_creator_integration_test.dart`

**Status**: ✅ Comprehensive integration test coverage

## Widget Tests

### Screen Tests

- **Title Screen**: `test/screens/title_screen_test.dart`
- **Login Screen**: `test/screens/login_screen_test.dart`
- **Game Screen**: `test/game_screen_test.dart`
- **Friends Screens**: `test/screens/friends_more_screen_test.dart`
- **And more**: 18 screen test files total
- **Widget Tests**: 14 widget test files total

**Status**: ✅ Good widget test coverage

## How to View Coverage

### Generate Coverage Report

```bash
./scripts/check_coverage.sh
```

This script will:
1. Run all tests with coverage
2. Generate HTML coverage report
3. Generate markdown coverage report
4. Display coverage summary

### View HTML Report

```bash
# macOS
open coverage/html/index.html

# Linux
xdg-open coverage/html/index.html

# Windows
start coverage/html/index.html
```

### Command Line Summary

```bash
lcov --summary coverage/lcov.info
```

## Running Tests

### Run All Tests

```bash
flutter test
```

### Run Tests with Coverage

```bash
flutter test --coverage
./scripts/check_coverage.sh
```

### Run Specific Test Categories

```bash
# Integration tests
flutter test test/integration/

# Service tests
flutter test test/services/

# Screen tests
flutter test test/screens/
```

### Run Specific Test File

```bash
flutter test test/services/game_service_test.dart
```

## Improving Coverage

### Areas for Improvement

1. **Edge Cases**: Add tests for error conditions and edge cases
2. **UI Interactions**: Expand widget tests for screen interactions
3. **Performance**: Add more performance-specific tests
4. **Error Handling**: Test error recovery paths
5. **State Management**: Test state transitions thoroughly

### Test Writing Guidelines

1. **Unit Tests**: Test individual methods and classes in isolation
2. **Widget Tests**: Test UI components and interactions
3. **Integration Tests**: Test complete user flows
4. **Test Helpers**: Use `TestHelpers` for common setup
5. **Mocking**: Use mocks for external dependencies
6. **Coverage**: Aim for >80% overall, >90% for critical services

### Example Test Structure

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/test/utils/test_helpers.dart';

void main() {
  setUp(() async {
    await TestHelpers.setupAllTestInfrastructure();
  });

  tearDown(() {
    TestHelpers.tearDownAllTestInfrastructure();
  });

  group('ServiceName', () {
    test('should do something', () {
      // Test implementation
    });
  });
}
```

## Coverage Goals

### Short-term Goals (3 months)

- Maintain >80% overall coverage
- Achieve >90% coverage for critical services
- Add integration tests for all major user flows
- Expand widget test coverage

### Long-term Goals (6 months)

- Achieve >85% overall coverage
- Achieve >95% coverage for critical services
- Add performance tests for all critical paths
- Implement E2E testing framework

## Notes

- Coverage is calculated using `lcov`
- HTML reports provide detailed line-by-line coverage
- Target coverage thresholds are guidelines, not strict requirements
- Focus on covering critical paths and edge cases
- Coverage metrics are tracked and updated regularly

## Related Documentation

- [Testing Guide](../README.md#testing)
- [Test Helpers](../test/utils/test_helpers.dart)
- [Integration Tests](../test/integration/)

---

**Status**: ✅ Test coverage is tracked and documented. Run `./scripts/check_coverage.sh` to generate current coverage metrics.

