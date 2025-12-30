import 'dart:async';
import 'package:n3rd_game/utils/unawaited_helper.dart';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Sound service for managing game audio effects and background music
/// Maintains the app's clean aesthetic with subtle, professional sound design
/// Uses file-based sounds for effects with SystemSound fallback
/// Uses audioplayers for background music tracks and sound effects
class SoundService extends ChangeNotifier {
  static const String _soundEnabledKey = 'sound_enabled';
  static const String _soundVolumeKey = 'sound_volume';
  static const String _musicEnabledKey = 'music_enabled';
  static const String _musicVolumeKey = 'music_volume';

  bool _soundEnabled = true;
  double _soundVolume = 1.0; // 0.0 to 1.0
  bool _musicEnabled = false;
  double _musicVolume = 0.5; // 0.0 to 1.0

  // Background music player
  final AudioPlayer _musicPlayer = AudioPlayer();
  String? _currentMusicTrack;
  bool _isMusicPlaying = false;
  StreamSubscription<PlayerState>? _musicStateSubscription;

  // Sound effect players - pool for concurrent playback
  final List<AudioPlayer> _effectPool = [];
  static const int _maxConcurrentEffects = 5;
  final Random _random = Random();

  // Track temporary players created when pool is exhausted (for proper disposal)
  final List<AudioPlayer> _temporaryPlayers = [];

  // Track StreamSubscriptions for temporary players to prevent memory leaks
  final Map<AudioPlayer, StreamSubscription> _tempPlayerSubscriptions = {};

  // Sound mapping: maps sound type to available sound file prefixes
  // Each prefix can have multiple variants (e.g., laserSmall_000, laserSmall_001)
  static const Map<String, List<String>> _soundMapping = {
    'correct': ['laserSmall'],
    'wrong': ['lowFrequency_explosion', 'explosionCrunch'],
    'perfect': ['laserLarge', 'forceField'],
    'partial': ['laserRetro'],
    'click': ['impactMetal', 'computerNoise'],
    'game_over': ['explosionCrunch'],
    'round_start': ['doorOpen', 'computerNoise'],
    'time_up': ['forceField', 'lowFrequency_explosion'],
  };

  bool get soundEnabled => _soundEnabled;
  double get soundVolume => _soundVolume;
  bool get musicEnabled => _musicEnabled;
  double get musicVolume => _musicVolume;
  bool get isMusicPlaying => _isMusicPlaying;
  String? get currentMusicTrack => _currentMusicTrack;

  // Sound effect types
  static const String soundCorrect = 'correct';
  static const String soundWrong = 'wrong';
  static const String soundPerfect = 'perfect';
  static const String soundPartial = 'partial';
  static const String soundClick = 'click';
  static const String soundGameOver = 'game_over';
  static const String soundRoundStart = 'round_start';
  static const String soundTimeUp = 'time_up';

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _soundEnabled = prefs.getBool(_soundEnabledKey) ?? true;
      _soundVolume = prefs.getDouble(_soundVolumeKey) ?? 1.0;
      _musicEnabled = prefs.getBool(_musicEnabledKey) ?? false;
      _musicVolume = prefs.getDouble(_musicVolumeKey) ?? 0.5;

      // Configure music player
      await _musicPlayer
          .setReleaseMode(ReleaseMode.loop); // Loop background music
      await _musicPlayer.setVolume(_musicVolume);

      // Listen to music player state changes
      _musicStateSubscription =
          _musicPlayer.onPlayerStateChanged.listen((state) {
        _isMusicPlaying = state == PlayerState.playing;
        notifyListeners();
      });

      // Initialize sound effect pool
      for (int i = 0; i < _maxConcurrentEffects; i++) {
        final player = AudioPlayer();
        await player
            .setReleaseMode(ReleaseMode.release); // Don't loop sound effects
        _effectPool.add(player);
      }

