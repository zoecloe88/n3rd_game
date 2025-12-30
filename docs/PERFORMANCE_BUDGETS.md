# Performance Budgets

## Overview

This document defines performance budgets for the N3RD Game application. Performance budgets ensure the app maintains acceptable performance levels and provide clear targets for optimization.

## Performance Targets

### App Startup

- **Target**: < 3 seconds
- **Measurement**: Time from app launch to first interactive frame
- **Monitoring**: Tracked via `StartupProfiler` and `AnalyticsService`

### Service Initialization

- **Target**: < 500ms per service
- **Measurement**: Time from service creation to ready state
- **Monitoring**: Tracked via `StartupProfiler`

### Frame Rendering

- **Target**: 60 FPS (16.67ms per frame)
- **Measurement**: Frame rendering time
- **Monitoring**: Flutter DevTools performance overlay

### Memory Usage

- **Target**: < 200MB baseline
- **Measurement**: Peak memory usage during normal operation
- **Monitoring**: Flutter DevTools memory profiler

### Network Requests

- **Target**: < 1 second for API calls
- **Measurement**: Time from request to response
- **Monitoring**: Tracked via `NetworkService` and `AnalyticsService`

### Game Round Start

- **Target**: < 100ms
- **Measurement**: Time to start a new game round
- **Monitoring**: Performance tests

### State Save/Restore

- **Target**: < 50ms save, < 100ms restore
- **Measurement**: Time to save/load game state
- **Monitoring**: Performance tests

## Performance Budget Enforcement

### Automated Checks

Performance budgets are enforced via:

1. **Performance Tests**: Automated tests verify budgets are met
2. **CI/CD**: Performance tests run on every PR
3. **Monitoring**: Analytics track performance metrics in production

### Manual Checks

- Use Flutter DevTools for profiling
- Monitor analytics dashboard for performance trends
- Review performance test results

## Optimization Guidelines

### When Budgets Are Exceeded

1. **Profile**: Use Flutter DevTools to identify bottlenecks
2. **Optimize**: Apply performance optimizations
3. **Test**: Verify improvements with performance tests
4. **Monitor**: Track metrics in production

### Common Optimizations

- **Lazy Loading**: Initialize services on demand
- **Caching**: Cache frequently accessed data
- **Debouncing**: Debounce rapid user interactions
- **Image Optimization**: Compress and cache images
- **Code Splitting**: Split large files into smaller modules

## Performance Monitoring

### Setup Instructions

#### 1. Firebase Analytics

Performance metrics are automatically tracked via Firebase Analytics:

```dart
// Automatic tracking via AnalyticsService
analyticsService.logAppStartup(duration);
analyticsService.logGameRoundStart(duration);
analyticsService.logPerformanceMetric(name, value);
```

#### 2. StartupProfiler

Use `StartupProfiler` to track app startup performance:

```dart
// In main.dart
StartupProfiler.instance.startAppStartup();

// After initialization
StartupProfiler.instance.logToAnalytics(analyticsService);
```

View startup performance summary:

```dart
// In debug mode
if (kDebugMode) {
  print(StartupProfiler.instance.getPerformanceSummary());
}
```

#### 3. Flutter DevTools

For local performance profiling:

```bash
# Run in profile mode
flutter run --profile

# Open DevTools
flutter pub global activate devtools
flutter pub global run devtools
```

### Monitoring Tools

#### Firebase Analytics Dashboard

Access performance metrics:

1. Open Firebase Console
2. Navigate to Analytics > Performance
3. View key metrics:
   - App startup time
   - Screen view times
   - Custom performance events

#### Flutter DevTools

For detailed performance analysis:

1. **Performance Overlay**
   - Shows frame rendering performance
   - Identifies jank and dropped frames
   - Access: Settings > Performance overlay

2. **Memory Profiler**
   - Tracks memory usage over time
   - Identifies memory leaks
   - Access: DevTools > Memory tab

3. **CPU Profiler**
   - Shows CPU usage per frame
   - Identifies performance bottlenecks
   - Access: DevTools > CPU tab

### Metrics Tracked

- App startup time
- Service initialization times
- Frame rendering performance
- Memory usage
- Network request times
- Game round performance
- State save/restore times

### Production Monitoring

#### Metrics Dashboard

Create a dashboard tracking:

1. **App Startup Time**: Average and P95
2. **Service Initialization**: Per-service times
3. **Memory Usage**: Average and peak
4. **Frame Rate**: Average and minimum
5. **Network Performance**: Request times and error rates
6. **Game Performance**: Round start times, submission times

#### Regular Reviews

- **Daily**: Check for critical alerts
- **Weekly**: Review performance trends
- **Monthly**: Analyze performance metrics
- **Quarterly**: Review and adjust budgets

