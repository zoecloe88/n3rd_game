import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Helper utility for safe provider access
///
/// Provides methods to safely access providers with error handling,
/// preventing crashes when providers are missing from the widget tree.
class ProviderHelper {
  /// Safely get a provider, returning null if not found
  ///
  /// Use this when the provider is optional and the code can handle its absence.
  ///
  /// Example:
  /// ```dart
  /// final service = ProviderHelper.safeGet<GameService>(context);
  /// if (service != null) {
  ///   service.doSomething();
  /// }
  /// ```
  static T? safeGet<T>(BuildContext context, {bool listen = false}) {
    try {
      return Provider.of<T>(context, listen: listen);
    } catch (e) {
      LoggerService.warning('Provider not found: $T', error: e);
      return null;
    }
  }

  /// Get a provider or throw with better error message
  ///
  /// Use this when the provider is required and its absence indicates a bug.
  ///
  /// Example:
  /// ```dart
  /// final service = ProviderHelper.safeGetOrThrow<GameService>(context);
  /// service.doSomething(); // Guaranteed to be non-null
  /// ```
  static T safeGetOrThrow<T>(BuildContext context, {bool listen = false}) {
    try {
      return Provider.of<T>(context, listen: listen);
    } catch (e) {
      LoggerService.error('Required provider not found: $T', error: e);
      rethrow;
    }
  }
}
