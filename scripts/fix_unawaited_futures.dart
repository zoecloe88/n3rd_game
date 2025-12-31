#!/usr/bin/env dart

// Script to automatically fix unawaited futures by wrapping them with unawaited()
// Usage: dart scripts/fix_unawaited_futures.dart

import 'dart:io';

void main() async {
  print('🔍 Finding unawaited futures...');
  
  // Get all unawaited future locations from analyzer
  final issues = await _getUnawaitedFutureIssues();
  
  if (issues.isEmpty) {
    print('✅ No unawaited futures found!');
    return;
  }
  
  print('Found ${issues.length} unawaited futures across ${issues.keys.length} files');
  
  // Group by file and fix
  int totalFixed = 0;
  for (final entry in issues.entries) {
    final filePath = entry.key;
    final lineNumbers = entry.value;
    
    print('Fixing ${lineNumbers.length} issues in $filePath...');
    final fixed = _fixFile(filePath, lineNumbers);
    totalFixed += fixed;
  }
  
  print('\n✅ Fixed $totalFixed unawaited futures');
  
  // Validate by re-running analyzer
  print('\n🔍 Validating fixes...');
  final remaining = await _getUnawaitedFutureIssues();
  if (remaining.isEmpty) {
    print('✅ All unawaited futures fixed!');
  } else {
    print('⚠️  ${remaining.values.map((v) => v.length).reduce((a, b) => a + b)} issues remaining');
    for (final entry in remaining.entries) {
      print('  ${entry.key}: ${entry.value.join(", ")}');
    }
  }
}

/// Get all unawaited future issues from dart analyze
Future<Map<String, List<int>>> _getUnawaitedFutureIssues() async {
  final result = await Process.run(
    'dart',
    ['analyze', '--fatal-infos'],
    runInShell: true,
  );
  
  final issues = <String, List<int>>{};
  
  for (final line in result.stdout.toString().split('\n')) {
    if (line.contains("Missing an 'await'") && line.contains('unawaited_futures')) {
      // Parse: "   info - lib/path/file.dart:123:45 - Missing an 'await'..."
      final match = RegExp(r'^\s+info - (.+):(\d+):\d+ -').firstMatch(line);
      if (match != null) {
        final filePath = match.group(1);
        final lineNumber = int.parse(match.group(2)!);
        
        if (filePath != null) {
          issues.putIfAbsent(filePath, () => []).add(lineNumber);
        }
      }
    }
  }
  
  // Sort line numbers for each file
  for (final entry in issues.entries) {
    entry.value.sort((a, b) => b.compareTo(a)); // Sort descending for safe replacement
  }
  
  return issues;
}

