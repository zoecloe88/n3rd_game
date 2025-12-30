#!/usr/bin/env dart
// Test Pattern Validator
// Validates test file structure and patterns

import 'dart:io';

void main() {
  print('🔍 Validating test patterns...\n');

  final testDir = Directory('test');
  if (!testDir.existsSync()) {
    print('❌ Test directory not found');
    exit(1);
  }

  final findings = <TestPatternFinding>[];

  // Find all test files
  final testFiles = testDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('_test.dart'))
      .toList();

  print('Found ${testFiles.length} test files to validate\n');

  for (final file in testFiles) {
    final fileFindings = validateFile(file);
    findings.addAll(fileFindings);
  }

  // Generate report
  generateReport(findings);

  if (findings.isNotEmpty) {
    print('\n⚠️  Found ${findings.length} test pattern issue(s)');
    exit(1);
  } else {
    print('\n✅ All test patterns are valid');
    exit(0);
  }
}

List<TestPatternFinding> validateFile(File file) {
  final findings = <TestPatternFinding>[];
  final content = file.readAsStringSync();
  final lines = content.split('\n');

  // Check for duplicate tearDown blocks
  int tearDownCount = 0;
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].contains('tearDown(()') ||
        lines[i].contains('tearDown(() async')) {
      tearDownCount++;
      if (tearDownCount > 1) {
        findings.add(
          TestPatternFinding(
            file: file.path,
            line: i + 1,
            severity: 'HIGH',
            issue: 'Duplicate tearDown block found',
            code: lines[i].trim(),
          ),
        );
      }
    }
  }

  // Check for setUp without tearDown
  bool hasSetUp = false;
  bool hasTearDown = false;
  for (final line in lines) {
    if (line.contains('setUp(()') || line.contains('setUp(() async')) {
      hasSetUp = true;
    }
    if (line.contains('tearDown(()') || line.contains('tearDown(() async')) {
      hasTearDown = true;
    }
  }

  if (hasSetUp && !hasTearDown) {
    findings.add(
      TestPatternFinding(
        file: file.path,
        line: 1,
        severity: 'MEDIUM',
        issue: 'setUp found but no tearDown block',
        code: 'setUp without tearDown',
      ),
    );
  }

  // Check for setUpAll without tearDownAll
  bool hasSetUpAll = false;
  bool hasTearDownAll = false;
  for (final line in lines) {
    if (line.contains('setUpAll(()') || line.contains('setUpAll(() async')) {
      hasSetUpAll = true;
    }
    if (line.contains('tearDownAll(()')) {
      hasTearDownAll = true;
    }
  }

  if (hasSetUpAll && !hasTearDownAll) {
    findings.add(
      TestPatternFinding(
        file: file.path,
        line: 1,
        severity: 'MEDIUM',
        issue: 'setUpAll found but no tearDownAll block',
        code: 'setUpAll without tearDownAll',
      ),
    );
  }

  // Check for TestWidgetsFlutterBinding.ensureInitialized() in widget tests
  bool hasWidgetTests = false;
  bool hasBindingInit = false;
  for (final line in lines) {
    if (line.contains('testWidgets(')) {
      hasWidgetTests = true;
    }
    if (line.contains('TestWidgetsFlutterBinding.ensureInitialized()')) {
      hasBindingInit = true;
    }
  }

  if (hasWidgetTests && !hasBindingInit) {
    findings.add(
      TestPatternFinding(
        file: file.path,
        line: 1,
        severity: 'MEDIUM',
        issue:
            'testWidgets found but TestWidgetsFlutterBinding.ensureInitialized() missing',
        code: 'Missing binding initialization',
      ),
    );
  }

  // Check for services created in setUp without dispose in tearDown
  final serviceTypes = [
    'GameService',
    'AnalyticsService',
    'SubscriptionService',
    'NetworkService',
    'AuthService',
  ];

  bool setUpCreatesService = false;
  bool tearDownHasDispose = false;

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];

    // Check setUp
    if (line.contains('setUp(()') || line.contains('setUp(() async')) {
      final setUpEnd = findBlockEnd(lines, i);
      final setUpContent = lines.sublist(i, setUpEnd).join('\n');

      for (final serviceType in serviceTypes) {
        if (setUpContent.contains('$serviceType()')) {
          setUpCreatesService = true;
          break;
        }
      }
    }

    // Check tearDown
    if (line.contains('tearDown(()') || line.contains('tearDown(() async')) {
      final tearDownEnd = findBlockEnd(lines, i);
      final tearDownContent = lines.sublist(i, tearDownEnd).join('\n');

      if (tearDownContent.contains('dispose()')) {
        tearDownHasDispose = true;
      }
    }
  }

  if (setUpCreatesService && !tearDownHasDispose) {
    findings.add(
      TestPatternFinding(
        file: file.path,
        line: 1,
        severity: 'HIGH',
        issue: 'Service created in setUp but tearDown missing dispose()',
        code: 'Missing dispose in tearDown',
      ),
    );
  }

  return findings;
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

void generateReport(List<TestPatternFinding> findings) {
  print('\n${'=' * 80}');
  print('TEST PATTERN VALIDATION REPORT');
  print('${'=' * 80}\n');

  if (findings.isEmpty) {
    print('✅ All test patterns are valid!\n');
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
      print('  Code: ${finding.code}');
      print('');
    }
  }

  // Summary by issue type
  print('\n${'-' * 80}');
  print('SUMMARY BY ISSUE TYPE:\n');
  final byIssue = <String, List<TestPatternFinding>>{};
  for (final finding in findings) {
    byIssue.putIfAbsent(finding.issue, () => []).add(finding);
  }

  for (final entry in byIssue.entries) {
    print('  ${entry.key}: ${entry.value.length} occurrence(s)');
  }
}

class TestPatternFinding {
  final String file;
  final int line;
  final String severity;
  final String issue;
  final String code;

  TestPatternFinding({
    required this.file,
    required this.line,
    required this.severity,
    required this.issue,
    required this.code,
  });
}
