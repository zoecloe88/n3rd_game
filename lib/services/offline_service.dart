import 'package:flutter/foundation.dart';
import 'package:n3rd_game/utils/unawaited_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:n3rd_game/models/trivia_item.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/services/network_service.dart';
import 'package:n3rd_game/services/direct_message_service.dart';
import 'package:n3rd_game/services/feedback_service.dart';

/// Offline operation queue entry
class _OfflineOperation {

  _OfflineOperation({
    required this.id,
    required this.type,
    required this.data,
    required this.timestamp,
  });

  factory _OfflineOperation.fromJson(Map<String, dynamic> json) =>
      _OfflineOperation(
        id: json['id'] as String,
        type: json['type'] as String,
        data: json['data'] as Map<String, dynamic>,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
  final String id;
  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
      };
}

class OfflineService extends ChangeNotifier {
  static const String _storageKey = 'offline_packs';
  static const String _offlineQueueKey = 'offline_operations_queue';
  static const String _templatesCacheKey = 'cached_trivia_templates';
  static const int _maxCacheSizeMB = 100; // Max 100MB cache
  List<String> _downloadedPacks = [];
  List<_OfflineOperation> _offlineQueue = [];
  bool _isInitialized = false;
  bool _isOfflineMode = false;
  Timer? _syncTimer;
  NetworkService? _networkService;

  List<String> get downloadedPacks => _downloadedPacks;
  bool get isInitialized => _isInitialized;
  bool get isOfflineMode => _isOfflineMode;
  List<Map<String, dynamic>> get pendingOperations =>
      _offlineQueue.map((op) => op.toJson()).toList();

  /// Set network service (called from main.dart)
  void setNetworkService(NetworkService? service) {
    _networkService = service;
  }

  Future<void> init() async {
    if (_isInitialized) return;

    await _loadDownloadedPacks();
    await _loadOfflineQueue();
    unawaited(_checkOfflineMode());
    _startBackgroundSync();
    _isInitialized = true;
    notifyListeners();
  }

  /// Check if device is offline and update state
  Future<void> _checkOfflineMode() async {
    try {
      if (_networkService == null) return;
      final networkService = _networkService!;
      // Ensure network service is initialized
      if (!networkService.hasInternetReachability) {
        // Force check if needed
        await networkService.checkInternetReachability();
      }
      final isOnline = networkService.hasInternetReachability;
      if (_isOfflineMode != !isOnline) {
        _isOfflineMode = !isOnline;
        notifyListeners();
      }
    } catch (e) {
      // Assume offline if check fails
      _isOfflineMode = true;
      notifyListeners();
    }
  }

