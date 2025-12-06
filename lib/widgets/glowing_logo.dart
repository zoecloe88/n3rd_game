import 'package:flutter/material.dart';

/// A simple logo widget (glow effects removed for performance)
class GlowingLogo extends StatelessWidget {
  final String imagePath;
  final double size;
  final bool enableShimmer;

  const GlowingLogo({
    super.key,
    required this.imagePath,
    required this.size,
    this.enableShimmer = false,
  });

  @override
  Widget build(BuildContext context) {
    // Make size responsive to screen size
    final screenSize = MediaQuery.of(context).size;
    final responsiveSize =
        size * (screenSize.width / 375.0); // Base on iPhone width

    return Image.asset(
      imagePath,
      width: responsiveSize,
      height: responsiveSize,
      fit: BoxFit.contain,
    );
  }
}
