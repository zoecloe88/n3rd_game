import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

/// Page transition animations for polished navigation
class PageTransitions {
  /// Fade transition
  static Route<T> fadeTransition<T>({
    required Widget page,
    RouteSettings? settings,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: duration,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }

  /// Slide transition from right
  static Route<T> slideTransition<T>({
    required Widget page,
    RouteSettings? settings,
    Duration duration = const Duration(milliseconds: 300),
    Offset begin = const Offset(1.0, 0.0),
    Offset end = Offset.zero,
    Curve curve = Curves.easeOut,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: duration,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slideAnimation = Tween<Offset>(
          begin: begin,
          end: end,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: curve,
          ),
        );

        return SlideTransition(
          position: slideAnimation,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }

  /// Scale transition
  static Route<T> scaleTransition<T>({
    required Widget page,
    RouteSettings? settings,
    Duration duration = const Duration(milliseconds: 300),
    double begin = 0.8,
    double end = 1.0,
    Curve curve = Curves.easeOut,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: duration,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final scaleAnimation = Tween<double>(
          begin: begin,
          end: end,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: curve,
          ),
        );

        return ScaleTransition(
          scale: scaleAnimation,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }

  /// Combined slide and fade (smooth transition)
  static Route<T> smoothTransition<T>({
    required Widget page,
    RouteSettings? settings,
    Duration duration = const Duration(milliseconds: 250),
  }) {
    return slideTransition<T>(
      page: page,
      settings: settings,
      duration: duration,
      curve: Curves.easeOutCubic,
    );
  }
}

/// Micro-interaction animations for buttons and widgets
class MicroAnimations {
  /// Scale animation for button presses
  static Widget scaleOnTap({
    required Widget child,
    required VoidCallback onTap,
    double scale = 0.95,
    Duration duration = const Duration(milliseconds: 100),
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1.0, end: 1.0),
      duration: duration,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: GestureDetector(
            onTapDown: (_) {
              // Animate scale down on tap
            },
            onTapUp: (_) {
              onTap();
            },
            onTapCancel: () {
              // Reset scale
            },
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  /// Celebration animation widget
  static Widget celebration({
    required Widget child,
    required bool trigger,
    Duration duration = const Duration(milliseconds: 600),
  }) {
    return AnimatedContainer(
      duration: duration,
      curve: Curves.elasticOut,
      transform: Matrix4.identity()
        ..scaleByVector3(Vector3.all(trigger ? 1.1 : 1.0)),
      child: child,
    );
  }

  /// Shake animation for errors
  static Widget shake({
    required Widget child,
    required bool trigger,
    Duration duration = const Duration(milliseconds: 400),
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: trigger ? 1 : 0),
      duration: duration,
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(value * 10 * (value - 1).abs(), 0),
          child: child,
        );
      },
      child: child,
    );
  }
}
