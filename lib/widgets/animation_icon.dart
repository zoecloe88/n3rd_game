import 'dart:convert';
import 'dart:io';
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
    // #region agent log
    final logData = {
      'animationPath': animationPath,
      'size': size,
      'hasColor': color != null,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'sessionId': 'debug-session',
      'runId': 'run1',
      'hypothesisId': 'B',
      'location': 'animation_icon.dart:19',
      'message': 'Building AnimationIcon',
    };
    File('/Users/gerardandre/n3rd_game/.cursor/debug.log').writeAsString('${jsonEncode(logData)}\n', mode: FileMode.append).then((_) {}, onError: (_) {});
    // #endregion
    // Animations load immediately with screen - VideoPlayerWidget initializes in initState
    // Use BoxFit.contain for icon-sized animations to prevent black boxes
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.1),
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

