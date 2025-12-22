import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/widgets/unified_background_widget.dart';
import 'package:n3rd_game/config/screen_animations_config.dart';
import 'package:n3rd_game/services/game_service.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_shadows.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/widgets/feature_tooltip_widget.dart';

class ModeSelectionScreen extends StatefulWidget {
  const ModeSelectionScreen({super.key});

  @override
  State<ModeSelectionScreen> createState() => _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends State<ModeSelectionScreen> {
  int _currentPage = 0;
  final PageController _pageController = PageController();

  // All game modes
  final List<Map<String, dynamic>> _gameModes = [
    {
      'title': 'Classic',
      'description': 'Memorize 10s, select 20s',
      'mode': GameMode.classic,
    },
    {
      'title': 'Classic II',
      'description': 'Faster—5s memorize, 10s select',
      'mode': GameMode.classicII,
    },
    {
      'title': 'Speed',
      'description': 'Words shown together, 7s answer',
      'mode': GameMode.speed,
    },
    {
      'title': 'Regular',
      'description': 'Words shown together, 15s answer',
      'mode': GameMode.regular,
    },
    {
      'title': 'Shuffle',
      'description': 'Tiles shuffle during play',
      'mode': GameMode.shuffle,
    },
    {
      'title': 'Challenge',
      'description': 'Gets harder each round',
      'mode': GameMode.challenge,
    },
    {
      'title': 'Random',
      'description': 'Different mode each round',
      'mode': GameMode.random,
    },
    {
      'title': 'Time Attack',
      'description': 'Score as much as possible in 60s',
      'mode': GameMode.timeAttack,
    },
    {
      'title': 'Streak',
      'description': 'Score multiplier increases with perfect rounds',
      'mode': GameMode.streak,
    },
    {
      'title': 'Blitz',
      'description': 'Ultra-fast: 3s memorize, 5s play',
      'mode': GameMode.blitz,
    },
    {
      'title': 'Marathon',
      'description': 'Infinite rounds, progressive difficulty',
      'mode': GameMode.marathon,
    },
    {
      'title': 'Perfect',
      'description': 'Must get all 3 correct, wrong = game over',
      'mode': GameMode.perfect,
    },
    {
      'title': 'Survival',
      'description': 'Start with 1 life, gain lives every 3 perfect rounds',
      'mode': GameMode.survival,
    },
    {
      'title': 'Precision',
      'description': 'Wrong selection = lose life immediately',
      'mode': GameMode.precision,
    },
    {
      'title': 'Flip Mode',
      'description': '10s study (4s visible, 6s flipping), 20s play',
      'mode': GameMode.flip,
    },
    {
      'title': 'AI Mode',
      'description': 'Adaptive difficulty that learns from you',
      'mode': GameMode.ai,
      'isPremium': true,
    },
    {
      'title': 'Practice',
      'description': 'No scoring, unlimited hints, learn at your pace',
      'mode': GameMode.practice,
      'isPremium': true,
    },
    {
      'title': 'Learning',
      'description': 'Review missed questions and improve',
      'mode': GameMode.learning,
      'isPremium': true,
    },
  ];

  int get _totalPages => (_gameModes.length / 4).ceil();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _showUpgradeDialog(BuildContext context) async {
    final localizations = AppLocalizations.of(context);
    final analyticsService = Provider.of<AnalyticsService>(
      context,
      listen: false,
    );

    // Log funnel step 1: Viewed locked feature
    await analyticsService.logConversionFunnelStep(
      step: 1,
      stepName: 'viewed_locked_feature',
      source: 'locked_mode',
    );

    // Log upgrade dialog shown
    await analyticsService.logUpgradeDialogShown(
      source: 'locked_mode',
      targetTier: 'premium', // AI/Practice/Learning require Premium
    );

    // Check if widget is still mounted before using context
    if (!mounted || !context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          localizations?.upgradeRequired ?? 'Upgrade Required',
          style: AppTypography.displayMedium.copyWith(fontSize: 20),
        ),
        content: Text(
          localizations?.upgradeModeDescription ??
              'This game mode is only available with Basic or Premium subscription. Upgrade to unlock all game modes!',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () {
              analyticsService.logUpgradeDialogDismissed(
                source: 'locked_mode',
                targetTier: 'premium',
              );
              Navigator.pop(context);
            },
            child: Text(
              localizations?.cancel ?? 'Cancel',
              style: AppTypography.labelLarge,
            ),
          ),
          ElevatedButton(
            onPressed: () {
              analyticsService.logConversionFunnelStep(
                step: 3,
                stepName: 'subscription_screen_opened',
                source: 'locked_mode',
                targetTier: 'premium',
              );
              Navigator.pop(context);
              NavigationHelper.safeNavigate(
                context,
                '/subscription-management',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            child: Text(
              localizations?.viewPlans ?? 'View Plans',
              style: AppTypography.labelLarge.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showShuffleDifficulty(BuildContext context) async {
    final colors = AppColors.of(context);
    final difficulty = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: colors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Shuffle Difficulty',
                style: AppTypography.displayMedium.copyWith(
                  fontSize: 24,
                  color: colors.primaryText,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return Column(
                    children: [
                      _difficultyOption(
                        context,
                        localizations?.easy ?? 'Easy',
                        localizations?.slowShuffles ?? 'Slow shuffles',
                        'easy',
                      ),
                      _difficultyOption(
                        context,
                        localizations?.medium ?? 'Medium',
                        localizations?.moderateShuffles ?? 'Moderate shuffles',
                        'medium',
                      ),
                      _difficultyOption(
                        context,
                        localizations?.hard ?? 'Hard',
                        localizations?.fastShuffles ?? 'Fast shuffles',
                        'hard',
                      ),
                      _difficultyOption(
                        context,
                        localizations?.insane ?? 'Insane',
                        localizations?.chaosMode ?? 'Chaos mode',
                        'insane',
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    if (difficulty != null) {
      if (context.mounted) {
        NavigationHelper.safeNavigate(
          context,
          '/mode-transition',
          arguments: {'mode': GameMode.shuffle, 'difficulty': difficulty},
        );
      }
    }
  }

  Future<void> _showFlipRevealMode(BuildContext context) async {
    final gameService = Provider.of<GameService>(context, listen: false);
    final colors = AppColors.of(context);

    final revealMode = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: colors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Flip Mode Reveal Setting',
                style: AppTypography.displayMedium.copyWith(
                  fontSize: 24,
                  color: colors.primaryText,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _difficultyOption(
                context,
                'Instant',
                'Tiles reveal immediately when selected',
                'instant',
              ),
              _difficultyOption(
                context,
                'Blind',
                'Select all 3, then reveal results',
                'blind',
              ),
              _difficultyOption(
                context,
                'Random',
                'Random reveal mode each round',
                'random',
              ),
            ],
          ),
        ),
      ),
    );
    if (revealMode != null) {
      gameService.setFlipRevealMode(revealMode);
      if (context.mounted) {
        // Log analytics for Flip Mode reveal mode selection
        final analyticsService = Provider.of<AnalyticsService>(
          context,
          listen: false,
        );
        final subscriptionService = Provider.of<SubscriptionService>(
          context,
          listen: false,
        );
        analyticsService.logGameModeSelected(
          'flip_$revealMode',
          subscriptionService.tierName,
        );

        NavigationHelper.safeNavigate(
          context,
          '/mode-transition',
          arguments: GameMode.flip,
        );
      }
    }
  }

  Widget _difficultyOption(
    BuildContext context,
    String title,
    String desc,
    String value,
  ) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => NavigationHelper.safePop(context, value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.cardBackgroundAlt,
            borderRadius: BorderRadius.circular(8),
            // No border - removed
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.labelLarge.copyWith(
                  fontSize: 16,
                  color: colors.primaryText,
                ),
              ),
              const SizedBox(height: AppSpacing.xs / 2),
              Text(
                desc,
                style: AppTypography.bodyMedium.copyWith(
                  fontSize: 13,
                  color: colors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context)?.settings.name ?? '/modes';
    final animationPath = ScreenAnimationsConfig.getAnimationForRoute(route);

    return Scaffold(
      backgroundColor: Colors.black,
      body: UnifiedBackgroundWidget(
        animationPath: animationPath,
        animationAlignment: Alignment.topCenter,
        animationPadding: const EdgeInsets.only(top: 60, left: 20),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              // Top app bar
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Semantics(
                      label: AppLocalizations.of(context)?.backButton ?? 'Back',
                      button: true,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => NavigationHelper.safePop(context),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Game Modes',
                      style: AppTypography.displayMedium.copyWith(
                        fontSize: 24,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Mode cards - 4 at a time with pagination
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    // Page view with 4 cards per page
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() {
                            _currentPage = index;
                          });
                        },
                        itemCount: _totalPages,
                        itemBuilder: (context, pageIndex) {
                          final startIndex = pageIndex * 4;
                          final endIndex = (startIndex + 4).clamp(
                            0,
                            _gameModes.length,
                          );
                          final pageModes = _gameModes.sublist(
                            startIndex,
                            endIndex,
                          );

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ...pageModes.map(
                                  (modeData) => Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: _buildModeCard(
                                      context,
                                      title: modeData['title'] as String,
                                      description:
                                          modeData['description'] as String,
                                      mode: modeData['mode'] as GameMode?,
                                      isPremium: modeData['isPremium'] == true,
                                      onTap:
                                          modeData['mode'] == GameMode.shuffle
                                          ? () =>
                                                _showShuffleDifficulty(context)
                                          : modeData['mode'] == GameMode.flip
                                          ? () => _showFlipRevealMode(context)
                                          : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    // Navigation arrows
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Back arrow
                          Semantics(
                            label: 'Previous page',
                            button: true,
                            enabled: _currentPage > 0,
                            child: IconButton(
                              icon: Icon(
                                Icons.arrow_back_ios,
                                color: _currentPage > 0
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.3),
                              ),
                              onPressed: _currentPage > 0
                                  ? () {
                                      if (_pageController.hasClients) {
                                        _pageController.previousPage(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          curve: Curves.easeInOut,
                                        );
                                      }
                                    }
                                  : null,
                            ),
                          ),
                          // Page indicators
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                              _totalPages,
                              (index) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: index == _currentPage
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Next arrow
                          Semantics(
                            label: 'Next page',
                            button: true,
                            enabled: _currentPage < _totalPages - 1,
                            child: IconButton(
                              icon: Icon(
                                Icons.arrow_forward_ios,
                                color: _currentPage < _totalPages - 1
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.3),
                              ),
                              onPressed: _currentPage < _totalPages - 1
                                  ? () {
                                      if (_pageController.hasClients) {
                                        _pageController.nextPage(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          curve: Curves.easeInOut,
                                        );
                                      }
                                    }
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard(
    BuildContext context, {
    required String title,
    required String description,
    GameMode? mode,
    bool isPremium = false,
    VoidCallback? onTap,
  }) {
    // Get color for left bar based on mode - ultralight colors
    Color getModeColor() {
      switch (mode) {
        case GameMode.classic:
          return Colors.blue.withValues(alpha: 0.3); // Ultralight blue
        case GameMode.regular:
          return Colors.green.withValues(alpha: 0.3); // Ultralight green
        case GameMode.shuffle:
          return Colors.purple.withValues(alpha: 0.3); // Ultralight purple
        case GameMode.timeAttack:
          return Colors.red.withValues(alpha: 0.3); // Ultralight red
        case GameMode.classicII:
          return Colors.orange.withValues(alpha: 0.3); // Ultralight orange
        case GameMode.speed:
          return Colors.teal.withValues(alpha: 0.3); // Ultralight teal
        case GameMode.random:
          return Colors.indigo.withValues(alpha: 0.3); // Ultralight indigo
        case GameMode.challenge:
          return Colors.amber.withValues(alpha: 0.3); // Ultralight amber
        case GameMode.flip:
          return Colors.cyan.withValues(
            alpha: 0.3,
          ); // Ultralight cyan for Flip Mode
        case GameMode.ai:
          return Colors.pink.withValues(alpha: 0.3); // Ultralight pink for AI
        case GameMode.practice:
          return Colors.lightBlue.withValues(
            alpha: 0.3,
          ); // Ultralight light blue for Practice
        case GameMode.learning:
          return Colors.lightGreen.withValues(
            alpha: 0.3,
          ); // Ultralight light green for Learning
        default:
          return Colors.grey.withValues(alpha: 0.3);
      }
    }

    // Check if mode is accessible for current subscription tier
    final subscriptionService = Provider.of<SubscriptionService>(
      context,
      listen: false,
    );
    // AI, Practice, and Learning modes require Premium, other modes check canAccessMode
    final isAccessible = mode == null
        ? true
        : (mode == GameMode.ai ||
                  mode == GameMode.practice ||
                  mode == GameMode.learning
              ? subscriptionService.isPremium
              : subscriptionService.canAccessMode(mode));
    final isLocked = mode != null && !isAccessible;

    final Widget cardContent = Semantics(
      label: isLocked ? '$title - Locked' : title,
      hint: description,
      button: true,
      enabled: !isLocked,
      child: InkWell(
        onTap: isLocked
            ? () => _showUpgradeDialog(context)
            : (onTap ??
                  () {
                    if (mode != null) {
                      // Practice and Learning modes go directly to their screens
                      if (mode == GameMode.practice) {
                        NavigationHelper.safeNavigate(context, '/practice');
                      } else if (mode == GameMode.learning) {
                        NavigationHelper.safeNavigate(context, '/learning');
                      } else {
                        // Other modes go through mode-transition
                        NavigationHelper.safeNavigate(
                          context,
                          '/mode-transition',
                          arguments: mode,
                        );
                      }
                    }
                  }),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(12),
            boxShadow: AppShadows.medium,
            // No border - removed for cleaner look
          ),
          child: Row(
            children: [
              // Colored vertical bar on left - ultralight
              Container(
                width: 6, // Slightly thinner for ultralight look
                decoration: BoxDecoration(
                  color: getModeColor(),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: AppTypography.headlineLarge.copyWith(
                                fontSize: 22, // Larger text
                                color: isLocked
                                    ? AppColors.of(context).tertiaryText
                                    : getModeColor().withValues(
                                        alpha: 0.8,
                                      ), // Ultralight title color
                              ),
                            ),
                          ),
                          if (isPremium && !isLocked)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: AppSpacing.sm,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Premium',
                                  style: AppTypography.labelSmall.copyWith(
                                    fontSize: 10,
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          if (isLocked)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: AppSpacing.sm,
                              ),
                              child: Text(
                                (mode == GameMode.ai ||
                                        mode == GameMode.practice ||
                                        mode == GameMode.learning)
                                    ? 'Premium'
                                    : 'Locked',
                                style: AppTypography.labelSmall.copyWith(
                                  fontSize: 12,
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        description,
                        style: AppTypography.bodyLarge.copyWith(
                          fontSize: 16, // Larger text
                          color: AppColors.of(context).secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.of(context).tertiaryText,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Wrap with feature tooltip if locked and premium
    if (isLocked && isPremium) {
      return FeatureTooltipWidget(
        featureName: title,
        requiresPremium: true,
        child: cardContent,
      );
    }

    return cardContent;
  }
}
