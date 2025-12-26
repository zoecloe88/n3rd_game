import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:n3rd_game/widgets/background_image_widget.dart';
import 'package:n3rd_game/services/video_cache_service.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Simple video background widget for MP4 backgrounds
/// Uses BoxFit.cover (equivalent to CSS object-fit: cover) to fill screen
/// Videos should be 1080x1920px (9:16 aspect ratio) for optimal responsiveness
/// This ensures the video fills the screen properly on all devices without distortion
class VideoBackgroundWidget extends StatefulWidget {
  final String videoPath;
  final Widget child;
  final BoxFit fit;
  final Alignment alignment;
  final bool loop;
  final bool autoplay;
  final VoidCallback? onVideoCompleted;

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

  @override
  State<VideoBackgroundWidget> createState() => _VideoBackgroundWidgetState();
}

class _VideoBackgroundWidgetState extends State<VideoBackgroundWidget> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _hasCalledCompletion = false;
  Timer? _completionCheckTimer;
  Timer? _fallbackTimer; // Timer for fallback completion callback (replaces Future.delayed for proper cancellation)

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

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
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

  Future<void> _initializeVideo() async {
    if (!mounted) return;

    try {
      // Try to get cached controller first
      final cacheService = VideoCacheService();
      VideoPlayerController? controller = cacheService.getCachedController(widget.videoPath);

      if (controller == null) {
        // Not cached - create new controller
        // Handle special characters in path (like colon in logo:loadingscreen.mp4)
        controller = VideoPlayerController.asset(widget.videoPath);
        await controller.initialize().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('Video initialization timed out');
          },
        );

        if (!mounted) {
          controller.dispose();
          return;
        }
      } else {
        // Cached controller found - verify it's still valid and initialized
        try {
          if (!controller.value.isInitialized) {
            // Controller exists but not initialized - create new one
            // Don't dispose cached controller, let cache service manage it
            controller = VideoPlayerController.asset(widget.videoPath);
            await controller.initialize().timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw TimeoutException('Video initialization timed out');
              },
            );

            if (!mounted) {
              controller.dispose();
              return;
            }
          }
        } catch (e) {
          // Cached controller was disposed - create new one
          LoggerService.debug('Cached controller was disposed, creating new one: ${widget.videoPath}');
          controller = VideoPlayerController.asset(widget.videoPath);
          await controller.initialize().timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Video initialization timed out');
            },
          );

          if (!mounted) {
            controller.dispose();
            return;
          }
        }
      }

      controller.setLooping(widget.loop);

      if (mounted) {
        setState(() {
          _controller = controller;
          _isInitialized = true;
          _hasError = false;
        });

        // Start playing if autoplay is enabled
        if (widget.autoplay) {
          // Seek to start to ensure video is at beginning
          await controller.seekTo(Duration.zero);
          await controller.play();
        }

        // Add listener for video completion if not looping and callback provided
        if (!widget.loop && widget.onVideoCompleted != null) {
          // Use a timer to periodically check for video completion
          _completionCheckTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
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
      // Log error for debugging
      debugPrint('VideoBackgroundWidget: Failed to load video ${widget.videoPath}: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isInitialized = false;
        });
        // If video fails and we have a completion callback, call it after a delay
        // This ensures navigation still happens even if video fails
        // Use Timer instead of Future.delayed for proper cancellation
        if (widget.onVideoCompleted != null && !widget.loop) {
          _fallbackTimer?.cancel(); // Cancel any existing fallback timer
          _fallbackTimer = Timer(const Duration(seconds: 2), () {
            if (mounted && !_hasCalledCompletion) {
              _hasCalledCompletion = true;
              widget.onVideoCompleted?.call();
            }
          });
        }
      }
    }
  }

  void _checkVideoCompletion() {
    final controller = _controller;
    if (controller != null &&
        controller.value.isInitialized &&
        controller.value.duration.inMilliseconds > 0 &&
        controller.value.position.inMilliseconds >= controller.value.duration.inMilliseconds - 100 && // Allow 100ms tolerance
        !_hasCalledCompletion) {
      _hasCalledCompletion = true;
      _completionCheckTimer?.cancel();
      widget.onVideoCompleted?.call();
    }
  }

  @override
  void dispose() {
    _completionCheckTimer?.cancel();
    _fallbackTimer?.cancel(); // Cancel fallback timer
    _fallbackTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    // Don't dispose cached controllers - VideoCacheService manages them
    // Only dispose if this controller is not cached
    final cacheService = VideoCacheService();
    if (_controller != null && cacheService.getCachedController(widget.videoPath) != _controller) {
      _controller?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Show black background first (prevents white flash)
        const Positioned.fill(
          child: ColoredBox(color: Colors.black),
        ),
        
        // Video background - show immediately when initialized (primary background)
        if (_isInitialized && _controller != null && !_hasError)
          // Video is loaded and ready - show video as primary background
          Positioned.fill(
            child: FittedBox(
              fit: widget.fit,
              alignment: widget.alignment,
              child: SizedBox(
                width: _controller!.value.size.width > 0 ? _controller!.value.size.width : 1,
                height: _controller!.value.size.height > 0 ? _controller!.value.size.height : 1,
                child: VideoPlayer(_controller!),
              ),
            ),
          )
        else if (!_isInitialized && !_hasError)
          // Show loading indicator while video initializes
          const Positioned.fill(
            child: Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
          ),
        
        // Static background only as last resort fallback (when error)
        if (_hasError)
          const Positioned.fill(
            child: BackgroundImageWidget(
              imagePath: 'assets/background n3rd.png',
              child: SizedBox.shrink(),
            ),
          ),

        // Content on top
        widget.child,
      ],
    );
  }
}

