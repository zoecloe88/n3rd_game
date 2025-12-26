import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:n3rd_game/widgets/video_background_widget.dart';
import 'package:n3rd_game/services/onboarding_service.dart';
import 'package:n3rd_game/services/resource_manager.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';

class GeneralTransitionScreen extends StatefulWidget {
  final String routeAfter;
  final Object? routeArgs;

  const GeneralTransitionScreen({
    super.key,
    required this.routeAfter,
    this.routeArgs,
  });

  @override
  State<GeneralTransitionScreen> createState() =>
      _GeneralTransitionScreenState();
}

class _GeneralTransitionScreenState extends State<GeneralTransitionScreen>
    with ResourceManagerMixin {
  late String _randomVideoPath;
  final OnboardingService _onboardingService = OnboardingService();
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    // Randomize transition video from available options
    _randomVideoPath = _getRandomTransitionVideo();
    // Navigation will happen when video completes (via onVideoCompleted callback)
    // But ensure minimum 3 seconds
  }

  Future<void> _navigateWithOnboardingCheck() async {
    if (!mounted || !context.mounted) return;

    // Ensure minimum 3 seconds have passed
    if (_startTime != null) {
      final elapsed = DateTime.now().difference(_startTime!);
      if (elapsed.inSeconds < 3) {
        // Wait for remaining time to reach 3 seconds
        await Future.delayed(Duration(seconds: 3 - elapsed.inSeconds));
      }
    }

    if (!mounted || !context.mounted) return;

    try {
      // Check onboarding before navigating to protected routes
      final hasCompletedOnboarding =
          await _onboardingService.hasCompletedOnboarding();

      // List of routes that require onboarding
      const protectedRoutes = [
        '/title',
        '/modes',
        '/game',
        '/stats',
        '/leaderboard',
        '/editions',
      ];

      final needsOnboarding = protectedRoutes.contains(widget.routeAfter) &&
          !hasCompletedOnboarding;

      if (needsOnboarding && mounted && context.mounted) {
        // Redirect to onboarding if accessing protected route without completing it
        NavigationHelper.safeNavigate(context, '/onboarding', replace: true);
        return;
      }
    } catch (e) {
      // Onboarding check failed - log error but allow access (fail-open to prevent blocking users)
      if (kDebugMode) {
        debugPrint('⚠️ Onboarding check failed in GeneralTransitionScreen: $e');
      }
      // Continue with normal flow - don't block navigation if onboarding check fails
    }

    // Safe to navigate
    if (mounted && context.mounted) {
      Navigator.of(
        context,
      ).pushReplacementNamed(widget.routeAfter, arguments: widget.routeArgs);
    }
  }

  String _getRandomTransitionVideo() {
    // Randomize between available transition videos
    final random = Random();
    final videos = [
      'assets/modeselectiontransitionscreen.mp4',
      'assets/modeselection2.mp4',
      'assets/modeselection3.mp4',
    ];
    return videos[random.nextInt(videos.length)];
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
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    return Scaffold(
      body: VideoBackgroundWidget(
        videoPath: _randomVideoPath,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter, // Characters/logos in upper portion
        loop: false,
        autoplay: true,
        onVideoCompleted: _navigateWithOnboardingCheck, // Navigate when video completes
        child: const SizedBox.shrink(), // No content overlay needed
      ),
    );
  }
}
