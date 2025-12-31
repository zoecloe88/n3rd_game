import 'dart:async';
import 'package:n3rd_game/utils/unawaited_helper.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:n3rd_game/widgets/video_background_widget.dart';
import 'package:n3rd_game/services/onboarding_service.dart';
import 'package:n3rd_game/services/resource_manager.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/config/app_config.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// General purpose transition screen for navigation between screens
///
/// Displays a transition video and navigates to the specified route after
/// a minimum delay. Checks onboarding status for protected routes.
///
/// Features:
/// - Random video selection
/// - Onboarding check for protected routes
/// - Minimum delay enforcement
/// - Error handling with fail-open approach
class GeneralTransitionScreen extends StatefulWidget {

  const GeneralTransitionScreen({
    super.key,
    required this.routeAfter,
    this.routeArgs,
  });
  final String routeAfter;
  final Object? routeArgs;

  @override
  State<GeneralTransitionScreen> createState() =>
      _GeneralTransitionScreenState();
}

class _GeneralTransitionScreenState extends State<GeneralTransitionScreen>
    with ResourceManagerMixin {
  late String _randomVideoPath;
  final OnboardingService _onboardingService = OnboardingService();
  DateTime? _startTime;

  // Constants
  static const List<String> _transitionVideos = [
    'assets/modeselectiontransitionscreen.mp4',
    'assets/modeselection2.mp4',
    'assets/modeselection3.mp4',
  ];

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    // Randomize transition video from available options
    _randomVideoPath = _getRandomTransitionVideo();
    // Navigation will happen when video completes (via onVideoCompleted callback)
    // But ensure minimum 3 seconds
  }

  /// Navigate to target route with onboarding check
  ///
  /// Ensures minimum delay has passed and checks onboarding status
  /// for protected routes. Uses fail-open approach for onboarding check.
  Future<void> _navigateWithOnboardingCheck() async {
    if (!mounted || !context.mounted) return;

    // Ensure minimum delay has passed (use AppConfig for consistency)
    if (_startTime != null) {
      final elapsed = DateTime.now().difference(_startTime!);
      final remaining = AppConfig.minModeTransitionDelay - elapsed;
      if (remaining.inMilliseconds > 0) {
        // Wait for remaining time to reach minimum delay
        await Future.delayed(remaining);
      }
    } else {
      // If start time is null, wait full minimum delay
      await Future.delayed(AppConfig.minModeTransitionDelay);
    }

    if (!mounted || !context.mounted) return;

    try {
      // Check onboarding before navigating to protected routes
      final hasCompletedOnboarding =
          await _onboardingService.hasCompletedOnboarding();

      // Use AppConfig protected routes constant
      final protectedRoutes = AppConfig.protectedRoutes;

      final needsOnboarding = protectedRoutes.contains(widget.routeAfter) &&
          !hasCompletedOnboarding;

      if (needsOnboarding && mounted && context.mounted) {
        // Redirect to onboarding if accessing protected route without completing it
        unawaited(NavigationHelper.safeNavigate(context, '/onboarding', replace: true));
        return;
      }
    } catch (e) {
      // Onboarding check failed - log error but allow access (fail-open to prevent blocking users)
      LoggerService.warning(
        'GeneralTransitionScreen: Onboarding check failed',
        error: e,
      );
      // Continue with normal flow - don't block navigation if onboarding check fails
    }

    // Safe to navigate
    if (mounted && context.mounted) {
      unawaited(NavigationHelper.safePushReplacementNamed(
        context,
        widget.routeAfter,
        arguments: widget.routeArgs,
      ),);
    }
  }

  /// Get a random transition video from available options
  ///
  /// Returns one of the predefined transition video paths
  String _getRandomTransitionVideo() {
    final random = Random();
    return _transitionVideos[random.nextInt(_transitionVideos.length)];
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    ); // Restore normal mode
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Semantics(
        label: 'Transition video playing',
        child: VideoBackgroundWidget(
          videoPath: _randomVideoPath,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter, // Characters/logos in upper portion
          loop: false,
          autoplay: true,
          onVideoCompleted:
              _navigateWithOnboardingCheck, // Navigate when video completes
          child: const SizedBox.shrink(), // No content overlay needed
        ),
      ),
    );
  }
}