import 'dart:math';
import 'package:flutter/material.dart';

/// Celebration animation widget for achievements, correct answers, and game completions
class CelebrationAnimation extends StatefulWidget {

  const CelebrationAnimation({
    super.key,
    required this.child,
    required this.trigger,
    this.duration = const Duration(milliseconds: 1500),
    this.onComplete,
    this.confettiColor,
  });
  final Widget child;
  final bool trigger;
  final Duration duration;
  final VoidCallback? onComplete;
  final Color? confettiColor;

  @override
  State<CelebrationAnimation> createState() => _CelebrationAnimationState();
}

class _CelebrationAnimationState extends State<CelebrationAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  bool _hasTriggered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.05).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });
  }

  @override
  void didUpdateWidget(CelebrationAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger && !_hasTriggered) {
      _hasTriggered = true;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Transform.rotate(
                angle: _rotationAnimation.value,
                child: widget.child,
              ),
            );
          },
        ),
        if (widget.trigger && _hasTriggered)
          _ConfettiParticles(
            animation: _controller,
            color: widget.confettiColor,
          ),
      ],
    );
  }
}

/// Confetti particles for celebration effect
class _ConfettiParticles extends StatelessWidget {

  const _ConfettiParticles({
    required this.animation,
    this.color,
  });
  final Animation<double> animation;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return CustomPaint(
            painter: _ConfettiPainter(
              progress: animation.value,
              color: color ?? Theme.of(context).colorScheme.primary,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {

  _ConfettiPainter({
    required this.progress,
    required this.color,
  });
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress > 0.7) return; // Stop painting after 70% of animation

    final particleCount = 30;

    for (int i = 0; i < particleCount; i++) {
      final particleProgress = (progress * 1.5).clamp(0.0, 1.0);
      final baseX = size.width / 2;
      final baseY = size.height / 2;

      final angle = (i / particleCount) * 2 * pi;
      final distance = particleProgress * size.width * 0.4;
      final x = baseX + cos(angle) * distance;
      final y = baseY +
          sin(angle) * distance -
          (particleProgress * particleProgress * size.height * 0.3);

      final paint = Paint()
        ..color = color.withValues(
          alpha: (1 - particleProgress).clamp(0.0, 1.0),
        )
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(x, y),
        4.0 * (1 - particleProgress * 0.5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Scale button animation for micro-interactions
class AnimatedButton extends StatefulWidget {

  const AnimatedButton({
    super.key,
    required this.child,
    this.onTap,
    this.duration = const Duration(milliseconds: 100),
    this.scaleDown = 0.95,
    this.curve = Curves.easeInOut,
  });
  final Widget child;
  final VoidCallback? onTap;
  final Duration duration;
  final double scaleDown;
  final Curve curve;

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleDown).animate(
      CurvedAnimation(
        parent: _controller,
        curve: widget.curve,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: widget.child,
          );
        },
      ),
    );
  }
}

/// Bounce animation for emphasis
class BounceAnimation extends StatefulWidget {

  const BounceAnimation({
    super.key,
    required this.child,
    required this.trigger,
    this.duration = const Duration(milliseconds: 600),
  });
  final Widget child;
  final bool trigger;
  final Duration duration;

  @override
  State<BounceAnimation> createState() => _BounceAnimationState();
}

class _BounceAnimationState extends State<BounceAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );
  }

  @override
  void didUpdateWidget(BounceAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      _controller.forward(from: 0.0).then((_) {
        if (mounted) {
          _controller.reverse();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bounceAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _bounceAnimation.value,
          child: widget.child,
        );
      },
    );
  }
}
