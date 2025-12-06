import 'dart:async';
import 'package:flutter/widgets.dart';

/// Utility class for managing resources and preventing memory leaks
///
/// Tracks and manages timers, stream subscriptions, and other resources
/// that need to be disposed.
class ResourceManager {
  final List<Timer> _timers = [];
  final List<StreamSubscription> _subscriptions = [];
  final List<ChangeNotifier> _notifiers = [];

  /// Register a timer for automatic disposal
  void registerTimer(Timer timer) {
    _timers.add(timer);
  }

  /// Register a stream subscription for automatic disposal
  void registerSubscription(StreamSubscription subscription) {
    _subscriptions.add(subscription);
  }

  /// Register a change notifier for automatic disposal
  void registerNotifier(ChangeNotifier notifier) {
    _notifiers.add(notifier);
  }

  /// Dispose all registered resources
  void dispose() {
    // Cancel all timers
    for (final timer in _timers) {
      if (timer.isActive) {
        timer.cancel();
      }
    }
    _timers.clear();

    // Cancel all subscriptions
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    // Dispose all notifiers
    for (final notifier in _notifiers) {
      notifier.dispose();
    }
    _notifiers.clear();
  }

  /// Get count of registered resources
  int get resourceCount =>
      _timers.length + _subscriptions.length + _notifiers.length;
}

/// Mixin for StatefulWidget states that need resource management
///
/// Usage:
/// ```dart
/// class _MyWidgetState extends State<MyWidget> with ResourceManagerMixin {
///   @override
///   void initState() {
///     super.initState();
///     registerTimer(Timer.periodic(...));
///   }
/// }
/// ```
mixin ResourceManagerMixin<T extends StatefulWidget> on State<T> {
  final ResourceManager _resourceManager = ResourceManager();

  /// Register a timer
  void registerTimer(Timer timer) {
    _resourceManager.registerTimer(timer);
  }

  /// Register a stream subscription
  void registerSubscription(StreamSubscription subscription) {
    _resourceManager.registerSubscription(subscription);
  }

  /// Register a change notifier
  void registerNotifier(ChangeNotifier notifier) {
    _resourceManager.registerNotifier(notifier);
  }

  @override
  void dispose() {
    _resourceManager.dispose();
    super.dispose();
  }
}
