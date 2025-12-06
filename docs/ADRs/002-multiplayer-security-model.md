# ADR-002: Multiplayer Security Model

**Status**: Accepted  
**Date**: 2024  
**Deciders**: Development Team

## Context

Multiplayer game rooms require secure access control. Firestore security rules cannot easily check nested objects in arrays (like the `players` array containing `Player` objects). We needed a security model that:
1. Prevents unauthorized access to game rooms
2. Validates player membership before allowing game actions
3. Provides defense-in-depth security

## Decision

We implemented a **defense-in-depth** security model with two layers:

1. **Firestore Rules Layer**: Provides status-based access control
   - Rooms in `waiting` status: Readable by authenticated users (for discovery)
   - Rooms in `inProgress` or `starting`: Updatable by authenticated users
   - Hosts can always read/update/delete their rooms

2. **Application Logic Layer**: Provides membership validation
   - `MultiplayerService.validatePlayerMembership()` checks if user is host or in players array
   - Called before allowing any game room operations
   - Validates player membership before updates

### Rationale

- Firestore rules cannot easily check nested array objects
- Application-level validation provides necessary membership checks
- Defense-in-depth ensures security even if one layer is bypassed
- Status-based rules provide first line of defense

## Consequences

### Positive

- Secure access control with multiple layers
- Flexible - can add additional validation layers
- Clear separation of concerns (rules vs. logic)
- Prevents unauthorized room access

### Negative

- Requires careful coordination between rules and app logic
- App-level validation must be consistently applied
- More complex than single-layer security

### Mitigation

- Comprehensive code review for all multiplayer operations
- Clear documentation of security model
- Regular security audits
- Consistent use of `validatePlayerMembership()` before operations


