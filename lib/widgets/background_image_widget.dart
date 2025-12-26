import 'package:flutter/material.dart';

/// Widget that displays the game background image
/// Used across all screens for consistent background
class BackgroundImageWidget extends StatelessWidget {
  final Widget child;
  final String? imagePath;

  const BackgroundImageWidget({super.key, required this.child, this.imagePath});

  @override
  Widget build(BuildContext context) {
    // Try multiple possible paths for the background image
    // Primary static background is 'assets/background n3rd.png'
    final paths = [
      imagePath,
      'assets/background n3rd.png', // Primary static background
      'assets/images/game_screen_bg_fallback.png',
      'assets/images/game_screen_bg.png',
    ].where((p) => p != null).cast<String>().toList();

    // Use the first available path or black fallback
    final path = paths.isNotEmpty ? paths.first : null;

    if (path == null) {
      // Fallback to black if no image is available (should not happen)
      return Container(color: Colors.black, child: child);
    }

    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(image: AssetImage(path), fit: BoxFit.cover),
      ),
      child: child,
    );
  }
}
