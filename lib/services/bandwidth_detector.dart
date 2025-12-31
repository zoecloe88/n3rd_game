import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Connection quality metrics
enum BandwidthQuality {
  fast, // High bandwidth, low latency
  medium, // Moderate bandwidth and latency
  slow, // Low bandwidth, high latency
  unknown, // Unable to determine
}

/// Connection quality metrics
class BandwidthMetrics {

  BandwidthMetrics({
    required this.quality,
    this.latencyMs,
    this.throughputMbps,
    required this.connectionType,
  });
  final BandwidthQuality quality;
  final int? latencyMs; // Latency in milliseconds
  final double? throughputMbps; // Throughput in Mbps (if available)
  final ConnectivityResult connectionType;
}

/// Service for detecting connection quality and bandwidth
///
/// Measures latency and throughput to determine connection quality
/// and provides recommendations for adaptive quality settings.
class BandwidthDetector extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();

  BandwidthMetrics? _currentMetrics;
  bool _isDetecting = false;
  Timer? _detectionTimer;

  BandwidthMetrics? get currentMetrics => _currentMetrics;
  bool get isDetecting => _isDetecting;
  BandwidthQuality get quality =>
      _currentMetrics?.quality ?? BandwidthQuality.unknown;

  /// Detect connection quality
  Future<BandwidthMetrics> detectQuality() async {
    if (_isDetecting) {
      return _currentMetrics ??
          BandwidthMetrics(
            quality: BandwidthQuality.unknown,
            connectionType: ConnectivityResult.none,
          );
    }

    _isDetecting = true;
    notifyListeners();

    try {
      // Get connection type
      final connectivityResults = await _connectivity.checkConnectivity();
      final connectionType = connectivityResults.isNotEmpty
          ? connectivityResults.first
          : ConnectivityResult.none;

      if (connectionType == ConnectivityResult.none) {
        _currentMetrics = BandwidthMetrics(
          quality: BandwidthQuality.slow,
          connectionType: connectionType,
        );
        _isDetecting = false;
        notifyListeners();
        return _currentMetrics!;
      }

      // Measure latency
      final latency = await _measureLatency();

      // Estimate quality based on latency and connection type
      BandwidthQuality quality;
      if (latency == null) {
        quality = BandwidthQuality.unknown;
      } else if (latency < 100) {
        quality = BandwidthQuality.fast;
      } else if (latency < 300) {
        quality = BandwidthQuality.medium;
      } else {
        quality = BandwidthQuality.slow;
      }

      // Adjust quality based on connection type
      if (connectionType == ConnectivityResult.mobile) {
        // Mobile connections are generally slower
        if (quality == BandwidthQuality.fast) {
          quality = BandwidthQuality.medium;
        } else if (quality == BandwidthQuality.medium) {
          quality = BandwidthQuality.slow;
        }
      }

      _currentMetrics = BandwidthMetrics(
        quality: quality,
        latencyMs: latency,
        connectionType: connectionType,
      );

      _isDetecting = false;
      notifyListeners();
      return _currentMetrics!;
    } catch (e, stack) {
      LoggerService.error('Error detecting bandwidth', error: e, stack: stack);
      _currentMetrics = BandwidthMetrics(
        quality: BandwidthQuality.unknown,
        connectionType: ConnectivityResult.none,
      );
      _isDetecting = false;
      notifyListeners();
      return _currentMetrics!;
    }
  }

  /// Measure latency to a test endpoint
  Future<int?> _measureLatency() async {
    try {
      final stopwatch = Stopwatch()..start();

      // Try to connect to Firebase (required for the app)
      final result = await InternetAddress.lookup('firebase.googleapis.com')
          .timeout(const Duration(seconds: 3));

      stopwatch.stop();

      if (result.isEmpty) {
        return null;
      }

      // Latency is roughly the time to lookup
      // This is a simple approximation
      return stopwatch.elapsedMilliseconds;
    } catch (e) {
      LoggerService.debug('Error measuring latency', error: e);
      return null;
    }
  }

  /// Start periodic quality detection
  void startPeriodicDetection(
      {Duration interval = const Duration(minutes: 5),}) {
    _detectionTimer?.cancel();
    _detectionTimer = Timer.periodic(interval, (_) {
      detectQuality();
    });
  }

  /// Stop periodic detection
  void stopPeriodicDetection() {
    _detectionTimer?.cancel();
    _detectionTimer = null;
  }

  /// Get quality recommendation for adaptive settings
  String getQualityRecommendation() {
    switch (_currentMetrics?.quality ?? BandwidthQuality.unknown) {
      case BandwidthQuality.fast:
        return 'High quality connection. All features available.';
      case BandwidthQuality.medium:
        return 'Moderate connection. Some features may be limited.';
      case BandwidthQuality.slow:
        return 'Slow connection. Consider reducing quality settings.';
      case BandwidthQuality.unknown:
        return 'Connection quality unknown.';
    }
  }

  /// Check if connection is suitable for real-time multiplayer
  bool get isSuitableForMultiplayer {
    final quality = _currentMetrics?.quality ?? BandwidthQuality.unknown;
    return quality == BandwidthQuality.fast ||
        quality == BandwidthQuality.medium;
  }

  /// Check if connection is suitable for high-quality features
  bool get isSuitableForHighQuality {
    return _currentMetrics?.quality == BandwidthQuality.fast;
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _detectionTimer = null;
    super.dispose();
  }
}







