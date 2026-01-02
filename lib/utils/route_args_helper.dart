import 'package:flutter/material.dart';

/// Helper utility for safely accessing route arguments
///
/// Provides safe methods to retrieve route arguments that handle
/// the proper widget lifecycle timing to avoid accessing ModalRoute
/// before the widget tree is built.
class RouteArgsHelper {
  /// Get route arguments safely in didChangeDependencies context
  ///
  /// Use this method in didChangeDependencies() or after the widget
  /// tree is built to safely access route arguments.
  ///
  /// [context] - BuildContext (must be in didChangeDependencies or later)
  ///
  /// Returns the arguments if available, null otherwise
  static T? getArguments<T>(BuildContext context) {
    try {
      final route = ModalRoute.of(context);
      final args = route?.settings.arguments;
      if (args is T) {
        return args;
      }
      return null;
    } catch (e) {
      // Route not available or not in proper lifecycle
      return null;
    }
  }

  /// Get route arguments with type checking and default fallback
  ///
  /// [context] - BuildContext
  /// [defaultValue] - Default value if arguments are null or wrong type
  ///
  /// Returns arguments cast to T or defaultValue
  static T getArgumentsOrDefault<T>(
    BuildContext context,
    T defaultValue,
  ) {
    final args = getArguments<T>(context);
    return args ?? defaultValue;
  }

  /// Check if route arguments match a specific type
  ///
  /// [context] - BuildContext
  /// [type] - Type to check (e.g., Map<String, dynamic>)
  ///
  /// Returns true if arguments match the type
  static bool hasArgumentsOfType<T>(BuildContext context) {
    return getArguments<T>(context) != null;
  }
}
