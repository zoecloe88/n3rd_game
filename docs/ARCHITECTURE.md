# Architecture Overview

## Service Architecture

This project follows a **service-oriented architecture** with dependency injection via Provider.

### Core Services

1. **GameService** - Core game logic and state management
2. **TriviaGeneratorService** - Trivia question generation
3. **SubscriptionService** - Premium feature management
4. **AuthService** - User authentication
5. **AnalyticsService** - Event tracking and analytics

### Service Lifecycle

All services that extend `ChangeNotifier` must:
1. Implement `init()` if async initialization is needed
2. Implement `dispose()` for cleanup
3. Be registered in `main.dart` MultiProvider

### Dependency Injection

Services are provided via Provider and can be accessed using:
```dart
final service = Provider.of<SomeService>(context, listen: false);
```

## State Management

### Immutable State Pattern

Game state uses immutable objects (`GameState`, `TriviaItem`) to prevent:
- Accidental mutations
- Race conditions
- State synchronization issues

### State Updates

State changes happen through:
- `copyWith()` for immutable objects
- `notifyListeners()` for ChangeNotifier services
- Proper async/await for state persistence

## Error Handling

### Multi-Layer Error Handling

1. **Service Level**: Try-catch with logging
2. **UI Level**: Error boundaries and user-friendly messages
3. **Analytics Level**: Crashlytics integration

### Error Recovery

- Services degrade gracefully on errors
- User-facing errors show recovery options
- All errors are logged for debugging

## Performance Optimization

### Caching Strategy

- Animation paths cached after first lookup
- Trivia templates loaded once at startup
- State persistence uses debouncing

### Lazy Loading

- Services initialize on-demand
- Animations loaded as needed
- Templates parsed only when required

## Testing Strategy

### Unit Tests
- Service logic
- State management
- Utility functions

### Integration Tests
- Service interactions
- Game flows
- User journeys

### Widget Tests
- UI components
- State updates
- User interactions

## Code Organization

### Directory Structure

```
lib/
├── models/          # Data models
├── services/        # Business logic services
├── screens/         # UI screens
├── widgets/         # Reusable widgets
├── config/          # Configuration constants
├── data/            # Static data (templates, etc.)
└── utils/           # Utility functions
```

### Naming Conventions

- Services: `*Service` (e.g., `GameService`)
- Models: PascalCase (e.g., `GameState`)
- Screens: `*Screen` (e.g., `TitleScreen`)
- Widgets: `*Widget` (e.g., `UnifiedBackgroundWidget`, `VideoPlayerWidget`)

## Best Practices

1. **Always validate inputs** - Never trust external data
2. **Handle errors gracefully** - Never crash silently
3. **Dispose resources** - Prevent memory leaks
4. **Document public APIs** - Help future developers
5. **Write tests** - Ensure code quality


