#!/usr/bin/env dart
// Resource Disposal Checker
// Checks for undisposed controllers, streams, and timers

import 'dart:io';

void main() {
  print('🔍 Checking resource disposal...\n');

  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    print('❌ lib directory not found');
    exit(1);
  }

  final findings = <ResourceFinding>[];

  // Find all Dart files in lib
  final dartFiles = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  print('Found ${dartFiles.length} files to scan\n');

  for (final file in dartFiles) {
    final fileFindings = scanFile(file);
    findings.addAll(fileFindings);
  }

  // Generate report
  generateReport(findings);

  if (findings.isNotEmpty) {
    print('\n⚠️  Found ${findings.length} potential resource leak(s)');
    exit(1);
  } else {
    print('\n✅ No resource leaks detected');
    exit(0);
  }
}

List<ResourceFinding> scanFile(File file) {
  final findings = <ResourceFinding>[];
  final content = file.readAsStringSync();
  final lines = content.split('\n');

  // Resource types to check
  final resourceTypes = [
    'TextEditingController',
    'AnimationController',
    'VideoPlayerController',
    'StreamController',
    'Timer',
    'StreamSubscription',
    'FocusNode',
    'ScrollController',
    'TabController',
  ];

  // Check for resource creation without disposal
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    final lineNum = i + 1;

    for (final resourceType in resourceTypes) {
      // Check for resource creation
      if (line.contains('$resourceType(') ||
          line.contains('$resourceType.') ||
          (resourceType == 'StreamSubscription' && line.contains('.listen('))) {
        // Find the class this is in
        final classStart = findClassStart(lines, i);
        if (classStart == -1) continue;

        // Check if class has dispose method
        final classEnd = findClassEnd(lines, classStart);
        final classContent = lines.sublist(classStart, classEnd).join('\n');

        // Special handling for StreamSubscription
        if (resourceType == 'StreamSubscription') {
          if (!classContent.contains('cancel()') &&
              !classContent.contains('dispose()')) {
            findings.add(
              ResourceFinding(
                file: file.path,
                line: lineNum,
                severity: 'HIGH',
                issue: 'StreamSubscription not cancelled',
                resourceType: resourceType,
                code: line.trim(),
              ),
            );
          }
        } else {
          // Check if dispose method exists and disposes this resource
          if (!classContent.contains('dispose()')) {
            findings.add(
              ResourceFinding(
                file: file.path,
                line: lineNum,
                severity: 'HIGH',
                issue: 'Resource created but class has no dispose method',
                resourceType: resourceType,
                code: line.trim(),
              ),
            );
          } else {
            // Check if dispose method actually disposes this resource
            final disposeIndex = classContent.indexOf('dispose()');
            if (disposeIndex != -1) {
              final disposeContent = classContent.substring(disposeIndex);
              final disposeEnd = disposeContent.indexOf('}');
              final disposeMethod = disposeContent.substring(0, disposeEnd);

              // Check if resource is disposed
              final resourceVarName = extractVariableName(line, resourceType);
              if (resourceVarName != null &&
                  !disposeMethod.contains('$resourceVarName.dispose') &&
                  !disposeMethod.contains('$resourceVarName.cancel') &&
                  !disposeMethod.contains('$resourceVarName.close')) {
                findings.add(
                  ResourceFinding(
                    file: file.path,
                    line: lineNum,
                    severity: 'MEDIUM',
                    issue: 'Resource may not be disposed in dispose method',
                    resourceType: resourceType,
                    code: line.trim(),
                  ),
                );
              }
            }
          }
        }
      }
    }
  }

  return findings;
}

int findClassStart(List<String> lines, int currentLine) {
  for (int i = currentLine; i >= 0; i--) {
    if (lines[i].contains('class ') && !lines[i].contains('//')) {
      return i;
    }
  }
  return -1;
}

int findClassEnd(List<String> lines, int startLine) {
  int braceCount = 0;
  bool inClass = false;

  for (int i = startLine; i < lines.length; i++) {
    final line = lines[i];
    if (line.contains('class ')) {
      inClass = true;
    }
    braceCount += '{'.allMatches(line).length;
    braceCount -= '}'.allMatches(line).length;

    if (inClass && braceCount == 0 && line.contains('}')) {
      return i + 1;
    }
  }
  return lines.length;
}

String? extractVariableName(String line, String resourceType) {
  // Try to extract variable name from line
  // e.g., "final controller = TextEditingController();" -> "controller"
  final patterns = [
    RegExp('final\\s+(\\w+)\\s*=\\s*$resourceType'),
    RegExp('late\\s+final\\s+(\\w+)\\s*=\\s*$resourceType'),
    RegExp('(\\w+)\\s*=\\s*$resourceType'),
    RegExp('$resourceType\\.(\\w+)'),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(line);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
  }

  return null;
}

void generateReport(List<ResourceFinding> findings) {
  print('\n${'=' * 80}');
  print('RESOURCE DISPOSAL CHECK REPORT');
  print('${'=' * 80}\n');

  if (findings.isEmpty) {
    print('✅ All resources are properly disposed!\n');
    return;
  }

  // Group by severity
  final high = findings.where((f) => f.severity == 'HIGH').toList();
  final medium = findings.where((f) => f.severity == 'MEDIUM').toList();

  if (high.isNotEmpty) {
    print('⚠️  HIGH PRIORITY ISSUES (${high.length}):\n');
    for (final finding in high) {
      print('  File: ${finding.file}');
      print('  Line: ${finding.line}');
      print('  Issue: ${finding.issue}');
      print('  Resource: ${finding.resourceType}');
      print('  Code: ${finding.code}');
      print('');
    }
  }

  if (medium.isNotEmpty) {
    print('ℹ️  MEDIUM PRIORITY ISSUES (${medium.length}):\n');
    for (final finding in medium) {
      print('  File: ${finding.file}');
      print('  Line: ${finding.line}');
      print('  Issue: ${finding.issue}');
      print('  Resource: ${finding.resourceType}');
      print('  Code: ${finding.code}');
      print('');
    }
  }

  // Summary by resource type
  print('\n${'-' * 80}');
  print('SUMMARY BY RESOURCE TYPE:\n');
  final byType = <String, List<ResourceFinding>>{};
  for (final finding in findings) {
    byType.putIfAbsent(finding.resourceType, () => []).add(finding);
  }

  for (final entry in byType.entries) {
    print('  ${entry.key}: ${entry.value.length} issue(s)');
  }
}

class ResourceFinding {
  final String file;
  final int line;
  final String severity;
  final String issue;
  final String resourceType;
  final String code;

  ResourceFinding({
    required this.file,
    required this.line,
    required this.severity,
    required this.issue,
    required this.resourceType,
    required this.code,
  });
}
