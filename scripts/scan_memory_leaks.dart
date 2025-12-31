#!/usr/bin/env dart
// Memory Leak Scanner for Test Files
// Scans all test files for potential memory leaks from undisposed services

import 'dart:io';

void main() {
  print('🔍 Scanning for memory leaks in test files...\n');

  final testDir = Directory('test');
  if (!testDir.existsSync()) {
    print('❌ Test directory not found');
    exit(1);
  }

  final findings = <MemoryLeakFinding>[];

  // Find all test files
  final testFiles = testDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('_test.dart'))
      .toList();

  print('Found ${testFiles.length} test files to scan\n');

  for (final file in testFiles) {
    final fileFindings = scanFile(file);
    findings.addAll(fileFindings);
  }

  // Generate report
  generateReport(findings);

  if (findings.isNotEmpty) {
    print('\n⚠️  Found ${findings.length} potential memory leak(s)');
    exit(1);
  } else {
    print('\n✅ No memory leaks detected');
    exit(0);
  }
}

List<MemoryLeakFinding> scanFile(File file) {
  final findings = <MemoryLeakFinding>[];
  final content = file.readAsStringSync();
  final lines = content.split('\n');

  // Service types to check
  final serviceTypes = [
    'GameService',
    'AnalyticsService',
    'SubscriptionService',
    'NetworkService',
    'MultiplayerService',
    'AuthService',
    'SoundService',
    'TextToSpeechService',
    'VoiceRecognitionService',
    'ThemeService',
    'LanguageService',
    'TriviaGeneratorService',
    'VideoCacheService',
    'EditionContentService',
    'StatsService',
    'GameHistoryService',
    'ChallengeService',
    'RoomDiscoveryService',
    'SpectatorService',
    'GlobalLeaderboardService',
  ];

  // Check for service creation in loops without disposal
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    final lineNum = i + 1;

    // Check for loops creating services
    if (line.contains('for (') && i + 1 < lines.length) {
      final nextLines = lines.sublist(i, (i + 10).clamp(0, lines.length));
      final loopContent = nextLines.join('\n');

      for (final serviceType in serviceTypes) {
        if (loopContent.contains('$serviceType()') &&
            !loopContent.contains('dispose()') &&
            !loopContent.contains('try') &&
            !loopContent.contains('finally')) {
          findings.add(
            MemoryLeakFinding(
              file: file.path,
              line: lineNum,
              severity: 'CRITICAL',
              issue: 'Service created in loop without disposal',
              serviceType: serviceType,
              code: line.trim(),
            ),
          );
        }
      }
    }

    // Check for service creation without dispose in same test
    for (final serviceType in serviceTypes) {
      if (line.contains('$serviceType()') && !line.contains('late')) {
        // Check if dispose is called in this test
        final testStart = findTestStart(lines, i);
        final testEnd = findTestEnd(lines, i);

        if (testStart != -1 && testEnd != -1) {
          final testContent = lines.sublist(testStart, testEnd).join('\n');

          if (!testContent.contains('dispose()') &&
              !testContent.contains('try') &&
              !testContent.contains('finally')) {
            findings.add(
              MemoryLeakFinding(
                file: file.path,
                line: lineNum,
                severity: 'HIGH',
                issue: 'Service created without dispose in test',
                serviceType: serviceType,
                code: line.trim(),
              ),
            );
          }
        }
      }
    }

    // Check for service creation in setUp without tearDown dispose
    if (line.contains('setUp(()') || line.contains('setUp(() async')) {
      final setUpEnd = findBlockEnd(lines, i);
      final setUpContent = lines.sublist(i, setUpEnd).join('\n');

      // Find corresponding tearDown
      final tearDownIndex = findTearDown(lines, i);

      if (tearDownIndex == -1) {
        // No tearDown found - check if services are created in setUp
        for (final serviceType in serviceTypes) {
          if (setUpContent.contains('$serviceType()')) {
            findings.add(
              MemoryLeakFinding(
                file: file.path,
                line: lineNum,
                severity: 'HIGH',
                issue: 'Service created in setUp without tearDown',
                serviceType: serviceType,
                code: line.trim(),
              ),
            );
          }
        }
      } else {
        // Check if tearDown has dispose
        final tearDownEnd = findBlockEnd(lines, tearDownIndex);
        final tearDownContent =
            lines.sublist(tearDownIndex, tearDownEnd).join('\n');

        for (final serviceType in serviceTypes) {
          if (setUpContent.contains('$serviceType()') &&
              !tearDownContent.contains('dispose()')) {
            findings.add(
              MemoryLeakFinding(
                file: file.path,
                line: lineNum,
                severity: 'HIGH',
                issue: 'Service created in setUp but tearDown missing dispose',
                serviceType: serviceType,
                code: line.trim(),
              ),
            );
          }
        }
      }
    }
  }

  return findings;
}

