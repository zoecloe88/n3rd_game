import 'dart:async';
import 'package:n3rd_game/utils/unawaited_helper.dart';
import 'package:flutter/material.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/services/onboarding_service.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/services/haptic_service.dart';
import 'package:n3rd_game/widgets/video_background_widget.dart';
import 'package:n3rd_game/widgets/animated_graphics_widget.dart';
import 'package:n3rd_game/services/resource_manager.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/utils/provider_helper.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/utils/error_handler.dart';

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
  bool _dontShowAgain = false;
  bool _isLoading = true;
  bool _isSaving = false;

  List<OnboardingPage> _buildPages(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return [
      OnboardingPage(
        title:
            localizations?.onboardingWelcomeTitle ?? 'Welcome to N3RD Trivia',
        description: localizations?.onboardingWelcomeDescription ??
            'Test your memory and knowledge with challenging trivia games.',
        icon: Icons.quiz_outlined,
      ),
      OnboardingPage(
        title: localizations?.onboardingFeaturesTitle ?? 'Features & Editions',
        description: localizations?.onboardingFeaturesDescription ??
            'Access multiple trivia editions, AI-generated content, and personalized learning experiences.',
        icon: Icons.collections_bookmark_outlined,
      ),
      OnboardingPage(
        title: localizations?.onboardingPlayTitle ?? 'Play Solo or Online',
        description: localizations?.onboardingPlayDescription ??
            'Challenge yourself or compete with friends in multiplayer matches.',
        icon: Icons.people_outline,
      ),
      OnboardingPage(
        title: localizations?.onboardingProgressTitle ?? 'Track Your Progress',
        description: localizations?.onboardingProgressDescription ??
            'View your stats, achievements, and climb the leaderboards.',
        icon: Icons.leaderboard_outlined,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    // Initialize loading state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    final pages = _buildPages(context);
    if (_currentPage < pages.length - 1) {
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
      final analyticsService = ProviderHelper.safeGetOrThrow<AnalyticsService>(
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
    if (_isSaving) return; // Prevent multiple simultaneous saves

    setState(() {
      _isSaving = true;
    });

    try {
      // Always navigate to word-of-day screen regardless of checkbox state
      // Mark onboarding as completed if user checked "don't show again"
      if (_dontShowAgain) {
        final success = await _onboardingService.completeOnboarding();
        if (!mounted || !context.mounted) return;
        
        if (!success) {
          // Show error to user - onboarding save failed, but still navigate
          final localizations = AppLocalizations.of(context);
          ErrorHandler.showSnackBar(
            context,
            localizations?.onboardingSaveError ??
                'Failed to save onboarding status. Please try again.',
          );
        }
      }

      if (!mounted || !context.mounted) return;

      // Track completion in analytics
      try {
        final analyticsService = ProviderHelper.safeGetOrThrow<AnalyticsService>(
          context,
          listen: false,
        );
        unawaited(analyticsService.logOnboardingCompleted());
      } catch (e) {
        // Ignore analytics errors
      }

      if (mounted && context.mounted) {
        // Navigate to word of day after onboarding
        unawaited(NavigationHelper.safeNavigate(
          context,
          '/word-of-day',
          replace: true,
        ),);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final pages = _buildPages(context);

    return Scaffold(
      backgroundColor:
          Colors.black, // Black fallback - video background will cover
      body: VideoBackgroundWidget(
        videoPath: 'assets/youthscreen.mp4',
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              )
            : SafeArea(
                child: Stack(
                  children: [
                    Column(
                      children: [
                        // Skip button
                        Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Semantics(
                              label: localizations?.skip ?? 'Skip',
                              button: true,
                              enabled: !_isSaving,
                              child: TextButton(
                                onPressed: _isSaving ? null : _skipOnboarding,
                                child: Text(
                                  localizations?.skip ?? 'Skip',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
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
                            },
                            itemCount: pages.length,
                            itemBuilder: (context, index) {
                              return _buildPage(pages[index], index);
                            },
                          ),
                        ),

                        // Page indicators
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            pages.length,
                            (index) =>
                                _buildIndicator(context, index == _currentPage),
                          ),
                        ),

                        const SizedBox(height: AppSpacing.lg),

                        // "Don't show again" checkbox (only on last page)
                        if (_currentPage == pages.length - 1)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xl,),
                            child: Row(
                              children: [
                                Semantics(
                                  label: localizations?.onboardingDontShowAgain ??
                                      "Don't show onboarding again",
                                  checked: _dontShowAgain,
                                  child: Checkbox(
                                    value: _dontShowAgain,
                                    onChanged: (value) {
                                      setState(() {
                                        _dontShowAgain = value ?? false;
                                      });
                                      // Store preference to not show onboarding again
                                      _onboardingService
                                          .setDontShowAgain(_dontShowAgain);
                                    },
                                    activeColor: const Color(0xFF00D9FF),
                                    checkColor: Colors.white,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    localizations?.onboardingDontShowAgain ??
                                        "Don't show again",
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Next/Get Started button
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xl,),
                          child: SizedBox(
                            width: double.infinity,
                            child: Semantics(
                              label: _currentPage == pages.length - 1
                                  ? (localizations?.onboardingGetStarted ?? 'Get Started')
                                  : (localizations?.next ?? 'Next'),
                              button: true,
                              enabled: !_isSaving,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _nextPage,
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
                              child: _isSaving
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      _currentPage == pages.length - 1
                                          ? (localizations
                                                  ?.onboardingGetStarted ??
                                              'Get Started')
                                          : (localizations?.next ?? 'Next'),
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                            ),
                          ),
                        ),

                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                    // Loading overlay
                    if (_isSaving)
                      Container(
                        color: Colors.black.withValues(alpha: 0.3),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page, int pageIndex) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated graphic or icon for onboarding page
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
            // Icon for onboarding page
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Icon(
                page.icon!,
                size: 80,
                color: Colors.white,
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: AppTypography.headlineLarge.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Description
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              fontSize: 16,
              color: Colors.white,
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

  OnboardingPage({
    required this.title,
    required this.description,
    this.icon,
  });
  final String title;
  final String description;
  final IconData? icon;
}