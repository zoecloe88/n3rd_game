import 'package:flutter/material.dart';
import 'package:n3rd_game/widgets/video_background_widget.dart';

/// Animated logo loading screen with background video
/// Shows animated logo while checking auth/onboarding status
/// Uses logo:loadingscreen.mp4 from assets folder
class AnimatedLogoLoadingScreen extends StatelessWidget {
  const AnimatedLogoLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: VideoBackgroundWidget(
        videoPath: 'assets/logo:loadingscreen.mp4',
        fit: BoxFit.cover, // CSS object-fit: cover equivalent
        alignment: Alignment.topCenter, // Logo in upper portion
        loop: true,
        autoplay: true,
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF00D9FF),
          ),
        ),
      ),
    );
  }
}
