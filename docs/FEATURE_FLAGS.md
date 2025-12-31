# Feature Flags Documentation

## Overview

This document describes the feature flag system used in the N3RD Trivia Game application. Feature flags allow for dynamic control of app features without requiring app updates.

**Last Updated**: January 2025  
**Status**: Production Ready

---

## Table of Contents

1. [Overview](#overview)
2. [FeatureFlagService](#featureflagservice)
3. [Using Feature Flags](#using-feature-flags)
4. [Firebase Remote Config Setup](#firebase-remote-config-setup)
5. [Best Practices](#best-practices)
6. [Examples](#examples)

---

## Overview

Feature flags provide:
- **Dynamic Feature Control**: Enable/disable features without app updates
- **A/B Testing**: Test features with subsets of users
- **Gradual Rollouts**: Gradually enable features for all users
- **Emergency Kill Switches**: Quickly disable problematic features
- **Environment-Specific Features**: Different features for dev/staging/production

### Implementation

The feature flag system uses:
- **Firebase Remote Config**: Remote configuration management
- **Local Cache**: Offline support and fallback values
- **FeatureFlagService**: Centralized feature flag management

---

## FeatureFlagService

### Location

`lib/services/feature_flag_service.dart`

### Initialization

The service is initialized in `AppInitializer`:

```dart
await FeatureFlagService().init();
```

### Methods

#### `isFeatureEnabled(String key, {bool defaultValue = false})`

Check if a feature is enabled:

```dart
final isEnabled = FeatureFlagService().isFeatureEnabled('new_game_mode');
if (isEnabled) {
  // Show new game mode
}
```

#### `getString(String key, {String defaultValue = ''})`

Get a string feature flag:

```dart
final apiUrl = FeatureFlagService().getString('api_url', defaultValue: 'https://api.example.com');
```

#### `getInt(String key, {int defaultValue = 0})`

Get an integer feature flag:

```dart
final maxPlayers = FeatureFlagService().getInt('max_players', defaultValue: 4);
```

#### `getDouble(String key, {double defaultValue = 0.0})`

Get a double feature flag:

```dart
final difficulty = FeatureFlagService().getDouble('difficulty', defaultValue: 0.5);
```

#### `setFeatureFlag(String key, dynamic value)`

Set a feature flag locally (for testing):

```dart
await FeatureFlagService().setFeatureFlag('test_feature', true);
```

---

## Using Feature Flags

### Basic Usage

```dart
import 'package:n3rd_game/services/feature_flag_service.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final featureFlagService = FeatureFlagService();
    
    if (featureFlagService.isFeatureEnabled('new_ui')) {
      return NewUIWidget();
    } else {
      return OldUIWidget();
    }
  }
}
```

### With Default Values

```dart
final showBetaFeatures = FeatureFlagService().isFeatureEnabled(
  'beta_features',
  defaultValue: false,
);
```

### Conditional Rendering

```dart
Widget build(BuildContext context) {
  return Column(
    children: [
      // Always show
      StandardWidget(),
      
      // Conditionally show
      if (FeatureFlagService().isFeatureEnabled('premium_features'))
        PremiumWidget(),
    ],
  );
}
```

---

## Firebase Remote Config Setup

### 1. Create Feature Flags in Firebase Console

1. Go to Firebase Console → Remote Config
2. Click "Add parameter"
3. Set parameter key (e.g., `new_game_mode`)
4. Set default value (e.g., `false` for boolean)
5. Save

### 2. Configure Fetch Interval

The service is configured to:
- Fetch timeout: 1 minute
- Minimum fetch interval: 1 hour

This can be adjusted in `FeatureFlagService.init()`:

```dart
await _remoteConfig.setConfigSettings(RemoteConfigSettings(
  fetchTimeout: const Duration(minutes: 1),
  minimumFetchInterval: const Duration(hours: 1),
));
```

### 3. Set Feature Flag Values

#### Boolean Flags

```json
{
  "new_game_mode": true,
  "beta_features": false,
  "premium_ui": true
}
```

#### String Flags

```json
{
  "api_url": "https://api.example.com",
  "cdn_url": "https://cdn.example.com"
}
```

#### Numeric Flags

```json
{
  "max_players": 8,
  "difficulty": 0.7,
  "time_limit": 60
}
```

---

## Best Practices

### 1. Naming Conventions

Use descriptive, consistent names:
- ✅ `new_game_mode`
- ✅ `premium_features`
- ✅ `beta_ui`
- ❌ `flag1`
- ❌ `test`

### 2. Default Values

Always provide sensible defaults:
```dart
final isEnabled = FeatureFlagService().isFeatureEnabled(
  'new_feature',
  defaultValue: false, // Safe default
);
```

### 3. Feature Flag Lifecycle

1. **Development**: Feature flag created, default `false`
2. **Testing**: Feature flag enabled for test users
3. **Staging**: Feature flag enabled for staging environment
4. **Production**: Feature flag gradually enabled
5. **Cleanup**: Remove feature flag after feature is stable

### 4. Avoid Feature Flag Sprawl

- Remove feature flags after features are stable
- Don't use feature flags for configuration (use `AppConfig`)
- Don't use feature flags for A/B testing (use dedicated service)

### 5. Testing

Test with feature flags enabled and disabled:
```dart
testWidgets('Feature works when enabled', (tester) async {
  await FeatureFlagService().setFeatureFlag('new_feature', true);
  // Test with feature enabled
});

testWidgets('Feature hidden when disabled', (tester) async {
  await FeatureFlagService().setFeatureFlag('new_feature', false);
  // Test with feature disabled
});
```

---

## Examples

### Example 1: Conditional Feature Display

```dart
class GameScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final showNewMode = FeatureFlagService().isFeatureEnabled('new_game_mode');
    
    return Column(
      children: [
        if (showNewMode)
          NewGameModeButton(),
        StandardGameModeButton(),
      ],
    );
  }
}
```

### Example 2: Dynamic Configuration

```dart
class ApiClient {
  final String baseUrl;
  
  ApiClient() : baseUrl = FeatureFlagService().getString(
    'api_url',
    defaultValue: 'https://api.default.com',
  );
}
```

### Example 3: Gradual Rollout

```dart
class FeatureManager {
  static bool shouldShowFeature(String userId) {
    final isEnabled = FeatureFlagService().isFeatureEnabled('new_feature');
    if (!isEnabled) return false;
    
    // Gradual rollout: enable for 10% of users
    final hash = userId.hashCode % 100;
    return hash < 10;
  }
}
```

---

## Related Documentation

- [Service Architecture](./ARCHITECTURE.md#service-architecture)
- [App Configuration](./ARCHITECTURE.md)
- [Firebase Setup](./SETUP_GUIDE.md)

---

**Last Updated**: January 2025  
**Status**: Production Ready

