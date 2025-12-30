import 'dart:io';
import 'package:n3rd_game/services/logger_service.dart';

/// Technical debt item
class TechDebtItem {

  TechDebtItem({
    required this.file,
    required this.line,
    required this.type,
    required this.message,
    this.category,
    this.priority,
    this.createdAt,
    this.resolvedAt,
  });

  factory TechDebtItem.fromJson(Map<String, dynamic> json) => TechDebtItem(
        file: json['file'] as String,
        line: json['line'] as int,
        type: json['type'] as String,
        message: json['message'] as String,
        category: json['category'] as String?,
        priority: json['priority'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
        resolvedAt: json['resolvedAt'] != null
            ? DateTime.parse(json['resolvedAt'] as String)
            : null,
      );
  final String file;
  final int line;
  // Type values: "TODO", "FIXME", "XXX", "HACK", "NOTE", "BUG"
  final String type;
  final String message;
  final String? category;
  final String? priority; // high, medium, low
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  Map<String, dynamic> toJson() => {
        'file': file,
        'line': line,
        'type': type,
        'message': message,
        'category': category,
        'priority': priority,
        'createdAt': createdAt?.toIso8601String(),
        'resolvedAt': resolvedAt?.toIso8601String(),
      };

  bool get isResolved => resolvedAt != null;
}

/// Technical debt tracking service
///
/// Scans codebase for technical debt comment patterns
/// (e.g., "TODO", "FIXME", "XXX", "HACK", "NOTE", "BUG")
/// and categorizes them for tracking and management
class TechDebtTrackingService {
  factory TechDebtTrackingService() => _instance;
  TechDebtTrackingService._internal();
  static final TechDebtTrackingService _instance =
      TechDebtTrackingService._internal();

  /// Scan codebase for technical debt items
  Future<List<TechDebtItem>?> scanCodebase(String rootPath) async {
    try {
      final List<TechDebtItem> items = [];
      final directory = Directory(rootPath);

      if (!directory.existsSync()) {
        LoggerService.warning('Directory does not exist: $rootPath');
        return null;
      }

      await _scanDirectory(directory, items, rootPath);

      LoggerService.info(
          'Scanned codebase: found ${items.length} technical debt items',);
      return items;
    } catch (e, stack) {
      LoggerService.error('Failed to scan codebase', error: e, stack: stack);
      return null;
    }
  }

