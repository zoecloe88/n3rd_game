import 'package:flutter/material.dart';
import 'package:n3rd_game/widgets/unified_background_widget.dart';

/// Initial loading screen - first screen shown on app launch
/// Uses static background with animation overlay
class InitialLoadingScreen extends StatelessWidget {
  const InitialLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: UnifiedBackgroundWidget(
        animationPath:
            'assets/animations/Green Neutral Simple Serendipity Phone Wallpaper(1)/Green Neutral Simple Serendipity Phone Wallpaper(1).mp4',
        animationAlignment: Alignment.center,
        child: SizedBox.shrink(), // No content, just background + animation
      ),
    );
  }
}
