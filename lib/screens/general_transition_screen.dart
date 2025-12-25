import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:n3rd_game/widgets/video_background_widget.dart';
import 'package:n3rd_game/services/onboarding_service.dart';
import 'package:n3rd_game/utils/responsive_helper.dart';
import 'package:n3rd_game/theme/app_colors.dart';
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

  @override
  void initState() {
    super.initState();
    // Randomize transition video from available options
    _randomVideoPath = _getRandomTransitionVideo();
    // Navigate after 3 seconds with onboarding check
    registerTimer(
      Timer(const Duration(seconds: 3), () {
        if (mounted && context.mounted) {
          _navigateWithOnboardingCheck();
        }
      }),
    );
  }

  Future<void> _navigateWithOnboardingCheck() async {
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
      'assets/mode selection transition screen.mp4',
      'assets/mode selection 2.mp4',
      'assets/mode selection 3.mp4',
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

    final isTablet = ResponsiveHelper.isTablet(context);
    final horizontalPadding = isTablet ? 48.0 : 24.0;
    final accentColor = const Color(0xFF00D9FF);

    return Scaffold(
      backgroundColor: AppColors.of(context).background,
      body: VideoBackgroundWidget(
        videoPath: _randomVideoPath,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter, // Characters/logos in upper portion
        loop: false,
        autoplay: true,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Simple loading indicator
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