  /// Start background sync timer (syncs every 30 seconds when online)
  void _startBackgroundSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!_isOfflineMode && _offlineQueue.isNotEmpty) {
        await _syncOfflineQueue();
      }
      await _checkOfflineMode();
    });
  }

  /// Load offline operations queue
  Future<void> _loadOfflineQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_offlineQueueKey);
      if (queueJson != null) {
        final queue = (jsonDecode(queueJson) as List)
            .map((item) =>
                _OfflineOperation.fromJson(item as Map<String, dynamic>),)
            .toList();
        _offlineQueue = queue;
      }
    } catch (e) {
      LoggerService.warning('Failed to load offline queue', error: e);
    }
  }

  /// Save offline operations queue
  Future<void> _saveOfflineQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson =
          jsonEncode(_offlineQueue.map((op) => op.toJson()).toList());
      await prefs.setString(_offlineQueueKey, queueJson);
    } catch (e) {
      LoggerService.warning('Failed to save offline queue', error: e);
    }
  }

  /// Add operation to offline queue
  Future<void> queueOperation(String type, Map<String, dynamic> data) async {
    final operation = _OfflineOperation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      data: data,
      timestamp: DateTime.now(),
    );
    _offlineQueue.add(operation);
    await _saveOfflineQueue();
    notifyListeners();

    // Try to sync immediately if online
    if (!_isOfflineMode) {
      await _syncOfflineQueue();
    }
  }

  /// Sync offline queue (process pending operations when online)
  Future<void> _syncOfflineQueue() async {
    if (_offlineQueue.isEmpty || _isOfflineMode) return;

    if (_networkService == null) return;
    final networkService = _networkService!;
    // Check internet reachability
    final hasInternet = await networkService.checkInternetReachability();
    if (!hasInternet) {
      _isOfflineMode = true;
      notifyListeners();
      return;
    }

    final operationsToSync = List<_OfflineOperation>.from(_offlineQueue);
    final successfulOps = <String>[];

    for (final operation in operationsToSync) {
      try {
        // Process operation based on type
        LoggerService.debug('Syncing offline operation: ${operation.type}');

        // Implement actual sync logic for each operation type
        switch (operation.type) {
          case 'submit_score':
            // Score is automatically updated in user_stats via StatsService
            // This operation is handled when stats are updated
            // No additional action needed as leaderboard reads from user_stats
            LoggerService.debug(
                'Score submission synced (handled via stats update);',);
            break;

          case 'submit_achievement':
            // Achievements are checked automatically when stats are updated
            // This operation is handled by AchievementService.checkAchievements()
            LoggerService.debug(
                'Achievement submission synced (handled via stats update);',);
            break;

          case 'update_stats':
            // Stats are updated via StatsService
            // Extract stats data and update
            final statsData = operation.data['stats'] as Map<String, dynamic>?;
            if (statsData != null) {
              // StatsService will handle the update when it syncs
              // Stats are updated asynchronously during sync to avoid blocking offline operations
              LoggerService.debug('Stats update queued for sync');
            }
            break;

          case 'send_message':
            // Sync direct message
            final otherUserId = operation.data['otherUserId'] as String?;
            final message = operation.data['message'] as String?;
            if (otherUserId != null && message != null) {
              final directMessageService = DirectMessageService();
              await directMessageService.sendMessage(otherUserId, message);
              LoggerService.debug('Direct message synced: $otherUserId');
            }
            break;

          case 'submit_feedback':
            // Sync feedback submission
            final feedbackService = FeedbackService();
            await feedbackService.submitFeedback(
              type: operation.data['type'] as String? ?? 'general',
              message: operation.data['message'] as String? ?? '',
              category: operation.data['category'] as String?,
              images: null, // Images can't be stored in offline queue
              deviceInfo: operation.data['deviceInfo'] as Map<String, dynamic>?,
              userEmail: operation.data['userEmail'] as String?,
            );
            LoggerService.debug('Feedback synced');
            break;

          case 'create_edition':
            // Sync AI edition creation
            // Note: AI edition generation requires user interaction and cannot be fully synced offline
            // This operation is logged but will need to be re-initiated by the user when online
            final topic = operation.data['topic'] as String?;
            if (topic != null) {
              LoggerService.debug(
                  'AI edition creation queued (requires user interaction);: $topic',);
              // AI edition generation requires active user session and cannot be automated
              // The user will need to manually retry when online
            }
            break;

          default:
            LoggerService.warning('Unknown operation type: ${operation.type}');
            // Don't mark as successful for unknown types
            continue;
        }

        successfulOps.add(operation.id);
      } catch (e) {
        LoggerService.warning('Failed to sync operation ${operation.id}',
            error: e,);
        // Keep failed operations in queue for retry
      }
    }

    // Remove successful operations
    _offlineQueue.removeWhere((op) => successfulOps.contains(op.id));
    await _saveOfflineQueue();
    notifyListeners();
  }

  /// Cache trivia templates for offline generation
  Future<void> cacheTemplates(List<Map<String, dynamic>> templates) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_templatesCacheKey, jsonEncode(templates));
      LoggerService.debug(
          'Cached ${templates.length} trivia templates for offline use',);
    } catch (e) {
      LoggerService.warning('Failed to cache templates', error: e);
    }
  }

  /// Get cached trivia templates
  Future<List<Map<String, dynamic>>?> getCachedTemplates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final templatesJson = prefs.getString(_templatesCacheKey);
      if (templatesJson != null) {
        return List<Map<String, dynamic>>.from(
            jsonDecode(templatesJson) as List,);
      }
      return null;
    } catch (e) {
      LoggerService.warning('Failed to load cached templates', error: e);
      return null;
    }
  }

  Future<void> _loadDownloadedPacks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final packsJson = prefs.getString(_storageKey);
      if (packsJson != null) {
        _downloadedPacks = List<String>.from(jsonDecode(packsJson) as List);
      }
    } catch (e) {
      LoggerService.warning('Failed to load downloaded packs', error: e);
    }
  }

  Future<void> _saveDownloadedPacks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_downloadedPacks));
    } catch (e) {
      LoggerService.warning('Failed to save downloaded packs', error: e);
    }
  }

  /// Download a trivia pack for offline use
  Future<bool> downloadPack(String packId, List<TriviaItem> triviaItems) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final packsDir = Directory('${directory.path}/trivia_packs');

      if (!packsDir.existsSync()) {
        await packsDir.create(recursive: true);
      }

      final packFile = File('${packsDir.path}/$packId.json');
      final packData = {
        'packId': packId,
        'downloadedAt': DateTime.now().toIso8601String(),
        'items': triviaItems.map((item) => item.toJson()).toList(),
      };

      packFile.writeAsStringSync(jsonEncode(packData));

      if (!_downloadedPacks.contains(packId)) {
        _downloadedPacks.add(packId);
        await _saveDownloadedPacks();
        await _enforceCacheLimit(); // Check cache size after adding
        notifyListeners();
      }

      return true;
    } catch (e) {
      LoggerService.error('Failed to download pack', error: e);
      return false;
    }
  }

  /// Load a downloaded pack
  Future<List<TriviaItem>?> loadPack(String packId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final packFile = File('${directory.path}/trivia_packs/$packId.json');

      if (!packFile.existsSync()) {
        return null;
      }

      final jsonString = packFile.readAsStringSync();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      final items = (data['items'] as List)
          .map((item) => TriviaItem.fromJson(item as Map<String, dynamic>))
          .toList();

      return items;
    } catch (e) {
      LoggerService.warning('Failed to load pack', error: e);
      return null;
    }
  }

  /// Delete a downloaded pack
  Future<bool> deletePack(String packId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final packFile = File('${directory.path}/trivia_packs/$packId.json');

      if (packFile.existsSync()) {
        packFile.deleteSync();
      }

      _downloadedPacks.remove(packId);
      await _saveDownloadedPacks();
      notifyListeners();

      return true;
    } catch (e) {
      LoggerService.warning('Failed to delete pack', error: e);
      return false;
    }
  }

  /// Evict old packs if cache size exceeds limit (smart cache eviction)
  Future<void> _enforceCacheLimit() async {
    try {
      final totalSize = await getTotalSize();
      final maxSizeBytes = _maxCacheSizeMB * 1024 * 1024;

      if (totalSize <= maxSizeBytes) return;

      // Get pack file sizes and sort by last access time (oldest first)
      final directory = await getApplicationDocumentsDirectory();
      final packsDir = Directory('${directory.path}/trivia_packs');

      if (!packsDir.existsSync()) return;

      final packFiles = <Map<String, dynamic>>[];
      await for (final entity in packsDir.list()) {
        if (entity is File) {
          final stat = entity.statSync();
          packFiles.add({
            'path': entity.path,
            'size': stat.size,
            'modified': stat.modified,
          });
        }
      }

      // Sort by modification time (oldest first)
      packFiles.sort((a, b) =>
          (a['modified'] as DateTime).compareTo(b['modified'] as DateTime),);

      // Delete oldest packs until under limit
      int currentSize = totalSize;
      for (final fileInfo in packFiles) {
        if (currentSize <= maxSizeBytes) break;

        final file = File(fileInfo['path'] as String);
        final packId = file.path.split('/').last.replaceAll('.json', '');
        await deletePack(packId);
        currentSize -= fileInfo['size'] as int;
        LoggerService.debug('Evicted pack $packId to enforce cache limit');
      }
    } catch (e) {
      LoggerService.warning('Failed to enforce cache limit', error: e);
    }
  }

  /// Check if a pack is downloaded
  bool isPackDownloaded(String packId) {
    return _downloadedPacks.contains(packId);
  }

  /// Get total size of downloaded packs
  Future<int> getTotalSize() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final packsDir = Directory('${directory.path}/trivia_packs');

      if (!packsDir.existsSync()) {
        return 0;
      }

      int totalSize = 0;
      await for (final entity in packsDir.list()) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }

      return totalSize;
    } catch (e) {
      LoggerService.warning('Failed to calculate total size', error: e);
      return 0;
    }
  }

  /// Clear all downloaded packs
  Future<bool> clearAllPacks() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final packsDir = Directory('${directory.path}/trivia_packs');

      if (packsDir.existsSync()) {
        packsDir.deleteSync(recursive: true);
      }

      _downloadedPacks.clear();
      await _saveDownloadedPacks();
      notifyListeners();

      return true;
    } catch (e) {
      LoggerService.warning('Failed to clear all packs', error: e);
      return false;
    }
  }

  /// Manually trigger sync (useful when connection restored)
  Future<void> syncNow() async {
    await _checkOfflineMode();
    if (!_isOfflineMode) {
      await _syncOfflineQueue();
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _syncTimer = null;
    super.dispose();
  }
}