/// Fix unawaited futures in a file
int _fixFile(String filePath, List<int> lineNumbers) {
  final file = File(filePath);
  if (!file.existsSync()) {
    print('  ⚠️  File not found: $filePath');
    return 0;
  }
  
  final lines = file.readAsLinesSync();
  var fixed = 0;
  var hasImport = false;
  int? importInsertIndex;
  final processedLines = <int>{};
  
  // Check if import already exists
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].contains("import 'package:n3rd_game/utils/unawaited_helper.dart';")) {
      hasImport = true;
      break;
    }
    // Find where to insert import (after other imports, before first non-import line)
    if (lines[i].startsWith('import ') && importInsertIndex == null) {
      importInsertIndex = i + 1;
    } else if (!lines[i].startsWith('import ') && 
               lines[i].trim().isNotEmpty && 
               !lines[i].startsWith('///') &&
               !lines[i].startsWith('//') &&
               importInsertIndex == null) {
      importInsertIndex = i;
    }
  }
  
  // Fix each line (process in reverse to maintain line numbers)
  for (final lineNum in lineNumbers) {
    if (lineNum < 1 || lineNum > lines.length) {
      print('  ⚠️  Invalid line number: $lineNum');
      continue;
    }
    
    final index = lineNum - 1;
    
    // Skip if already processed (as part of multi-line expression)
    if (processedLines.contains(index)) {
      continue;
    }
    
    final originalLine = lines[index];
    
    // Skip if already wrapped with unawaited
    if (originalLine.trim().startsWith('unawaited(') || 
        originalLine.contains('unawaited(')) {
      continue;
    }
    
    // Check if this is a method chain like .catchError() - need to look backwards
    final trimmed = originalLine.trim();
    if (trimmed.startsWith('.catchError') || 
        trimmed.startsWith('.then') ||
        trimmed.startsWith(').catchError') ||
        trimmed.startsWith(').then')) {
      // Look backwards to find the start of the expression
      final backwardResult = _findExpressionStart(lines, index);
      if (backwardResult != null) {
        // Mark all processed lines
        for (int i = backwardResult.startIndex; i <= backwardResult.endIndex; i++) {
          processedLines.add(i);
        }
        lines[backwardResult.startIndex] = backwardResult.wrappedStart;
        if (backwardResult.endIndex > backwardResult.startIndex) {
          lines[backwardResult.endIndex] = backwardResult.wrappedEnd;
        }
        fixed++;
        continue;
      }
    }
    
    // Try to find and wrap multi-line expression first
    final multilineResult = _wrapMultilineExpression(lines, index);
    if (multilineResult != null) {
      // Mark all processed lines
      for (int i = multilineResult.startIndex; i <= multilineResult.endIndex; i++) {
        processedLines.add(i);
      }
      lines[multilineResult.startIndex] = multilineResult.wrappedStart;
      // Update lines in between if needed
      if (multilineResult.endIndex > multilineResult.startIndex) {
        lines[multilineResult.endIndex] = multilineResult.wrappedEnd;
      }
      fixed++;
      continue;
    }
    
    // Try single-line wrap
    final wrapped = _wrapWithUnawaited(originalLine, lines, index);
    if (wrapped != null) {
      lines[index] = wrapped;
      fixed++;
    }
  }
  
  // Add import if needed
  if (!hasImport && fixed > 0 && importInsertIndex != null) {
    lines.insert(importInsertIndex, "import 'package:n3rd_game/utils/unawaited_helper.dart';");
    fixed++; // Count import addition
  }
  
  // Write file back
  if (fixed > 0) {
    file.writeAsStringSync(lines.join('\n'));
  }
  
  return fixed;
}

/// Result of wrapping a multi-line expression
class _MultilineWrapResult {
  
  _MultilineWrapResult({
    required this.startIndex,
    required this.endIndex,
    required this.wrappedStart,
    required this.wrappedEnd,
  });
  final int startIndex;
  final int endIndex;
  final String wrappedStart;
  final String wrappedEnd;
}

