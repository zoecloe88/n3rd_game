import 'package:flutter/material.dart';
import 'package:n3rd_game/widgets/background_image_widget.dart';
import 'package:n3rd_game/widgets/video_player_widget.dart';

/// Animated logo loading screen with background
/// Shows animated logo while checking auth/onboarding status
class AnimatedLogoLoadingScreen extends StatelessWidget {
  const AnimatedLogoLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Make logo size responsive to screen size
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    // Calculate responsive size: 60% of screen width, but max 500px and min 300px
    // Also ensure it fits within screen height (80% max)
    final logoSize = (screenWidth * 0.6).clamp(300.0, 500.0);
    final maxHeight = screenHeight * 0.8;
    final finalSize = logoSize > maxHeight ? maxHeight : logoSize;

    return Scaffold(
      backgroundColor: Colors.black,
      body: BackgroundImageWidget(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated logo (responsive size, centered)
              SizedBox(
                width: finalSize,
                height: finalSize,
                child: const ClipRect(
                  child: VideoPlayerWidget(
                    videoPath:
                        'assets/animations/Green Neutral Simple Serendipity Phone Wallpaper(1)/Green Neutral Simple Serendipity Phone Wallpaper.mp4',
                    loop: true,
                    autoplay: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
