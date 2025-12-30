import 'dart:async';
/// Manages all game timers (memorize, play, shuffle, flip, time attack)
///
/// This service centralizes timer management to prevent memory leaks
/// and ensure proper cleanup. All timers are tracked and can be
/// cancelled when the game ends or service is disposed.
class GameTimerManager {
  /// Memorize phase timer
  Timer? _memorizeTimer;

  /// Play phase timer
  Timer? _playTimer;

  /// Shuffle timer (for shuffle mode)
  Timer? _shuffleTimer;

  /// Time attack timer
  Timer? _timeAttackTimer;

  /// Time freeze timer
  Timer? _timeFreezeTimer;

  /// Flip initial timer (for flip mode)
  Timer? _flipInitialTimer;

  /// Flip periodic timer (for flip mode)
  Timer? _flipPeriodicTimer;

  /// Pending next round timer
  Timer? _pendingNextRoundTimer;

  /// Disposal flag
  bool _disposed = false;

  /// Callback for when memorize phase completes
  VoidCallback? onMemorizeComplete;

  /// Callback for when play phase completes
  VoidCallback? onPlayComplete;

  /// Callback for time attack tick (receives seconds left)
  ValueChanged<int>? onTimeAttackTick;

  /// Callback for when time attack expires
  VoidCallback? onTimeAttackExpired;

  /// Callback for shuffle tick
  VoidCallback? onShuffleTick;

  /// Cancel all active timers
  void cancelAllTimers() {
    _memorizeTimer?.cancel();
    _playTimer?.cancel();
    _shuffleTimer?.cancel();
    _timeAttackTimer?.cancel();
    _flipInitialTimer?.cancel();
    _flipPeriodicTimer?.cancel();
    _pendingNextRoundTimer?.cancel();
    _timeFreezeTimer?.cancel();

    _memorizeTimer = null;
    _playTimer = null;
    _shuffleTimer = null;
    _timeAttackTimer = null;
    _flipInitialTimer = null;
    _flipPeriodicTimer = null;
    _pendingNextRoundTimer = null;
    _timeFreezeTimer = null;
  }

  /// Start memorize phase timer
  void startMemorizeTimer(Duration duration) {
    _memorizeTimer?.cancel();
    _memorizeTimer = Timer(duration, () {
      if (_disposed) return;
      onMemorizeComplete?.call();
    });
  }

  /// Start play phase timer
  void startPlayTimer(Duration duration) {
    _playTimer?.cancel();
    _playTimer = Timer(duration, () {
      if (_disposed) return;
      onPlayComplete?.call();
    });
  }

  /// Start time attack timer
  void startTimeAttackTimer({
    required int totalSeconds,
    required Duration tickInterval,
  }) {
    _timeAttackTimer?.cancel();
    int secondsLeft = totalSeconds;

    _timeAttackTimer = Timer.periodic(tickInterval, (timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }

      secondsLeft--;
      if (secondsLeft > 0) {
        onTimeAttackTick?.call(secondsLeft);
      } else {
        timer.cancel();
        if (!_disposed) {
          onTimeAttackExpired?.call();
        }
      }
    });
  }

  /// Start shuffle timer
  void startShuffleTimer({
    required Duration interval,
    required VoidCallback onTick,
  }) {
    _shuffleTimer?.cancel();
    _shuffleTimer = Timer.periodic(interval, (timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }
      onTick();
    });
  }

  /// Start flip sequence timers
  void startFlipSequence({
    required Duration initialDelay,
    required Duration flipInterval,
    required int totalTiles,
    required ValueChanged<int> onTileFlip,
  }) {
    _flipInitialTimer?.cancel();
    _flipPeriodicTimer?.cancel();

    _flipInitialTimer = Timer(initialDelay, () {
      if (_disposed) return;

      int currentIndex = 0;
      _flipPeriodicTimer = Timer.periodic(flipInterval, (timer) {
        if (_disposed) {
          timer.cancel();
          return;
        }

        if (currentIndex < totalTiles) {
          onTileFlip(currentIndex);
          currentIndex++;
        } else {
          timer.cancel();
        }
      });
    });
  }

  /// Cancel memorize timer
  void cancelMemorizeTimer() {
    _memorizeTimer?.cancel();
    _memorizeTimer = null;
  }

  /// Cancel play timer
  void cancelPlayTimer() {
    _playTimer?.cancel();
    _playTimer = null;
  }

  /// Cancel shuffle timer
  void cancelShuffleTimer() {
    _shuffleTimer?.cancel();
    _shuffleTimer = null;
  }

  /// Cancel time attack timer
  void cancelTimeAttackTimer() {
    _timeAttackTimer?.cancel();
    _timeAttackTimer = null;
  }

  /// Cancel flip timers
  void cancelFlipTimers() {
    _flipInitialTimer?.cancel();
    _flipPeriodicTimer?.cancel();
    _flipInitialTimer = null;
    _flipPeriodicTimer = null;
  }

  /// Dispose of all timers and resources
  void dispose() {
    _disposed = true;
    cancelAllTimers();
  }
}
