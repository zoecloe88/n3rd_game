import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/widgets/animated_logo_loading_screen.dart';
import 'package:n3rd_game/services/auth_service.dart';
import 'package:n3rd_game/services/onboarding_service.dart';

/// Wrapper that shows animated logo loading screen, then routes based on auth/onboarding
class AnimatedLogoLoadingScreenWrapper extends StatefulWidget {
  const AnimatedLogoLoadingScreenWrapper({super.key});

  @override
  State<AnimatedLogoLoadingScreenWrapper> createState() =>
      _AnimatedLogoLoadingScreenWrapperState();
}

class _AnimatedLogoLoadingScreenWrapperState
    extends State<AnimatedLogoLoadingScreenWrapper> {
  Future<void> _checkAndRoute() async {
    if (!mounted) return;

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final onboardingService = OnboardingService();

      // Check auth first - if not authenticated, go to login
      if (!authService.isAuthenticated) {
        if (mounted && context.mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
        return;
      }

      // Check onboarding - if not completed, go to onboarding
      final hasCompletedOnboarding =
          await onboardingService.hasCompletedOnboarding();

      if (!hasCompletedOnboarding) {
        if (mounted && context.mounted) {
          Navigator.of(context).pushReplacementNamed('/onboarding');
        }
        return;
      }

      // Both onboarding and auth complete - go to word of day, then title
      if (mounted && context.mounted) {
        Navigator.of(context).pushReplacementNamed('/word-of-day');
      }
    } catch (e) {
      // On error, go to login
      if (mounted && context.mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedLogoLoadingScreen(
      onVideoCompleted: _checkAndRoute,
    );
  }
}
