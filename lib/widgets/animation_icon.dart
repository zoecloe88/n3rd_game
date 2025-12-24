import 'package:flutter/material.dart';
import 'package:n3rd_game/widgets/video_player_widget.dart';

/// Widget that replaces Icon widgets with animations
/// Animations are resized to match icon size and blend with background
class AnimationIcon extends StatelessWidget {
  final String animationPath;
  final double size;
  final Color? color; // For opacity/blending control

  const AnimationIcon({
    super.key,
    required this.animationPath,
    required this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    // 3/4 inch = 54-72px at mobile DPI
    // Use provided size directly, scale like Lottie files or icons
    final double iconSize = size > 0 ? size : 54.0; // Default to 54px if not provided
    
    // Animations load immediately with screen - VideoPlayerWidget initializes in initState
    // Use BoxFit.contain for icon-sized animations to prevent black boxes
    return SizedBox(
      width: iconSize,
      height: iconSize,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(iconSize * 0.1),
        child: color != null
            ? ColorFiltered(
                colorFilter: ColorFilter.mode(
                  color!,
                  BlendMode.srcATop,
                ),
                child: VideoPlayerWidget(
                  videoPath: animationPath,
                  loop: true,
                  autoplay: true,
                  fit: BoxFit.contain, // Use contain for icon-sized animations
                ),
              )
            : VideoPlayerWidget(
                videoPath: animationPath,
                loop: true,
                autoplay: true,
                fit: BoxFit.contain, // Use contain for icon-sized animations
              ),
      ),
    );
  }
}

