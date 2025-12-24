import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/widgets/video_player_widget.dart';
import 'package:n3rd_game/services/animation_randomizer_service.dart';

/// Widget that displays animated MP4 graphics (1024x1012) with proper sizing and placement
/// Ensures no content overlap by using constrained sizing and positioning
class AnimatedGraphicsWidget extends StatefulWidget {
  final String? category;
  final String? specificPath;
  final double? width;
  final double? height;
  final Alignment alignment;
  final EdgeInsets? padding;
  final bool loop;
  final bool autoplay;

  const AnimatedGraphicsWidget({
    super.key,
    this.category,
    this.specificPath,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.padding,
    this.loop = true,
    this.autoplay = true,
  }) : assert(
          category != null || specificPath != null,
          'Either category or specificPath must be provided',
        );

  @override
  State<AnimatedGraphicsWidget> createState() => _AnimatedGraphicsWidgetState();
}

class _AnimatedGraphicsWidgetState extends State<AnimatedGraphicsWidget> {
  String? _animationPath;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadAnimation();
  }

  Future<void> _loadAnimation() async {
    if (!mounted) return;

    try {
      String? path;

      if (widget.specificPath != null) {
        // Validate specific path exists
        final randomizer = Provider.of<AnimationRandomizerService>(
          context,
          listen: false,
        );
        // Extract category and filename if it's a full path
        final fullPath = widget.specificPath!;
        final parts = fullPath.split('/');
        if (parts.length >= 3 && parts[parts.length - 2] != 'animations') {
          final category = parts[parts.length - 2];
          final filename = parts[parts.length - 1];
          path = await randomizer.getAnimationPath(category, filename) ??
              widget.specificPath;
        } else {
          path = widget.specificPath;
        }
      } else if (widget.category != null) {
        final randomizer = Provider.of<AnimationRandomizerService>(
          context,
          listen: false,
        );
        path = await randomizer.getRandomAnimation(widget.category!);
      }

      if (mounted) {
        setState(() {
          _animationPath = path;
          _loading = false;
          _error = path == null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox.shrink();
    }

    if (_error || _animationPath == null) {
      return const SizedBox.shrink();
    }

    final width = widget.width;
    final height = widget.height;

    Widget videoWidget = ClipRect(
      child: VideoPlayerWidget(
        videoPath: _animationPath!,
        loop: widget.loop,
        autoplay: widget.autoplay,
      ),
    );

    // Apply sizing constraints
    if (width != null || height != null) {
      videoWidget = SizedBox(width: width, height: height, child: videoWidget);
    }

    // Apply padding if provided
    if (widget.padding != null) {
      videoWidget = Padding(padding: widget.padding!, child: videoWidget);
    }

    // Apply alignment
    return Align(alignment: widget.alignment, child: videoWidget);
  }
}
