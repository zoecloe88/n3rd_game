import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test utilities for common test setup and mocking
class TestHelpers {
  /// Set up mock SharedPreferences for testing
  static void setupMockSharedPreferences() {
    final Map<String, dynamic> mockData = {};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') {
          return Map<String, dynamic>.from(mockData);
        }
        if (methodCall.method == 'getString') {
          final key = _extractKey(methodCall.arguments);
          return mockData[key] as String?;
        }
        if (methodCall.method == 'getInt') {
          final key = _extractKey(methodCall.arguments);
          return mockData[key] as int?;
        }
        if (methodCall.method == 'setString') {
          final args = _extractArgs(methodCall.arguments);
          mockData[args[0] as String] = args[1] as String;
          return true;
        }
        if (methodCall.method == 'setInt') {
          final args = _extractArgs(methodCall.arguments);
          mockData[args[0] as String] = args[1] as int;
          return true;
        }
        if (methodCall.method == 'remove') {
          final key = _extractKey(methodCall.arguments);
          mockData.remove(key);
          return true;
        }
        if (methodCall.method == 'clear') {
          mockData.clear();
          return true;
        }
        return null;
      },
    );
  }

  /// Extract key from arguments (handles both String and List formats)
  static String _extractKey(dynamic arguments) {
    if (arguments is String) {
      return arguments;
    }
    if (arguments is List && arguments.isNotEmpty) {
      return arguments[0] as String;
    }
    if (arguments is Map && arguments.containsKey('key')) {
      return arguments['key'] as String;
    }
    return '';
  }

  /// Extract args from arguments (handles both List and Map formats)
  static List _extractArgs(dynamic arguments) {
    if (arguments is List) {
      return arguments;
    }
    if (arguments is Map) {
      // Convert map to list format [key, value]
      final key = arguments['key'] ?? arguments['0'];
      final value = arguments['value'] ?? arguments['1'];
      return [key, value];
    }
    return [];
  }

  /// Clear mock SharedPreferences handler
  static void clearMockSharedPreferences() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      null,
    );
  }

  /// Set up mock connectivity for testing
  static void setupMockConnectivity({bool isConnected = true}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'check') {
          return isConnected ? ['wifi'] : ['none'];
        }
        return null;
      },
    );
  }

  /// Clear mock connectivity handler
  static void clearMockConnectivity() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      null,
    );
  }

  /// Ensure test binding is initialized
  static void ensureInitialized() {
    TestWidgetsFlutterBinding.ensureInitialized();
  }

  /// Create a test SharedPreferences instance with data
  static Future<SharedPreferences> createTestPrefs(
    Map<String, dynamic> data,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in data.entries) {
      if (entry.value is String) {
        await prefs.setString(entry.key, entry.value as String);
      } else if (entry.value is int) {
        await prefs.setInt(entry.key, entry.value as int);
      } else if (entry.value is bool) {
        await prefs.setBool(entry.key, entry.value as bool);
      } else if (entry.value is double) {
        await prefs.setDouble(entry.key, entry.value as double);
      } else if (entry.value is List<String>) {
        await prefs.setStringList(entry.key, entry.value as List<String>);
      }
    }
    return prefs;
  }
}

