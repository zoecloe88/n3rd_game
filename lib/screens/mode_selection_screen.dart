import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/widgets/unified_background_widget.dart';
import 'package:n3rd_game/services/game_service.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_shadows.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/utils/responsive_helper.dart';
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

  // All game modes with clearer descriptions
  final List<Map<String, dynamic>> _gameModes = [
    {
      'title': 'Classic',
      'description': 'Study words for 10 seconds, then select the correct answers in 20 seconds. Perfect for beginners.',
      'mode': GameMode.classic,
    },
    {
      'title': 'Classic II',
      'description': 'Faster-paced version: Study for 5 seconds, select answers in 10 seconds. For experienced players.',
      'mode': GameMode.classicII,
    },
    {
      'title': 'Speed',
      'description': 'Words and question shown together. Answer quickly within 7 seconds. Test your reflexes!',
      'mode': GameMode.speed,
    },
    {
      'title': 'Regular',
      'description': 'Words and question shown together. Take your time with 15 seconds to answer. Great for learning.',
      'mode': GameMode.regular,
    },
    {
      'title': 'Shuffle',
      'description': 'Tiles continuously shuffle during play. Stay focused and find the correct answers!',
      'mode': GameMode.shuffle,
    },
    {
      'title': 'Challenge',
      'description': 'Difficulty increases each round. Can you survive the escalating challenge?',
      'mode': GameMode.challenge,
    },
    {
      'title': 'Random',
      'description': 'Experience a different game mode each round. Never know what\'s coming next!',
      'mode': GameMode.random,
    },
    {
      'title': 'Time Attack',
      'description': 'Score as many points as possible within 60 seconds. Race against the clock!',
      'mode': GameMode.timeAttack,
    },
    {
      'title': 'Streak',
      'description': 'Score multiplier increases with each perfect round. Build your streak for maximum points!',
      'mode': GameMode.streak,
    },
    {
      'title': 'Blitz',
      'description': 'Ultra-fast mode: Study for 3 seconds, answer in 5 seconds. Only for the quickest minds!',
      'mode': GameMode.blitz,
    },
    {
      'title': 'Marathon',
      'description': 'Infinite rounds with progressive difficulty. How long can you last?',
      'mode': GameMode.marathon,
    },
    {
      'title': 'Perfect',
      'description': 'Must get all 3 answers correct. One wrong answer ends the game. Precision is key!',
      'mode': GameMode.perfect,
    },
    {
      'title': 'Survival',
      'description': 'Start with 1 life. Gain a life every 3 perfect rounds. Survive as long as possible!',
      'mode': GameMode.survival,
    },
    {
      'title': 'Precision',
      'description': 'Wrong selection loses a life immediately. Perfect accuracy required to succeed!',
      'mode': GameMode.precision,
    },
    {
      'title': 'Flip Mode',
      'description': 'Study for 10 seconds (4s visible, 6s flipping), then play for 20 seconds with face-down tiles.',
      'mode': GameMode.flip,
    },
    {
      'title': 'AI Mode',
      'description': 'AI adapts difficulty based on your performance. Personalized challenge that learns from you.',
      'mode': GameMode.ai,
      'isPremium': true,
    },
    {
      'title': 'Practice',
      'description': 'No scoring, unlimited hints. Learn at your own pace without pressure.',
      'mode': GameMode.practice,
      'isPremium': true,
    },
    {
      'title': 'Learning',
      'description': 'Review questions you missed and improve your knowledge. Track your progress over time.',
      'mode': GameMode.learning,
      'isPremium': true,
    },
  ];

  /// Get number of cards to show per page based on device type
  /// Tablets show 6 cards (2 columns x 3 rows), phones show 3 cards (1 column)
  int _cardsPerPage(BuildContext context) {
    return ResponsiveHelper.isTablet(context) ? 6 : 3;
  }

  int _totalPages(BuildContext context) {
    final cardsPerPage = _cardsPerPage(context);
    return (_gameModes.length / cardsPerPage).ceil();
  }

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
          style: AppTypography.displayMedium.copyWith(
            fontSize: ResponsiveHelper.isTablet(context)
                ? 24 // Larger on tablets
                : 20, // Standard size on phones
          ),
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
                  fontSize: ResponsiveHelper.isTablet(context)
                      ? 28 // Larger on tablets
                      : 24, // Standard size on phones
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
                  fontSize: ResponsiveHelper.isTablet(context)
                      ? 28 // Larger on tablets
                      : 24, // Standard size on phones
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
                  fontSize: ResponsiveHelper.isTablet(context)
                      ? 18 // Larger on tablets
                      : 16, // Standard size on phones
                  color: colors.primaryText,
                ),
              ),
              const SizedBox(height: AppSpacing.xs / 2),
              Text(
                desc,
                style: AppTypography.bodyMedium.copyWith(
                  fontSize: ResponsiveHelper.isTablet(context)
                      ? 15 // Larger on tablets
                      : 13, // Standard size on phones
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: UnifiedBackgroundWidget(
        // Remove large animation overlay - use icon-sized animations only
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
                        fontSize: ResponsiveHelper.isTablet(context)
                            ? 28 // Larger on tablets
                            : 24, // Standard size on phones
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Mode cards with responsive pagination (3 per page on phones, 6 on tablets)
              // Content positioned in lower portion to avoid overlapping animated logos in upper portion
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    // Spacer to push content to lower portion (logos are in upper portion)
                    SizedBox(height: ResponsiveHelper.responsiveHeight(context, 0.20).clamp(120.0, 200.0)),
                    
                    // Page view with responsive cards per page
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() {
                            _currentPage = index;
                          });
                        },
                        itemCount: _totalPages(context),
                        itemBuilder: (context, pageIndex) {
                          final cardsPerPage = _cardsPerPage(context);
                          final startIndex = pageIndex * cardsPerPage;
                          final endIndex = (startIndex + cardsPerPage).clamp(
                            0,
                            _gameModes.length,
                          );
                          final pageModes = _gameModes.sublist(
                            startIndex,
                            endIndex,
                          );

                          // On tablets, use GridView for 2 columns; on phones, use Column
                          final isTablet = ResponsiveHelper.isTablet(context);
                          
                          return SingleChildScrollView(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 32 : 16,
                                vertical: isTablet ? 16 : 0,
                              ),
                              child: isTablet
                                  ? GridView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        childAspectRatio: 1.2,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                      ),
                                      itemCount: pageModes.length,
                                      itemBuilder: (context, index) {
                                        final modeData = pageModes[index];
                                        return _buildModeCard(
                                          context,
                                          title: modeData['title'] as String,
                                          description:
                                              modeData['description'] as String,
                                          mode: modeData['mode'] as GameMode?,
                                          isPremium:
                                              modeData['isPremium'] == true,
                                          onTap: modeData['mode'] ==
                                                  GameMode.shuffle
                                              ? () => _showShuffleDifficulty(
                                                    context,
                                                  )
                                              : modeData['mode'] == GameMode.flip
                                                  ? () => _showFlipRevealMode(
                                                        context,
                                                      )
                                                  : null,
                                        );
                                      },
                                    )
                                  : Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        ...pageModes.map(
                                          (modeData) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 16,
                                            ),
                                            child: _buildModeCard(
                                              context,
                                              title:
                                                  modeData['title'] as String,
                                              description: modeData[
                                                  'description'] as String,
                                              mode:
                                                  modeData['mode'] as GameMode?,
                                              isPremium: modeData['isPremium'] ==
                                                  true,
                                              onTap: modeData['mode'] ==
                                                      GameMode.shuffle
                                                  ? () => _showShuffleDifficulty(
                                                        context,
                                                      )
                                                  : modeData['mode'] ==
                                                          GameMode.flip
                                                      ? () =>
                                                          _showFlipRevealMode(
                                                            context,
                                                          )
                                                      : null,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
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
                              _totalPages(context),
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
                            enabled: _currentPage < _totalPages(context) - 1,
                            child: IconButton(
                              icon: Icon(
                                Icons.arrow_forward_ios,
                                color: _currentPage < _totalPages(context) - 1
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.3),
                              ),
                              onPressed: _currentPage < _totalPages(context) - 1
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
    // Use responsive sizing - larger cards on tablets
    final double minCardHeight = ResponsiveHelper.isTablet(context)
        ? 160.0 // Larger cards on tablets
        : 130.0; // Standard size on phones
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
          constraints: BoxConstraints(
            minHeight: minCardHeight, // Minimum height - responsive based on device
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(12),
            boxShadow: AppShadows.medium,
            // No border - removed for cleaner look
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: AppTypography.headlineLarge.copyWith(
                                fontSize: ResponsiveHelper.isTablet(context)
                                    ? 24 // Larger on tablets
                                    : 20, // Standard size on phones
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
                                    fontSize: ResponsiveHelper.isTablet(context)
                                        ? 12
                                        : 10,
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
                      // Responsive description text - more lines on tablets
                      Text(
                        description,
                        style: AppTypography.bodyMedium.copyWith(
                          fontSize: ResponsiveHelper.isTablet(context)
                              ? 16 // Larger on tablets
                              : 14, // Standard size on phones
                          color: AppColors.of(context).secondaryText,
                        ),
                        maxLines: ResponsiveHelper.isTablet(context)
                            ? 3 // More lines on tablets
                            : 2, // Limit to 2 lines on phones
                        overflow: TextOverflow.ellipsis, // Show ellipsis if too long
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
