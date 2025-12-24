import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:n3rd_game/utils/video_path_helper.dart';
import 'package:n3rd_game/services/analytics_service.dart';

/// A reusable video player widget that handles initialization and disposal
///
/// Automatically selects the appropriate video variant (standard/tall/extra_tall)
/// based on device aspect ratio to ensure perfect fit without cropping or letterboxing.
class VideoPlayerWidget extends StatefulWidget {
  final String videoPath;
  final bool loop;
  final bool autoplay;
  final VoidCallback? onVideoComplete;
  final BoxFit fit; // Add fit parameter for icon-sized animations

  const VideoPlayerWidget({
    super.key,
    required this.videoPath,
    this.loop = true,
    this.autoplay = true,
    this.onVideoComplete,
    this.fit = BoxFit.cover, // Default to cover for full-screen videos
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  int _retryCount = 0;
  static const int _maxRetries = 2;
  bool _hasCalledCompletion = false;
  DateTime? _videoStartTime; // Track when video started playing
  Duration? _expectedDuration; // Track expected video duration for analytics

  @override
  void initState() {
    super.initState();
    // Initialize after first frame to access MediaQuery context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeVideo();
      }
    });
  }

  Future<void> _initializeVideo() async {
    if (!mounted) return;

    // Get the appropriate video path based on device aspect ratio
    String actualPath;
    try {
      actualPath = VideoPathHelper.getVideoPath(context, widget.videoPath);
    } catch (e) {
      // Fallback to base path if helper fails
      actualPath = widget.videoPath;
    }

    try {
      final controller = VideoPlayerController.asset(actualPath);
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }

      // Only set controller if still mounted
      _controller = controller;
      _controller!.setLooping(widget.loop);

      // Store expected duration for analytics
      _expectedDuration = controller.value.duration;

      // Add listener for video completion (only if not looping and callback provided)
      if (!widget.loop && widget.onVideoComplete != null) {
        _controller!.addListener(_checkVideoCompletion);
      }

      if (widget.autoplay) {
        _videoStartTime = DateTime.now(); // Track start time
        _controller!.play();
      }
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      // Log error for debugging
      if (kDebugMode) {
        debugPrint(
          'VideoPlayerWidget: Failed to load video at $actualPath: $e',
        );
      }

      // Track video load failure in analytics
      try {
        final context = this.context;
        if (context.mounted) {
          final analyticsService = Provider.of<AnalyticsService>(
            context,
            listen: false,
          );
          analyticsService.logVideoLoadFailure(actualPath, e.toString());
        }
      } catch (analyticsError) {
        // Ignore analytics errors
        if (kDebugMode) {
          debugPrint('Failed to log video error to analytics: $analyticsError');
        }
      }

      // If variant doesn't exist, try fallback to base path
      if (actualPath != widget.videoPath) {
        try {
          if (kDebugMode) {
            debugPrint(
              'VideoPlayerWidget: Trying fallback path: ${widget.videoPath}',
            );
          }

          final controller = VideoPlayerController.asset(widget.videoPath);
          await controller.initialize();
          if (!mounted) {
            controller.dispose();
            return;
          }

          // Dispose old controller if it exists
          final oldController = _controller;
          _controller = controller;
          oldController?.removeListener(_checkVideoCompletion);
          oldController?.dispose();

          _controller!.setLooping(widget.loop);

          // Store expected duration for analytics
          _expectedDuration = controller.value.duration;

          // Add listener for video completion (only if not looping and callback provided)
          if (!widget.loop && widget.onVideoComplete != null) {
            _controller!.addListener(_checkVideoCompletion);
          }

          if (widget.autoplay) {
            _videoStartTime = DateTime.now(); // Track start time
            _controller!.play();
          }
          if (mounted) {
            setState(() {
              _isInitialized = true;
            });
          }
        } catch (fallbackError) {
          // Video failed to load - mark as failed but show fallback UI
          if (kDebugMode) {
            debugPrint(
              'VideoPlayerWidget: Fallback also failed: $fallbackError',
            );
          }

          // Track fallback failure in analytics
          try {
            final context = this.context;
            if (context.mounted) {
              final analyticsService = Provider.of<AnalyticsService>(
                context,
                listen: false,
              );
              analyticsService.logVideoLoadFailure(
                '${widget.videoPath} (fallback)',
                fallbackError.toString(),
              );
            }
          } catch (analyticsError) {
            // Ignore analytics errors
            if (kDebugMode) {
              debugPrint(
                'Failed to log video error to analytics: $analyticsError',
              );
            }
          }

          if (mounted) {
            setState(() {
              _isInitialized = false;
              _hasError = true;
            });
          }
        }
      } else {
        // Video failed to load - mark as failed but show fallback UI
        if (mounted) {
          setState(() {
            _isInitialized = false;
            _hasError = true;
          });
        }
      }
    }
  }

  void _checkVideoCompletion() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    // Check if video has reached the end (within 100ms tolerance)
    // Also check if video is no longer playing (alternative completion detection)
    final duration = controller.value.duration;
    final position = controller.value.position;
    final isPlaying = controller.value.isPlaying;

    final hasReachedEnd =
        duration.inMilliseconds > 0 &&
        position.inMilliseconds >= duration.inMilliseconds - 100;

    // Detect completion: either reached end OR stopped playing near end (for robustness)
    final isCompleted =
        hasReachedEnd ||
        (!isPlaying &&
            duration.inMilliseconds > 0 &&
            position.inMilliseconds > 0 &&
            position.inMilliseconds >= duration.inMilliseconds - 500);

    if (isCompleted &&
        !_hasCalledCompletion &&
        widget.onVideoComplete != null) {
      _hasCalledCompletion = true;

      // Track video completion with timing analytics
      _logVideoCompletion(controller, duration);

      widget.onVideoComplete!();
    }
  }

  void _logVideoCompletion(
    VideoPlayerController controller,
    Duration duration,
  ) {
    if (_videoStartTime == null || _expectedDuration == null) return;

    try {
      final actualDuration = DateTime.now().difference(_videoStartTime!);
      final expectedMs = _expectedDuration!.inMilliseconds;
      final actualMs = actualDuration.inMilliseconds;
      final differenceMs = actualMs - expectedMs;

      // Only log if context is available (non-blocking)
      try {
        final ctx = context;
        if (ctx.mounted) {
          final analyticsService = Provider.of<AnalyticsService>(
            ctx,
            listen: false,
          );
          analyticsService.logVideoCompletion(
            widget.videoPath,
            expectedMs,
            actualMs,
            differenceMs,
          );
        }
      } catch (e) {
        // Silently ignore analytics errors - not critical
        if (kDebugMode) {
          debugPrint('Failed to log video completion analytics: $e');
        }
      }
    } catch (e) {
      // Ignore timing calculation errors
      if (kDebugMode) {
        debugPrint('Failed to calculate video completion timing: $e');
      }
    }
  }

  void _retryVideo() {
    if (_retryCount >= _maxRetries) return;

    setState(() {
      _hasError = false;
      _retryCount++;
      _isInitialized = false;
      _hasCalledCompletion = false;
      _videoStartTime = null; // Reset timing for retry
      _expectedDuration = null;
    });

    // Dispose old controller
    _controller?.removeListener(_checkVideoCompletion);
    _controller?.dispose();
    _controller = null;

    // Retry initialization with proper error handling
    _initializeVideo().then((_) {
      // Track successful retry in analytics
      if (!mounted) return;

      if (_isInitialized) {
        try {
          final ctx = context;
          if (ctx.mounted) {
            final analyticsService = Provider.of<AnalyticsService>(
              ctx,
              listen: false,
            );
            analyticsService.logVideoRetrySuccess(
              widget.videoPath,
              _retryCount,
            );
          }
        } catch (e) {
          // Ignore analytics errors
          if (kDebugMode) {
            debugPrint('Failed to log video retry success: $e');
          }
        }
      }
    }).catchError((error) {
      // Handle retry initialization errors gracefully
      if (kDebugMode) {
        debugPrint('Video retry initialization failed: $error');
      }
      // Update state to show error UI if widget is still mounted
      if (mounted) {
        setState(() {
          _isInitialized = false;
          _hasError = true;
        });
      }
    });
  }

  @override
  void dispose() {
    // Remove listener and dispose controller
    final controller = _controller;
    _controller = null;
    controller?.removeListener(_checkVideoCompletion);
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    // Show loading indicator while initializing
    if (!_isInitialized && controller == null) {
      return SizedBox.expand(
        child: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
          ),
        ),
      );
    }

    // Show fallback UI if video failed to load
    if (_hasError ||
        (!_isInitialized && controller == null) ||
        (controller != null && !controller.value.isInitialized)) {
      return SizedBox.expand(
        child: Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.play_circle_outline,
                  color: Color(0xFF00D9FF),
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Video unavailable',
                  style: TextStyle(color: Color(0xFF00D9FF), fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The background video could not be loaded.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                if (_hasError && _retryCount < _maxRetries) ...[
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _retryVideo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D9FF),
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // Use BoxFit.cover to fill screen without shrinking
    // This ensures the video fills the entire screen area
    if (controller == null || !controller.value.isInitialized) {
      return SizedBox.expand(
        child: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
          ),
        ),
      );
    }

    // Use the specified fit mode (cover for full-screen, contain for icons)
    return SizedBox.expand(
      child: widget.fit == BoxFit.contain
          ? FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            )
          : FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),
    );
  }
}
