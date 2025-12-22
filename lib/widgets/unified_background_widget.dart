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
  Widget _buildAnimationOverlay() {
    return Builder(
      builder: (context) {
        final screenSize = MediaQuery.of(context).size;
        final screenWidth = screenSize.width;
        final screenHeight = screenSize.height;

        // Make animation responsive: scale to fit screen while maintaining aspect ratio
        // Default size is 1012x1024, so aspect ratio is ~0.988
        final aspectRatio =
            (animationWidth ?? 1012) / (animationHeight ?? 1024);

        // Calculate responsive size: use 90% of screen width or height, whichever is smaller
        // but maintain aspect ratio
        double responsiveWidth;
        double responsiveHeight;

        if (screenWidth / screenHeight > aspectRatio) {
          // Screen is wider than animation aspect ratio
          responsiveHeight = screenHeight * 0.9;
          responsiveWidth = responsiveHeight * aspectRatio;
        } else {
          // Screen is taller than animation aspect ratio
          responsiveWidth = screenWidth * 0.9;
          responsiveHeight = responsiveWidth / aspectRatio;
        }

        // Clamp to reasonable min/max sizes
        responsiveWidth = responsiveWidth.clamp(300.0, screenWidth);
        responsiveHeight = responsiveHeight.clamp(300.0, screenHeight);

        return Positioned.fill(
          child: IgnorePointer(
            // Make animation non-interactive so it doesn't block UI elements
            child: ClipRect(
              // Prevent overflow if animation is larger than screen
              child: Align(
                alignment: animationAlignment,
                child: Padding(
                  padding: animationPadding ?? EdgeInsets.zero,
                  child: SizedBox(
                    width: responsiveWidth,
                    height: responsiveHeight,
                    child: VideoPlayerWidget(
                      videoPath: animationPath!,
                      loop: true,
                      autoplay: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
