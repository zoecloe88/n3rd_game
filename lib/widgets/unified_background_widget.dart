import 'package:flutter/material.dart';
import 'package:n3rd_game/widgets/video_player_widget.dart';
import 'package:n3rd_game/config/screen_background_videos.dart';

/// Unified background widget that provides screen-specific video backgrounds
/// Falls back to static image if no video is configured for the route
/// 
/// Videos are intentionally oversized (2000x3000) to preserve logo animation quality
/// and maintain responsiveness across all devices (phones and tablets)
class UnifiedBackgroundWidget extends StatelessWidget {
  final Widget child;
  final String? videoPath; // Optional: override video path, otherwise auto-detects from route

  // Fallback background configuration (used when no video is available)
  static const String fallbackBackgroundImage =
      'assets/images/game_screen_bg.png';
  static const Color fallbackBackgroundColor = Color(0xFF00D9FF); // Cyan/turquoise

  const UnifiedBackgroundWidget({
    super.key,
    required this.child,
    this.videoPath,
  });

  @override
  Widget build(BuildContext context) {
    // Get video path: use provided path, or auto-detect from route, or null
    final String? backgroundVideo = videoPath ?? 
        ScreenBackgroundVideos.getVideoForCurrentRoute(context);

    return Stack(
      children: [
        // Background: video if available, otherwise static image
        if (backgroundVideo != null)
          _buildVideoBackground(backgroundVideo)
        else
          _buildFallbackBackground(),

        // Screen content (on top, fully interactive)
        child,
      ],
    );
  }

  /// Build video background - fills screen, maintains aspect ratio
  /// Videos are 2000x3000 (oversized to preserve logo quality)
  Widget _buildVideoBackground(String videoPath) {
    return Positioned.fill(
      child: VideoPlayerWidget(
        videoPath: videoPath,
        loop: true,
        autoplay: true,
        fit: BoxFit.cover, // Cover entire screen, maintain aspect ratio
      ),
    );
  }

  /// Build fallback static image background
  Widget _buildFallbackBackground() {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage(fallbackBackgroundImage),
          fit: BoxFit.cover,
        ),
        color: fallbackBackgroundColor,
      ),
      constraints: const BoxConstraints.expand(),
    );
  }
}


