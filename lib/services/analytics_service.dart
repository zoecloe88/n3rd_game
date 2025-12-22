import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:n3rd_game/models/performance_metric.dart';
import 'package:n3rd_game/models/trivia_item.dart';
import 'package:n3rd_game/data/trivia_templates_consolidated.dart' deferred as templates; // Deferred to reduce kernel size
import 'package:n3rd_game/services/logger_service.dart';

class AnalyticsService extends ChangeNotifier {
  static const String _storageKey = 'analytics_data';
  List<PerformanceMetric> _metrics = [];
  bool _firebaseAvailable = false;
  FirebaseAnalytics? _analytics;

  List<PerformanceMetric> get metrics => _metrics;

  FirebaseFirestore? get _firestore {
    if (!_firebaseAvailable) return null;
    try {
      Firebase.app();
      return FirebaseFirestore.instance;
    } catch (e) {
      _firebaseAvailable = false;
      return null;
    }
  }

  String? get _userId {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (e) {
      return null;
    }
  }

  Future<void> init() async {
    try {
      Firebase.app();
      _firebaseAvailable = true;
      _analytics = FirebaseAnalytics.instance;

      // Track trivia template initialization status (templates initialized before AnalyticsService)
      try {
        final templatesInitialized = templates.EditionTriviaTemplates.isInitialized;
        final lastError = templates.EditionTriviaTemplates.lastValidationError;
        final initDuration = templates.EditionTriviaTemplates.lastInitializationDuration;
        final initTemplateCount =
            templates.EditionTriviaTemplates.lastInitializationTemplateCount;
        final initRetryCount =
            templates.EditionTriviaTemplates.lastInitializationRetryCount;

        // Get template count (count all templates across all themes)
        int templateCount = 0;
        if (templatesInitialized) {
          try {
            final themes = templates.EditionTriviaTemplates.getAvailableThemes();
            for (final theme in themes) {
              final themeTemplates = templates.EditionTriviaTemplates.getTemplatesForTheme(
                theme,
              );
              templateCount += themeTemplates.length;
            }
          } catch (e) {
            // If we can't count templates, use stored count or 0
            templateCount = initTemplateCount;
            LoggerService.warning(
              'Failed to count trivia templates, using stored count',
              error: e,
            );
          }
        }

        await logTriviaValidation(
          templateCount,
          templatesInitialized,
          error: lastError,
        );

        // Track performance metrics if initialization duration is available
        if (initDuration != null) {
          try {
            await logTemplateInitialization(
              initDuration,
              success: templatesInitialized,
              templateCount: initTemplateCount > 0
                  ? initTemplateCount
                  : templateCount,
              retryCount: initRetryCount,
            );
          } catch (e) {
            // Performance tracking failure shouldn't block init
            LoggerService.warning(
              'Failed to track template initialization performance',
              error: e,
            );
          }
        }
      } catch (e) {
        // Template tracking failed - log but don't fail init
        LoggerService.warning(
          'Failed to track trivia template initialization',
          error: e,
        );
      }

      final userId = _userId;
      if (userId != null) {
        try {
          final doc = await _firestore!
              .collection('user_analytics')
              .doc(userId)
              .get()
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  throw TimeoutException(
                    'Analytics Firestore load timeout after 10s',
                  );
                },
              );
          if (doc.exists) {
            final data = doc.data();
            if (data == null) return;
            _metrics =
                (data['metrics'] as List?)
                    ?.map(
                      (m) =>
                          PerformanceMetric.fromJson(m as Map<String, dynamic>),
                    )
                    .toList() ??
                [];
            notifyListeners();
            await _saveLocal();
            return;
          }
        } catch (e) {
          LoggerService.warning(
            'Failed to load analytics from Firestore',
            error: e,
          );
        }
      }
    } catch (e) {
      _firebaseAvailable = false;
      debugPrint('Firebase not available for analytics: $e');
    }

    // Load from local storage
    await _loadLocal();
  }

  Future<void> _loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        _metrics =
            (data['metrics'] as List?)
                ?.map(
                  (m) => PerformanceMetric.fromJson(m as Map<String, dynamic>),
                )
                .toList() ??
            [];
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to load analytics from local storage: $e');
    }
  }

  Future<void> _saveLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {'metrics': _metrics.map((m) => m.toJson()).toList()};
      await prefs.setString(_storageKey, jsonEncode(data));
    } catch (e) {
      debugPrint('Failed to save analytics to local storage: $e');
    }
  }

  Future<void> _saveToFirestore() async {
    if (!_firebaseAvailable) return;
    final userId = _userId;
    if (userId == null) return;

    try {
      await _firestore!.collection('user_analytics').doc(userId).set({
        'metrics': _metrics.map((m) => m.toJson()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true,),);
    } catch (e) {
      debugPrint('Failed to save analytics to Firestore: $e');
    }
  }

  /// Record a game session
  Future<void> recordGameSession({
    required double score,
    required double accuracy,
    required int gamesPlayed,
    String? category,
    required TriviaItem triviaItem,
  }) async {
    final now = DateTime.now();
    final metric = PerformanceMetric(
      date: now,
      score: score,
      accuracy: accuracy,
      gamesPlayed: gamesPlayed,
      category: category ?? triviaItem.category,
      hourOfDay: now.hour,
    );

    _metrics.add(metric);

    // Keep only last 365 days of data
    final cutoffDate = DateTime.now().subtract(const Duration(days: 365));
    _metrics.removeWhere((m) => m.date.isBefore(cutoffDate));

    notifyListeners();
    await _saveLocal();
    await _saveToFirestore();
  }

  /// Get weekly performance trends
  List<PerformanceMetric> getWeeklyTrends() {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return _metrics.where((m) => m.date.isAfter(weekAgo)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Get monthly performance trends
  List<PerformanceMetric> getMonthlyTrends() {
    final now = DateTime.now();
    final monthAgo = now.subtract(const Duration(days: 30));
    return _metrics.where((m) => m.date.isAfter(monthAgo)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Get category breakdown
  List<CategoryPerformance> getCategoryBreakdown() {
    final categoryMap = <String, List<PerformanceMetric>>{};

    for (final metric in _metrics) {
      if (metric.category != null) {
        categoryMap.putIfAbsent(metric.category!, () => []).add(metric);
      }
    }

    return categoryMap.entries.map((entry) {
      final metrics = entry.value;
      final totalQuestions = metrics.fold<int>(
        0,
        (total, m) => total + m.gamesPlayed * 3,
      );
      final correctAnswers = metrics.fold<double>(
        0,
        (total, m) => total + (m.accuracy / 100) * m.gamesPlayed * 3,
      );
      final avgAccuracy =
          metrics.fold<double>(0, (total, m) => total + m.accuracy) /
          metrics.length;
      final avgScore =
          metrics.fold<double>(0, (total, m) => total + m.score) /
          metrics.length;

      return CategoryPerformance(
        category: entry.key,
        totalQuestions: totalQuestions,
        correctAnswers: correctAnswers.toInt(),
        accuracy: avgAccuracy,
        averageScore: avgScore,
      );
    }).toList()..sort((a, b) => b.accuracy.compareTo(a.accuracy));
  }

  /// Get time-of-day performance
  List<TimeOfDayPerformance> getTimeOfDayPerformance() {
    final hourMap = <int, List<PerformanceMetric>>{};

    for (final metric in _metrics) {
      hourMap.putIfAbsent(metric.hourOfDay, () => []).add(metric);
    }

    return List.generate(24, (hour) {
      final metrics = hourMap[hour] ?? [];
      if (metrics.isEmpty) {
        return TimeOfDayPerformance(
          hour: hour,
          averageScore: 0,
          averageAccuracy: 0,
          totalGames: 0,
        );
      }

      final avgScore =
          metrics.fold<double>(0, (total, m) => total + m.score) /
          metrics.length;
      final avgAccuracy =
          metrics.fold<double>(0, (total, m) => total + m.accuracy) /
          metrics.length;
      final totalGames = metrics.fold<int>(
        0,
        (total, m) => total + m.gamesPlayed,
      );

      return TimeOfDayPerformance(
        hour: hour,
        averageScore: avgScore,
        averageAccuracy: avgAccuracy,
        totalGames: totalGames,
      );
    });
  }

  /// Get personal bests
  Map<String, double> getPersonalBests() {
    if (_metrics.isEmpty) {
      return {
        'highestScore': 0.0,
        'bestAccuracy': 0.0,
        'bestDayScore': 0.0,
        'longestStreak': 0.0,
      };
    }

    final highestScore = _metrics
        .map((m) => m.score)
        .reduce((a, b) => a > b ? a : b);
    final bestAccuracy = _metrics
        .map((m) => m.accuracy)
        .reduce((a, b) => a > b ? a : b);

    // Calculate best day score (sum of all games in a day)
    final dayScores = <DateTime, double>{};
    for (final metric in _metrics) {
      final day = DateTime(
        metric.date.year,
        metric.date.month,
        metric.date.day,
      );
      dayScores[day] = (dayScores[day] ?? 0) + metric.score;
    }
    final bestDayScore = dayScores.values.isEmpty
        ? 0.0
        : dayScores.values.reduce((a, b) => a > b ? a : b);

    // Calculate longest streak (consecutive perfect games with 100% accuracy)
    int longestStreak = 0;
    int currentStreak = 0;
    for (final metric in _metrics) {
      if (metric.accuracy >= 100.0) {
        currentStreak++;
        longestStreak = currentStreak > longestStreak
            ? currentStreak
            : longestStreak;
      } else {
        currentStreak = 0;
      }
    }

    return {
      'highestScore': highestScore,
      'bestAccuracy': bestAccuracy,
      'bestDayScore': bestDayScore,
      'longestStreak': longestStreak.toDouble(),
    };
  }

  /// Get improvement tracking (compare recent vs older performance)
  Map<String, double> getImprovementTracking() {
    if (_metrics.length < 2) {
      return {'scoreImprovement': 0.0, 'accuracyImprovement': 0.0};
    }

    final sorted = List<PerformanceMetric>.from(_metrics)
      ..sort((a, b) => a.date.compareTo(b.date));
    final midpoint = sorted.length ~/ 2;
    final older = sorted.sublist(0, midpoint);
    final recent = sorted.sublist(midpoint);

    final olderAvgScore = older.isEmpty
        ? 0.0
        : older.fold<double>(0, (total, m) => total + m.score) / older.length;
    final recentAvgScore = recent.isEmpty
        ? 0.0
        : recent.fold<double>(0, (total, m) => total + m.score) / recent.length;

    final olderAvgAccuracy = older.isEmpty
        ? 0.0
        : older.fold<double>(0, (total, m) => total + m.accuracy) /
              older.length;
    final recentAvgAccuracy = recent.isEmpty
        ? 0.0
        : recent.fold<double>(0, (total, m) => total + m.accuracy) /
              recent.length;

    return {
      'scoreImprovement': recentAvgScore - olderAvgScore,
      'accuracyImprovement': recentAvgAccuracy - olderAvgAccuracy,
    };
  }

  // Firebase Analytics methods
  //
  // **Fire-and-Forget Pattern:**
  // All analytics logging methods are designed to be non-blocking.
  // They catch errors internally and never throw, making them safe to call
  // without await. Critical flows should await for reliability, but non-critical
  // flows can use `unawaited()` for better performance.
  //
  // **Critical Analytics (recommend awaiting):**
  // - logPurchase() - Revenue tracking
  // - logPurchaseAttempt() - Purchase funnel analysis
  // - logError() - Error monitoring
  //
  // **Non-Critical Analytics (can use unawaited()):**
  // - logScreenView() - UI navigation tracking
  // - logGameModeSelected() - Feature usage
  // - logTriviaGeneration() - Content performance

  /// Log an error event
  /// **Critical**: Recommended to await for error tracking reliability
  Future<void> logError(String errorType, String errorMessage) async {
    debugPrint('Analytics Error: $errorType - $errorMessage');
    try {
      await _analytics?.logEvent(
        name: 'error',
        parameters: {'error_type': errorType, 'error_message': errorMessage},
      );
    } catch (e) {
      debugPrint('Failed to log error to Firebase Analytics: $e');
    }
  }

  /// Log a purchase event
  /// **Critical**: Recommended to await for revenue tracking accuracy
  Future<void> logPurchase(String tier, String packageId, bool success) async {
    try {
      await _analytics?.logEvent(
        name: 'purchase',
        parameters: {'tier': tier, 'package_id': packageId, 'success': success},
      );
    } catch (e) {
      debugPrint('Failed to log purchase to Firebase Analytics: $e');
    }
  }

  /// Log a purchase attempt event
  /// **Critical**: Recommended to await for purchase funnel analysis
  Future<void> logPurchaseAttempt(String tier, String packageId) async {
    try {
      await _analytics?.logEvent(
        name: 'purchase_attempt',
        parameters: {'tier': tier, 'package_id': packageId},
      );
    } catch (e) {
      debugPrint('Failed to log purchase attempt to Firebase Analytics: $e');
    }
  }

  /// Log trivia generation event
  /// **Non-Critical**: Safe to use `unawaited()` for better performance
  Future<void> logTriviaGeneration(
    String mode,
    bool success, {
    String? error,
  }) async {
    try {
      await _analytics?.logEvent(
        name: 'trivia_generation',
        parameters: {
          'mode': mode,
          'success': success,
          if (error != null) 'error': error,
        },
      );
    } catch (e) {
      debugPrint('Failed to log trivia generation to Firebase Analytics: $e');
    }
  }

  /// Log subscription tier change event
  /// **Critical**: Recommended to await for subscription analytics accuracy
  Future<void> logSubscriptionTierChange(String oldTier, String newTier) async {
    try {
      await _analytics?.logEvent(
        name: 'subscription_tier_change',
        parameters: {'old_tier': oldTier, 'new_tier': newTier},
      );
    } catch (e) {
      debugPrint(
        'Failed to log subscription tier change to Firebase Analytics: $e',
      );
    }
  }

  /// Log game mode selection event
  /// **Non-Critical**: Safe to use `unawaited()` for better performance
  Future<void> logGameModeSelected(String mode, String tier) async {
    try {
      await _analytics?.logEvent(
        name: 'game_mode_selected',
        parameters: {'mode': mode, 'tier': tier},
      );
    } catch (e) {
      debugPrint('Failed to log game mode selection to Firebase Analytics: $e');
    }
  }

  /// Log login event
  /// **Critical**: Recommended to await for authentication analytics accuracy
  Future<void> logLogin(
    String method, {
    bool success = true,
    String? error,
  }) async {
    try {
      await _analytics?.logEvent(
        name: 'login',
        parameters: {
          'method': method,
          'success': success,
          if (error != null) 'error': error,
        },
      );
    } catch (e) {
      debugPrint('Failed to log login to Firebase Analytics: $e');
    }
  }

  /// Log signup event
  /// **Critical**: Recommended to await for authentication analytics accuracy
  Future<void> logSignup(
    String method, {
    bool success = true,
    String? error,
  }) async {
    try {
      await _analytics?.logEvent(
        name: 'signup',
        parameters: {
          'method': method,
          'success': success,
          if (error != null) 'error': error,
        },
      );
    } catch (e) {
      debugPrint('Failed to log signup to Firebase Analytics: $e');
    }
  }

  /// Log free tier limit reached event
  /// **Non-Critical**: Safe to use `unawaited()` for better performance
  Future<void> logFreeTierLimitReached() async {
    try {
      await _analytics?.logEvent(name: 'free_tier_limit_reached');
    } catch (e) {
      debugPrint('Failed to log free tier limit to Firebase Analytics: $e');
    }
  }

  /// Log subscription validation event
  /// **Critical**: Recommended to await for subscription analytics accuracy
  Future<void> logSubscriptionValidation(
    bool tierChanged,
    String? oldTier,
    String? newTier,
  ) async {
    try {
      await _analytics?.logEvent(
        name: 'subscription_validation',
        parameters: {
          'tier_changed': tierChanged,
          if (oldTier != null) 'old_tier': oldTier,
          if (newTier != null) 'new_tier': newTier,
        },
      );
    } catch (e) {
      debugPrint(
        'Failed to log subscription validation to Firebase Analytics: $e',
      );
    }
  }

  /// Log when user views subscription management screen
  /// **Non-Critical**: Safe to use `unawaited()` for better performance
  Future<void> logSubscriptionViewed() async {
    try {
      await _analytics?.logEvent(name: 'subscription_viewed');
    } catch (e) {
      debugPrint('Failed to log subscription viewed to Firebase Analytics: $e');
    }
  }

  /// Log when user selects a subscription tier
  /// **Non-Critical**: Safe to use `unawaited()` for better performance
  Future<void> logSubscriptionTierSelected(String tier) async {
    try {
      await _analytics?.logEvent(
        name: 'subscription_tier_selected',
        parameters: {'tier': tier},
      );
    } catch (e) {
      debugPrint(
        'Failed to log subscription tier selected to Firebase Analytics: $e',
      );
    }
  }

  /// Log when upgrade dialog is displayed
  /// **Non-Critical**: Safe to use `unawaited()` for better performance
  Future<void> logUpgradeDialogShown({
    required String
    source, // 'daily_limit', 'locked_mode', 'editions', 'multiplayer'
    required String targetTier, // 'basic' or 'premium'
  }) async {
    try {
      await _analytics?.logEvent(
        name: 'upgrade_dialog_shown',
        parameters: {'source': source, 'target_tier': targetTier},
      );
    } catch (e) {
      debugPrint(
        'Failed to log upgrade dialog shown to Firebase Analytics: $e',
      );
    }
  }

  /// Log when user dismisses upgrade dialog
  /// **Non-Critical**: Safe to use `unawaited()` for better performance
  Future<void> logUpgradeDialogDismissed({
    required String source,
    required String targetTier,
  }) async {
    try {
      await _analytics?.logEvent(
        name: 'upgrade_dialog_dismissed',
        parameters: {'source': source, 'target_tier': targetTier},
      );
    } catch (e) {
      debugPrint(
        'Failed to log upgrade dialog dismissed to Firebase Analytics: $e',
      );
    }
  }

  /// Log when free trial starts
  /// **Critical**: Recommended to await for trial analytics accuracy
  Future<void> logTrialStarted(String tier) async {
    try {
      await _analytics?.logEvent(
        name: 'trial_started',
        parameters: {'tier': tier},
      );
    } catch (e) {
      debugPrint('Failed to log trial started to Firebase Analytics: $e');
    }
  }

  /// Log when trial converts to paid subscription
  /// **Critical**: Recommended to await for conversion analytics accuracy
  Future<void> logTrialConverted(String tier) async {
    try {
      await _analytics?.logEvent(
        name: 'trial_converted',
        parameters: {'tier': tier},
      );
    } catch (e) {
      debugPrint('Failed to log trial converted to Firebase Analytics: $e');
    }
  }

  /// Log when trial expires without conversion
  /// **Critical**: Recommended to await for trial analytics accuracy
  Future<void> logTrialExpired(String tier) async {
    try {
      await _analytics?.logEvent(
        name: 'trial_expired',
        parameters: {'tier': tier},
      );
    } catch (e) {
      debugPrint('Failed to log trial expired to Firebase Analytics: $e');
    }
  }

  /// Track conversion funnel steps
  /// **Non-Critical**: Safe to use `unawaited()` for better performance
  Future<void> logConversionFunnelStep({
    required int step, // 1-6
    required String stepName,
    required String source, // Where user came from
    String? targetTier,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      await _analytics?.logEvent(
        name: 'conversion_funnel_step',
        parameters: {
          'step': step,
          'step_name': stepName,
          'source': source,
          if (targetTier != null) 'target_tier': targetTier,
          'timestamp': DateTime.now().toIso8601String(),
          ...?additionalData,
        },
      );
    } catch (e) {
      debugPrint(
        'Failed to log conversion funnel step to Firebase Analytics: $e',
      );
    }
  }

  /// Log trivia validation event (template initialization)
  /// **Critical**: Recommended to await for content quality monitoring
  Future<void> logTriviaValidation(
    int templateCount,
    bool success, {
    String? error,
  }) async {
    try {
      await _analytics?.logEvent(
        name: 'trivia_validation',
        parameters: {
          'template_count': templateCount,
          'success': success,
          if (error != null) 'error': error,
        },
      );
    } catch (e) {
      debugPrint('Failed to log trivia validation to Firebase Analytics: $e');
    }
  }

  /// Log ping sent event (multiplayer)
  /// **Non-Critical**: Safe to use `unawaited()` for better performance
  Future<void> logPingSent() async {
    debugPrint('Analytics: Ping sent');
    try {
      await _analytics?.logEvent(name: 'ping_sent');
    } catch (e) {
      debugPrint('Failed to log ping sent to Firebase Analytics: $e');
    }
  }

  /// Log room created event (multiplayer)
  /// **Non-Critical**: Safe to use `unawaited()` for better performance
  Future<void> logRoomCreated() async {
    debugPrint('Analytics: Room created');
    try {
      await _analytics?.logEvent(name: 'room_created');
    } catch (e) {
      debugPrint('Failed to log room created to Firebase Analytics: $e');
    }
  }

  /// Log room joined event (multiplayer)
  /// **Non-Critical**: Safe to use `unawaited()` for better performance
  Future<void> logRoomJoined() async {
    debugPrint('Analytics: Room joined');
    try {
      await _analytics?.logEvent(name: 'room_joined');
    } catch (e) {
      debugPrint('Failed to log room joined to Firebase Analytics: $e');
    }
  }

  /// Log game start event
  /// **Non-Critical**: Safe to use `unawaited()` for better performance
  Future<void> logGameStart() async {
    debugPrint('Analytics: Game started');
    try {
      await _analytics?.logEvent(name: 'game_start');
    } catch (e) {
      debugPrint('Failed to log game start to Firebase Analytics: $e');
    }
  }

  /// Log screen view event
  /// **Non-Critical**: Safe to use `unawaited()` for better performance
  /// This is typically called frequently during navigation, so fire-and-forget is preferred
  /// Log family group events
  Future<void> logFamilyGroupEvent(String eventName, Map<String, dynamic>? parameters) async {
    try {
      await _analytics?.logEvent(
        name: eventName,
        parameters: parameters != null ? Map<String, Object>.from(parameters) : null,
      );
    } catch (e) {
      LoggerService.warning('Failed to log family group event: $eventName', error: e);
    }
  }

  Future<void> logScreenView(String screenName) async {
    debugPrint('Analytics: Screen viewed - $screenName');
    try {
      await _analytics?.logScreenView(screenName: screenName);
    } catch (e) {
      debugPrint('Failed to log screen view to Firebase Analytics: $e');
    }
  }

  /// Log trivia generation exhaustion warning
  /// **Non-Critical**: Safe to use `unawaited()` for better performance
  /// Called when batch size exceeds remaining unique combinations
  /// This helps monitor content exhaustion trends
  Future<void> logTriviaExhaustionWarning(
    int requestedCount,
    int remainingCombinations,
  ) async {
    try {
      await _analytics?.logEvent(
        name: 'trivia_exhaustion_warning',
        parameters: {
          'requested_count': requestedCount,
          'remaining_combinations': remainingCombinations,
          'exhaustion_ratio': remainingCombinations > 0
              ? (requestedCount / remainingCombinations).toStringAsFixed(2)
              : '0.00',
        },
      );
    } catch (e) {
      debugPrint(
        'Failed to log trivia exhaustion warning to Firebase Analytics: $e',
      );
    }
  }

  /// Log trivia generation partial batch
  /// **Non-Critical**: Safe to use `unawaited()` for better performance
  /// Called when batch generation fails for some items - helps monitor content generation reliability
  Future<void> logTriviaPartialBatch(
    int requestedCount,
    int actualCount,
    String? error,
  ) async {
    try {
      await _analytics?.logEvent(
        name: 'trivia_partial_batch',
        parameters: {
          'requested_count': requestedCount,
          'actual_count': actualCount,
          'success_rate': actualCount > 0
              ? (actualCount / requestedCount).toStringAsFixed(2)
              : '0.00',
          if (error != null) 'error': error,
        },
      );
    } catch (e) {
      debugPrint(
        'Failed to log trivia partial batch to Firebase Analytics: $e',
      );
    }
  }

  /// Log video load failure
  /// **Non-Critical**: Safe to use `unawaited()` for better performance
  Future<void> logVideoLoadFailure(String videoPath, String error) async {
    try {
      await _analytics?.logEvent(
        name: 'video_load_failure',
        parameters: {'video_path': videoPath, 'error': error},
      );
    } catch (e) {
      debugPrint('Failed to log video load failure to Firebase Analytics: $e');
    }
  }

  /// Log navigation error
  /// **Non-Critical**: Safe to use `unawaited()` for better performance
  Future<void> logNavigationError(String route, String error) async {
    try {
      await _analytics?.logEvent(
        name: 'navigation_error',
        parameters: {'route': route, 'error': error},
      );
    } catch (e) {
      debugPrint('Failed to log navigation error to Firebase Analytics: $e');
    }
  }

  /// Log service initialization failure
  /// **Non-Critical**: Safe to use `unawaited()` for better performance
  /// Log font load failure for monitoring
  Future<void> logFontLoadFailure(
    String fontName,
    String error,
    int loadDurationMs,
  ) async {
    debugPrint(
      'Analytics: Font load failure - $fontName: $error (${loadDurationMs}ms)',
    );
    try {
      await _analytics?.logEvent(
        name: 'font_load_failure',
        parameters: {
          'font_name': fontName,
          'error': error,
          'load_duration_ms': loadDurationMs,
        },
      );
    } catch (e) {
      debugPrint('Failed to log font load failure to Firebase Analytics: $e');
    }
  }

  /// Log font load success for monitoring
  Future<void> logFontLoadSuccess(String fontName, int loadDurationMs) async {
    try {
      await _analytics?.logEvent(
        name: 'font_load_success',
        parameters: {'font_name': fontName, 'load_duration_ms': loadDurationMs},
      );
    } catch (e) {
      debugPrint('Failed to log font load success to Firebase Analytics: $e');
    }
  }

  /// Log template quality metrics
  Future<void> logTemplateQualityMetrics({
    required String editionId,
    required String theme,
    required int templateCount,
    required double diversityRatio,
  }) async {
    try {
      await _analytics?.logEvent(
        name: 'template_quality_metrics',
        parameters: {
          'edition_id': editionId,
          'theme': theme,
          'template_count': templateCount,
          'diversity_ratio': diversityRatio,
        },
      );
    } catch (e) {
      debugPrint(
        'Failed to log template quality metrics to Firebase Analytics: $e',
      );
    }
  }

  Future<void> logServiceInitializationFailure(
    String serviceName,
    String error,
  ) async {
    try {
      await _analytics?.logEvent(
        name: 'service_init_failure',
        parameters: {'service_name': serviceName, 'error': error},
      );
    } catch (e) {
      debugPrint(
        'Failed to log service initialization failure to Firebase Analytics: $e',
      );
    }
  }

  /// Log onboarding completion
  /// **Non-Critical**: Safe to use `unawaited()` for better performance
  Future<void> logOnboardingCompleted() async {
    try {
      await _analytics?.logEvent(name: 'onboarding_completed');
    } catch (e) {
      debugPrint(
        'Failed to log onboarding completion to Firebase Analytics: $e',
      );
    }
  }

  /// Log onboarding skipped
  /// **Non-Critical**: Safe to use `unawaited()` for better performance
  Future<void> logOnboardingSkipped() async {
    try {
      await _analytics?.logEvent(name: 'onboarding_skipped');
    } catch (e) {
      debugPrint('Failed to log onboarding skip to Firebase Analytics: $e');
    }
  }

  /// Log video retry success
  /// **Non-Critical**: Safe to use `unawaited()` for better performance
  Future<void> logVideoRetrySuccess(String videoPath, int retryCount) async {
    try {
      await _analytics?.logEvent(
        name: 'video_retry_success',
        parameters: {'video_path': videoPath, 'retry_count': retryCount},
      );
    } catch (e) {
      debugPrint('Failed to log video retry success to Firebase Analytics: $e');
    }
  }

  /// Log video completion with timing analytics
  /// Tracks actual vs expected video duration to identify timing issues
  /// **Non-Critical**: Safe to use `unawaited()` for better performance
  Future<void> logVideoCompletion(
    String videoPath,
    int expectedDurationMs,
    int actualDurationMs,
    int differenceMs,
  ) async {
    try {
      await _analytics?.logEvent(
        name: 'video_completion',
        parameters: {
          'video_path': videoPath,
          'expected_duration_ms': expectedDurationMs,
          'actual_duration_ms': actualDurationMs,
          'difference_ms': differenceMs,
          'completed_on_time':
              differenceMs.abs() < 500, // Within 500ms is considered "on time"
        },
      );
    } catch (e) {
      debugPrint('Failed to log video completion to Firebase Analytics: $e');
    }
  }

  /// Log when fallback timer is used instead of video completion callback
  /// Helps identify videos that don't complete properly
  /// **Non-Critical**: Safe to use `unawaited()` for better performance
  Future<void> logVideoFallbackTimerUsed(String videoPath) async {
    try {
      await _analytics?.logEvent(
        name: 'video_fallback_timer_used',
        parameters: {'video_path': videoPath},
      );
    } catch (e) {
      debugPrint(
        'Failed to log video fallback timer usage to Firebase Analytics: $e',
      );
    }
  }

  /// Log navigation transition time
  /// **Non-Critical**: Safe to use `unawaited()` for better performance
  Future<void> logNavigationTransition(
    String fromRoute,
    String toRoute,
    int milliseconds,
  ) async {
    try {
      await _analytics?.logEvent(
        name: 'navigation_transition',
        parameters: {
          'from_route': fromRoute,
          'to_route': toRoute,
          'duration_ms': milliseconds,
        },
      );
    } catch (e) {
      debugPrint(
        'Failed to log navigation transition to Firebase Analytics: $e',
      );
    }
  }

  /// Log service initialization timing
  /// **Non-Critical**: Safe to use `unawaited()` for better performance
  Future<void> logServiceInitializationTime(
    String serviceName,
    int milliseconds,
    bool success,
  ) async {
    try {
      await _analytics?.logEvent(
        name: 'service_init_timing',
        parameters: {
          'service_name': serviceName,
          'duration_ms': milliseconds,
          'success': success,
        },
      );
    } catch (e) {
      debugPrint(
        'Failed to log service initialization time to Firebase Analytics: $e',
      );
    }
  }

  /// Log achievement unlocked event
  /// **Non-Critical**: Safe to use `unawaited()` for better performance
  Future<void> logAchievementUnlocked(
    String achievementId,
    String achievementName,
  ) async {
    try {
      await _analytics?.logEvent(
        name: 'achievement_unlocked',
        parameters: {
          'achievement_id': achievementId,
          'achievement_name': achievementName,
        },
      );
    } catch (e) {
      debugPrint(
        'Failed to log achievement unlocked to Firebase Analytics: $e',
      );
    }
  }

  /// Log friend request sent
  /// **Non-Critical**: Safe to use `unawaited()` for better performance
  Future<void> logFriendRequestSent() async {
    try {
      await _analytics?.logEvent(name: 'friend_request_sent');
    } catch (e) {
      debugPrint('Failed to log friend request sent to Firebase Analytics: $e');
    }
  }

  /// Log friend request accepted
  /// **Non-Critical**: Safe to use `unawaited()` for better performance
  Future<void> logFriendRequestAccepted() async {
    try {
      await _analytics?.logEvent(name: 'friend_request_accepted');
    } catch (e) {
      debugPrint(
        'Failed to log friend request accepted to Firebase Analytics: $e',
      );
    }
  }

  /// Log game mode completion
  /// **Non-Critical**: Safe to use `unawaited()` for better performance
  Future<void> logGameModeCompletion(
    String mode,
    int score,
    double accuracy,
    int rounds,
  ) async {
    try {
      await _analytics?.logEvent(
        name: 'game_mode_completion',
        parameters: {
          'mode': mode,
          'score': score,
          'accuracy': accuracy,
          'rounds': rounds,
        },
      );
    } catch (e) {
      debugPrint(
        'Failed to log game mode completion to Firebase Analytics: $e',
      );
    }
  }

  /// Log power-up usage
  /// **Non-Critical**: Safe to use `unawaited()` for better performance
  Future<void> logPowerUpUsed(String powerUpType, int remainingUses) async {
    try {
      await _analytics?.logEvent(
        name: 'power_up_used',
        parameters: {
          'power_up_type': powerUpType,
          'remaining_uses': remainingUses,
        },
      );
    } catch (e) {
      debugPrint('Failed to log power-up usage to Firebase Analytics: $e');
    }
  }

  /// Log settings changed
  /// **Non-Critical**: Safe to use `unawaited()` for better performance
  Future<void> logSettingsChanged(
    String settingName,
    String settingValue,
  ) async {
    try {
      await _analytics?.logEvent(
        name: 'settings_changed',
        parameters: {
          'setting_name': settingName,
          'setting_value': settingValue,
        },
      );
    } catch (e) {
      debugPrint('Failed to log settings changed to Firebase Analytics: $e');
    }
  }

  /// Log daily challenge completed
  /// **Non-Critical**: Safe to use `unawaited()` for better performance
  Future<void> logDailyChallengeCompleted(
    String challengeId,
    int score,
    int rank,
  ) async {
    try {
      await _analytics?.logEvent(
        name: 'daily_challenge_completed',
        parameters: {'challenge_id': challengeId, 'score': score, 'rank': rank},
      );
    } catch (e) {
      debugPrint(
        'Failed to log daily challenge completion to Firebase Analytics: $e',
      );
    }
  }

  /// Track performance metrics for monitoring and optimization
  ///
  /// **Performance Metrics Tracked:**
  /// - Game state save/load times
  /// - Trivia generation latency
  /// - Network reachability check duration
  /// - Template initialization time
  ///
  /// **Non-Critical**: Safe to use `unawaited()` for better performance
  Future<void> logPerformanceMetric({
    required String metricName,
    required Duration duration,
    Map<String, dynamic>? additionalParams,
    bool success = true,
  }) async {
    try {
      final params = <String, Object>{
        'metric_name': metricName,
        'duration_ms': duration.inMilliseconds,
        'success': success,
        if (additionalParams != null)
          ...additionalParams.map((k, v) => MapEntry(k, v as Object)),
      };

      await _analytics?.logEvent(
        name: 'performance_metric',
        parameters: params,
      );

      if (kDebugMode && duration.inMilliseconds > 1000) {
        debugPrint(
          '⚠️ Performance: $metricName took ${duration.inMilliseconds}ms',
        );
      }
    } catch (e) {
      debugPrint('Failed to log performance metric to Firebase Analytics: $e');
    }
  }

  /// Track game state save performance
  Future<void> logGameStateSave(
    Duration duration, {
    bool success = true,
    int retryCount = 0,
  }) async {
    await logPerformanceMetric(
      metricName: 'game_state_save',
      duration: duration,
      success: success,
      additionalParams: {'retry_count': retryCount},
    );
  }

  /// Track game state load performance
  Future<void> logGameStateLoad(
    Duration duration, {
    bool success = true,
  }) async {
    await logPerformanceMetric(
      metricName: 'game_state_load',
      duration: duration,
      success: success,
    );
  }

  /// Track trivia generation performance
  Future<void> logTriviaGenerationPerformance(
    Duration duration, {
    required String mode,
    bool success = true,
    int poolSize = 0,
  }) async {
    await logPerformanceMetric(
      metricName: 'trivia_generation',
      duration: duration,
      success: success,
      additionalParams: {'mode': mode, 'pool_size': poolSize},
    );
  }

  /// Track network reachability check performance
  Future<void> logNetworkReachabilityCheck(
    Duration duration, {
    bool success = true,
    bool hasInternet = false,
    int retryCount = 0,
  }) async {
    await logPerformanceMetric(
      metricName: 'network_reachability_check',
      duration: duration,
      success: success,
      additionalParams: {
        'has_internet': hasInternet,
        'retry_count': retryCount,
      },
    );
  }

  /// Track trivia template initialization performance
  Future<void> logTemplateInitialization(
    Duration duration, {
    bool success = true,
    int templateCount = 0,
    int retryCount = 0,
  }) async {
    await logPerformanceMetric(
      metricName: 'template_initialization',
      duration: duration,
      success: success,
      additionalParams: {
        'template_count': templateCount,
        'retry_count': retryCount,
      },
    );
  }

  /// Track multiplayer room creation performance
  Future<void> logRoomCreation(
    Duration duration, {
    bool success = true,
    String? mode,
    int maxPlayers = 0,
    int retryCount = 0,
  }) async {
    await logPerformanceMetric(
      metricName: 'room_creation',
      duration: duration,
      success: success,
      additionalParams: {
        if (mode != null) 'mode': mode,
        'max_players': maxPlayers,
        'retry_count': retryCount,
      },
    );
  }

  /// Track multiplayer room joining performance
  Future<void> logRoomJoining(
    Duration duration, {
    bool success = true,
    int retryCount = 0,
  }) async {
    await logPerformanceMetric(
      metricName: 'room_joining',
      duration: duration,
      success: success,
      additionalParams: {
        'retry_count': retryCount,
      },
    );
  }

  /// Track AI edition generation performance
  Future<void> logAIEditionGeneration(
    Duration duration, {
    bool success = true,
    bool isYouth = false,
    int retryCount = 0,
    String? errorType,
  }) async {
    await logPerformanceMetric(
      metricName: 'ai_edition_generation',
      duration: duration,
      success: success,
      additionalParams: {
        'is_youth': isYouth,
        'retry_count': retryCount,
        if (errorType != null) 'error_type': errorType,
      },
    );
  }

  /// Track app startup time
  Future<void> logAppStartup(
    Duration duration, {
    bool success = true,
    bool firebaseInitialized = false,
    bool templatesInitialized = false,
  }) async {
    await logPerformanceMetric(
      metricName: 'app_startup',
      duration: duration,
      success: success,
      additionalParams: {
        'firebase_initialized': firebaseInitialized,
        'templates_initialized': templatesInitialized,
      },
    );
  }

  /// Track family group creation performance
  Future<void> logFamilyGroupCreation(
    Duration duration, {
    bool success = true,
    int retryCount = 0,
  }) async {
    await logPerformanceMetric(
      metricName: 'family_group_creation',
      duration: duration,
      success: success,
      additionalParams: {
        'retry_count': retryCount,
      },
    );
  }
}
