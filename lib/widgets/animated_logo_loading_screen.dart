import 'package:flutter/material.dart';
import 'package:n3rd_game/widgets/video_background_widget.dart';

/// Animated logo loading screen with background video
/// Shows animated logo while checking auth/onboarding status
/// Uses logo:loadingscreen.mp4 from assets folder
class AnimatedLogoLoadingScreen extends StatelessWidget {
  final VoidCallback? onVideoCompleted;

  const AnimatedLogoLoadingScreen({
    super.key,
    this.onVideoCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: VideoBackgroundWidget(
        videoPath: 'assets/logoloadingscreen.mp4',
        fit: BoxFit.cover, // CSS object-fit: cover equivalent
        alignment: Alignment.topCenter, // Logo in upper portion
        loop: false, // Don't loop - wait for video to complete
        autoplay: true,
        onVideoCompleted: onVideoCompleted,
        child: const SizedBox.shrink(), // No spinner - only video is visible
      ),
    );
  }
}