      notifyListeners();
    } catch (e) {
      LoggerService.error('Error initializing sound service', error: e);
    }
  }

  /// Get available sound file variants for a given prefix
  /// Returns list of available file paths (e.g., ['laserSmall_000.ogg', 'laserSmall_001.ogg'])
  List<String> _getAvailableVariants(String prefix) {
    final variants = <String>[];
    // Check for variants _000 through _004 (max variants in Kenney pack)
    for (int i = 0; i <= 4; i++) {
      final fileName = '${prefix}_${i.toString().padLeft(3, '0')}.ogg';
      final assetPath = 'assets/audio/effects/$fileName';
      variants.add(assetPath);
    }
    return variants;
  }

  /// Select a random sound file from available mappings
  /// Returns the asset path or null if no sound found
  String? _selectSoundFile(String soundType) {
    final mappings = _soundMapping[soundType];
    if (mappings == null || mappings.isEmpty) return null;

    // Select random prefix from available mappings
    final selectedPrefix = mappings[_random.nextInt(mappings.length)];

    // Get all available variants for this prefix
    final variants = _getAvailableVariants(selectedPrefix);

    // Randomly select a variant (tries _000 through _004)
    // We'll handle missing files gracefully when playing
    if (variants.isEmpty) return null;

    // Select random variant number (0-4)
    final variantIndex = _random.nextInt(variants.length);
    return variants[variantIndex];
  }

  /// Get an available player from the pool or create a temporary one
  AudioPlayer _getAvailablePlayer() {
    // Try to find an idle player
    for (final player in _effectPool) {
      if (player.state != PlayerState.playing) {
        return player;
      }
    }
    // All players busy - create temporary player and track for disposal
    final tempPlayer = AudioPlayer();
    _temporaryPlayers.add(tempPlayer);

    // Auto-dispose when player completes to prevent memory leaks
    // Track subscription for proper cleanup
    late final StreamSubscription subscription;
    subscription = tempPlayer.onPlayerComplete.listen((_) {
      subscription.cancel();
      _temporaryPlayers.remove(tempPlayer);
      _tempPlayerSubscriptions.remove(tempPlayer);
      tempPlayer.dispose();
    });
    _tempPlayerSubscriptions[tempPlayer] = subscription;

    return tempPlayer;
  }

  /// Play a sound effect using file-based sounds with SystemSound fallback
  /// Uses AudioPlayer for professional sci-fi sounds with graceful degradation
  Future<void> playSound(String soundType) async {
    if (!_soundEnabled) return;

    try {
      // Try to play file-based sound first
      final soundPath = _selectSoundFile(soundType);
      if (soundPath != null) {
        try {
          final player = _getAvailablePlayer();
          await player.setVolume(_soundVolume);
          await player.play(AssetSource(soundPath));

          // For perfect score, play second sound for emphasis
          if (soundType == soundPerfect) {
            await Future.delayed(const Duration(milliseconds: 100));
            final secondPath = _selectSoundFile(soundPerfect);
            if (secondPath != null) {
              try {
                final secondPlayer = _getAvailablePlayer();
                await secondPlayer.setVolume(_soundVolume);
                await secondPlayer.play(AssetSource(secondPath));
              } catch (e) {
                // Fall through to SystemSound fallback
                LoggerService.error('Error playing second perfect sound', error: e);
              }
            }
          }

          // Sound played successfully, return
          return;
        } catch (e) {
          // File-based sound failed, fall back to SystemSound
          debugPrint(
              'Error playing file-based sound ($soundPath): $e, falling back to SystemSound',);
        }
      }

      // Fallback to SystemSound for robustness
      switch (soundType) {
        case soundClick:
          unawaited(SystemSound.play(SystemSoundType.click));
          break;
        case soundCorrect:
        case soundPartial:
          unawaited(SystemSound.play(SystemSoundType.alert));
          break;
        case soundPerfect:
          // Play alert twice for emphasis on perfect score
          unawaited(SystemSound.play(SystemSoundType.alert));
          await Future.delayed(const Duration(milliseconds: 100));
          unawaited(SystemSound.play(SystemSoundType.alert));
          break;
        case soundWrong:
        case soundGameOver:
          unawaited(SystemSound.play(SystemSoundType.alert));
          break;
        case soundRoundStart:
        case soundTimeUp:
          unawaited(SystemSound.play(SystemSoundType.alert));
          break;
        default:
          unawaited(SystemSound.play(SystemSoundType.click));
      }
    } catch (e) {
      LoggerService.error('Error playing sound', error: e);
    }
  }

  /// Toggle sound on/off
  Future<void> toggleSound() async {
    _soundEnabled = !_soundEnabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_soundEnabledKey, _soundEnabled);
      notifyListeners();
    } catch (e) {
      LoggerService.error('Error saving sound preference', error: e);
    }
  }

  /// Set sound enabled state
  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_soundEnabledKey, _soundEnabled);
      notifyListeners();
    } catch (e) {
      LoggerService.error('Error saving sound enabled', error: e);
    }
  }

  /// Set sound volume (0.0 to 1.0)
  Future<void> setSoundVolume(double volume) async {
    _soundVolume = volume.clamp(0.0, 1.0);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_soundVolumeKey, _soundVolume);
      // Update volume on all effect players in pool
      for (final player in _effectPool) {
        await player.setVolume(_soundVolume);
      }
      notifyListeners();
    } catch (e) {
      LoggerService.error('Error saving sound volume', error: e);
    }
  }

  /// Set music enabled state
  Future<void> setMusicEnabled(bool enabled) async {
    _musicEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_musicEnabledKey, _musicEnabled);
      notifyListeners();
    } catch (e) {
      LoggerService.error('Error saving music enabled', error: e);
    }
  }

  /// Set music volume (0.0 to 1.0)
  Future<void> setMusicVolume(double volume) async {
    _musicVolume = volume.clamp(0.0, 1.0);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_musicVolumeKey, _musicVolume);
      // Update music player volume if playing
      await _musicPlayer.setVolume(_musicVolume);
      notifyListeners();
    } catch (e) {
      LoggerService.error('Error saving music volume', error: e);
    }
  }

  /// Set music enabled state (also stops/starts music accordingly)
  Future<void> setMusicEnabledWithPlayback(bool enabled) async {
    _musicEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_musicEnabledKey, _musicEnabled);
      if (!enabled) {
        await stopBackgroundMusic();
      }
      notifyListeners();
    } catch (e) {
      LoggerService.error('Error saving music enabled', error: e);
    }
  }

  /// Play correct answer sound
  Future<void> playCorrect() => playSound(soundCorrect);

  /// Play wrong answer sound
  Future<void> playWrong() => playSound(soundWrong);

  /// Play perfect score sound (3/3 correct)
  Future<void> playPerfect() => playSound(soundPerfect);

  /// Play partial correct sound (1-2/3 correct)
  Future<void> playPartial() => playSound(soundPartial);

  /// Play click/tap sound
  Future<void> playClick() => playSound(soundClick);

  /// Play game over sound
  Future<void> playGameOver() => playSound(soundGameOver);

  /// Play round start sound
  Future<void> playRoundStart() => playSound(soundRoundStart);

  /// Play time up sound
  Future<void> playTimeUp() => playSound(soundTimeUp);

  /// Play background music track
  /// [trackPath] should be a path to an audio asset (e.g., 'assets/audio/game_music.mp3')
  /// Returns true if music started successfully, false otherwise
  Future<bool> playBackgroundMusic(String trackPath) async {
    if (!_musicEnabled) return false;
    if (_currentMusicTrack == trackPath && _isMusicPlaying) {
      // Already playing this track
      return true;
    }

    try {
      // Stop current music if playing different track
      if (_currentMusicTrack != null && _currentMusicTrack != trackPath) {
        await stopBackgroundMusic();
      }

      _currentMusicTrack = trackPath;
      await _musicPlayer.setVolume(_musicVolume);
      await _musicPlayer.play(AssetSource(trackPath));
      _isMusicPlaying = true;
      notifyListeners();
      return true;
    } catch (e) {
      LoggerService.error('Error playing background music', error: e);
      _currentMusicTrack = null;
      _isMusicPlaying = false;
      notifyListeners();
      return false;
    }
  }

  /// Stop background music
  Future<void> stopBackgroundMusic() async {
    try {
      await _musicPlayer.stop();
      _isMusicPlaying = false;
      _currentMusicTrack = null;
      notifyListeners();
    } catch (e) {
      LoggerService.error('Error stopping background music', error: e);
    }
  }

  /// Pause background music (can be resumed)
  Future<void> pauseBackgroundMusic() async {
    try {
      if (_isMusicPlaying) {
        await _musicPlayer.pause();
        _isMusicPlaying = false;
        notifyListeners();
      }
    } catch (e) {
      LoggerService.error('Error pausing background music', error: e);
    }
  }

  /// Resume paused background music
  Future<void> resumeBackgroundMusic() async {
    if (!_musicEnabled || _currentMusicTrack == null) return;

    try {
      await _musicPlayer.resume();
      _isMusicPlaying = true;
      notifyListeners();
    } catch (e) {
      LoggerService.error('Error resuming background music', error: e);
    }
  }

  /// Set background music for specific game mode or theme
  /// Maps game modes/themes to appropriate background tracks using available sci-fi sounds
  Future<bool> playMusicForMode(String modeOrTheme) async {
    if (!_musicEnabled) return false;

    // Map modes/themes to background music tracks using available engine/space sounds
    // Uses looping engine sounds for ambient background music
    final trackMap = <String, String>{
      // Game mode tracks - use space engine sounds for ambient background
      'classic': 'assets/audio/effects/spaceEngineLow_000.ogg',
      'speed': 'assets/audio/effects/spaceEngineSmall_000.ogg',
      'timeAttack': 'assets/audio/effects/spaceEngine_000.ogg',
      'practice': 'assets/audio/effects/spaceEngineLow_001.ogg',
      'blitz': 'assets/audio/effects/spaceEngineSmall_001.ogg',
      'challenge': 'assets/audio/effects/spaceEngine_001.ogg',
      'streak': 'assets/audio/effects/spaceEngineLow_002.ogg',

      // Theme tracks - can use different engine sounds for variety
      'geography': 'assets/audio/effects/engineCircular_000.ogg',
      'science': 'assets/audio/effects/spaceEngine_002.ogg',
      'arts': 'assets/audio/effects/engineCircular_001.ogg',
      'sports': 'assets/audio/effects/thrusterFire_000.ogg',
      'history': 'assets/audio/effects/spaceEngineLow_003.ogg',
    };

    final trackPath =
        trackMap[modeOrTheme.toLowerCase()] ?? trackMap['classic'];
    if (trackPath != null) {
      return playBackgroundMusic(trackPath);
    }

    return false;
  }

  /// Handle app lifecycle changes (pause/resume music on backgrounding)
  Future<void> handleAppLifecycleChange(AppLifecycleState state) async {
    if (!_musicEnabled) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // Pause music when app goes to background
        await pauseBackgroundMusic();
        break;
      case AppLifecycleState.resumed:
        // Resume music when app comes to foreground
        if (_currentMusicTrack != null) {
          await resumeBackgroundMusic();
        }
        break;
      case AppLifecycleState.detached:
        // Stop music when app is detached
        await stopBackgroundMusic();
        break;
      case AppLifecycleState.hidden:
        // Pause music when app is hidden
        await pauseBackgroundMusic();
        break;
    }
  }

  /// Dispose of the service and clean up resources
  @override
  void dispose() {
    _musicStateSubscription?.cancel();
    _musicPlayer.dispose();
    // Dispose all effect players from pool
    for (final player in _effectPool) {
      player.dispose();
    }
    _effectPool.clear();
    // Cancel all temporary player subscriptions first to prevent leaks
    for (final subscription in _tempPlayerSubscriptions.values) {
      subscription.cancel();
    }
    _tempPlayerSubscriptions.clear();
    // Dispose all temporary players to prevent memory leaks
    for (final player in _temporaryPlayers) {
      player.dispose();
    }
    _temporaryPlayers.clear();
    super.dispose();
  }
}