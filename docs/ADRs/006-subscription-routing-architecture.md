# ADR-006: Subscription Routing Architecture

**Status**: Accepted  
**Date**: 2024  
**Deciders**: Development Team

## Context

The application has multiple subscription tiers (Free, Basic, Premium, Family & Friends) with different feature access levels. We needed a centralized, maintainable way to enforce subscription requirements across all screens and features.

## Decision

We implemented a **centralized subscription routing architecture** using `RouteGuard` and `SubscriptionGuard`:

1. **RouteGuard Widget**:
   - Wraps protected screens at the route level
   - Checks subscription access before rendering
   - Shows upgrade dialog if access denied
   - Handles all subscription-related UI consistently

2. **SubscriptionGuard Utility**:
   - Centralized logic for access checking
   - Provides consistent tier name and benefits
   - Single source of truth for subscription rules

3. **SubscriptionService Integration**:
   - `hasEditionsAccess` - Premium/Family & Friends
   - `hasOnlineAccess` - Premium/Family & Friends
   - `hasAllModesAccess` - Basic and above
   - `isPremium`, `isFamilyFriends` - Tier checks

4. **Route-Level Protection**:
   - All premium routes wrapped in `main.dart`
   - Consistent upgrade prompts
   - Analytics tracking for upgrade attempts

### Rationale

- **Single Source of Truth**: All subscription logic in one place
- **Maintainability**: Easy to update subscription rules
- **Consistency**: Same upgrade experience everywhere
- **Type Safety**: Compile-time checks for subscription requirements
- **Analytics**: Centralized tracking of upgrade attempts

## Consequences

### Positive

- Easy to add new protected features
- Consistent user experience
- Reduced code duplication
- Centralized analytics tracking
- Type-safe subscription checks

### Negative

- All routes must be explicitly protected
- Requires understanding of subscription tiers
- Potential performance overhead (minimal)

### Mitigation

- Clear documentation of subscription tiers
- Route protection enforced at compile time
- Efficient subscription checks (cached in service)
- Regular audits of route protection

## Implementation

```dart
// Route definition with protection
'/analytics': (context) => const RouteGuard(
  requiresPremium: true,
  featureName: 'Analytics Dashboard',
  child: AnalyticsDashboardScreen(),
),

// Utility for access checking
SubscriptionGuard.canAccessFeature(
  subscriptionService: subscriptionService,
  requiresPremium: true,
)
```

## Related ADRs

- ADR-003: State Persistence Strategy (subscription state)
- ADR-004: Error Recovery Mechanisms (upgrade dialogs)







