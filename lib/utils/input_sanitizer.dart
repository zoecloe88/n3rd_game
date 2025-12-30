import 'package:n3rd_game/config/app_config.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Utility for sanitizing user input to prevent XSS and injection attacks
/// Enhanced with advanced XSS detection, SQL injection prevention, and comprehensive validation
class InputSanitizer {
  // Request size limits
  static const int maxRequestSizeBytes = 1024 * 1024; // 1MB
  static const int maxStringLength = 10000; // Maximum string length
  static const int maxFieldLength =
      500; // Maximum field length (messages, etc.)

  // SQL injection patterns
  static List<RegExp> _getSqlInjectionPatterns() {
    return [
      // Common SQL keywords in suspicious contexts
      RegExp(
          r'\b(union|select|insert|update|delete|drop|create|alter|exec|execute)\b',
          caseSensitive: false,),
      // SQL comment patterns
      RegExp(r'(--|/\*|\*/|#)'),
      // SQL injection with quotes
      RegExp(r"'?\s*(or|and)\s*'?\s*(\d+|'[^']*')\s*=\s*\2"),
      // SQL injection with 1=1, 1'='1 patterns
      RegExp(r"'?\s*=\s*'?"),
      // SQL injection with UNION SELECT
      RegExp(r'union\s+(all\s+)?select', caseSensitive: false),
    ];
  }

  // Advanced XSS patterns beyond basic sanitization
  static List<RegExp> _getAdvancedXssPatterns() {
    return [
      // Encoded script tags
      RegExp(r'(%3C|<)script(%3E|>)', caseSensitive: false),
      // Event handlers with double quotes
      RegExp(r'on\w+\s*=\s*"', caseSensitive: false),
      // Event handlers with single quotes
      RegExp(r"on\w+\s*=\s*'", caseSensitive: false),
      // JavaScript protocols (various encodings)
      RegExp(r'(javascript|vbscript|data):', caseSensitive: false),
      // CSS expression injection
      RegExp(r'expression\s*\(', caseSensitive: false),
      // Iframe injection
      RegExp(r'(<iframe|<frame|<embed|<object)', caseSensitive: false),
      // SVG injection
      RegExp(r'<svg[^>]*on\w+\s*=', caseSensitive: false),
      // HTML entities used for XSS
      RegExp(r'&[#\w]+;.*script', caseSensitive: false),
      // Data URI with scripts
      RegExp(r'data:\s*text/html', caseSensitive: false),
    ];
  }

  /// Validate request size to prevent DoS attacks
  static void validateRequestSize(String input, {String? fieldName}) {
    final sizeInBytes = input.codeUnits.length * 2; // UTF-16 encoding
    if (sizeInBytes > maxRequestSizeBytes) {
      LoggerService.warning(
        'Request size exceeded limit: $sizeInBytes bytes (max: $maxRequestSizeBytes); | field: ${fieldName ?? 'unknown'}',
      );
      throw ValidationException(
        'Input size exceeds maximum allowed size of ${maxRequestSizeBytes ~/ 1024}KB',
      );
    }
  }

  /// Validate string length
  static void validateStringLength(String input,
      {int? maxLength, String? fieldName,}) {
    final max = maxLength ?? maxStringLength;
    if (input.length > max) {
      throw ValidationException(
        'Input length exceeds maximum allowed length of $max characters | field: ${fieldName ?? 'unknown'}',
      );
    }
  }

  /// Check for SQL injection patterns
  static bool containsSqlInjection(String input) {
    for (final pattern in _getSqlInjectionPatterns()) {
      if (pattern.hasMatch(input)) {
        LoggerService.warning('SQL injection pattern detected in input');
        return true;
      }
    }
    return false;
  }

  /// Check for advanced XSS patterns
  static bool containsAdvancedXss(String input) {
    for (final pattern in _getAdvancedXssPatterns()) {
      if (pattern.hasMatch(input)) {
        LoggerService.warning('Advanced XSS pattern detected in input');
        return true;
      }
    }
    return false;
  }

