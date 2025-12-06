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
    final paths = [
      imagePath,
      'assets/images/game_screen_bg_fallback.png',
      'assets/images/game_screen_bg.png',
    ].where((p) => p != null).cast<String>().toList();

    // Use the first available path or a solid color fallback
    final path = paths.isNotEmpty ? paths.first : null;

    if (path == null) {
      // Fallback to cyan/turquoise solid color
      return Container(color: const Color(0xFF00D9FF), child: child);
    }

    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(image: AssetImage(path), fit: BoxFit.cover),
      ),
      child: child,
    );
  }
}