  /// Recursively scan directory for technical debt
  Future<void> _scanDirectory(
    Directory directory,
    List<TechDebtItem> items,
    String rootPath,
  ) async {
    try {
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          final extension = entity.path.split('.').last;
          if (_isDartFile(extension)) {
            await _scanFile(entity, items, rootPath);
          }
        }
      }
    } catch (e) {
      LoggerService.debug('Error scanning directory: ${directory.path}',
          error: e,);
    }
  }

  /// Check if file is a Dart file
  bool _isDartFile(String extension) {
    return extension == 'dart';
  }

  /// Scan a single file for technical debt
  Future<void> _scanFile(
      File file, List<TechDebtItem> items, String rootPath,) async {
    try {
      final content = file.readAsStringSync();
      final lines = content.split('\n');

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        final lineNumber = i + 1;

        // Check for technical debt comment patterns
        final patterns = {
          'TODO': RegExp(r'//\s*TODO[:\s]*(.+)', caseSensitive: false),
          'FIXME': RegExp(r'//\s*FIXME[:\s]*(.+)', caseSensitive: false),
          'XXX': RegExp(r'//\s*XXX[:\s]*(.+)', caseSensitive: false),
          'HACK': RegExp(r'//\s*HACK[:\s]*(.+)', caseSensitive: false),
          'NOTE': RegExp(r'//\s*NOTE[:\s]*(.+)', caseSensitive: false),
          'BUG': RegExp(r'//\s*BUG[:\s]*(.+)', caseSensitive: false),
        };

        for (final entry in patterns.entries) {
          final match = entry.value.firstMatch(line);
          if (match != null) {
            final message = match.group(1)?.trim() ?? '';
            final relativePath = file.path
                .replaceFirst(rootPath, '')
                .replaceFirst(RegExp(r'^/'), '');

            items.add(TechDebtItem(
              file: relativePath,
              line: lineNumber,
              type: entry.key,
              message: message,
              category: _categorizeItem(message, entry.key),
              priority: _determinePriority(message, entry.key),
              createdAt: DateTime.now(),
            ),);
          }
        }
      }
    } catch (e) {
      LoggerService.debug('Error scanning file: ${file.path}', error: e);
    }
  }

  /// Categorize technical debt item
  String? _categorizeItem(String message, String type) {
    final lowerMessage = message.toLowerCase();

    // Security-related
    if (lowerMessage.contains('security') ||
        lowerMessage.contains('auth') ||
        lowerMessage.contains('encrypt') ||
        lowerMessage.contains('vulnerability')) {
      return 'security';
    }

    // Performance-related
    if (lowerMessage.contains('performance') ||
        lowerMessage.contains('optimize') ||
        lowerMessage.contains('slow') ||
        lowerMessage.contains('memory') ||
        lowerMessage.contains('leak')) {
      return 'performance';
    }

    // Testing-related
    if (lowerMessage.contains('test') ||
        lowerMessage.contains('coverage') ||
        lowerMessage.contains('mock')) {
      return 'testing';
    }

    // Refactoring-related
    if (lowerMessage.contains('refactor') ||
        lowerMessage.contains('cleanup') ||
        lowerMessage.contains('duplicate') ||
        lowerMessage.contains('extract')) {
      return 'refactoring';
    }

    // Feature-related
    if (lowerMessage.contains('feature') ||
        lowerMessage.contains('implement') ||
        lowerMessage.contains('add')) {
      return 'feature';
    }

    // Bug-related
    if (type == 'BUG' ||
        lowerMessage.contains('bug') ||
        lowerMessage.contains('fix') ||
        lowerMessage.contains('error') ||
        lowerMessage.contains('crash')) {
      return 'bug';
    }

    // Documentation-related
    if (lowerMessage.contains('document') ||
        lowerMessage.contains('doc') ||
        lowerMessage.contains('comment')) {
      return 'documentation';
    }

    // Architecture-related
    if (lowerMessage.contains('architecture') ||
        lowerMessage.contains('design') ||
        lowerMessage.contains('structure')) {
      return 'architecture';
    }

    return 'other';
  }

  /// Determine priority of technical debt item
  String? _determinePriority(String message, String type) {
    final lowerMessage = message.toLowerCase();

    // High priority indicators
    if (type == 'BUG' ||
        type == 'FIXME' ||
        lowerMessage.contains('critical') ||
        lowerMessage.contains('urgent') ||
        lowerMessage.contains('security') ||
        lowerMessage.contains('crash') ||
        lowerMessage.contains('data loss')) {
      return 'high';
    }

    // Medium priority indicators
    if (type == 'TODO' ||
        lowerMessage.contains('important') ||
        lowerMessage.contains('should') ||
        lowerMessage.contains('consider')) {
      return 'medium';
    }

    // Low priority indicators
    if (type == 'NOTE' ||
        type == 'XXX' ||
        lowerMessage.contains('nice to have') ||
        lowerMessage.contains('future') ||
        lowerMessage.contains('maybe')) {
      return 'low';
    }

    return 'medium'; // Default
  }

  /// Generate technical debt report
  Future<Map<String, dynamic>> generateReport(List<TechDebtItem> items) async {
    final byType = <String, List<TechDebtItem>>{};
    final byCategory = <String, List<TechDebtItem>>{};
    final byPriority = <String, List<TechDebtItem>>{};
    final byFile = <String, List<TechDebtItem>>{};

    for (final item in items) {
      // Group by type
      byType.putIfAbsent(item.type, () => []).add(item);

      // Group by category
      final category = item.category ?? 'uncategorized';
      byCategory.putIfAbsent(category, () => []).add(item);

      // Group by priority
      final priority = item.priority ?? 'medium';
      byPriority.putIfAbsent(priority, () => []).add(item);

      // Group by file
      byFile.putIfAbsent(item.file, () => []).add(item);
    }

    return {
      'total': items.length,
      'byType': byType.map((k, v) => MapEntry(k, v.length)),
      'byCategory': byCategory.map((k, v) => MapEntry(k, v.length)),
      'byPriority': byPriority.map((k, v) => MapEntry(k, v.length)),
      'byFile': byFile.map((k, v) => MapEntry(k, v.length)),
      'highPriority': byPriority['high']?.length ?? 0,
      'mediumPriority': byPriority['medium']?.length ?? 0,
      'lowPriority': byPriority['low']?.length ?? 0,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  /// Get items by category
  List<TechDebtItem> getItemsByCategory(
      List<TechDebtItem> items, String category,) {
    return items.where((item) => item.category == category).toList();
  }

  /// Get items by priority
  List<TechDebtItem> getItemsByPriority(
      List<TechDebtItem> items, String priority,) {
    return items.where((item) => item.priority == priority).toList();
  }

  /// Get items by type
  List<TechDebtItem> getItemsByType(List<TechDebtItem> items, String type) {
    return items.where((item) => item.type == type).toList();
  }

  /// Get items by file
  List<TechDebtItem> getItemsByFile(List<TechDebtItem> items, String file) {
    return items.where((item) => item.file == file).toList();
  }
}
