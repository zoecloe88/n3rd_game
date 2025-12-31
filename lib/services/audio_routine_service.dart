import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/services/sound_service.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'dart:convert';

/// Audio routine service for scheduling background audio playback
/// Supports routine templates (morning, focus, relaxation) and custom routines
class AudioRoutineService extends ChangeNotifier {

  AudioRoutineService(this._soundService);
  static const String _routinesKey = 'audio_routines';
  static const String _activeRoutineKey = 'active_audio_routine';

  final SoundService _soundService;
  Timer? _routineTimer;
  AudioRoutine? _activeRoutine;
  List<AudioRoutine> _routines = [];
  bool _isInitialized = false;

  List<AudioRoutine> get routines => List.unmodifiable(_routines);
  AudioRoutine? get activeRoutine => _activeRoutine;
  bool get isInitialized => _isInitialized;

  /// Initialize service and load routines
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await _loadRoutines();
      await _loadActiveRoutine();
      _isInitialized = true;
      notifyListeners();
      LoggerService.info('AudioRoutineService initialized');
    } catch (e) {
      LoggerService.error('Error initializing AudioRoutineService', error: e);
    }
  }

  /// Load routines from SharedPreferences
  Future<void> _loadRoutines() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final routinesJson = prefs.getString(_routinesKey);

      if (routinesJson != null) {
        final routinesList = (jsonDecode(routinesJson) as List)
            .map((item) => AudioRoutine.fromJson(item as Map<String, dynamic>))
            .toList();
        _routines = routinesList;
      } else {
        // Initialize with default templates
        _routines = _getDefaultRoutines();
        await _saveRoutines();
      }
    } catch (e) {
      LoggerService.warning('Failed to load routines', error: e);
      _routines = _getDefaultRoutines();
    }
  }

  /// Save routines to SharedPreferences
  Future<void> _saveRoutines() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final routinesJson = jsonEncode(
        _routines.map((r) => r.toJson()).toList(),
      );
      await prefs.setString(_routinesKey, routinesJson);
    } catch (e) {
      LoggerService.warning('Failed to save routines', error: e);
    }
  }

  /// Load active routine from SharedPreferences
  Future<void> _loadActiveRoutine() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeRoutineJson = prefs.getString(_activeRoutineKey);

      if (activeRoutineJson != null) {
        final routineData =
            jsonDecode(activeRoutineJson) as Map<String, dynamic>;
        final routineId = routineData['id'] as String;
        _activeRoutine = _routines.firstWhere(
          (r) => r.id == routineId,
          orElse: () => _getDefaultRoutines().first,
        );

        // Check if routine should be active now
        if (_activeRoutine != null && _activeRoutine!.isEnabled) {
          _scheduleRoutine(_activeRoutine!);
        }
      }
    } catch (e) {
      LoggerService.warning('Failed to load active routine', error: e);
    }
  }

  /// Save active routine to SharedPreferences
  Future<void> _saveActiveRoutine() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_activeRoutine != null) {
        final routineData = {
          'id': _activeRoutine!.id,
          'enabled': _activeRoutine!.isEnabled,
        };
        await prefs.setString(_activeRoutineKey, jsonEncode(routineData));
      } else {
        await prefs.remove(_activeRoutineKey);
      }
    } catch (e) {
      LoggerService.warning('Failed to save active routine', error: e);
    }
  }

  /// Get default routine templates
  List<AudioRoutine> _getDefaultRoutines() {
    return [
      AudioRoutine(
        id: 'morning',
        name: 'Morning Routine',
        description: 'Start your day with focus and energy',
        audioTrack: 'assets/audio/morning_routine.mp3',
        scheduledTime: const TimeOfDay(hour: 7, minute: 0),
        isEnabled: false,
        isTemplate: true,
      ),
      AudioRoutine(
        id: 'focus',
        name: 'Focus Mode',
        description: 'Deep work and concentration',
        audioTrack: 'assets/audio/focus_mode.mp3',
        scheduledTime: const TimeOfDay(hour: 9, minute: 0),
        isEnabled: false,
        isTemplate: true,
      ),
      AudioRoutine(
        id: 'relaxation',
        name: 'Relaxation',
        description: 'Wind down and relax',
        audioTrack: 'assets/audio/relaxation.mp3',
        scheduledTime: const TimeOfDay(hour: 20, minute: 0),
        isEnabled: false,
        isTemplate: true,
      ),
    ];
  }

  /// Create a custom routine
  Future<void> createRoutine({
    required String name,
    required String description,
    required String audioTrack,
    required TimeOfDay scheduledTime,
    bool isEnabled = false,
  }) async {
    final routine = AudioRoutine(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: description,
      audioTrack: audioTrack,
      scheduledTime: scheduledTime,
      isEnabled: isEnabled,
      isTemplate: false,
    );

    _routines.add(routine);
    await _saveRoutines();
    notifyListeners();
    LoggerService.info('Created routine: $name');
  }

  /// Update a routine
  Future<void> updateRoutine(AudioRoutine routine) async {
    final index = _routines.indexWhere((r) => r.id == routine.id);
    if (index != -1) {
      _routines[index] = routine;
      await _saveRoutines();

      // If this is the active routine, reschedule it
      if (_activeRoutine?.id == routine.id) {
        _activeRoutine = routine;
        await _saveActiveRoutine();
        _scheduleRoutine(routine);
      }

      notifyListeners();
      LoggerService.info('Updated routine: ${routine.name}');
    }
  }

  /// Delete a routine
  Future<void> deleteRoutine(String routineId) async {
    _routines.removeWhere((r) => r.id == routineId);
    await _saveRoutines();

    // If deleted routine was active, clear active routine
    if (_activeRoutine?.id == routineId) {
      _activeRoutine = null;
      await _saveActiveRoutine();
      _routineTimer?.cancel();
      _routineTimer = null;
    }

    notifyListeners();
    LoggerService.info('Deleted routine: $routineId');
  }

  /// Enable/disable a routine
  Future<void> setRoutineEnabled(String routineId, bool enabled) async {
    final routine = _routines.firstWhere(
      (r) => r.id == routineId,
      orElse: () => throw Exception('Routine not found'),
    );

    final updatedRoutine = routine.copyWith(isEnabled: enabled);
    await updateRoutine(updatedRoutine);
  }

  /// Set active routine
  Future<void> setActiveRoutine(String? routineId) async {
    if (routineId == null) {
      _activeRoutine = null;
      _routineTimer?.cancel();
      _routineTimer = null;
      await _saveActiveRoutine();
      notifyListeners();
      return;
    }

    final routine = _routines.firstWhere(
      (r) => r.id == routineId,
      orElse: () => throw Exception('Routine not found'),
    );

    _activeRoutine = routine;
    await _saveActiveRoutine();

    if (routine.isEnabled) {
      _scheduleRoutine(routine);
    }

    notifyListeners();
    LoggerService.info('Set active routine: ${routine.name}');
  }

  /// Schedule routine playback
  void _scheduleRoutine(AudioRoutine routine) {
    _routineTimer?.cancel();

    if (!routine.isEnabled) {
      return;
    }

    final now = DateTime.now();
    final scheduledTime = TimeOfDay(
      hour: routine.scheduledTime.hour,
      minute: routine.scheduledTime.minute,
    );

    final scheduledDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      scheduledTime.hour,
      scheduledTime.minute,
    );

    // If scheduled time has passed today, schedule for tomorrow
    final targetTime = scheduledDateTime.isBefore(now)
        ? scheduledDateTime.add(const Duration(days: 1))
        : scheduledDateTime;

    final durationUntilRoutine = targetTime.difference(now);

    _routineTimer = Timer(durationUntilRoutine, () {
      _playRoutine(routine);
      // Schedule next occurrence
      if (routine.isEnabled) {
        _scheduleRoutine(routine);
      }
    });

    LoggerService.debug(
      'Scheduled routine "${routine.name}" for ${targetTime.toString()}',
    );
  }

  /// Play routine audio
  Future<void> _playRoutine(AudioRoutine routine) async {
    try {
      LoggerService.info('Playing routine: ${routine.name}');

      // Play audio track using SoundService
      // Note: This assumes SoundService has a method to play background audio
      // You may need to add this method to SoundService if it doesn't exist
      await _soundService.playBackgroundMusic(routine.audioTrack);

      notifyListeners();
    } catch (e) {
      LoggerService.error('Error playing routine audio', error: e);
    }
  }

  /// Stop active routine
  Future<void> stopRoutine() async {
    _routineTimer?.cancel();
    _routineTimer = null;
    await _soundService.stopBackgroundMusic();
    notifyListeners();
  }

  @override
  void dispose() {
    _routineTimer?.cancel();
    super.dispose();
  }
}