/// Try to wrap a multi-line expression starting at the given index
_MultilineWrapResult? _wrapMultilineExpression(List<String> lines, int startIndex) {
  if (startIndex >= lines.length) return null;
  
  final startLine = lines[startIndex].trim();
  
  // Check if this looks like the start of a multi-line call
  // Pattern: "MethodName(" or ends with "("
  if (!startLine.contains('(') || startLine.endsWith(');')) {
    return null;
  }
  
  // Find where the expression ends by matching parentheses
  int parenDepth = 0;
  int endIndex = startIndex;
  bool foundStart = false;
  bool foundSemicolon = false;
  
  for (int i = startIndex; i < lines.length; i++) {
    final line = lines[i];
    for (int j = 0; j < line.length; j++) {
      if (line[j] == '(') {
        parenDepth++;
        foundStart = true;
      } else if (line[j] == ')') {
        parenDepth--;
        if (foundStart && parenDepth == 0) {
          // Found the closing paren - check if there's a semicolon after or method chain
          final restOfLine = line.substring(j + 1).trim();
          if (restOfLine.startsWith(';')) {
            endIndex = i;
            foundSemicolon = true;
            break;
          } else if (restOfLine.startsWith('.') && i + 1 < lines.length) {
            // Method chain - continue to find the end
            continue;
          } else if (restOfLine.isEmpty && i + 1 < lines.length) {
            // Check next line
            final nextLine = lines[i + 1].trim();
            if (nextLine.startsWith('.catchError') || 
                nextLine.startsWith('.then') ||
                nextLine.startsWith(';')) {
              continue;
            } else {
              endIndex = i;
              break;
            }
          } else {
            endIndex = i;
            break;
          }
        }
      }
    }
    
    if (foundSemicolon || (foundStart && parenDepth == 0 && endIndex == i)) {
      break;
    }
    
    // Safety: don't go beyond 20 lines
    if (i - startIndex > 20) break;
  }
  
  if (endIndex == startIndex && !foundSemicolon) {
    // Check if it's a single line that just needs wrapping
    final trimmed = startLine;
    if (trimmed.endsWith(');')) {
      final indent = lines[startIndex].substring(0, lines[startIndex].length - trimmed.length);
      final expr = trimmed.substring(0, trimmed.length - 1);
      final wrapped = '${indent}unawaited($expr);';
      return _MultilineWrapResult(
        startIndex: startIndex,
        endIndex: startIndex,
        wrappedStart: wrapped,
        wrappedEnd: wrapped,
      );
    }
    return null;
  }
  
  // Check if this looks like a Future-returning method that should be wrapped
  final startTrimmed = startLine.toLowerCase();
  final shouldWrap = 
      startTrimmed.contains('navigationhelper.safenavigate') ||
      startTrimmed.contains('navigationhelper.safepushreplacementnamed') ||
      startTrimmed.contains('errorhandler.') ||
      startTrimmed.contains('errorhandler.show') ||
      (startTrimmed.contains('analytics') && startTrimmed.contains('log')) ||
      startTrimmed.contains('.catcherror') ||
      startTrimmed.startsWith('_show') && startTrimmed.contains('dialog') ||
      startTrimmed.startsWith('_show') && startTrimmed.contains('upgrade') ||
      startTrimmed.startsWith('_show') && startTrimmed.contains('trivia') ||
      startTrimmed.contains('showdialog') ||
      startTrimmed.contains('navigator.of') && startTrimmed.contains('pushreplacement');
  
  if (!shouldWrap) {
    return null;
  }
  
  final indent = lines[startIndex].substring(0, lines[startIndex].length - startLine.length);
  final wrappedStart = '${indent}unawaited($startLine';
  
  String wrappedEnd;
  if (endIndex == startIndex) {
    // Single line
    final endLine = lines[endIndex];
    if (endLine.trim().endsWith(');')) {
      wrappedEnd = endLine.replaceFirst(');', '));');
    } else if (endLine.trim().endsWith(')')) {
      wrappedEnd = endLine.replaceFirst(')', '));');
    } else {
      wrappedEnd = '$endLine);';
    }
  } else {
    // Multi-line - wrap the closing
    final endLine = lines[endIndex];
    if (endLine.trim().endsWith(');')) {
      wrappedEnd = endLine.replaceFirst(');', '));');
    } else if (endLine.trim().endsWith(')')) {
      // Check if next line has semicolon
      if (endIndex + 1 < lines.length && lines[endIndex + 1].trim() == ';') {
        wrappedEnd = endLine;
        lines[endIndex + 1] = ');';
      } else {
        wrappedEnd = endLine.replaceFirst(')', '));');
      }
    } else {
      wrappedEnd = endLine;
    }
  }
  
  return _MultilineWrapResult(
    startIndex: startIndex,
    endIndex: endIndex,
    wrappedStart: wrappedStart,
    wrappedEnd: wrappedEnd,
  );
}

