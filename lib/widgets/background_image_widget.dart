import 'package:flutter/material.dart';

/// Widget that displays the game background image
/// Used across all screens for consistent background
class BackgroundImageWidget extends StatelessWidget {

  const BackgroundImageWidget({super.key, required this.child, this.imagePath});
  final Widget child;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    // Try multiple possible paths for the background image
    // Primary static background is 'assets/background n3rd.png'
    final paths = [
      imagePath,
      'assets/background n3rd.png', // Primary static background
    ].where((p) => p != null).cast<String>().toList();

    // Use the first available path or black fallback
    final path = paths.isNotEmpty ? paths.first : null;

    if (path == null) {
      // Fallback to black if no image is available (should not happen)
      return Semantics(
        excludeSemantics: true, // Hide decorative background from screen readers
        child: Container(color: Colors.black, child: child),
      );
    }

    // Use Image.asset with errorBuilder to gracefully handle test environments
    // where assets may not be available, preventing "Message corrupted" errors
    // Wrap in Semantics to exclude decorative background from accessibility tree
    return Semantics(
      excludeSemantics: true, // Hide decorative background from screen readers
      child: Container(
        color: Colors.black, // Base fallback color
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              path,
              fit: BoxFit.cover,
              semanticLabel: null, // Explicitly no label for decorative image
              errorBuilder: (context, error, stackTrace) {
                // In test environments or when asset loading fails,
                // return empty widget (will show black background from parent Container)
                return const SizedBox.shrink();
              },
            ),
            child,
          ],
        ),
      ),
    );
  }
}
