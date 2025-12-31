#!/usr/bin/env dart
// ignore_for_file: avoid_print

// Script to analyze and categorize test failures
//
// This script parses test output to identify failure patterns and
// categorizes them into common categories for systematic fixing.
//
// Usage:
// ```bash
// flutter test 2>&1 | dart scripts/analyze_test_failures.dart
// ```

import 'dart:io';

void main() async {
  print('🔍 Analyzing test failures...\n');

  final categories = <String, List<String>>{
    'Missing Providers': [],
    'Firebase Initialization': [],
    'Async/Timeout Issues': [],
    'Mock/Setup Issues': [],
    'Widget Expectation Mismatches': [],
    'Test Isolation Issues': [],
    'Integration Test Issues': [],
    'Other': [],
  };

  final input = stdin.readLineSync();
  if (input == null) {
    print('No input provided. Pipe test output to this script.');
    exit(1);
  }

  // Read all lines from stdin
  final lines = <String>[];
  while (true) {
    final line = stdin.readLineSync();
    if (line == null) break;
    lines.add(line);
  }

  // Analyze each failure
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    
    // Look for FAILED markers
    if (line.contains('FAILED') || line.contains('✗')) {
      // Try to extract test name and error
      String? testName;
      String? errorMessage;
      
      // Look ahead for error details
      for (int j = i; j < lines.length && j < i + 10; j++) {
        final nextLine = lines[j];
        
        if (testName == null && nextLine.contains('test/')) {
          // Extract test file and name
          final match = RegExp(r'test/([^:]+):\s*(.+)').firstMatch(nextLine);
          if (match != null) {
            testName = '${match.group(1)}: ${match.group(2)}';
          }
        }
        
        // Categorize based on error patterns
        if (errorMessage == null) {
          if (nextLine.contains('ProviderNotFoundError') ||
              nextLine.contains('Provider not found')) {
            categories['Missing Providers']!.add(testName ?? nextLine);
            errorMessage = 'Missing Provider';
            break;
          } else if (nextLine.contains('Firebase') ||
              nextLine.contains('FirebaseException') ||
              nextLine.contains('FirebaseCrashlytics')) {
            categories['Firebase Initialization']!.add(testName ?? nextLine);
            errorMessage = 'Firebase Issue';
            break;
          } else if (nextLine.contains('TimeoutException') ||
              nextLine.contains('pumpAndSettle') ||
              nextLine.contains('timed out')) {
            categories['Async/Timeout Issues']!.add(testName ?? nextLine);
            errorMessage = 'Timeout';
            break;
          } else if (nextLine.contains('Mock') ||
              nextLine.contains('SharedPreferences') ||
              nextLine.contains('setupMock')) {
            categories['Mock/Setup Issues']!.add(testName ?? nextLine);
            errorMessage = 'Mock/Setup';
            break;
          } else if (nextLine.contains('expect') ||
              nextLine.contains('findsNothing') ||
              nextLine.contains('findsOneWidget')) {
            categories['Widget Expectation Mismatches']!.add(testName ?? nextLine);
            errorMessage = 'Expectation Mismatch';
            break;
          } else if (nextLine.contains('integration/')) {
            categories['Integration Test Issues']!.add(testName ?? nextLine);
            errorMessage = 'Integration Test';
            break;
          }
        }
      }
      
      if (errorMessage == null && testName != null) {
        categories['Other']!.add(testName);
      }
    }
  }

  // Print summary
  print('📊 Test Failure Analysis Summary\n');
  print('=' * 50);
  
  int totalFailures = 0;
  for (final entry in categories.entries) {
    final count = entry.value.length;
    totalFailures += count;
    if (count > 0) {
      print('\n${entry.key}: $count failures');
      print('-' * 50);
      for (final failure in entry.value.take(5)) {
        print('  • $failure');
      }
      if (entry.value.length > 5) {
        print('  ... and ${entry.value.length - 5} more');
      }
    }
  }
  
  print('\n${'=' * 50}');
  print('Total failures analyzed: $totalFailures');
  print('\n💡 Next steps:');
  print('  1. Fix Category 1: Missing Providers (${categories['Missing Providers']!.length} tests)');
  print('  2. Fix Category 2: Firebase Issues (${categories['Firebase Initialization']!.length} tests)');
  print('  3. Fix Category 3: Async/Timeout (${categories['Async/Timeout Issues']!.length} tests)');
  print('  4. Fix Category 4: Mock/Setup (${categories['Mock/Setup Issues']!.length} tests)');
  print('  5. Fix Category 5: Widget Expectations (${categories['Widget Expectation Mismatches']!.length} tests)');
  print('  6. Fix Category 6: Test Isolation (${categories['Test Isolation Issues']!.length} tests)');
  print('  7. Fix Category 7: Integration Tests (${categories['Integration Test Issues']!.length} tests)');
  print('  8. Fix Other Issues (${categories['Other']!.length} tests)');
}

