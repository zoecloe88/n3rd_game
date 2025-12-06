# ADR-003: State Persistence Strategy

**Status**: Accepted  
**Date**: 2024  
**Deciders**: Development Team

## Context

Game state must be persisted to allow players to resume games after app restarts or crashes. We needed to decide:
1. What state to persist (core vs. extended)
2. How to handle save failures
3. How to ensure data integrity

## Decision

We implemented a **two-tier state persistence** strategy:

1. **Core State** (Critical - must succeed):
   - Score, lives, round, game over status, perfect streak
   - Saved first, failure prevents entire save
   - Retry with exponential backoff (3 attempts)

2. **Extended State** (Best-effort - failure doesn't fail entire save):
   - Power-ups, competitive challenge state, mode-specific state
   - Round-level state (phase, trivia, selections, timers)
   - Saved after core state, failure logged but doesn't fail save

### Rationale

- Core state is essential for game continuity
- Extended state enhances experience but isn't critical
- Best-effort approach ensures core state always saves
- Separate failure tracking allows targeted user notifications

## Consequences

### Positive

- Core game progress always preserved
- Enhanced features (power-ups, timers) preserved when possible
- Clear failure handling and user notifications
- Performance tracking for monitoring

### Negative

- More complex save logic
- Requires careful error handling
- Extended state may be lost in some scenarios

### Mitigation

- Comprehensive error logging and analytics
- User notifications for persistent failures
- Performance monitoring to identify issues early
- Retry mechanisms with exponential backoff


