import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Network service with actual internet reachability testing
///
/// **Features:**
/// - Connectivity type detection (WiFi, Mobile, etc.)
/// - Actual internet reachability test (not just connection type)
/// - Automatic retry with exponential backoff
/// - Cached reachability status for performance
/// - Performance tracking for monitoring
class NetworkService extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Optional analytics service for performance tracking
  // Set via setter to avoid circular dependencies
  dynamic _analyticsService;
  void setAnalyticsService(dynamic analyticsService) {
    _analyticsService = analyticsService;
  }

  bool _isConnected = true;
  bool _hasInternetReachability = true; // Actual internet access
  ConnectivityResult _connectionType = ConnectivityResult.none;
  DateTime? _lastReachabilityCheck;
  static const Duration _reachabilityCacheDuration = Duration(seconds: 30);

  bool get isConnected => _isConnected;
  bool get hasInternetReachability => _hasInternetReachability;
  ConnectivityResult get connectionType => _connectionType;

  Future<void> init() async {
    // Check initial connection status
    final result = await _connectivity.checkConnectivity();
    await _updateConnectionStatus(result);

    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) async {
      await _updateConnectionStatus(results);
    });
  }

  Future<void> _updateConnectionStatus(List<ConnectivityResult> results) async {
    final wasConnected = _isConnected;
    final hadInternet = _hasInternetReachability;
    _connectionType = results.first;
    _isConnected = results.first != ConnectivityResult.none;

    // If we have a connection type, test actual internet reachability
    if (_isConnected) {
      await _checkInternetReachability();
    } else {
      _hasInternetReachability = false;
    }

    if (wasConnected != _isConnected ||
        hadInternet != _hasInternetReachability) {
      LoggerService.info(
        'Network status changed: ${_isConnected ? "Connected" : "Disconnected"} '
        '(${_hasInternetReachability ? "Internet available" : "No internet access"})',
      );
      notifyListeners();
    }
  }

  /// Test actual internet reachability (not just connection type)
  /// Uses Firebase as the test endpoint since it's required for the app
  /// Includes retry logic for slow networks
  Future<bool> _checkInternetReachability() async {
    // Use cached result if recent check was done
    if (_lastReachabilityCheck != null) {
      final timeSinceCheck = DateTime.now().difference(_lastReachabilityCheck!);
      if (timeSinceCheck < _reachabilityCacheDuration) {
        return _hasInternetReachability;
      }
    }

    // Retry mechanism for slow networks
    const maxRetries = 2;
    const timeoutDuration = Duration(
      seconds: 10,
    ); // Increased from 5s to 10s for slow networks
    final checkStartTime = DateTime.now();
    int retryCount = 0;

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        // Test reachability by attempting to connect to Firebase
        // This is more reliable than just checking connectivity type
        final result = await InternetAddress.lookup(
          'firebase.googleapis.com',
        ).timeout(timeoutDuration);

        final hasReachability =
            result.isNotEmpty && result[0].rawAddress.isNotEmpty;
        _hasInternetReachability = hasReachability;
        _lastReachabilityCheck = DateTime.now();

        // Track performance metrics
        final checkDuration = DateTime.now().difference(checkStartTime);
        try {
          if (_analyticsService != null) {
            await _analyticsService.logNetworkReachabilityCheck(
              checkDuration,
              success: true,
              hasInternet: hasReachability,
              retryCount: retryCount,
            );
          }
        } catch (e) {
          // Analytics failure shouldn't block network check
          LoggerService.warning(
            'Failed to log network reachability performance',
            error: e,
          );
        }

        if (!hasReachability) {
          LoggerService.warning(
            'Network connected but no internet reachability detected',
          );
        }

        return hasReachability;
      } catch (e) {
        retryCount = attempt + 1;
        // If DNS lookup fails, retry if not last attempt
        if (attempt < maxRetries - 1) {
          LoggerService.debug(
            'Internet reachability check failed (attempt ${attempt + 1}/$maxRetries), retrying...',
          );
          // Brief delay before retry (exponential backoff)
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
          continue;
        }

        // All retries exhausted
        _hasInternetReachability = false;
        _lastReachabilityCheck = DateTime.now();

        // Track performance metrics on failure
        final checkDuration = DateTime.now().difference(checkStartTime);
        try {
          if (_analyticsService != null) {
            await _analyticsService.logNetworkReachabilityCheck(
              checkDuration,
              success: false,
              hasInternet: false,
              retryCount: retryCount,
            );
          }
        } catch (analyticsError) {
          // Analytics failure shouldn't block error handling
          LoggerService.warning(
            'Failed to log network reachability failure performance',
            error: analyticsError,
          );
        }

        LoggerService.warning(
          'Internet reachability check failed after $maxRetries attempts',
          error: e,
        );

        return false;
      }
    }

    // Should never reach here, but return false as fallback
    return false;
  }

  /// Force a fresh internet reachability check
  /// Useful when network operations fail unexpectedly
  Future<bool> checkInternetReachability() async {
    _lastReachabilityCheck = null; // Clear cache
    final hasInternet = await _checkInternetReachability();
    notifyListeners();
    return hasInternet;
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
