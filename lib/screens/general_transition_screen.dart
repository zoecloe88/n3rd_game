import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:n3rd_game/widgets/video_player_widget.dart';
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
    // Randomize transition video
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
    // Use the mode selection transition screen video for general transitions
    // This provides consistent transition animation throughout the app
    return 'assets/animations/Green Neutral Simple Serendipity Phone Wallpaper(1)/mode selection transition screen.mp4';
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
      body: Stack(
        children: [
          // Video background - fills entire screen perfectly
          VideoPlayerWidget(
            videoPath: _randomVideoPath,
            loop: false,
            autoplay: true,
          ),
          // Content overlay - no gradients, just content
          Positioned.fill(
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
        ],
      ),
    );
  }
}
