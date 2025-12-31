/// Helper function to mark futures as intentionally unawaited
///
/// This function satisfies the linter's requirement to explicitly mark
/// futures that are intentionally not awaited (fire-and-forget operations).
///
/// Usage:
/// ```dart
/// unawaited(someAsyncFunction());
/// ```
@pragma('vm:prefer-inline')
void unawaited(Future<dynamic>? future) {
  // Intentionally empty - this is a fire-and-forget operation
  // The linter sees that we're explicitly handling the future by passing it
  // to a function, which satisfies the unawaited_futures lint rule
}