/// Audio routine model
class AudioRoutine {

  AudioRoutine({
    required this.id,
    required this.name,
    required this.description,
    required this.audioTrack,
    required this.scheduledTime,
    required this.isEnabled,
    required this.isTemplate,
  });

  factory AudioRoutine.fromJson(Map<String, dynamic> json) => AudioRoutine(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        audioTrack: json['audioTrack'] as String,
        scheduledTime: TimeOfDay(
          hour: json['scheduledHour'] as int,
          minute: json['scheduledMinute'] as int,
        ),
        isEnabled: json['isEnabled'] as bool? ?? false,
        isTemplate: json['isTemplate'] as bool? ?? false,
      );
  final String id;
  final String name;
  final String description;
  final String audioTrack;
  final TimeOfDay scheduledTime;
  final bool isEnabled;
  final bool isTemplate;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'audioTrack': audioTrack,
        'scheduledHour': scheduledTime.hour,
        'scheduledMinute': scheduledTime.minute,
        'isEnabled': isEnabled,
        'isTemplate': isTemplate,
      };

  AudioRoutine copyWith({
    String? id,
    String? name,
    String? description,
    String? audioTrack,
    TimeOfDay? scheduledTime,
    bool? isEnabled,
    bool? isTemplate,
  }) {
    return AudioRoutine(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      audioTrack: audioTrack ?? this.audioTrack,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      isEnabled: isEnabled ?? this.isEnabled,
      isTemplate: isTemplate ?? this.isTemplate,
    );
  }
}
