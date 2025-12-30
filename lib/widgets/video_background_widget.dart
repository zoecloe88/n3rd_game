import 'dart:async';
import 'package:n3rd_game/utils/unawaited_helper.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/widgets/background_image_widget.dart';
import 'package:n3rd_game/services/video_cache_service.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/services/accessibility_service.dart';
import 'package:n3rd_game/config/app_config.dart';

/// Simple video background widget for MP4 backgrounds
/// Uses BoxFit.cover (equivalent to CSS object-fit: cover) to fill screen
/// Videos should be 1080x1920px (9:16 aspect ratio) for optimal responsiveness
/// This ensures the video fills the screen properly on all devices without distortion
class VideoBackgroundWidget extends StatefulWidget {

  const VideoBackgroundWidget({
    super.key,
    required this.videoPath,
    required this.child,
    this.fit = BoxFit.cover, // CSS object-fit: cover equivalent
    this.alignment = Alignment.center,
    this.loop = true,
    this.autoplay = true,
    this.onVideoCompleted,
  });
  final String videoPath;
  final Widget child;
  final BoxFit fit;
  final Alignment alignment;
  final bool loop;
  final bool autoplay;
  final VoidCallback? onVideoCompleted;

  @override
  State<VideoBackgroundWidget> createState() => _VideoBackgroundWidgetState();
}

