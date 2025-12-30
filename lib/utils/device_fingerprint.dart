import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Service for generating device fingerprints for security tracking
///
/// Device fingerprinting helps detect suspicious activity by tracking:
/// - Device identifiers
/// - App version
/// - Platform information
/// - Device characteristics
class DeviceFingerprint {
  static DeviceInfoPlugin? _deviceInfo;
  static PackageInfo? _packageInfo;
  static String? _cachedFingerprint;

  /// Get device info plugin instance
  static DeviceInfoPlugin get _deviceInfoPlugin {
    _deviceInfo ??= DeviceInfoPlugin();
    return _deviceInfo!;
  }

  /// Initialize and cache package info
  static Future<void> _ensurePackageInfo() async {
    _packageInfo ??= await PackageInfo.fromPlatform();
  }

  /// Generate a device fingerprint hash
  ///
  /// Creates a consistent identifier based on device characteristics.
  /// This fingerprint helps identify devices for security purposes.
  ///
  /// **Note**: This fingerprint is not tied to user accounts and is used
  /// for anomaly detection and suspicious activity monitoring.
  static Future<String> getFingerprint() async {
    if (_cachedFingerprint != null) {
      return _cachedFingerprint!;
    }

    try {
      await _ensurePackageInfo();
      final deviceInfo = _deviceInfoPlugin;

      String fingerprintData = '';

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        fingerprintData = '${androidInfo.id}-'
            '${androidInfo.model}-${androidInfo.manufacturer}-'
            '${androidInfo.brand}-${androidInfo.device}-'
            '${androidInfo.product}-${_packageInfo?.packageName ?? ''}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        fingerprintData = '${iosInfo.identifierForVendor ?? ''}-'
            '${iosInfo.model}-${iosInfo.name}-'
            '${iosInfo.systemName}-${_packageInfo?.packageName ?? ''}';
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        fingerprintData = '${windowsInfo.computerName}-'
            '${windowsInfo.productName}-${_packageInfo?.packageName ?? ''}';
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        fingerprintData = '${macInfo.computerName}-'
            '${macInfo.model}-${_packageInfo?.packageName ?? ''}';
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        fingerprintData = '${linuxInfo.machineId}-'
            '${linuxInfo.prettyName}-${_packageInfo?.packageName ?? ''}';
      } else {
        // Web or other platforms
        fingerprintData = '${_packageInfo?.packageName ?? ''}-'
            '${Platform.operatingSystem}';
      }

      // Generate SHA-256 hash of fingerprint data
      final bytes = utf8.encode(fingerprintData);
      final digest = sha256.convert(bytes);
      _cachedFingerprint = digest.toString();

      return _cachedFingerprint!;
    } catch (e) {
      // Fallback to a basic fingerprint if device info fails
      final fallback = '${Platform.operatingSystem}-'
          '${_packageInfo?.packageName ?? 'unknown'}';
      final bytes = utf8.encode(fallback);
      final digest = sha256.convert(bytes);
      _cachedFingerprint = digest.toString();
      return _cachedFingerprint!;
    }
  }

  /// Get device information summary for logging
  static Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      await _ensurePackageInfo();
      final deviceInfo = _deviceInfoPlugin;
      final info = <String, dynamic>{
        'platform': Platform.operatingSystem,
        'packageName': _packageInfo?.packageName,
        'version': _packageInfo?.version,
      };

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        info['model'] = androidInfo.model;
        info['manufacturer'] = androidInfo.manufacturer;
        info['androidVersion'] = androidInfo.version.release;
        info['sdkInt'] = androidInfo.version.sdkInt;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        info['model'] = iosInfo.model;
        info['systemVersion'] = iosInfo.systemVersion;
        info['name'] = iosInfo.name;
      }

      return info;
    } catch (e) {
      return {
        'platform': Platform.operatingSystem,
        'error': e.toString(),
      };
    }
  }

  /// Clear cached fingerprint (useful for testing)
  static void clearCache() {
    _cachedFingerprint = null;
  }
}
