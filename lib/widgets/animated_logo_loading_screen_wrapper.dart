import 'package:flutter/material.dart';
import 'package:n3rd_game/utils/unawaited_helper.dart';
import 'package:n3rd_game/widgets/animated_logo_loading_screen.dart';
import 'package:n3rd_game/services/auth_service.dart';
import 'package:n3rd_game/services/onboarding_service.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/utils/provider_helper.dart';

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
    if (!mounted) {
      return;
    }

    LoggerService.debug('AnimatedLogoLoadingScreenWrapper: Video completed, checking auth and onboarding');

    try {
      final authService = ProviderHelper.safeGet<AuthService>(context, listen: false);
      if (authService == null) {
        // AuthService not available yet - navigate to login as fallback
        if (mounted && context.mounted) {
          unawaited(NavigationHelper.safeNavigate(context, '/login', replace: true));
        }
        return;
      }

      final onboardingService = OnboardingService();

      // Check auth first - if not authenticated, go to login
      if (!authService.isAuthenticated) {
        if (mounted && context.mounted) {
          unawaited(NavigationHelper.safeNavigate(context, '/login', replace: true));
        }
        return;
      }

      // Check onboarding - if not completed, go to onboarding
      final hasCompletedOnboarding =
          await onboardingService.hasCompletedOnboarding();

      if (!hasCompletedOnboarding) {
        if (mounted && context.mounted) {
          unawaited(NavigationHelper.safeNavigate(context, '/onboarding', replace: true));
        }
        return;
      }

      // Both onboarding and auth complete - go to word of day, then title
      if (mounted && context.mounted) {
        LoggerService.debug('AnimatedLogoLoadingScreenWrapper: Navigating to /word-of-day');
        unawaited(NavigationHelper.safeNavigate(context, '/word-of-day', replace: true));
      }
    } catch (e) {
      // On error, go to login
      LoggerService.error(
        'AnimatedLogoLoadingScreenWrapper: Error during routing',
        error: e,
      );
      if (mounted && context.mounted) {
        unawaited(NavigationHelper.safeNavigate(context, '/login', replace: true));
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