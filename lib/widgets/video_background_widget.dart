import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

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

  const VideoBackgroundWidget({
    super.key,
    required this.videoPath,
    required this.child,
    this.fit = BoxFit.cover, // CSS object-fit: cover equivalent
    this.alignment = Alignment.center,
    this.loop = true,
    this.autoplay = true,
  });

  @override
  State<VideoBackgroundWidget> createState() => _VideoBackgroundWidgetState();
}

class _VideoBackgroundWidgetState extends State<VideoBackgroundWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    if (!mounted) return;

    try {
      final controller = VideoPlayerController.asset(widget.videoPath);
      await controller.initialize();

      if (!mounted) {
        controller.dispose();
        return;
      }

      controller.setLooping(widget.loop);

      if (widget.autoplay) {
        controller.play();
      }

      setState(() {
        _controller = controller;
        _isInitialized = true;
        _hasError = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isInitialized = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Video background
        if (_isInitialized && _controller != null && !_hasError)
          Positioned.fill(
            child: FittedBox(
              fit: widget.fit,
              alignment: widget.alignment,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            ),
          )
        else if (!_hasError)
          // Loading state - show black background
          const ColoredBox(color: Colors.black)
        else
          // Error state - show solid color background as fallback
          const ColoredBox(color: Color(0xFF00D9FF)),

        // Content on top
        widget.child,
      ],
    );
  }
}

