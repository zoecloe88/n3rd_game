import 'package:flutter/material.dart';

/// Shimmer effect widget for skeleton loaders
/// Provides animated shimmer effect during loading states
class Shimmer extends StatefulWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration period;

  const Shimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.period = const Duration(milliseconds: 1500),
  });

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.period,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return _ShimmerEffect(
          progress: _controller.value,
          baseColor: widget.baseColor,
          highlightColor: widget.highlightColor,
          child: widget.child,
        );
      },
    );
  }
}

class _ShimmerEffect extends StatelessWidget {
  final Widget child;
  final double progress;
  final Color? baseColor;
  final Color? highlightColor;

  const _ShimmerEffect({
    required this.child,
    required this.progress,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final defaultBaseColor = baseColor ?? colors.surface.withValues(alpha: 0.3);
    final defaultHighlightColor =
        highlightColor ?? colors.surface.withValues(alpha: 0.5);

    return ShaderMask(
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: Alignment(-1.0 + 2 * progress, 0.0),
          end: Alignment(1.0 + 2 * progress, 0.0),
          colors: [
            defaultBaseColor,
            defaultHighlightColor,
            defaultBaseColor,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(bounds);
      },
      child: child,
    );
  }
}

