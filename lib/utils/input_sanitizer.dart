import 'package:flutter/foundation.dart';
import 'package:n3rd_game/config/app_config.dart';

/// Utility for sanitizing user input to prevent XSS and injection attacks
class InputSanitizer {
  /// Sanitize HTML content by removing script tags and dangerous attributes
  static String sanitizeHtml(String input) {
    // Remove script tags and their content
    String sanitized = input.replaceAll(
      RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false, dotAll: true),
      '',
    );

    // Remove event handlers (onclick, onerror, etc.)
    // Match either double or single quotes
    sanitized = sanitized.replaceAll(
      RegExp(r'\s*on\w+\s*=\s*"[^"]*"', caseSensitive: false),
      '',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r"\s*on\w+\s*=\s*'[^']*'", caseSensitive: false),
      '',
    );

    // Remove javascript: protocol
    sanitized = sanitized.replaceAll(
      RegExp(r'javascript:', caseSensitive: false),
      '',
    );

    // Remove data: URLs that could be dangerous
    sanitized = sanitized.replaceAll(
      RegExp(r'data:\s*text/html', caseSensitive: false),
      '',
    );

    return sanitized;
  }

  /// Sanitize plain text by removing control characters
  static String sanitizeText(String input) {
    // Remove control characters except newlines and tabs
    return input.replaceAll(RegExp(r'[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F]'), '');
  }

  /// Escape HTML special characters
  static String escapeHtml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll('/', '&#x2F;');
  }

  /// Sanitize for use in JSON (prevent injection)
  static String sanitizeForJson(String input) {
    return input
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }

  /// Validate and sanitize email input
  static String? sanitizeEmail(String email) {
    final trimmed = email.trim().toLowerCase();
    if (trimmed.isEmpty) return null;

    // Basic email validation
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(trimmed)) {
      return null;
    }

    return trimmed;
  }

  /// Validate and sanitize URL
  /// Enforces HTTPS if AppConfig.enforceHttps is true
  static String? sanitizeUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;

    try {
      // Check if AppConfig.enforceHttps is true
      // If so, only allow HTTPS URLs
      final enforceHttps = AppConfig.enforceHttps;

      if (enforceHttps) {
        // Only allow HTTPS URLs when enforcement is enabled
        if (!trimmed.startsWith('https://')) {
          return null;
        }
      } else {
        // Allow both HTTP and HTTPS when enforcement is disabled
        if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
          return null;
        }
      }

      // Basic URL validation
      final uri = Uri.parse(trimmed);
      if (uri.hasScheme) {
        if (enforceHttps) {
          // Only HTTPS allowed
          if (uri.scheme == 'https') {
            return trimmed;
          }
        } else {
          // Both HTTP and HTTPS allowed
          if (uri.scheme == 'http' || uri.scheme == 'https') {
            return trimmed;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Invalid URL: $e');
      }
    }

    return null;
  }

  /// Sanitize file name to prevent path traversal
  static String sanitizeFileName(String fileName) {
    // Remove path separators and dangerous characters
    return fileName
        .replaceAll(RegExp(r'[<>:"|?*\x00-\x1F]'), '_')
        .replaceAll('/', '_')
        .replaceAll('\\', '_')
        .trim();
  }

  /// Sanitize display name for user profiles
  /// Removes HTML tags, limits length, and removes special characters
  static String sanitizeDisplayName(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML
        .replaceAll(
          RegExp(r'[^\w\s-]'),
          '',
        ) // Remove special chars except - and _
        .substring(0, input.length > 50 ? 50 : input.length);
  }

  /// Validate and sanitize edition names for AI generation
  static String? validateEditionName(String? name) {
    if (name == null || name.trim().isEmpty) return null;
    final sanitized = name.trim().substring(
          0,
          name.length > 100 ? 100 : name.length,
        );
    if (sanitized.length < 3) return null;
    return sanitized;
  }
}