int findTestStart(List<String> lines, int currentLine) {
  for (int i = currentLine; i >= 0; i--) {
    if (lines[i].contains('test(') || lines[i].contains('testWidgets(')) {
      return i;
    }
  }
  return -1;
}

int findTestEnd(List<String> lines, int startLine) {
  int braceCount = 0;
  bool inTest = false;

  for (int i = startLine; i < lines.length; i++) {
    final line = lines[i];
    braceCount += '{'.allMatches(line).length;
    braceCount -= '}'.allMatches(line).length;

    if (line.contains('test(') || line.contains('testWidgets(')) {
      inTest = true;
    }

    if (inTest && braceCount == 0 && line.contains('}')) {
      return i + 1;
    }
  }
  return lines.length;
}

int findBlockEnd(List<String> lines, int startLine) {
  int braceCount = 0;
  bool inBlock = false;

  for (int i = startLine; i < lines.length; i++) {
    final line = lines[i];
    if (line.contains('{')) {
      inBlock = true;
      braceCount++;
    }
    if (line.contains('}')) {
      braceCount--;
      if (inBlock && braceCount == 0) {
        return i + 1;
      }
    }
  }
  return lines.length;
}

int findTearDown(List<String> lines, int afterLine) {
  for (int i = afterLine; i < lines.length; i++) {
    if (lines[i].contains('tearDown(()') ||
        lines[i].contains('tearDown(() async')) {
      return i;
    }
  }
  return -1;
}

void generateReport(List<MemoryLeakFinding> findings) {
  print('\n${'=' * 80}');
  print('MEMORY LEAK SCAN REPORT');
  print('${'=' * 80}\n');

  if (findings.isEmpty) {
    print('✅ No memory leaks found!\n');
    return;
  }

  // Group by severity
  final critical = findings.where((f) => f.severity == 'CRITICAL').toList();
  final high = findings.where((f) => f.severity == 'HIGH').toList();

  if (critical.isNotEmpty) {
    print('🚨 CRITICAL ISSUES (${critical.length}):\n');
    for (final finding in critical) {
      print('  File: ${finding.file}');
      print('  Line: ${finding.line}');
      print('  Issue: ${finding.issue}');
      print('  Service: ${finding.serviceType}');
      print('  Code: ${finding.code}');
      print('');
    }
  }

  if (high.isNotEmpty) {
    print('⚠️  HIGH PRIORITY ISSUES (${high.length}):\n');
    for (final finding in high) {
      print('  File: ${finding.file}');
      print('  Line: ${finding.line}');
      print('  Issue: ${finding.issue}');
      print('  Service: ${finding.serviceType}');
      print('  Code: ${finding.code}');
      print('');
    }
  }

  // Summary by file
  print('\n${'-' * 80}');
  print('SUMMARY BY FILE:\n');
  final byFile = <String, List<MemoryLeakFinding>>{};
  for (final finding in findings) {
    byFile.putIfAbsent(finding.file, () => []).add(finding);
  }

  for (final entry in byFile.entries) {
    print('  ${entry.key}: ${entry.value.length} issue(s)');
  }
}

class MemoryLeakFinding {
  final String file;
  final int line;
  final String severity;
  final String issue;
  final String serviceType;
  final String code;

  MemoryLeakFinding({
    required this.file,
    required this.line,
    required this.severity,
    required this.issue,
    required this.serviceType,
    required this.code,
  });
}
