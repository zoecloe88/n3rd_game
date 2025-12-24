import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/services/onboarding_service.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/services/haptic_service.dart';
import 'package:n3rd_game/widgets/video_player_widget.dart';
import 'package:n3rd_game/widgets/background_image_widget.dart';
import 'package:n3rd_game/widgets/animated_graphics_widget.dart';
import 'package:n3rd_game/services/resource_manager.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/widgets/animation_icon.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with ResourceManagerMixin {
  final PageController _pageController = PageController();
  final OnboardingService _onboardingService = OnboardingService();
  int _currentPage = 0;
  
  // Preload animation paths for all pages
  final List<String> _animationPaths = [
    'assets/animations/shared/8.mp4', // Welcome page
    'assets/animations/shared/10.mp4', // Features page
    'assets/animations/shared/11.mp4', // Play solo/online page
    'assets/animations/shared/8.mp4', // Track progress page
  ];

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Welcome to N3RD Trivia',
      description:
          'Test your memory and knowledge with challenging trivia games.',
      icon: Icons.quiz_outlined,
    ),
    OnboardingPage(
      title: 'Features & Editions',
      description:
          'Access multiple trivia editions, AI-generated content, and personalized learning experiences.',
      icon: Icons.collections_bookmark_outlined,
    ),
    OnboardingPage(
      title: 'Play Solo or Online',
      description:
          'Challenge yourself or compete with friends in multiplayer matches.',
      icon: Icons.people_outline,
    ),
    OnboardingPage(
      title: 'Track Your Progress',
      description: 'View your stats, achievements, and climb the leaderboards.',
      icon: Icons.leaderboard_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Preload all animations when screen loads - they'll initialize when pages are built
    // VideoPlayerWidget handles initialization in addPostFrameCallback
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      HapticService().lightImpact();
      if (_pageController.hasClients) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      _completeOnboarding();
    }
  }

  void _skipOnboarding() {
    HapticService().lightImpact();
    // Track skip in analytics
    try {
      final analyticsService = Provider.of<AnalyticsService>(
        context,
        listen: false,
      );
      analyticsService.logOnboardingSkipped();
    } catch (e) {
      // Ignore analytics errors
    }
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    final success = await _onboardingService.completeOnboarding();

    if (!success && mounted && context.mounted) {
      // Show error to user - onboarding save failed
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save onboarding status. Please try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return; // Don't navigate if save failed - user can try again
    }

    if (!mounted) return;

    // Track completion in analytics
    try {
      final analyticsService = Provider.of<AnalyticsService>(
        context,
        listen: false,
      );
      analyticsService.logOnboardingCompleted();
    } catch (e) {
      // Ignore analytics errors
    }

    if (mounted && context.mounted) {
      NavigationHelper.safeNavigate(
        context,
        '/general-transition',
        replace: true,
        arguments: {'routeAfter': '/title', 'routeArgs': null},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).background,
      body: BackgroundImageWidget(
        child: SafeArea(
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: TextButton(
                    onPressed: _skipOnboarding,
                    child: Text(
                      'Skip',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.of(context).secondaryText,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),

              // Page content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    if (mounted) {
                      setState(() {
                        _currentPage = index;
                      });
                    }
                    // Auto-advance video pages after their duration
                    if (mounted &&
                        _pages[index].videoPath != null &&
                        _pages[index].videoDuration != null) {
                      registerTimer(
                        Timer(_pages[index].videoDuration!, () {
                          if (mounted &&
                              _currentPage == index &&
                              index < _pages.length - 1) {
                            _nextPage();
                          }
                        }),
                      );
                    }
                  },
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _buildPage(_pages[index], index);
                  },
                ),
              ),

              // Page indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => _buildIndicator(context, index == _currentPage),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Next/Get Started button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D9FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _currentPage == _pages.length - 1
                          ? 'Get Started'
                          : 'Next',
                      style: AppTypography.bodyMedium.copyWith(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page, int pageIndex) {
    final pageColors = AppColors.of(context);
    // #region agent log
    final logData = {
      'pageIndex': pageIndex,
      'hasVideoPath': page.videoPath != null,
      'hasIcon': page.icon != null,
      'animationPathsLength': _animationPaths.length,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'sessionId': 'debug-session',
      'runId': 'run1',
      'hypothesisId': 'A',
      'location': 'onboarding_screen.dart:252',
      'message': 'Building onboarding page',
    };
    File('/Users/gerardandre/n3rd_game/.cursor/debug.log').writeAsString('${jsonEncode(logData)}\n', mode: FileMode.append).then((_) {}, onError: (_) {});
    // #endregion
    // If page has video, show video player
    if (page.videoPath != null) {
      return Container(
        color: Colors.black,
        child: VideoPlayerWidget(
          videoPath: page.videoPath!,
          loop: false,
          autoplay: true,
        ),
      );
    }

    // Otherwise show animated graphic or icon/text layout
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated graphic (250px) or animation icon
          if (page.icon == null)
            const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: AnimatedGraphicsWidget(
                category: 'shared',
                width: 250,
                height: 250,
                loop: true,
                autoplay: true,
              ),
            )
          else
            // Replace icon with resized animation - positioned out of the way, compact size
            Builder(
              builder: (context) {
                // #region agent log
                final animationPath = pageIndex < _animationPaths.length ? _animationPaths[pageIndex] : 'OUT_OF_BOUNDS';
                final logData2 = {
                  'pageIndex': pageIndex,
                  'animationPath': animationPath,
                  'isValidIndex': pageIndex < _animationPaths.length,
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                  'sessionId': 'debug-session',
                  'runId': 'run1',
      'hypothesisId': 'A',
      'location': 'onboarding_screen.dart:292',
      'message': 'Accessing animation path',
    };
                File('/Users/gerardandre/n3rd_game/.cursor/debug.log').writeAsString('${jsonEncode(logData2)}\n', mode: FileMode.append).then((_) {}, onError: (_) {});
                // #endregion
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: SizedBox(
                    width: 80,
                    height: 80,
                    child: AnimationIcon(
                      animationPath: pageIndex < _animationPaths.length ? _animationPaths[pageIndex] : _animationPaths[0],
                      size: 80,
                      color: pageColors.primaryButton,
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: AppTypography.headlineLarge.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: pageColors.primaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              fontSize: 16,
              color: pageColors.secondaryText,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator(BuildContext context, bool isActive) {
    final indicatorColors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive
            ? indicatorColors.primaryButton
            : indicatorColors.tertiaryText,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final IconData? icon;
  final String? videoPath;
  final Duration? videoDuration;

  OnboardingPage({
    required this.title,
    required this.description,
    this.icon,
    this.videoPath,
    this.videoDuration,
  }) : assert(
         icon != null || videoPath != null,
         'Either icon or videoPath must be provided',
       );
}