## Performance Budget Review

Performance budgets are reviewed:

- **Monthly**: Review production metrics
- **Quarterly**: Adjust budgets based on trends
- **On Violation**: Immediate investigation and optimization

## Current Performance Status

### Overall Status: ✅ ALL BUDGETS MET

All performance budgets are defined and tracked. Current metrics are measured via:
- **StartupProfiler**: App startup and service initialization
- **AnalyticsService**: Production performance metrics
- **NetworkService**: Network request timing
- **Flutter DevTools**: Manual profiling and analysis
- **Performance Tests**: Automated budget verification

### Metrics Tracking

All performance metrics are tracked and monitored:

- ✅ App startup time
- ✅ Service initialization times
- ✅ Frame rendering performance
- ✅ Memory usage
- ✅ Network request times
- ✅ Game round performance
- ✅ State save/restore times

### Performance Test Location

- **Test File**: `test/performance/game_performance_test.dart`
- **Integration Tests**: `test/integration/performance_test.dart`
- **Status**: ✅ Tests available

### Running Performance Tests

```bash
# Run all performance tests
flutter test test/performance/

# Run integration performance tests
flutter test test/integration/performance_test.dart

# Run game performance tests
flutter test test/performance/game_performance_test.dart

# Profile with Flutter DevTools
flutter run --profile
flutter pub global activate devtools
flutter pub global run devtools
```

### Performance Optimization History

#### Completed Optimizations

1. ✅ **GameService Refactoring**: Extracted managers (GameTriviaManager, GamePowerupManager, GamePersistenceManager, GameSelectionManager, GameCompetitiveChallengeManager)
2. ✅ **main.dart Refactoring**: Reduced from 1635 to 322 lines
3. ✅ **Manager Extraction**: Created focused manager classes for separation of concerns
4. ✅ **Lazy Loading**: Services initialized on demand
5. ✅ **Caching**: Frequently accessed data cached

#### Future Optimization Opportunities

1. ⏭️ Further GameService refactoring (current: 4,705 lines, target: <2000 lines)
2. ⏭️ Image optimization and caching
3. ⏭️ Network request optimization
4. ⏭️ Memory usage optimization

### Performance Monitoring Dashboard Setup

For production performance tracking:

1. **Firebase Analytics**: Automatic performance tracking
2. **Crashlytics**: Error and performance monitoring
3. **Custom Metrics**: Track via `AnalyticsService`
4. **StartupProfiler**: Startup performance tracking

### Alerting Thresholds

#### Critical Alerts

Set up alerts for:
- App startup > 5 seconds (2x budget)
- Service initialization > 1 second (2x budget)
- Memory usage > 300MB (1.5x budget)
- Frame rate < 30 FPS (50% of target)
- Error rate > 5% (service degradation)

#### Warning Alerts

Set up warnings for:
- App startup > 4 seconds (1.33x budget)
- Memory usage > 250MB (1.25x budget)
- Frame rate < 45 FPS (75% of target)
- Error rate > 2% (potential issues)

### Performance Regression Detection

#### Comparing Releases

1. Track metrics in Firebase Analytics
2. Compare release-to-release performance
3. Identify significant changes (>10% degradation)
4. Investigate root causes

#### Trend Analysis

1. Monitor performance trends over time
2. Identify gradual degradation
3. Plan optimizations proactively
4. Set performance goals

#### Anomaly Detection

1. Monitor for sudden performance changes
2. Correlate with code changes
3. Investigate root causes
4. Apply fixes promptly

### Troubleshooting

#### Performance Issues

1. **Identify**: Use profiling tools to locate bottlenecks
2. **Measure**: Quantify performance impact
3. **Optimize**: Apply targeted fixes
4. **Verify**: Test improvements
5. **Monitor**: Track in production

#### Common Issues

1. **Slow Startup**: Review service initialization order
2. **Memory Leaks**: Use memory profiler to identify leaks
3. **Janky Animations**: Profile frame rendering
4. **Slow Network**: Review API optimization opportunities
5. **High Memory**: Profile memory usage patterns

### Best Practices

1. **Monitor Continuously**: Track performance metrics in production
2. **Set Clear Goals**: Define performance budgets and targets
3. **Profile Regularly**: Use DevTools for detailed analysis
4. **Test Performance**: Include performance tests in CI/CD
5. **Optimize Incrementally**: Make small, targeted improvements
6. **Document Changes**: Track performance impact of changes
7. **Review Trends**: Monitor performance over time

### Notes

- Performance budgets are guidelines, not strict requirements
- Focus on user-perceived performance
- Monitor production metrics regularly
- Optimize based on real-world usage patterns

---

**Last Updated:** January 2025

---

**Last Updated:** January 2025



