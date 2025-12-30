#!/usr/bin/env dart

// Script to scan codebase for technical debt items
// Usage: dart scripts/scan_tech_debt.dart [--output=report.json]
import 'dart:io';
import 'dart:convert';
import 'package:n3rd_game/services/tech_debt_tracking_service.dart';

void main(List<String> args) async {
  final outputPath = _getOutputPath(args);
  final rootPath = Directory.current.path;

  print('🔍 Scanning codebase for technical debt...');
  print('Root path: $rootPath');

  final service = TechDebtTrackingService();
  final items = await service.scanCodebase(rootPath);

  if (items == null) {
    print('❌ Failed to scan codebase');
    exit(1);
  }

  print('✅ Found ${items.length} technical debt items');

  // Generate report
  final report = await service.generateReport(items);

  // Print summary
  print('\n📊 Technical Debt Summary:');
  print('Total items: ${report['total']}');
  print('\nBy Type:');
  (report['byType'] as Map<String, dynamic>).forEach((type, count) {
    print('  $type: $count');
  });
  print('\nBy Category:');
  (report['byCategory'] as Map<String, dynamic>).forEach((category, count) {
    print('  $category: $count');
  });
  print('\nBy Priority:');
  (report['byPriority'] as Map<String, dynamic>).forEach((priority, count) {
    print('  $priority: $count');
  });
  print('\nHigh Priority Items: ${report['highPriority']}');
  print('Medium Priority Items: ${report['mediumPriority']}');
  print('Low Priority Items: ${report['lowPriority']}');

  // Save report if output path specified
  if (outputPath != null) {
    final file = File(outputPath);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    print('\n💾 Report saved to: $outputPath');
  }

  // Print top files with most debt
  print('\n📁 Top 10 Files with Most Technical Debt:');
  final byFile = report['byFile'] as Map<String, dynamic>;
  final sortedFiles = byFile.entries.toList()
    ..sort((a, b) => (b.value as int).compareTo(a.value as int));

  for (int i = 0; i < sortedFiles.length && i < 10; i++) {
    final entry = sortedFiles[i];
    print('  ${entry.key}: ${entry.value}');
  }

  exit(0);
}

String? _getOutputPath(List<String> args) {
  for (final arg in args) {
    if (arg.startsWith('--output=')) {
      return arg.split('=')[1];
    }
  }
  return null;
}
