import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:n3rd_game/models/trivia_item.dart';
import 'package:n3rd_game/services/logger_service.dart';

class OfflineService extends ChangeNotifier {
  static const String _storageKey = 'offline_packs';
  List<String> _downloadedPacks = [];
  bool _isInitialized = false;

  List<String> get downloadedPacks => _downloadedPacks;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    if (_isInitialized) return;

    await _loadDownloadedPacks();
    _isInitialized = true;
    notifyListeners();
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

      if (!await packsDir.exists()) {
        await packsDir.create(recursive: true);
      }

      final packFile = File('${packsDir.path}/$packId.json');
      final packData = {
        'packId': packId,
        'downloadedAt': DateTime.now().toIso8601String(),
        'items': triviaItems.map((item) => item.toJson()).toList(),
      };

      await packFile.writeAsString(jsonEncode(packData));

      if (!_downloadedPacks.contains(packId)) {
        _downloadedPacks.add(packId);
        await _saveDownloadedPacks();
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

      if (!await packFile.exists()) {
        return null;
      }

      final jsonString = await packFile.readAsString();
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

      if (await packFile.exists()) {
        await packFile.delete();
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

  /// Check if a pack is downloaded
  bool isPackDownloaded(String packId) {
    return _downloadedPacks.contains(packId);
  }

  /// Get total size of downloaded packs
  Future<int> getTotalSize() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final packsDir = Directory('${directory.path}/trivia_packs');

      if (!await packsDir.exists()) {
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

      if (await packsDir.exists()) {
        await packsDir.delete(recursive: true);
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

  @override
  void dispose() {
    // OfflineService uses SharedPreferences and File operations which don't require explicit cleanup
    // but dispose for consistency with other services
    super.dispose();
  }
}
