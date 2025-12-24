import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/models/ai_performance_data.dart';

/// Service for AI-powered adaptive game mode
/// Provides personalized difficulty adjustment and question selection
class AIModeService extends ChangeNotifier {
  static const String _collectionName = 'ai_performance_data';
  static const String _localStorageKey = 'ai_performance_data_local';

  AIPerformanceData? _currentPerformanceData;
  bool _isLoading = false;
  String? _lastError;
  bool _isOfflineMode = false;

  SharedPreferences? _prefs;

  AIPerformanceData? get currentPerformanceData => _currentPerformanceData;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  bool get isOfflineMode => _isOfflineMode;

  /// Get or initialize SharedPreferences
  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Load performance data from local storage
  Future<void> _loadFromLocalStorage(String userId) async {
    try {
      final prefs = await _getPrefs();
      final jsonString = prefs.getString('$_localStorageKey$userId');
      if (jsonString != null) {
        final jsonData = json.decode(jsonString) as Map<String, dynamic>;
        _currentPerformanceData = AIPerformanceData(
          userId: userId,
          averageAccuracy: (jsonData['averageAccuracy'] ?? 0.0).toDouble(),
          averageResponseTime:
              (jsonData['averageResponseTime'] ?? 10.0).toDouble(),
          categoryAccuracy: Map<String, double>.from(
            jsonData['categoryAccuracy'] ?? {},
          ),
          categoryAttempts: Map<String, int>.from(
            jsonData['categoryAttempts'] ?? {},
          ),
          totalRounds: jsonData['totalRounds'] ?? 0,
          totalCorrect: jsonData['totalCorrect'] ?? 0,
          totalWrong: jsonData['totalWrong'] ?? 0,
          lastUpdated: jsonData['lastUpdated'] != null
              ? DateTime.parse(jsonData['lastUpdated'] as String)
              : DateTime.now(),
          currentDifficultyLevel:
              (jsonData['currentDifficultyLevel'] ?? 0.5).toDouble(),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading from local storage: $e');
      }
    }
  }

  /// Save performance data to local storage
  Future<void> _saveToLocalStorage() async {
    final currentData = _currentPerformanceData;
    if (currentData == null) return;

    try {
      final prefs = await _getPrefs();
      final json = currentData.toFirestore();
      json['lastUpdated'] = DateTime.now().toIso8601String();
      await prefs.setString(
        '$_localStorageKey${currentData.userId}',
        jsonEncode(json),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving to local storage: $e');
      }
    }
  }

  /// Initialize and load user's AI performance data
  /// Supports offline mode with local storage fallback
  Future<void> init() async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;

      // If no user, create anonymous local data
      if (user == null) {
        _isOfflineMode = true;
        await _loadFromLocalStorage('anonymous');
        if (_currentPerformanceData == null) {
          _currentPerformanceData = AIPerformanceData(
            userId: 'anonymous',
            averageAccuracy: 0.0,
            averageResponseTime: 10.0,
            categoryAccuracy: {},
            categoryAttempts: {},
            totalRounds: 0,
            totalCorrect: 0,
            totalWrong: 0,
            lastUpdated: DateTime.now(),
            currentDifficultyLevel: 0.5,
          );
          await _saveToLocalStorage();
        }
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Try to load from Firestore first
      try {
        final doc = await FirebaseFirestore.instance
            .collection(_collectionName)
            .doc(user.uid)
            .get()
            .timeout(const Duration(seconds: 5));

        if (doc.exists) {
          _currentPerformanceData = AIPerformanceData.fromFirestore(doc);
          _isOfflineMode = false;
          // Sync to local storage
          await _saveToLocalStorage();
        } else {
          // Try local storage first
          await _loadFromLocalStorage(user.uid);
          _currentPerformanceData ??= AIPerformanceData(
            userId: user.uid,
            averageAccuracy: 0.0,
            averageResponseTime: 10.0,
            categoryAccuracy: {},
            categoryAttempts: {},
            totalRounds: 0,
            totalCorrect: 0,
            totalWrong: 0,
            lastUpdated: DateTime.now(),
            currentDifficultyLevel: 0.5,
          );
          await _savePerformanceData();
          await _saveToLocalStorage();
        }
      } catch (e) {
        // Firestore failed, use local storage
        if (kDebugMode) {
          debugPrint('Firestore unavailable, using local storage: $e');
        }
        _isOfflineMode = true;
        await _loadFromLocalStorage(user.uid);
        if (_currentPerformanceData == null) {
          _currentPerformanceData = AIPerformanceData(
            userId: user.uid,
            averageAccuracy: 0.0,
            averageResponseTime: 10.0,
            categoryAccuracy: {},
            categoryAttempts: {},
            totalRounds: 0,
            totalCorrect: 0,
            totalWrong: 0,
            lastUpdated: DateTime.now(),
            currentDifficultyLevel: 0.5,
          );
          await _saveToLocalStorage();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error initializing AI mode service: $e');
      }
      _lastError = 'Failed to initialize AI mode. Using default settings.';
      // Create default data on error
      final user = FirebaseAuth.instance.currentUser;
      _currentPerformanceData = AIPerformanceData(
        userId: user?.uid ?? 'anonymous',
        averageAccuracy: 0.0,
        averageResponseTime: 10.0,
        categoryAccuracy: {},
        categoryAttempts: {},
        totalRounds: 0,
        totalCorrect: 0,
        totalWrong: 0,
        lastUpdated: DateTime.now(),
        currentDifficultyLevel: 0.5,
      );
      await _saveToLocalStorage();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Save performance data to Firestore
  /// Falls back to local storage if Firestore is unavailable
  Future<void> _savePerformanceData() async {
    if (_currentPerformanceData == null) return;

    // Always save to local storage first
    await _saveToLocalStorage();

    // Try to save to Firestore if online
    final currentData = _currentPerformanceData;
    if (!_isOfflineMode &&
        currentData != null &&
        currentData.userId != 'anonymous') {
      try {
        await FirebaseFirestore.instance
            .collection(_collectionName)
            .doc(currentData.userId)
            .set(currentData.toFirestore())
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error saving AI performance data to Firestore: $e');
        }
        // Mark as offline and continue with local storage
        _isOfflineMode = true;
      }
    }
  }

  /// Update performance after a round
  /// Returns the new difficulty level
  /// Validates category and handles errors gracefully
  Future<double> updatePerformance({
    required bool wasCorrect,
    required String category,
    required double responseTime, // in seconds
    required int memorizeTime,
    required int playTime,
  }) async {
    if (_currentPerformanceData == null) {
      await init();
      if (_currentPerformanceData == null) return 0.5;
    }

    final currentData = _currentPerformanceData;
    if (currentData == null) return 0.5;

    // Validate category is not empty
    if (category.isEmpty) {
      if (kDebugMode) {
        debugPrint('Warning: Empty category provided to updatePerformance');
      }
      return currentData.currentDifficultyLevel;
    }

    // Validate response time is reasonable (0.1s to 300s)
    final validResponseTime = responseTime.clamp(0.1, 300.0);
    if (responseTime != validResponseTime) {
      if (kDebugMode) {
        debugPrint(
          'Warning: Response time $responseTime clamped to $validResponseTime',
        );
      }
    }

    final data = currentData;

    // Update totals
    final newTotalCorrect =
        wasCorrect ? data.totalCorrect + 1 : data.totalCorrect;
    final newTotalWrong = wasCorrect ? data.totalWrong : data.totalWrong + 1;
    final newTotalRounds = data.totalRounds + 1;

    // Calculate new average accuracy
    final newAverageAccuracy = (newTotalCorrect / newTotalRounds) * 100.0;

    // Update average response time (exponential moving average)
    final alpha = 0.3; // Smoothing factor
    final newAverageResponseTime =
        (alpha * responseTime) + ((1 - alpha) * data.averageResponseTime);

    // Update category-specific data
    final categoryAcc = Map<String, double>.from(data.categoryAccuracy);
    final categoryAtt = Map<String, int>.from(data.categoryAttempts);

    final currentCategoryAttempts = categoryAtt[category] ?? 0;
    final currentCategoryAccuracy = categoryAcc[category] ?? 0.0;

    categoryAtt[category] = currentCategoryAttempts + 1;

    // Update category accuracy (weighted average)
    if (currentCategoryAttempts == 0) {
      categoryAcc[category] = wasCorrect ? 100.0 : 0.0;
    } else {
      final newCategoryAccuracy =
          ((currentCategoryAccuracy * currentCategoryAttempts) +
                  (wasCorrect ? 100.0 : 0.0)) /
              (currentCategoryAttempts + 1);
      categoryAcc[category] = newCategoryAccuracy;
    }

    // Calculate new difficulty level based on recent performance
    // Look at last 10 rounds for recent trend
    final recentAccuracy = newAverageAccuracy;
    double newDifficultyLevel = data.currentDifficultyLevel;

    // Adjust difficulty based on accuracy
    if (recentAccuracy > 80.0) {
      // User is doing well - increase difficulty
      newDifficultyLevel = (data.currentDifficultyLevel + 0.05).clamp(0.0, 1.0);
    } else if (recentAccuracy < 50.0) {
      // User is struggling - decrease difficulty
      newDifficultyLevel = (data.currentDifficultyLevel - 0.05).clamp(0.0, 1.0);
    } else {
      // User is in the sweet spot - maintain difficulty
      // Slight adjustment based on recent round
      if (wasCorrect) {
        newDifficultyLevel = (data.currentDifficultyLevel + 0.02).clamp(
          0.0,
          1.0,
        );
      } else {
        newDifficultyLevel = (data.currentDifficultyLevel - 0.02).clamp(
          0.0,
          1.0,
        );
      }
    }

    // Update performance data
    _currentPerformanceData = data.copyWith(
      averageAccuracy: newAverageAccuracy,
      averageResponseTime: newAverageResponseTime,
      categoryAccuracy: categoryAcc,
      categoryAttempts: categoryAtt,
      totalRounds: newTotalRounds,
      totalCorrect: newTotalCorrect,
      totalWrong: newTotalWrong,
      lastUpdated: DateTime.now(),
      currentDifficultyLevel: newDifficultyLevel,
    );

    // Save to Firestore (async, don't wait)
    _savePerformanceData();

    notifyListeners();
    return newDifficultyLevel;
  }

  /// Get recommended memorize and play times based on current difficulty
  /// Returns (memorizeTime, playTime)
  (int, int) getRecommendedTiming() {
    if (_currentPerformanceData == null) {
      return (10, 20); // Default
    }

    final difficulty = _currentPerformanceData!.currentDifficultyLevel;
    final avgResponseTime = _currentPerformanceData!.averageResponseTime;

    // Base timing: 10s memorize, 20s play
    // Adjust based on difficulty and response time
    final baseMemorize = 10;
    final basePlay = 20;

    // Difficulty affects both times
    // Higher difficulty = less time
    final difficultyMultiplier = 1.0 - (difficulty * 0.4); // 0.6 to 1.0

    // Response time affects play time
    // Faster responses = less time needed
    final responseTimeMultiplier = (avgResponseTime / 10.0).clamp(0.7, 1.3);

    final memorizeTime = (baseMemorize * difficultyMultiplier).round().clamp(
          5,
          15,
        );
    final playTime = (basePlay * difficultyMultiplier * responseTimeMultiplier)
        .round()
        .clamp(8, 25);

    return (memorizeTime, playTime);
  }

  /// Get recommended categories to focus on (weakest areas)
  List<String> getRecommendedCategories({int limit = 3}) {
    final currentData = _currentPerformanceData;
    if (currentData == null || currentData.categoryAccuracy.isEmpty) {
      return [];
    }

    // Sort categories by accuracy (ascending - weakest first)
    final sortedCategories = currentData.categoryAccuracy.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return sortedCategories.take(limit).map((e) => e.key).toList();
  }

  /// Get categories to avoid (strongest areas - user already knows these)
  List<String> getStrongCategories({int limit = 3}) {
    final currentData = _currentPerformanceData;
    if (currentData == null || currentData.categoryAccuracy.isEmpty) {
      return [];
    }

    // Sort categories by accuracy (descending - strongest first)
    final sortedCategories = currentData.categoryAccuracy.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedCategories.take(limit).map((e) => e.key).toList();
  }

  /// Get personalized hint based on performance
  String? getPersonalizedHint(String category) {
    if (_currentPerformanceData == null) return null;

    final categoryAcc =
        _currentPerformanceData!.categoryAccuracy[category] ?? 0.0;

    if (categoryAcc < 40.0) {
      return 'Focus on the key words in the question. Take your time.';
    } else if (categoryAcc < 70.0) {
      return 'You\'re improving in this category! Keep practicing.';
    } else {
      return 'You\'re doing great in this category!';
    }
  }

  /// Reset performance data (for testing or user request)
  /// Works in offline mode too
  Future<void> resetPerformanceData() async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? 'anonymous';

    _currentPerformanceData = AIPerformanceData(
      userId: userId,
      averageAccuracy: 0.0,
      averageResponseTime: 10.0,
      categoryAccuracy: {},
      categoryAttempts: {},
      totalRounds: 0,
      totalCorrect: 0,
      totalWrong: 0,
      lastUpdated: DateTime.now(),
      currentDifficultyLevel: 0.5,
    );

    await _savePerformanceData();
    await _saveToLocalStorage();
    notifyListeners();
  }

  /// Sync local data to Firestore when connection is restored
  Future<void> syncToFirestore() async {
    final currentData = _currentPerformanceData;
    if (currentData == null) return;
    if (currentData.userId == 'anonymous') return;

    try {
      await FirebaseFirestore.instance
          .collection(_collectionName)
          .doc(currentData.userId)
          .set(currentData.toFirestore())
          .timeout(const Duration(seconds: 5));
      _isOfflineMode = false;
      _lastError = null;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error syncing to Firestore: $e');
      }
      _lastError = 'Sync failed. Data saved locally.';
    }
  }
}
