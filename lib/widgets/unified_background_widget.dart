import 'package:flutter/material.dart';
import 'package:n3rd_game/widgets/video_player_widget.dart';

/// Unified background widget that provides consistent background across all screens
/// with optional animation overlays (1012x1024) for specific screens
///
/// This widget ensures all screens share the same background image/video,
/// while allowing specific screens to have decorative animation overlays.
class UnifiedBackgroundWidget extends StatelessWidget {
  final Widget child;
  final String? animationPath; // Optional: 1012x1024 animation video path
  final Alignment animationAlignment; // Where to place the animation
  final EdgeInsets? animationPadding;
  final double? animationWidth; // Width of animation overlay
  final double? animationHeight; // Height of animation overlay

  // Common background configuration
  // Using static image for better performance and consistency
  static const String commonBackgroundImage =
      'assets/images/game_screen_bg.png';
  static const String fallbackBackgroundImage =
      'assets/images/game_screen_bg_fallback.png';
  static const Color fallbackBackgroundColor = Color(
    0xFF00D9FF,
  ); // Cyan/turquoise

  const UnifiedBackgroundWidget({
    super.key,
    required this.child,
    this.animationPath,
    this.animationAlignment = Alignment.bottomCenter,
    this.animationPadding,
    this.animationWidth = 1012,
    this.animationHeight = 1024,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Common background (static image)
        _buildCommonBackground(),

        // Optional animation overlay (behind content, non-interactive)
        // Placed before child so it appears behind UI elements
        if (animationPath != null) _buildAnimationOverlay(),

        // Screen content (on top, fully interactive)
        child,
      ],
    );
  }

  /// Build the common background that all screens share
  Widget _buildCommonBackground() {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage(commonBackgroundImage),
          fit: BoxFit.cover,
          // Note: onError callback doesn't support fallback, so we use color fallback
        ),
        // Fallback color if image fails to load
        color: fallbackBackgroundColor,
      ),
      child: Container(
        // Ensure background covers entire screen
        constraints: const BoxConstraints.expand(),
      ),
    );
  }

  /// Build the optional animation overlay
  /// Animations are resized to 3/4 inch (18px) and placed at top/bottom center
  Widget _buildAnimationOverlay() {
    return Builder(
      builder: (context) {
        // 3/4 inch = 18px at standard DPI (72 DPI)
        // For mobile, use logical pixels: ~18-24px depending on device
        final double animationSize = 18.0;
        
        // Determine if animation should be at top or bottom based on alignment
        final bool isTop = animationAlignment == Alignment.topCenter || 
                          animationAlignment == Alignment.topLeft ||
                          animationAlignment == Alignment.topRight;
        
        return Positioned(
          top: isTop ? (animationPadding?.top ?? 60.0) : null,
          bottom: !isTop ? (animationPadding?.bottom ?? 60.0) : null,
          left: 0,
          right: 0,
          child: IgnorePointer(
            // Make animation non-interactive so it doesn't block UI elements
            child: Center(
              child: SizedBox(
                width: animationSize,
                height: animationSize,
                child: VideoPlayerWidget(
                  videoPath: animationPath!,
                  loop: true,
                  autoplay: true,
                  fit: BoxFit.contain, // Ensure animation fits within size
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