class _VideoBackgroundWidgetState extends State<VideoBackgroundWidget>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _hasCalledCompletion = false;
  Timer? _completionCheckTimer;
  Timer?
      _fallbackTimer; // Timer for fallback completion callback (replaces Future.delayed for proper cancellation)
  Timer?
      _retryTimer; // Timer for retry delay (replaces Future.delayed for proper cancellation)
  Timer? _maxWaitTimer; // Maximum wait timeout to prevent indefinite waiting
  DateTime?
      _videoInitStartTime; // Track video initialization start time for analytics

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeVideo();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Pause video when app goes to background
      _controller?.pause();
    } else if (state == AppLifecycleState.resumed) {
      // Resume video when app comes to foreground (if autoplay was enabled)
      if (widget.autoplay && !widget.loop) {
        // For non-looping videos, only resume if not at end
        if (_controller!.value.position < _controller!.value.duration) {
          _controller?.play();
        }
      } else if (widget.autoplay) {
        _controller?.play();
      }
    }
  }

  Future<void> _initializeVideo({int retryCount = 0}) async {
    if (!mounted) return;

    // Early exit if video path is invalid
    if (widget.videoPath.isEmpty) {
      LoggerService.warning('VideoBackgroundWidget: Empty video path provided');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isInitialized = false;
        });
      }
      return;
    }

    // Track initialization start time for analytics
    if (retryCount == 0) {
      _videoInitStartTime = DateTime.now();
    }

    try {
      // Try to get cached controller first
      final cacheService = VideoCacheService();
      VideoPlayerController? controller =
          cacheService.getCachedController(widget.videoPath);

      if (controller == null) {
        // Not cached - create new controller
        // Handle special characters in path (like colon in logo:loadingscreen.mp4)
        controller = VideoPlayerController.asset(widget.videoPath);
        // Use AppConfig timeout for better device compatibility
        await controller.initialize().timeout(
          AppConfig.videoInitializationTimeout,
          onTimeout: () {
            throw TimeoutException(
                'Video initialization timed out after ${AppConfig.videoInitializationTimeout.inSeconds} seconds',);
          },
        );

        if (!mounted) {
          unawaited(controller.dispose());
          return;
        }
      } else {
        // Cached controller found - verify it's still valid and initialized
        try {
          // Validate controller state before reuse
          if (!controller.value.isInitialized) {
            // Controller exists but not initialized - create new one
            // Don't dispose cached controller, let cache service manage it
            controller = VideoPlayerController.asset(widget.videoPath);
            await controller.initialize().timeout(
              AppConfig.videoInitializationTimeout,
              onTimeout: () {
                throw TimeoutException('Video initialization timed out');
              },
            );

            if (!mounted) {
              unawaited(controller.dispose());
              return;
            }
          } else {
            // Cached controller is valid - check if we need to reset position
            // Only seek to start if video is not looping or if we need to restart
            if (widget.autoplay) {
              // Only seek if video is at the end (for looping videos, this is unnecessary)
              if (!widget.loop &&
                  controller.value.position >= controller.value.duration) {
                await controller.seekTo(Duration.zero);
              } else if (controller.value.position >
                  const Duration(milliseconds: 100)) {
                // Video is in middle - only reset if not looping
                if (!widget.loop) {
                  await controller.seekTo(Duration.zero);
                }
              }
            }
          }
        } catch (e) {
          // Cached controller was disposed or invalid - create new one
          LoggerService.debug(
              'Cached controller invalid, creating new one: ${widget.videoPath}',);
          controller = VideoPlayerController.asset(widget.videoPath);
          await controller.initialize().timeout(
            AppConfig.videoInitializationTimeout,
            onTimeout: () {
              throw TimeoutException('Video initialization timed out');
            },
          );

          if (!mounted) {
            unawaited(controller.dispose());
            return;
          }
        }
      }

      unawaited(controller.setLooping(widget.loop));

      if (mounted) {
        setState(() {
          _controller = controller;
          _isInitialized = true;
          _hasError = false;
        });

        // Start playing if autoplay is enabled
        if (widget.autoplay) {
          // Only seek to start if controller was newly created (not cached)
          // Cached controllers already have their position managed above
          final wasCached =
              cacheService.getCachedController(widget.videoPath) == controller;
          if (!wasCached) {
            await controller.seekTo(Duration.zero);
          }
          await controller.play();
        }

        // Add listener for video completion if not looping and callback provided
        if (!widget.loop && widget.onVideoCompleted != null) {
          // Maximum wait timeout to prevent indefinite waiting
          _maxWaitTimer = Timer(AppConfig.videoMaxWaitDuration, () {
            if (mounted && !_hasCalledCompletion) {
              _hasCalledCompletion = true;
              _completionCheckTimer?.cancel();
              _fallbackTimer?.cancel();
              // Log analytics for timeout usage
              _logVideoFallbackTimerUsed();
              widget.onVideoCompleted?.call();
            }
          });

          // Use a timer to periodically check for video completion
          _completionCheckTimer =
              Timer.periodic(const Duration(milliseconds: 100), (timer) {
            if (!mounted || _hasCalledCompletion) {
              timer.cancel();
              return;
            }
            _checkVideoCompletion();
          });

          // Also check immediately in case video is already at end
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _controller != null) {
              _checkVideoCompletion();
            }
          });
        }
      }
    } catch (e) {
      // Log error for debugging with enhanced error messages
      String errorMessage = e.toString();
      String errorType = 'unknown';

      // Identify common error types for better recovery
      if (e is TimeoutException) {
        errorType = 'timeout';
        errorMessage =
            'Video initialization timed out after ${AppConfig.videoInitializationTimeout.inSeconds} seconds';
      } else if (e.toString().contains('Unable to load asset') ||
          e.toString().contains('Asset not found')) {
        errorType = 'file_not_found';
        errorMessage = 'Video file not found: ${widget.videoPath}';
      } else if (e.toString().contains('codec') ||
          e.toString().contains('format')) {
        errorType = 'codec_error';
        errorMessage = 'Video codec or format not supported';
      } else if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        errorType = 'network_error';
        errorMessage = 'Network error while loading video';
      }

      LoggerService.warning(
        'VideoBackgroundWidget: Failed to load video ${widget.videoPath} (type: $errorType);',
        error: e,
      );

      // Track video load failure with error type
      _logVideoLoadFailure('$errorType: $errorMessage');

      // Retry logic for failed video loads
      if (retryCount < AppConfig.maxVideoRetries && mounted) {
        LoggerService.debug(
            'Retrying video load (attempt ${retryCount + 1}/${AppConfig.maxVideoRetries});',);
        // Use a cancelable Timer instead of Future.delayed for better test cleanup
        final completer = Completer<void>();
        _retryTimer?.cancel(); // Cancel any existing retry timer
        if (mounted) {
          final retryDelay = Duration(
            milliseconds:
                AppConfig.videoRetryDelayBase.inMilliseconds * (retryCount + 1),
          );
          _retryTimer = Timer(retryDelay, () {
            if (mounted && !completer.isCompleted) {
              completer.complete();
            }
          });
          await completer.future;
          if (mounted) {
            return _initializeVideo(retryCount: retryCount + 1);
          }
        }
      }

      // Track retry success if we're retrying
      if (retryCount > 0) {
        _logVideoRetrySuccess(retryCount);
      }

      if (mounted) {
        setState(() {
          _hasError = true;
          _isInitialized = false;
        });
        // If video fails and we have a completion callback, call it after a delay
        // This ensures navigation still happens even if video fails
        // Use Timer instead of Future.delayed for proper cancellation
        if (mounted && widget.onVideoCompleted != null && !widget.loop) {
          _fallbackTimer?.cancel(); // Cancel any existing fallback timer
          _maxWaitTimer
              ?.cancel(); // Cancel max wait timer since we're using fallback
          // Only create timer if still mounted
          if (mounted) {
            _fallbackTimer = Timer(AppConfig.videoFallbackTimerDuration, () {
              if (mounted && !_hasCalledCompletion) {
                _hasCalledCompletion = true;
                _logVideoFallbackTimerUsed();
                widget.onVideoCompleted?.call();
              }
            });
          }
        }
      }
    }
  }

  void _checkVideoCompletion() {
    final controller = _controller;
    if (controller != null &&
        controller.value.isInitialized &&
        controller.value.duration.inMilliseconds > 0 &&
        controller.value.position.inMilliseconds >=
            controller.value.duration.inMilliseconds -
                100 && // Allow 100ms tolerance
        !_hasCalledCompletion) {
      _hasCalledCompletion = true;
      _completionCheckTimer?.cancel();
      _maxWaitTimer
          ?.cancel(); // Cancel max wait timer since video completed normally
      _fallbackTimer?.cancel(); // Cancel fallback timer if it exists

      // Track video completion with timing analytics
      if (_videoInitStartTime != null) {
        final actualDuration = DateTime.now().difference(_videoInitStartTime!);
        final expectedDuration =
            Duration(milliseconds: controller.value.duration.inMilliseconds);
        final difference =
            (actualDuration.inMilliseconds - expectedDuration.inMilliseconds)
                .abs();
        _logVideoCompletion(expectedDuration.inMilliseconds,
            actualDuration.inMilliseconds, difference,);
      }

      widget.onVideoCompleted?.call();
    }
  }

  /// Log video load failure (non-blocking)
  void _logVideoLoadFailure(String error) {
    try {
      final analytics = Provider.of<AnalyticsService>(context, listen: false);
      analytics.logVideoLoadFailure(widget.videoPath, error);
    } catch (e) {
      // Analytics not available - non-critical, continue
      LoggerService.debug('Analytics not available for video load failure', error: e);
    }
  }

  /// Log video retry success (non-blocking)
  void _logVideoRetrySuccess(int retryCount) {
    try {
      final analytics = Provider.of<AnalyticsService>(context, listen: false);
      analytics.logVideoRetrySuccess(widget.videoPath, retryCount);
    } catch (e) {
      // Analytics not available - non-critical, continue
      LoggerService.debug(
          'Analytics not available for video retry success: $e',);
    }
  }

  /// Log video completion with timing (non-blocking)
  void _logVideoCompletion(
      int expectedDurationMs, int actualDurationMs, int differenceMs,) {
    try {
      final analytics = Provider.of<AnalyticsService>(context, listen: false);
      analytics.logVideoCompletion(
        widget.videoPath,
        expectedDurationMs,
        actualDurationMs,
        differenceMs,
      );
    } catch (e) {
      // Analytics not available - non-critical, continue
      LoggerService.debug('Analytics not available for video completion', error: e);
    }
  }

  /// Log fallback timer usage (non-blocking)
  void _logVideoFallbackTimerUsed() {
    try {
      final analytics = Provider.of<AnalyticsService>(context, listen: false);
      analytics.logVideoFallbackTimerUsed(widget.videoPath);
    } catch (e) {
      // Analytics not available - non-critical, continue
      LoggerService.debug('Analytics not available for fallback timer', error: e);
    }
  }

  /// Check if video should be shown based on accessibility settings
  /// Respects system "Reduce Motion" setting and app-level accessibility preferences
  bool _shouldShowVideo(BuildContext context) {
    // Check system-level "Reduce Motion" setting
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery?.disableAnimations ?? false) {
      return false;
    }

    // Check app-level accessibility settings
    try {
      final accessibilityService =
          Provider.of<AccessibilityService>(context, listen: false);
      final settings = accessibilityService.settings;

      // Don't show video if user has disabled background videos
      if (settings.disableBackgroundVideos) {
        return false;
      }

      // Don't show video if user prefers reduced motion
      if (settings.reducedMotion) {
        return false;
      }
    } catch (e) {
      // AccessibilityService not available - default to showing video
      // This maintains backward compatibility
      LoggerService.debug(
          'AccessibilityService not available, defaulting to show video: $e',);
    }

    return true;
  }

  @override
  void dispose() {
    _completionCheckTimer?.cancel();
    _fallbackTimer?.cancel(); // Cancel fallback timer
    _retryTimer?.cancel(); // Cancel retry timer
    _maxWaitTimer?.cancel(); // Cancel maximum wait timer
    _completionCheckTimer = null;
    _fallbackTimer = null;
    _retryTimer = null;
    _maxWaitTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    // Don't dispose cached controllers - VideoCacheService manages them
    // Only dispose if this controller is not cached
    final cacheService = VideoCacheService();
    if (_controller != null) {
      try {
        // Check if controller is cached before disposing
        final cachedController =
            cacheService.getCachedController(widget.videoPath);
        if (cachedController != _controller) {
          // Not cached, safe to dispose
          _controller?.dispose();
        }
      } catch (e) {
        // Controller already disposed or invalid - ignore
        LoggerService.debug(
            'Controller already disposed during cleanup: ${widget.videoPath}',);
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if video should be shown based on accessibility settings
    final shouldShowVideo = _shouldShowVideo(context);

    // Wrap entire background in Semantics to exclude from accessibility tree
    // Background videos and images are decorative and should not be announced
    return Semantics(
      excludeSemantics: true, // Hide decorative background from screen readers
      child: Stack(
        children: [
          // Show black background first (prevents white flash)
          const Positioned.fill(
            child: ColoredBox(color: Colors.black),
          ),

          // Video background - show only if motion is allowed and video is ready
          if (shouldShowVideo &&
              _isInitialized &&
              _controller != null &&
              !_hasError)
            // Video is loaded and ready - show video as primary background
            Positioned.fill(
              child: FittedBox(
                fit: widget.fit,
                alignment: widget.alignment,
                child: SizedBox(
                  width: _controller!.value.size.width > 0
                      ? _controller!.value.size.width
                      : 1,
                  height: _controller!.value.size.height > 0
                      ? _controller!.value.size.height
                      : 1,
                  child: VideoPlayer(_controller!),
                ),
              ),
            )
          else if (shouldShowVideo && !_isInitialized && !_hasError)
            // Show loading indicator while video initializes (only if motion allowed)
            const Positioned.fill(
              child: Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ),

          // Static background fallback when:
          // 1. Motion is disabled (accessibility preference)
          // 2. Video failed to load (error state)
          if (!shouldShowVideo || _hasError)
            const Positioned.fill(
              child: BackgroundImageWidget(
                imagePath: 'assets/background n3rd.png',
                child: SizedBox.shrink(),
              ),
            ),

          // Content on top
          widget.child,
        ],
      ),
    );
  }
}