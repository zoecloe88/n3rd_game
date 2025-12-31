#!/usr/bin/env dart
// ignore_for_file: avoid_print

/// Automated verification script for resource disposal coverage
///
/// Scans all StatefulWidget screens and verifies that:
/// - Resources (TextEditingController, FocusNode, StreamSubscription, Timer, etc.) are properly disposed
/// - Dispose methods exist and dispose all resources
/// - Generates a report of missing disposals
///
/// Usage:
/// ```bash
/// dart scripts/verify_resource_disposal.dart
/// ```

library;

import 'dart:io';

void main() {
  print('🔍 Verifying resource disposal coverage...\n');

  final screensDir = Directory('lib/screens');
  if (!screensDir.existsSync()) {
    print('❌ Error: lib/screens directory not found');
    exit(1);
  }

  final issues = <String>[];
  int totalScreens = 0;
  int screensWithResources = 0;
  int screensWithProperDisposal = 0;

  // Scan all Dart files in screens directory
  final files = screensDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  for (final file in files) {
    final content = file.readAsStringSync();
    final fileName = file.path.replaceAll('lib/screens/', '');

    // Skip view models and non-screen files
    if (fileName.contains('_view_model.dart') ||
        fileName.contains('_model.dart') ||
        fileName.contains('_state.dart')) {
      continue;
    }

    // Check if it's a StatefulWidget
    if (!content.contains('StatefulWidget') &&
        !content.contains('extends State<')) {
      continue;
    }

    totalScreens++;

    // Detect resources
    final hasTextEditingController =
        content.contains('TextEditingController');
    final hasFocusNode = content.contains('FocusNode');
    final hasPageController = content.contains('PageController');
    final hasScrollController = content.contains('ScrollController');
    final hasAnimationController = content.contains('AnimationController');
    final hasStreamSubscription = content.contains('StreamSubscription');
    final hasTimer = content.contains('Timer(') || content.contains('Timer.');
    final hasServiceInstance = RegExp(
      r'final\s+\w+Service\s+\w+\s*=\s*\w+Service\(\)',
    ).hasMatch(content);

    final hasResources = hasTextEditingController ||
        hasFocusNode ||
        hasPageController ||
        hasScrollController ||
        hasAnimationController ||
        hasStreamSubscription ||
        hasTimer ||
        hasServiceInstance;

    if (!hasResources) {
      continue; // No resources to dispose
    }

    screensWithResources++;

    // Check for dispose method
    final hasDisposeMethod = RegExp(
      r'@override\s+void\s+dispose\(\)',
      multiLine: true,
    ).hasMatch(content);

    if (!hasDisposeMethod) {
      issues.add(
        '❌ $fileName: Has resources but no dispose() method',
      );
      continue;
    }

    // Extract dispose method content
    final disposeMatch = RegExp(
      r'@override\s+void\s+dispose\(\)\s*\{([^}]+)\}',
      multiLine: true,
      dotAll: true,
    ).firstMatch(content);

    if (disposeMatch == null) {
      issues.add('⚠️  $fileName: Has dispose() but cannot parse content');
      continue;
    }

    final disposeContent = disposeMatch.group(1) ?? '';

    // Check if resources are disposed
    bool allDisposed = true;
    final missingDisposals = <String>[];

    if (hasTextEditingController) {
      final controllerPattern = RegExp(
        r'_?\w+Controller\s*=\s*TextEditingController\(\)',
      );
      final controllers = controllerPattern
          .allMatches(content)
          .map((m) {
            final match = m.group(0) ?? '';
            return match.split('=')[0].trim();
          })
          .toList();

      for (final controller in controllers) {
        if (!disposeContent.contains('$controller.dispose()') &&
            !disposeContent.contains('$controller?.dispose()')) {
          allDisposed = false;
          missingDisposals.add('$controller (TextEditingController)');
        }
      }
    }

    if (hasFocusNode) {
      final focusPattern = RegExp(r'_\w+FocusNode\s*=\s*FocusNode\(\)');
      final focusNodes = focusPattern
          .allMatches(content)
          .map((m) => m.group(0)?.split('=')[0].trim() ?? '')
          .toList();

      for (final focusNode in focusNodes) {
        if (!disposeContent.contains('$focusNode.dispose()')) {
          allDisposed = false;
          missingDisposals.add('$focusNode (FocusNode)');
        }
      }
    }

    if (hasPageController) {
      // Find PageController variable names
      final pageControllerPattern = RegExp(
        r'_?\w*[Pp]age[Cc]ontroller\s*=\s*PageController\(\)',
      );
      final pageControllers = pageControllerPattern
          .allMatches(content)
          .map((m) {
            final match = m.group(0) ?? '';
            return match.split('=')[0].trim();
          })
          .toList();

      bool pageControllerDisposed = false;
      for (final controller in pageControllers) {
        if (disposeContent.contains('$controller.dispose()') ||
            disposeContent.contains('$controller?.dispose()')) {
          pageControllerDisposed = true;
          break;
        }
      }
      
      if (!pageControllerDisposed && pageControllers.isNotEmpty) {
        allDisposed = false;
        missingDisposals.add('PageController');
      }
    }

    if (hasStreamSubscription) {
      final subscriptionPattern = RegExp(
        r'StreamSubscription[^?]*\?\s*_\w+Subscription',
      );
      final subscriptions = subscriptionPattern
          .allMatches(content)
          .map((m) => m.group(0)?.split('?')[1].trim() ?? '')
          .toList();

      for (final subscription in subscriptions) {
        if (!disposeContent.contains('$subscription?.cancel()') &&
            !disposeContent.contains('$subscription.cancel()')) {
          allDisposed = false;
          missingDisposals.add('$subscription (StreamSubscription)');
        }
      }
    }

    if (hasTimer) {
      final timerPattern = RegExp(r'Timer[^?]*\?\s*_\w+Timer');
      final timers = timerPattern
          .allMatches(content)
          .map((m) => m.group(0)?.split('?')[1].trim() ?? '')
          .toList();

      for (final timer in timers) {
        if (!disposeContent.contains('$timer?.cancel()') &&
            !disposeContent.contains('$timer.cancel()')) {
          allDisposed = false;
          missingDisposals.add('$timer (Timer)');
        }
      }
    }

    if (allDisposed) {
      screensWithProperDisposal++;
    } else {
      issues.add(
        '⚠️  $fileName: Missing disposal for: ${missingDisposals.join(', ')}',
      );
    }
  }

  // Print report
  print('📊 Resource Disposal Coverage Report\n');
  print('Total screens scanned: $totalScreens');
  print('Screens with resources: $screensWithResources');
  print('Screens with proper disposal: $screensWithProperDisposal');
  if (screensWithResources > 0) {
    final coverage = (screensWithProperDisposal / screensWithResources * 100)
        .toStringAsFixed(1);
    print('Coverage: $coverage%\n');
  }

  if (issues.isEmpty) {
    print('✅ All screens with resources have proper disposal!\n');
    exit(0);
  } else {
    print('❌ Issues found:\n');
    for (final issue in issues) {
      print('  $issue');
    }
    print('\n');
    exit(1);
  }
}

