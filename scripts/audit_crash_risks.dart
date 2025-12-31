#!/usr/bin/env dart
// Copyright (c) 2025 Girard Clairsaint. All rights reserved.

// Crash risk audit script
//
// Verifies that all crash prevention measures are in place:
// - List accesses use ListHelper
// - Provider access uses ProviderHelper
// - Firebase access checks initialization
// - JSON decoding uses JsonHelper
//
// Usage:
// ```bash
// dart scripts/audit_crash_risks.dart
// ```

import 'dart:io';

class CrashRiskFinding {
  CrashRiskFinding({
    required this.file,
    required this.line,
    required this.severity,
    required this.issue,
    required this.code,
    this.suggestion,
  });

  final String file;
  final int line;
  final String severity; // CRITICAL, HIGH, MEDIUM, LOW
  final String issue;
  final String code;
  final String? suggestion;

  @override
  String toString() {
    final suggestionText = suggestion != null ? '\n  Suggestion: $suggestion' : '';
    return '$severity: $file:$line\n  Issue: $issue\n  Code: $code$suggestionText';
  }
}

class CrashRiskAuditor {
  final List<CrashRiskFinding> findings = [];
  int totalFilesScanned = 0;
  int totalIssuesFound = 0;

  /// Scan a file for crash risks
  void scanFile(File file) {
    if (!file.path.endsWith('.dart')) return;
    if (file.path.contains('/test/')) return; // Skip test files
    if (file.path.contains('.g.dart')) return; // Skip generated files

    totalFilesScanned++;
    final content = file.readAsStringSync();
    final lines = content.split('\n');

    // Check for unsafe list accesses
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineNum = i + 1;

      // Check for .first, .last, .single without ListHelper
      if (line.contains('.first') || line.contains('.last') || line.contains('.single')) {
        // Skip if already using ListHelper
        if (line.contains('ListHelper.safe')) continue;
        // Skip if in comments
        if (line.trim().startsWith('//')) continue;
        // Skip if in strings
        if (line.contains("'.first'") || line.contains('".first"')) continue;
        // Skip email split patterns (safe)
        if (line.contains("split('@').first")) continue;

        // Check context - if there's a bounds check nearby, it might be safe
        bool hasBoundsCheck = false;
        for (int j = (i - 5).clamp(0, lines.length); j < (i + 5).clamp(0, lines.length); j++) {
          if (lines[j].contains('.isNotEmpty') || 
              lines[j].contains('.isEmpty') ||
              lines[j].contains('length > 0') ||
              lines[j].contains('length >= 1')) {
            hasBoundsCheck = true;
            break;
          }
        }

        if (!hasBoundsCheck) {
          findings.add(CrashRiskFinding(
            file: file.path,
            line: lineNum,
            severity: 'MEDIUM',
            issue: 'Unsafe list access (.first/.last/.single) without ListHelper',
            code: line.trim(),
            suggestion: 'Use ListHelper.safeFirst(), ListHelper.safeLast(), or ListHelper.safeSingle()',
          ),
        );
          totalIssuesFound++;
        }
      }

      // Check for direct Provider.of calls in screens
      if (file.path.contains('/screens/') && line.contains('Provider.of<')) {
        if (!line.contains('ProviderHelper.safe')) {
          findings.add(CrashRiskFinding(
            file: file.path,
            line: lineNum,
            severity: 'MEDIUM',
            issue: 'Direct Provider.of call without ProviderHelper',
            code: line.trim(),
            suggestion: 'Use ProviderHelper.safeGetOrThrow() or ProviderHelper.safeGet()',
          ),
        );
          totalIssuesFound++;
        }
      }

      // Check for Firebase access without initialization check
      if (line.contains('FirebaseAuth.instance') || line.contains('FirebaseFirestore.instance')) {
        // Check if FirebaseHelper is used in nearby context
        bool hasFirebaseHelper = false;
        for (int j = (i - 10).clamp(0, lines.length); j < (i + 10).clamp(0, lines.length); j++) {
          if (lines[j].contains('FirebaseHelper.isInitialized()')) {
            hasFirebaseHelper = true;
            break;
          }
        }
        // Skip if in getter that already checks (like _firestore getter)
        if (line.contains('get _') && (line.contains('FirebaseHelper') || line.contains('Firebase.app()'))) {
          hasFirebaseHelper = true;
        }

        if (!hasFirebaseHelper && !line.contains('FirebaseHelper')) {
          findings.add(CrashRiskFinding(
            file: file.path,
            line: lineNum,
            severity: 'MEDIUM',
            issue: 'Firebase access without initialization check',
            code: line.trim(),
            suggestion: 'Check FirebaseHelper.isInitialized() before accessing Firebase services',
          ),
        );
          totalIssuesFound++;
        }
      }

      // Check for unsafe JSON decoding
      if (line.contains('jsonDecode') && line.contains(' as ')) {
        if (!line.contains('JsonHelper.safe')) {
          findings.add(CrashRiskFinding(
            file: file.path,
            line: lineNum,
            severity: 'MEDIUM',
            issue: 'Unsafe JSON decoding with type cast',
            code: line.trim(),
            suggestion: 'Use JsonHelper.safeDecodeMap() or JsonHelper.safeDecodeList()',
          ),
        );
          totalIssuesFound++;
        }
      }
    }
  }

  /// Scan directory recursively
  void scanDirectory(Directory dir) {
    if (!dir.existsSync()) return;

    for (final entity in dir.listSync(recursive: true)) {
      if (entity is File) {
        scanFile(entity);
      }
    }
  }

  /// Generate report
  String generateReport() {
    final buffer = StringBuffer();
    buffer.writeln('=' * 80);
    buffer.writeln('CRASH RISK AUDIT REPORT');
    buffer.writeln('=' * 80);
    buffer.writeln();
    buffer.writeln('Files Scanned: $totalFilesScanned');
    buffer.writeln('Issues Found: $totalIssuesFound');
    buffer.writeln();

    if (findings.isEmpty) {
      buffer.writeln('✅ NO CRASH RISKS FOUND');
      buffer.writeln('All crash prevention measures are in place.');
      return buffer.toString();
    }

    // Group by severity
    final critical = findings.where((f) => f.severity == 'CRITICAL').toList();
    final high = findings.where((f) => f.severity == 'HIGH').toList();
    final medium = findings.where((f) => f.severity == 'MEDIUM').toList();
    final low = findings.where((f) => f.severity == 'LOW').toList();

    if (critical.isNotEmpty) {
      buffer.writeln('🔴 CRITICAL ISSUES (${critical.length}):');
      buffer.writeln('-' * 80);
      for (final finding in critical) {
        buffer.writeln(finding);
        buffer.writeln();
      }
    }

    if (high.isNotEmpty) {
      buffer.writeln('🟠 HIGH PRIORITY ISSUES (${high.length}):');
      buffer.writeln('-' * 80);
      for (final finding in high) {
        buffer.writeln(finding);
        buffer.writeln();
      }
    }

    if (medium.isNotEmpty) {
      buffer.writeln('🟡 MEDIUM PRIORITY ISSUES (${medium.length}):');
      buffer.writeln('-' * 80);
      for (final finding in medium) {
        buffer.writeln(finding);
        buffer.writeln();
      }
    }

    if (low.isNotEmpty) {
      buffer.writeln('🟢 LOW PRIORITY ISSUES (${low.length}):');
      buffer.writeln('-' * 80);
      for (final finding in low) {
        buffer.writeln(finding);
        buffer.writeln();
      }
    }

    buffer.writeln('=' * 80);
    buffer.writeln('SUMMARY');
    buffer.writeln('=' * 80);
    buffer.writeln('Total Issues: $totalIssuesFound');
    buffer.writeln('  - Critical: ${critical.length}');
    buffer.writeln('  - High: ${high.length}');
    buffer.writeln('  - Medium: ${medium.length}');
    buffer.writeln('  - Low: ${low.length}');
    buffer.writeln();

    if (critical.isEmpty && high.isEmpty && medium.isEmpty) {
      buffer.writeln('✅ All critical and high-priority crash risks have been addressed.');
    } else {
      buffer.writeln('⚠️  Please address the issues above to ensure crash prevention.');
    }

    return buffer.toString();
  }
}

void main(List<String> args) {
  final auditor = CrashRiskAuditor();
  final libDir = Directory('lib');

  if (!libDir.existsSync()) {
    print('Error: lib/ directory not found');
    exit(1);
  }

  print('Scanning for crash risks...');
  auditor.scanDirectory(libDir);

  final report = auditor.generateReport();
  print(report);

  // Exit with error code if critical or high issues found
  final hasCriticalOrHigh = auditor.findings.any(
    (f) => f.severity == 'CRITICAL' || f.severity == 'HIGH',
  );

  if (hasCriticalOrHigh) {
    exit(1);
  }
}
