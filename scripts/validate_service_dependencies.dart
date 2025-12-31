#!/usr/bin/env dart

/// Script to validate service dependency order and detect circular dependencies
///
/// Usage: dart scripts/validate_service_dependencies.dart

library;

import 'dart:io';

void main() {
  print('🔍 Validating Service Dependencies...\n');

  // Define service dependencies (based on ServiceRegistry)
  final dependencies = <String, List<String>>{
    // Core services (no dependencies)
    'LoggerService': [],
    'AuthService': [],
    'AnalyticsService': [],
    'ThemeService': [],
    'LanguageService': [],
    'SettingsService': [],
    'SoundService': [],
    'NotificationService': [],
    'NetworkService': [],
    'OfflineService': [],
    'AccessibilityService': [],

    // Game services with dependencies
    'TriviaPersonalizationService': [],
    'TriviaGamificationService': [],
    'TriviaGeneratorService': [
      'TriviaPersonalizationService',
      'AnalyticsService',
    ],
    'GameService': [
      'TriviaPersonalizationService',
      'TriviaGamificationService',
      'AnalyticsService',
      'SubscriptionService',
      'GameHistoryService',
    ],
    'AIEditionService': [
      'TriviaPersonalizationService',
      'TriviaGeneratorService',
      'AnalyticsService',
    ],

    // Subscription services
    'RevenueCatService': [],
    'SubscriptionService': ['RevenueCatService', 'AuthService'],
    'EditionAccessService': ['RevenueCatService', 'SubscriptionService'],

    // Social services
    'MultiplayerService': ['AnalyticsService'],
    'FriendsService': [],
    'FamilyGroupService': [],
    'DirectMessageService': [],
    'NewsfeedService': [],
    'SocialDiscoveryService': [],
  };

  // Check for circular dependencies
  final circularDeps = findCircularDependencies(dependencies);
  if (circularDeps.isNotEmpty) {
    print('❌ Circular dependencies found:');
    for (final cycle in circularDeps) {
      print('  ${cycle.join(' -> ')} -> ${cycle.first}');
    }
    exitCode = 1;
    return;
  }

  // Check initialization order
  final initOrder = getInitializationOrder(dependencies);
  print('✅ Initialization Order:');
  for (var i = 0; i < initOrder.length; i++) {
    print('  ${i + 1}. ${initOrder[i]}');
  }

  // Validate no missing dependencies
  final missingDeps = findMissingDependencies(dependencies);
  if (missingDeps.isNotEmpty) {
    print('\n⚠️  Services with undefined dependencies:');
    missingDeps.forEach((service, deps) {
      print('  $service depends on: ${deps.join(", ")}');
    });
  }

  print('\n✅ Service dependency validation complete!');
}

/// Find circular dependencies using DFS
List<List<String>> findCircularDependencies(
  Map<String, List<String>> dependencies,
) {
  final cycles = <List<String>>[];
  final visited = <String>{};
  final recStack = <String>{};
  final path = <String>[];

  void dfs(String service) {
    visited.add(service);
    recStack.add(service);
    path.add(service);

    for (final dep in dependencies[service] ?? []) {
      if (!visited.contains(dep)) {
        dfs(dep);
      } else if (recStack.contains(dep)) {
        // Found cycle
        final cycleStart = path.indexOf(dep);
        cycles.add(path.sublist(cycleStart)..add(dep));
      }
    }

    recStack.remove(service);
    path.removeLast();
  }

  for (final service in dependencies.keys) {
    if (!visited.contains(service)) {
      dfs(service);
    }
  }

  return cycles;
}

/// Get initialization order using topological sort
List<String> getInitializationOrder(Map<String, List<String>> dependencies) {
  final inDegree = <String, int>{};
  final graph = <String, List<String>>{};

  // Initialize in-degree and graph
  for (final service in dependencies.keys) {
    inDegree[service] = 0;
    graph[service] = [];
  }

  // Build graph and calculate in-degrees
  dependencies.forEach((service, deps) {
    for (final dep in deps) {
      if (graph.containsKey(dep)) {
        graph[dep]!.add(service);
        inDegree[service] = (inDegree[service] ?? 0) + 1;
      }
    }
  });

  // Topological sort
  final queue = <String>[];
  final result = <String>[];

  // Add services with no dependencies
  inDegree.forEach((service, degree) {
    if (degree == 0) {
      queue.add(service);
    }
  });

  while (queue.isNotEmpty) {
    queue.sort(); // Sort for consistent output
    final service = queue.removeAt(0);
    result.add(service);

    for (final dependent in graph[service] ?? []) {
      inDegree[dependent] = (inDegree[dependent] ?? 0) - 1;
      if (inDegree[dependent] == 0) {
        queue.add(dependent);
      }
    }
  }

  return result;
}

/// Find services with undefined dependencies
Map<String, List<String>> findMissingDependencies(
  Map<String, List<String>> dependencies,
) {
  final allServices = dependencies.keys.toSet();
  final missing = <String, List<String>>{};

  dependencies.forEach((service, deps) {
    final undefined = deps.where((dep) => !allServices.contains(dep)).toList();
    if (undefined.isNotEmpty) {
      missing[service] = undefined;
    }
  });

  return missing;
}