  /// Sanitize HTML content by removing script tags and dangerous attributes
  /// Enhanced with advanced XSS detection
  static String sanitizeHtml(String input, {bool throwOnXss = false}) {
    // Validate input size
    validateRequestSize(input, fieldName: 'html');

    // Check for advanced XSS patterns
    if (containsAdvancedXss(input)) {
      if (throwOnXss) {
        throw ValidationException('XSS attack pattern detected in HTML input');
      }
      LoggerService.warning('Advanced XSS pattern detected, sanitizing');
    }

    // Check for SQL injection (even though this is HTML, could be stored in DB)
    if (containsSqlInjection(input)) {
      if (throwOnXss) {
        throw ValidationException(
            'SQL injection pattern detected in HTML input',);
      }
      LoggerService.warning(
          'SQL injection pattern detected in HTML, sanitizing',);
    }

    // Remove script tags and their content (using multiline and dotAll equivalent)
    String sanitized = input.replaceAll(
      RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false),
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

    // Remove javascript: protocol (various encodings)
    sanitized = sanitized.replaceAll(
      RegExp(r'(javascript|vbscript|data):', caseSensitive: false),
      '',
    );

    // Remove data: URLs that could be dangerous
    sanitized = sanitized.replaceAll(
      RegExp(r'data:\s*text/html', caseSensitive: false),
      '',
    );

    // Remove iframe, frame, embed, object tags (using multiline and dotAll equivalent)
    sanitized = sanitized.replaceAll(
      RegExp(r'<(iframe|frame|embed|object)[^>]*>[\s\S]*?</\1>',
          caseSensitive: false,),
      '',
    );

    // Remove CSS expressions
    sanitized = sanitized.replaceAll(
      RegExp(r'expression\s*\([^)]*\)', caseSensitive: false),
      '',
    );

    return sanitized;
  }

  /// Sanitize plain text by removing control characters
  /// Enhanced with SQL injection and XSS detection
  static String sanitizeText(String input, {bool throwOnThreat = false}) {
    // Validate input size
    validateRequestSize(input, fieldName: 'text');
    validateStringLength(input, maxLength: maxStringLength, fieldName: 'text');

    // Check for SQL injection
    if (containsSqlInjection(input)) {
      if (throwOnThreat) {
        throw ValidationException(
            'SQL injection pattern detected in text input',);
      }
      LoggerService.warning(
          'SQL injection pattern detected in text, sanitizing',);
    }

    // Check for XSS (even in plain text, could be rendered as HTML)
    if (containsAdvancedXss(input)) {
      if (throwOnThreat) {
        throw ValidationException('XSS pattern detected in text input');
      }
      LoggerService.warning('XSS pattern detected in text, sanitizing');
    }

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
      LoggerService.debug('Invalid URL', error: e);
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
  /// Enhanced with security validation
  static String sanitizeDisplayName(String input) {
    // Validate input size
    validateStringLength(input,
        maxLength: AppConfig.maxDisplayNameLength, fieldName: 'displayName',);

    // Check for threats
    if (containsSqlInjection(input) || containsAdvancedXss(input)) {
      LoggerService.warning('Security threat detected in display name');
    }

    var sanitized = input
        .trim()
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML
        .replaceAll(
          RegExp(r'[^\w\s-]'),
          '',
        ); // Remove special chars except - and _

    // Limit length
    if (sanitized.length > AppConfig.maxDisplayNameLength) {
      sanitized = sanitized.substring(0, AppConfig.maxDisplayNameLength);
    }

    return sanitized;
  }

  /// Validate and sanitize file upload (file name and type validation)
  /// Returns sanitized file name if valid, throws ValidationException if invalid
  static String validateAndSanitizeFileName(String fileName,
      {List<String>? allowedExtensions,}) {
    // Validate input size
    validateStringLength(fileName, maxLength: 255, fieldName: 'fileName');

    // Check for path traversal attempts
    if (fileName.contains('..') ||
        fileName.contains('/') ||
        fileName.contains('\\')) {
      throw ValidationException('Invalid file name: path traversal detected');
    }

    // Check for SQL injection
    if (containsSqlInjection(fileName)) {
      throw ValidationException(
          'Invalid file name: SQL injection pattern detected',);
    }

    // Sanitize file name
    final sanitized = sanitizeFileName(fileName);

    // Validate file extension if specified
    if (allowedExtensions != null && allowedExtensions.isNotEmpty) {
      final extension = sanitized.split('.').last.toLowerCase();
      if (!allowedExtensions.contains(extension)) {
        throw ValidationException(
          'Invalid file type. Allowed types: ${allowedExtensions.join(', ')}',
        );
      }
    }

    return sanitized;
  }

  /// Validate file size for uploads
  static void validateFileSize(int fileSizeBytes, {int? maxSizeBytes}) {
    final maxSize =
        maxSizeBytes ?? maxRequestSizeBytes * 5; // Default: 5MB for files
    if (fileSizeBytes > maxSize) {
      throw ValidationException(
        'File size exceeds maximum allowed size of ${maxSize ~/ (1024 * 1024)}MB',
      );
    }
  }

  /// Get Content Security Policy header value (for web platform)
  /// Returns CSP header string
  static String getContentSecurityPolicyHeader() {
    // Default CSP policy - strict by default
    return "default-src 'self'; "
        "script-src 'self' 'unsafe-inline' 'unsafe-eval'; "
        "style-src 'self' 'unsafe-inline'; "
        "img-src 'self' data: https:; "
        "font-src 'self' data:; "
        "connect-src 'self' https:; "
        "frame-ancestors 'none'; "
        "base-uri 'self'; "
        "form-action 'self';";
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
