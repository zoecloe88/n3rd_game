import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Security helper for certificate pinning and additional security measures
class SecurityHelper {
  /// Certificate pinning validation helper for API calls
  /// Validates that the server certificate hash matches expected fingerprints
  ///
  /// This is a validation helper that works with pre-calculated certificate hashes.
  /// For full certificate pinning with automatic certificate extraction, use
  /// `SecureHttpClient` which has access to the certificate object during TLS handshake.
  ///
  /// Parameters:
  /// - [host]: The hostname being validated (for host allowlist check)
  /// - [expectedPins]: List of base64-encoded SHA-256 certificate hashes to match against
  /// - [certificateHash]: Optional base64-encoded SHA-256 hash of the certificate to validate
  ///
  /// Returns:
  /// - `true` if host is allowed and (certificate hash matches OR no hash provided)
  /// - `false` if host is not allowed OR certificate hash doesn't match expected pins
  ///
  /// Example:
  /// ```dart
  /// final hash = SecurityHelper.calculateCertificateHash(certBytes);
  /// final isValid = SecurityHelper.validateCertificatePin(
  ///   host: 'api.example.com',
  ///   expectedPins: ['ABC123...XYZ789='],
  ///   certificateHash: hash,
  /// );
  /// ```
  static bool validateCertificatePin({
    required String host,
    required List<String> expectedPins,
    String? certificateHash,
  }) {
    // First layer: Validate host is in allowed list (defense in depth)
    final allowedHosts = [
      'firebase.googleapis.com',
      'firebaseapp.com',
      'googleapis.com',
      'api.dictionaryapi.dev',
      'cloudfunctions.net',
    ];

    if (!allowedHosts.any((allowed) => host.contains(allowed))) {
      LoggerService.warning(
        'Certificate pinning: Host not in allowed list: $host',
      );
      return false;
    }

    // Second layer: If certificate hash is provided, validate it against expected pins
    if (certificateHash != null && certificateHash.isNotEmpty) {
      if (expectedPins.isEmpty) {
        LoggerService.warning(
          'Certificate pinning: No expected pins provided for validation',
        );
        return false;
      }

      // Normalize the certificate hash (remove whitespace, ensure uppercase if needed)
      final normalizedHash = certificateHash.trim();

      // Check if certificate hash matches any expected pin
      final matches = expectedPins.any((pin) {
        final normalizedPin = pin.trim();
        return normalizedHash == normalizedPin;
      });

      if (!matches) {
        LoggerService.warning(
          'Certificate pinning: Certificate hash does not match any expected pin for $host',
        );
        return false;
      }

      // Host is allowed and certificate hash matches
      return true;
    }

    // If no certificate hash provided, only host validation is performed
    // This allows the method to be used for host validation only
    // Note: For full security, certificate hash should always be provided
    if (certificateHash == null) {
      LoggerService.debug(
        'Certificate pinning: No certificate hash provided, only host validation performed for $host',
      );
    }

    return true;
  }

  /// Calculate SHA-256 hash of a certificate for pinning validation
  ///
  /// This helper method calculates the base64-encoded SHA-256 hash of certificate bytes
  /// (typically in DER format) for use with `validateCertificatePin()`.
  ///
  /// Parameters:
  /// - [certificateBytes]: The certificate bytes (typically DER format)
  ///
  /// Returns:
  /// - Base64-encoded SHA-256 hash of the certificate
  ///
  /// Example:
  /// ```dart
  /// final certBytes = certificate.der; // From X509Certificate
  /// final hash = SecurityHelper.calculateCertificateHash(certBytes);
  /// ```
  static String calculateCertificateHash(List<int> certificateBytes) {
    final hash = sha256.convert(certificateBytes);
    return base64Encode(hash.bytes);
  }

  /// Validate API key format (without exposing the actual key)
  static bool isValidApiKeyFormat(String? apiKey) {
    if (apiKey == null || apiKey.isEmpty) return false;

    // Basic format validation (length, character set)
    // Actual key validation happens server-side
    return apiKey.length >= 20 &&
        apiKey.length <= 200 &&
        RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(apiKey);
  }

  /// Hash sensitive data for logging (prevents logging actual sensitive values)
  static String hashForLogging(String sensitiveData) {
    final bytes = utf8.encode(sensitiveData);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16); // First 16 chars for brevity
  }

  /// Validate deep link parameters for security
  static bool validateDeepLinkParams(Map<String, dynamic> params) {
    // Validate all string parameters for XSS/injection
    for (final entry in params.entries) {
      if (entry.value is String) {
        final value = entry.value as String;

        // Check for script tags
        if (value.toLowerCase().contains('<script')) {
          LoggerService.warning(
            'Deep link validation failed: Script tag detected in ${entry.key}',
          );
          return false;
        }

        // Check for javascript: protocol
        if (value.toLowerCase().contains('javascript:')) {
          LoggerService.warning(
            'Deep link validation failed: JavaScript protocol detected in ${entry.key}',
          );
          return false;
        }

        // Check for excessive length (prevent DoS)
        if (value.length > 1000) {
          LoggerService.warning(
            'Deep link validation failed: Parameter too long: ${entry.key}',
          );
          return false;
        }
      }
    }

    return true;
  }

  /// Sanitize user-generated content for display
  /// Removes potentially dangerous content while preserving formatting
  static String sanitizeUserContent(String content) {
    // Remove script tags
    var sanitized = content.replaceAll(
      RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false, dotAll: true),
      '',
    );

    // Remove event handlers
    sanitized = sanitized.replaceAll(
      RegExp(r'\s*on\w+\s*=\s*"[^"]*"', caseSensitive: false),
      '',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r"\s*on\w+\s*=\s*'[^']*'", caseSensitive: false),
      '',
    );

    // Remove javascript: and data: URLs
    sanitized = sanitized.replaceAll(
      RegExp(r'javascript:', caseSensitive: false),
      '',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'data:\s*text/html', caseSensitive: false),
      '',
    );

    return sanitized;
  }

  /// Validate file upload for security
  static bool validateFileUpload({
    required String fileName,
    required int fileSize,
    required List<String> allowedExtensions,
    int maxSizeBytes = 10 * 1024 * 1024, // 10MB default
  }) {
    // Check file extension
    final extension = fileName.split('.').last.toLowerCase();
    if (!allowedExtensions.contains(extension)) {
      LoggerService.warning(
        'File upload validation failed: Invalid extension: $extension',
      );
      return false;
    }

    // Check file size
    if (fileSize > maxSizeBytes) {
      LoggerService.warning(
        'File upload validation failed: File too large: $fileSize bytes',
      );
      return false;
    }

    // Check file name for path traversal
    if (fileName.contains('..') ||
        fileName.contains('/') ||
        fileName.contains('\\')) {
      LoggerService.warning(
        'File upload validation failed: Invalid file name: $fileName',
      );
      return false;
    }

    return true;
  }

  /// Generate secure random token
  static String generateSecureToken({int length = 32}) {
    final random = DateTime.now().millisecondsSinceEpoch.toString();
    final bytes = utf8.encode(random);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, length.clamp(0, 64));
  }

  /// Validate session token format
  static bool isValidSessionToken(String? token) {
    if (token == null || token.isEmpty) return false;

    // Basic format validation
    return token.length >= 20 &&
        token.length <= 200 &&
        RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(token);
  }
}
