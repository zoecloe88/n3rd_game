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
  @override
  void initState() {
    super.initState();
    // Show logo for at least 3 seconds, then check routing
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _checkAndRoute();
      }
    });
  }

  Future<void> _checkAndRoute() async {
    if (!mounted) return;

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final onboardingService = OnboardingService();

      // Check onboarding first
      final hasCompletedOnboarding =
          await onboardingService.hasCompletedOnboarding();

      if (!hasCompletedOnboarding) {
        if (mounted && context.mounted) {
          Navigator.of(context).pushReplacementNamed('/onboarding');
        }
        return;
      }

      // Check auth
      if (!authService.isAuthenticated) {
        if (mounted && context.mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
        return;
      }

      // Both onboarding and auth complete - go to main app
      if (mounted && context.mounted) {
        Navigator.of(context).pushReplacementNamed('/title');
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
    return const AnimatedLogoLoadingScreen();
  }
}
