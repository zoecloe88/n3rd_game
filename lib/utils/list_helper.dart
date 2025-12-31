/// Helper utility for safe list access
///
/// Provides methods to safely access list elements with bounds checking,
/// preventing IndexOutOfRangeException and StateError crashes.
class ListHelper {
  /// Safely get the first element of a list
  ///
  /// Returns null if the list is null or empty.
  ///
  /// Example:
  /// ```dart
  /// final item = ListHelper.safeFirst(list);
  /// if (item == null) {
  ///   LoggerService.warning('List is empty, cannot get first element');
  ///   return;
  /// }
  /// ```
  static T? safeFirst<T>(List<T>? list) {
    if (list == null || list.isEmpty) {
      return null;
    }
    return list.first;
  }

  /// Safely get the last element of a list
  ///
  /// Returns null if the list is null or empty.
  ///
  /// Example:
  /// ```dart
  /// final last = ListHelper.safeLast(items);
  /// if (last == null) {
  ///   LoggerService.warning('List is empty, cannot get last element');
  ///   return;
  /// }
  /// ```
  static T? safeLast<T>(List<T>? list) {
    if (list == null || list.isEmpty) {
      return null;
    }
    return list.last;
  }

  /// Safely get an element at a specific index
  ///
  /// Returns null if the list is null, index is negative, or index is out of bounds.
  ///
  /// Example:
  /// ```dart
  /// final item = ListHelper.safeElementAt(list, 0);
  /// if (item == null) {
  ///   LoggerService.warning('Index 0 is out of bounds or list is null');
  ///   return;
  /// }
  /// ```
  static T? safeElementAt<T>(List<T>? list, int index) {
    if (list == null || index < 0 || index >= list.length) {
      return null;
    }
    return list[index];
  }

  /// Safely get the single element of a list
  ///
  /// Returns null if the list is null, empty, or has more than one element.
  ///
  /// Example:
  /// ```dart
  /// final single = ListHelper.safeSingle(list);
  /// if (single == null) {
  ///   LoggerService.warning('List does not have exactly one element');
  ///   return;
  /// }
  /// ```
  static T? safeSingle<T>(List<T>? list) {
    if (list == null || list.length != 1) {
      return null;
    }
    return list.single;
  }

  /// Safely check if a list is not empty
  ///
  /// Returns false if the list is null or empty, true otherwise.
  ///
  /// Example:
  /// ```dart
  /// if (ListHelper.isNotEmpty(list)) {
  ///   // Safe to access list elements
  /// }
  /// ```
  static bool isNotEmpty<T>(List<T>? list) {
    return list != null && list.isNotEmpty;
  }

  /// Safely check if a list is empty
  ///
  /// Returns true if the list is null or empty, false otherwise.
  ///
  /// Example:
  /// ```dart
  /// if (ListHelper.isEmpty(list)) {
  ///   LoggerService.warning('List is empty');
  ///   return;
  /// }
  /// ```
  static bool isEmpty<T>(List<T>? list) {
    return list == null || list.isEmpty;
  }
}