/// Find the start of an expression when we're at a method chain (.catchError, etc.)
_MultilineWrapResult? _findExpressionStart(List<String> lines, int chainIndex) {
  if (chainIndex < 1) return null;
  
  // Look backwards to find where the expression starts
  int startIndex = chainIndex;
  bool foundClosing = false;
  
  // First, find where the chain ends
  int endIndex = chainIndex;
  for (int i = chainIndex; i < lines.length && i < chainIndex + 10; i++) {
    final line = lines[i];
    if (line.trim().endsWith(');')) {
      endIndex = i;
      foundClosing = true;
      break;
    }
  }
  
  if (!foundClosing) return null;
  
  // Now look backwards to find the start
  for (int i = chainIndex - 1; i >= 0 && i >= chainIndex - 20; i--) {
    final line = lines[i].trim();
    
    // Check if this line looks like the start of a method call
    if (line.contains('(') && 
        (line.contains('Service') || 
         line.contains('logCustomEvent') ||
         line.contains('log') ||
         line.contains('analytics'))) {
      startIndex = i;
      break;
    }
  }
  
  if (startIndex >= chainIndex) return null;
  
  final startLine = lines[startIndex].trim();
  final indent = lines[startIndex].substring(0, lines[startIndex].length - startLine.length);
  
  // Wrap the start
  final wrappedStart = '${indent}unawaited($startLine';
  
  // Wrap the end
  final endLine = lines[endIndex];
  final wrappedEnd = endLine.replaceFirst(');', '));').replaceAll(';;', ';');
  
  return _MultilineWrapResult(
    startIndex: startIndex,
    endIndex: endIndex,
    wrappedStart: wrappedStart,
    wrappedEnd: wrappedEnd,
  );
}

/// Wrap a line with unawaited()
String? _wrapWithUnawaited(String line, List<String> allLines, int index) {
  final trimmed = line.trim();
  
  // Skip empty lines, comments, imports
  if (trimmed.isEmpty || 
      trimmed.startsWith('//') || 
      trimmed.startsWith('///') ||
      trimmed.startsWith('import ') ||
      trimmed.startsWith('export ') ||
      trimmed.startsWith('library ') ||
      trimmed.startsWith('part ')) {
    return null;
  }
  
  // Find the expression to wrap - look for common patterns
  // Pattern 1: Simple method call ending with semicolon
  // e.g., "HapticService().lightImpact();"
  if (trimmed.endsWith(');')) {
    // Find the opening parenthesis
    final parenIndex = trimmed.lastIndexOf('(');
    if (parenIndex > 0) {
      // Check if it's a method call (has dot or is constructor call)
      final beforeParen = trimmed.substring(0, parenIndex).trim();
      if (beforeParen.contains('.') || beforeParen.endsWith('()')) {
        // Wrap the entire call
        final indent = line.substring(0, line.length - trimmed.length);
        final expression = trimmed.substring(0, trimmed.length - 1); // Remove semicolon
        return '${indent}unawaited($expression);';
      }
    }
  }
  
  // Pattern 2: Method call with arguments (multi-line detection)
  // Check if line ends with comma (likely part of multi-line call)
  if (trimmed.endsWith(',') || trimmed.endsWith(',')) {
    // This is likely part of a multi-line expression
    // We'll need to handle it differently - for now, skip
    return null;
  }
  
  // Pattern 3: Assignment with Future call
  // e.g., "final result = someMethod();"
  final assignMatch = RegExp(r'^(\s*)(\w+\s+\w+\s*=\s*)(.+?)(;?)$').firstMatch(trimmed);
  if (assignMatch != null) {
    final indent = assignMatch.group(1)!;
    final assignment = assignMatch.group(2)!;
    final expression = assignMatch.group(3)!;
    final semicolon = assignMatch.group(4) ?? '';
    
    // Check if expression looks like a Future-returning call
    if (expression.contains('(') && expression.contains(')')) {
      return '$indent$assignment unawaited($expression)$semicolon';
    }
  }
  
  // Pattern 4: Standalone call (no assignment)
  // Try to wrap the whole line if it looks like a method call
  if (trimmed.contains('(') && trimmed.contains(')')) {
    final indent = line.substring(0, line.length - trimmed.length);
    // Simple approach: wrap entire expression
    if (trimmed.endsWith(';')) {
      final expr = trimmed.substring(0, trimmed.length - 1);
      return '${indent}unawaited($expr);';
    }
  }
  
  return null;
}

