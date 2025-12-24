import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:n3rd_game/exceptions/app_exceptions.dart';

/// Service for checking app version and forcing updates
class AppVersionService {
  static const String _versionCheckUrl =
      'https://api.github.com/repos/yourusername/n3rd_game/releases/latest';
  // Or use your own API endpoint

  PackageInfo? _packageInfo;
  String? _latestVersion;
  bool _updateRequired = false;

  String? get currentVersion => _packageInfo?.version;
  String? get latestVersion => _latestVersion;
  bool get updateRequired => _updateRequired;

  Future<void> init() async {
    _packageInfo = await PackageInfo.fromPlatform();
  }

  /// Check for app updates
  Future<bool> checkForUpdates({bool forceUpdate = false}) async {
    try {
      await init();

      // In a real app, you'd check against your server/API
      // For now, we'll use a simple version comparison
      // You can implement your own version checking logic here

      // Example: Check against Firebase Remote Config or your API
      final response = await http.get(Uri.parse(_versionCheckUrl)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw NetworkException('Version check timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _latestVersion =
            data['tag_name']?.replaceAll('v', '') ?? data['version'] as String?;

        if (_latestVersion != null && _packageInfo != null) {
          _updateRequired = _isVersionNewer(
            _latestVersion!,
            _packageInfo!.version,
          );
        }
      }

      return _updateRequired;
    } catch (e) {
      debugPrint('Failed to check for updates: $e');
      // Don't block app usage if version check fails
      return false;
    }
  }

  /// Compare version strings (e.g., "1.2.3" vs "1.2.4")
  bool _isVersionNewer(String latest, String current) {
    try {
      final latestParts = latest.split('.').map(int.parse).toList();
      final currentParts = current.split('.').map(int.parse).toList();

      // Pad with zeros if needed
      while (latestParts.length < currentParts.length) {
        latestParts.add(0);
      }
      while (currentParts.length < latestParts.length) {
        currentParts.add(0);
      }

      for (int i = 0; i < latestParts.length; i++) {
        if (latestParts[i] > currentParts[i]) {
          return true;
        } else if (latestParts[i] < currentParts[i]) {
          return false;
        }
      }

      return false; // Versions are equal
    } catch (e) {
      debugPrint('Version comparison error: $e');
      return false;
    }
  }

  /// Get app store URL for update
  String getUpdateUrl() {
    // Return App Store or Play Store URL based on platform
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'https://apps.apple.com/app/idYOUR_APP_ID'; // Replace with your App ID
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'https://play.google.com/store/apps/details?id=com.clairsaint.wordn3rd';
    }
    return '';
  }
}
