import 'package:flutter/material.dart';
import 'package:n3rd_game/widgets/unified_background_widget.dart';
import 'package:n3rd_game/widgets/video_player_widget.dart';

/// Animated logo loading screen with background
/// Shows animated logo while checking auth/onboarding status
/// Uses 2000x3000 video (oversized to preserve logo animation quality)
class AnimatedLogoLoadingScreen extends StatelessWidget {
  const AnimatedLogoLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Video is 2000x3000 (intentionally oversized to preserve logo quality)
    // Simple approach: let video fill screen width and maintain aspect ratio
    // Focus is on the animation logos, not fitting the entire video perfectly
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      body: UnifiedBackgroundWidget(
        child: Center(
          child: SizedBox(
            width: screenWidth,
            child: const AspectRatio(
              aspectRatio: 2 / 3, // 2000:3000 = 2:3
              child: VideoPlayerWidget(
                videoPath:
                    'assets/animations/Green Neutral Simple Serendipity Phone Wallpaper(1)/dec24n3rdlogoloadingscreen.mp4',
                loop: true,
                autoplay: true,
                fit: BoxFit.contain, // Maintain aspect ratio, focus on logos
              ),
            ),
          ),
        ),
      ),
    );
  }
}
