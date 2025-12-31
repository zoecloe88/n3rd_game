import 'dart:convert';
import 'package:n3rd_game/services/logger_service.dart';

/// Helper utility for safe JSON decoding
///
/// Provides methods to safely decode JSON strings with proper type checking,
/// preventing TypeError crashes from unsafe type casts.
class JsonHelper {
  /// Safely decode a JSON string as a Map
  ///
  /// Returns null if the JSON is not a Map or if decoding fails.
  ///
  /// Example:
  /// ```dart
  /// final data = JsonHelper.safeDecodeMap(jsonString);
  /// if (data != null) {
  ///   final value = data['key'];
  /// }
  /// ```
  static Map<String, dynamic>? safeDecodeMap(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      LoggerService.warning('JSON is not a Map: ${decoded.runtimeType}');
      return null;
    } catch (e) {
      LoggerService.error('Failed to decode JSON', error: e);
      return null;
    }
  }

  /// Safely decode a JSON string as a List
  ///
  /// Returns null if the JSON is not a List or if decoding fails.
  ///
  /// Example:
  /// ```dart
  /// final list = JsonHelper.safeDecodeList(jsonString);
  /// if (list != null) {
  ///   for (final item in list) {
  ///     // Process item
  ///   }
  /// }
  /// ```
  static List<dynamic>? safeDecodeList(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is List) {
        return decoded;
      }
      LoggerService.warning('JSON is not a List: ${decoded.runtimeType}');
      return null;
    } catch (e) {
      LoggerService.error('Failed to decode JSON', error: e);
      return null;
    }
  }
}
