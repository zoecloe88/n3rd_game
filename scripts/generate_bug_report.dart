#!/usr/bin/env dart
// Bug Report Generator
// Aggregates findings from all bugbot scans into a comprehensive report

import 'dart:io';

void main() {
  print('📊 Generating comprehensive bug report...\n');

  final report = StringBuffer();
  final timestamp = DateTime.now().toIso8601String();

  // Header
  report.writeln('# Bugbot Full Project Scan Report');
  report.writeln('');
  report.writeln('**Generated:** $timestamp');
  report.writeln(
    '**Workflow Run:** ${Platform.environment['GITHUB_RUN_ID'] ?? 'N/A'}',
  );
  report.writeln('');
  report.writeln('---');
  report.writeln('');

  // Collect findings from artifacts
  final findings = <String, List<String>>{};

  // Check for static analysis results
  if (Directory('artifacts/static-analysis-results').existsSync()) {
    final analyzeFile =
        File('artifacts/static-analysis-results/.bugbot/analyze_output.txt');
    if (analyzeFile.existsSync()) {
      final content = analyzeFile.readAsStringSync();
      if (content.isNotEmpty && !content.contains('No issues found')) {
        findings['Static Analysis'] = [content];
      }
    }
  }

  // Check for memory leak results
  if (Directory('artifacts/memory-leak-results').existsSync()) {
    final memoryLeaks =
        File('artifacts/memory-leak-results/.bugbot/memory_leaks.txt');
    final resourceDisposal =
        File('artifacts/memory-leak-results/.bugbot/resource_disposal.txt');
    final testPatterns =
        File('artifacts/memory-leak-results/.bugbot/test_patterns.txt');

    final memoryFindings = <String>[];
    if (memoryLeaks.existsSync()) {
      final content = memoryLeaks.readAsStringSync();
      if (content.isNotEmpty) {
        memoryFindings.add('## Memory Leaks\n\n$content');
      }
    }
    if (resourceDisposal.existsSync()) {
      final content = resourceDisposal.readAsStringSync();
      if (content.isNotEmpty) {
        memoryFindings.add('## Resource Disposal\n\n$content');
      }
    }
    if (testPatterns.existsSync()) {
      final content = testPatterns.readAsStringSync();
      if (content.isNotEmpty) {
        memoryFindings.add('## Test Patterns\n\n$content');
      }
    }

    if (memoryFindings.isNotEmpty) {
      findings['Memory Leaks'] = memoryFindings;
    }
  }

  // Check for security results
  if (Directory('artifacts/security-results').existsSync()) {
    final secrets = File('artifacts/security-results/.bugbot/secrets.txt');
    final dependencies =
        File('artifacts/security-results/.bugbot/dependencies.txt');

    final securityFindings = <String>[];
    if (secrets.existsSync()) {
      final content = secrets.readAsStringSync();
      if (content.isNotEmpty) {
        securityFindings.add('## Secret Scanning\n\n$content');
      }
    }
    if (dependencies.existsSync()) {
      final content = dependencies.readAsStringSync();
      if (content.isNotEmpty) {
        securityFindings.add('## Dependencies\n\n$content');
      }
    }

    if (securityFindings.isNotEmpty) {
      findings['Security'] = securityFindings;
    }
  }

  // Check for code quality results
  if (Directory('artifacts/code-quality-results').existsSync()) {
    final complexity =
        File('artifacts/code-quality-results/.bugbot/complexity.txt');
    if (complexity.existsSync()) {
      final content = complexity.readAsStringSync();
      if (content.isNotEmpty) {
        findings['Code Quality'] = [content];
      }
    }
  }

  // Check for test results
  if (Directory('artifacts/test-results').existsSync()) {
    final testFailures =
        File('artifacts/test-results/.bugbot/test_failures.txt');
    if (testFailures.existsSync()) {
      final content = testFailures.readAsStringSync();
      if (content.isNotEmpty && !content.contains('No test failures')) {
        findings['Test Failures'] = [content];
      }
    }
  }

  // Generate summary
  final totalFindings =
      findings.values.fold<int>(0, (sum, list) => sum + list.length);

  report.writeln('## Executive Summary');
  report.writeln('');
  report.writeln('| Category | Issues Found |');
  report.writeln('|----------|--------------|');
  for (final entry in findings.entries) {
    report.writeln('| ${entry.key} | ${entry.value.length} |');
  }
  report.writeln('| **Total** | **$totalFindings** |');
  report.writeln('');

  // Critical issues section
  bool hasCritical = false;
  for (final category in findings.keys) {
    for (final finding in findings[category]!) {
      if (finding.contains('CRITICAL') || finding.contains('Critical')) {
        hasCritical = true;
        break;
      }
    }
  }

  if (hasCritical) {
    report.writeln('## 🚨 Critical Issues');
    report.writeln('');
    report.writeln(
      '**Action Required:** These issues may cause crashes or data loss.',
    );
    report.writeln('');
  }

  // Detailed findings
  for (final entry in findings.entries) {
    report.writeln('## ${entry.key}');
    report.writeln('');

    for (final finding in entry.value) {
      report.writeln(finding);
      report.writeln('');
    }

    report.writeln('---');
    report.writeln('');
  }

  // Recommendations
  report.writeln('## Recommendations');
  report.writeln('');

  if (findings.containsKey('Memory Leaks')) {
    report.writeln(
      '1. **Memory Leaks**: Review and fix all undisposed services in test files',
    );
    report.writeln(
      '   - Ensure all services created in tests have dispose() calls',
    );
    report.writeln('   - Use try-finally blocks for service cleanup');
    report.writeln('   - Check for loops creating services without disposal');
    report.writeln('');
  }

  if (findings.containsKey('Security')) {
    report.writeln(
      '2. **Security**: Address security vulnerabilities immediately',
    );
    report.writeln('   - Remove any hardcoded secrets');
    report.writeln('   - Update vulnerable dependencies');
    report.writeln('');
  }

  if (findings.containsKey('Static Analysis')) {
    report.writeln('3. **Static Analysis**: Fix linter warnings and errors');
    report.writeln('   - Run `flutter analyze` locally');
    report.writeln('   - Fix formatting issues with `dart format`');
    report.writeln('');
  }

  if (findings.containsKey('Test Failures')) {
    report.writeln('4. **Test Failures**: Fix failing tests');
    report.writeln('   - Review test output for details');
    report.writeln('   - Ensure all tests pass before merging');
    report.writeln('');
  }

  // Footer
  report.writeln('---');
  report.writeln('');
  report.writeln(
    '*This report was automatically generated by the Bugbot workflow.*',
  );
  report.writeln(
    '*For questions or issues, please contact the development team.*',
  );

  // Write report
  final reportFile = File('bugbot_report.md');
  reportFile.writeAsStringSync(report.toString());

  print('✅ Bug report generated: bugbot_report.md');
  print('\nSummary:');
  print('  Total categories: ${findings.length}');
  print('  Total findings: $totalFindings');

  if (hasCritical) {
    print('\n⚠️  CRITICAL issues found - immediate action required!');
    exit(1);
  } else if (totalFindings > 0) {
    print('\nℹ️  Issues found - review recommended');
    exit(1);
  } else {
    print('\n✅ No issues found!');
    exit(0);
  }
}
