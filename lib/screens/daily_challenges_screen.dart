import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:n3rd_game/services/challenge_service.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/services/daily_challenge_leaderboard_service.dart';
import 'package:n3rd_game/models/daily_challenge.dart';
import 'package:n3rd_game/screens/daily_challenge_view_model.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/theme/app_radius.dart';
import 'package:n3rd_game/widgets/empty_state_widget.dart';
import 'package:n3rd_game/widgets/background_image_widget.dart';
import 'package:n3rd_game/widgets/video_background_widget.dart';
import 'package:n3rd_game/widgets/app_button.dart';
import 'package:n3rd_game/widgets/app_card.dart';
import 'package:n3rd_game/utils/feedback_helper.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/utils/responsive_helper.dart';

class DailyChallengesScreen extends StatefulWidget {
  const DailyChallengesScreen({super.key});

  @override
  State<DailyChallengesScreen> createState() => _DailyChallengesScreenState();
}

class _DailyChallengesScreenState extends State<DailyChallengesScreen>
    with WidgetsBindingObserver {
  int _leaderboardRefreshKey = 0;
  DailyChallengeViewModel? _viewModel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _viewModel?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh leaderboard when app comes to foreground
      _viewModel?.refreshLeaderboard();
      _refreshLeaderboard();
    }
  }

  void _refreshLeaderboard() {
    setState(() {
      _leaderboardRefreshKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    // Use Consumer to listen for subscription state changes
    return Consumer<SubscriptionService>(
      builder: (context, subscriptionService, _) {
        // Check if user has online access (Base or Premium)
        if (!subscriptionService.hasOnlineAccess) {
          return Scaffold(
            backgroundColor: AppColors.overlayDark,
            body: BackgroundImageWidget(
              imagePath: 'assets/background n3rd.png',
              child: SafeArea(
                child: Center(
                  child: AppCard.elevated(
                    margin: const EdgeInsets.all(AppSpacing.lg),
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 64,
                          color: colors.tertiaryText,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Premium Feature',
                          style: AppTypography.headlineLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.primaryText,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Daily Challenges are available for Premium subscribers.',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium.copyWith(
                            color: colors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppButton.primary(
                          label: 'Upgrade to Premium',
                          onPressed: () {
                            NavigationHelper.safeNavigate(
                              context,
                              '/subscription-management',
                            );
                          },
                          isFullWidth: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return Consumer2<ChallengeService, DailyChallengeLeaderboardService>(
          builder: (context, challengeService, leaderboardService, _) {
            // Initialize ViewModel if needed
            _viewModel ??= DailyChallengeViewModel(
              challengeService: challengeService,
              leaderboardService: leaderboardService,
            );

            return ChangeNotifierProvider.value(
              value: _viewModel!,
              child: Scaffold(
                body: VideoBackgroundWidget(
                  videoPath: 'assets/modeselectionscreen.mp4',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  loop: true,
                  autoplay: true,
                  child: SafeArea(
                    child: Column(
                      children: [
                        // Back button only (header moved to bottom)
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            children: [
                              AppButton(
                                icon: Icons.arrow_back,
                                onPressed: () =>
                                    NavigationHelper.safePop(context),
                                variant: AppButtonVariant.icon,
                                backgroundColor: Colors.transparent,
                                foregroundColor: colors.onDarkText,
                                semanticsLabel:
                                    AppLocalizations.of(context)?.backButton ??
                                        'Back',
                              ),
                              const Spacer(),
                            ],
                          ),
                        ),

                        // Challenges list
                        Expanded(
                          child: Consumer<DailyChallengeViewModel>(
                            builder: (context, viewModel, _) {
                              final todayChallenges = viewModel.todayChallenges;

                              if (todayChallenges.isEmpty) {
                                return EmptyStateWidget(
                                  icon: Icons.event_available,
                                  title: AppLocalizations.of(context)
                                          ?.noChallenges ??
                                      'No challenges available',
                                  description: AppLocalizations.of(context)
                                          ?.noChallengesDescription ??
                                      'Check back tomorrow for new challenges!',
                                );
                              }

                              // Find competitive challenge
                              final competitiveChallenge = todayChallenges
                                  .where((c) =>
                                      c.type == ChallengeType.dailyCompetitive,)
                                  .firstOrNull;

                              return ListView(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                  16,
                                  ResponsiveHelper.responsiveHeight(
                                          context, 0.10,)
                                      .clamp(60.0, 100.0),
                                  16,
                                  80,
                                ),
                                children: [
                                  // Top 5 Leaderboard (only for competitive challenge)
                                  if (competitiveChallenge != null)
                                    _buildTop5Leaderboard(
                                      context,
                                      competitiveChallenge.id,
                                      _leaderboardRefreshKey,
                                      viewModel,
                                    ),
                                  if (competitiveChallenge != null)
                                    const SizedBox(height: 16),
                                  Text(
                                    'Complete challenges to earn rewards!',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: colors.onDarkText
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  ...todayChallenges.map(
                                    (challenge) => _buildChallengeCard(
                                      context,
                                      challenge,
                                      viewModel,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        // Header at bottom
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Text(
                            'Daily Challenges',
                            style: AppTypography.headlineLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.onDarkText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChallengeCard(
    BuildContext context,
    DailyChallenge challenge,
    DailyChallengeViewModel viewModel,
  ) {
    final progress = challenge.progress.toDouble();
    final target = (challenge.target['count'] ??
            challenge.target['streak'] ??
            challenge.target['score'] ??
            1)
        .toDouble();
    final progressPercent =
        target > 0 ? (progress / target).clamp(0.0, 1.0) : 0.0;

    final colors = AppColors.of(context);
    return AppCard.filled(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      backgroundColor: challenge.isCompleted
          ? colors.success.withValues(alpha: 0.1)
          : colors.onDarkText.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge.title,
                      style: AppTypography.headlineLarge.copyWith(
                        color: colors.onDarkText,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      challenge.description,
                      style: AppTypography.bodyMedium.copyWith(
                        color: colors.onDarkText.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              if (challenge.isCompleted)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: colors.success,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check, color: colors.onDarkText, size: 20),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            child: LinearProgressIndicator(
              value: progressPercent,
              backgroundColor: colors.onDarkText.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                challenge.isCompleted ? colors.success : colors.accent,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${progress.toInt()}/${target.toInt()}',
                style: AppTypography.bodyMedium.copyWith(
                  color: colors.onDarkText.withValues(alpha: 0.7),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.stars, size: 16, color: colors.warning),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '${challenge.rewardPoints} pts',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.warning,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Play button for competitive challenges
          if (challenge.type == ChallengeType.dailyCompetitive) ...[
            const SizedBox(height: 12),
            FutureBuilder<int>(
              future: viewModel.getAttemptCount(challenge.id),
              builder: (context, snapshot) {
                final attemptCount = snapshot.data ?? 0;
                final maxAttempts = 5;
                final remainingAttempts = maxAttempts - attemptCount;
                final canPlay = remainingAttempts > 0 && !viewModel.isLoading;

                return Column(
                  children: [
                    if (attemptCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '$remainingAttempts of $maxAttempts attempts remaining',
                          style: AppTypography.bodyMedium.copyWith(
                            fontSize: 12,
                            color: canPlay
                                ? Colors.white.withValues(alpha: 0.7)
                                : Colors.red.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    AppButton(
                      variant: AppButtonVariant.primary,
                      icon: Icons.play_arrow,
                      label:
                          canPlay ? 'Play Challenge' : 'Max Attempts Reached',
                      onPressed: canPlay
                          ? () => _playCompetitiveChallenge(
                              context, challenge, viewModel,)
                          : null,
                      isLoading: viewModel.isLoading,
                      isFullWidth: true,
                      backgroundColor:
                          canPlay ? colors.warning : colors.disabled,
                      foregroundColor:
                          canPlay ? colors.primaryText : colors.disabledText,
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _playCompetitiveChallenge(
    BuildContext context,
    DailyChallenge challenge,
    DailyChallengeViewModel viewModel,
  ) async {
    if (!mounted) return;

    // Check if user is logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      FeedbackHelper.showWarning(
        context,
        'Please log in to play competitive challenges.',
      );
      return;
    }

    // Use ViewModel to play challenge
    final gameMode = await viewModel.playCompetitiveChallenge(challenge);
    if (!mounted) return;

    if (gameMode == null) {
      // Show error from ViewModel
      if (viewModel.errorMessage != null) {
        if (!mounted) return;
        FeedbackHelper.showError(
          // ignore: use_build_context_synchronously
          context,
          viewModel.errorMessage!,
        );
      }
      return;
    }

    // Get target rounds
    final targetRounds = challenge.target['rounds'] as int? ?? 5;

    // Navigate to game with challenge info
    try {
      if (!mounted) return;
      await NavigationHelper.safeNavigate(
        // ignore: use_build_context_synchronously
        context,
        '/game',
        arguments: {
          'mode': gameMode,
          'competitiveChallengeId': challenge.id,
          'targetRounds': targetRounds,
        },
      );
      if (!mounted) return;

      // Refresh leaderboard when returning from game
      viewModel.refreshLeaderboard();
      _refreshLeaderboard();
    } catch (e) {
      // Handle navigation error gracefully
      if (!mounted) return;
      final localizations = AppLocalizations.of(
        // ignore: use_build_context_synchronously
        context,
      );
      FeedbackHelper.showError(
        // ignore: use_build_context_synchronously
        context,
        localizations?.challengeNavigationError ??
            'Failed to start challenge. Please try again.',
      );
    }
  }

  Widget _buildTop5Leaderboard(
    BuildContext context,
    String challengeId,
    int refreshKey,
    DailyChallengeViewModel viewModel,
  ) {
    return FutureBuilder<List<DailyChallengeLeaderboardEntry>>(
      key: ValueKey(refreshKey),
      future: viewModel.getTop5Leaderboard(challengeId),
      builder: (context, snapshot) {
        final colors = AppColors.of(context);
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AppCard.filled(
            padding: const EdgeInsets.all(AppSpacing.lg),
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            backgroundColor: colors.onDarkText.withValues(alpha: 0.05),
            child: Center(
              child: CircularProgressIndicator(color: colors.onDarkText),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return AppCard.filled(
            padding: const EdgeInsets.all(AppSpacing.lg),
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            backgroundColor: colors.onDarkText.withValues(alpha: 0.05),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.leaderboard,
                      color: colors.onDarkText.withValues(alpha: 0.7),
                      size: 24,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Top 5 Today',
                      style: AppTypography.headlineLarge.copyWith(
                        color: colors.onDarkText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'No scores yet. Be the first!',
                  style: AppTypography.bodyMedium.copyWith(
                    color: colors.onDarkText.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          );
        }

        final entries = snapshot.data!;
        final userId = FirebaseAuth.instance.currentUser?.uid;

        // Get user rank if not in top 5
        Future<int?>? userRankFuture;
        if (userId != null) {
          userRankFuture = viewModel.getUserRank(challengeId, userId);
        }

        return FutureBuilder<int?>(
          future: userRankFuture,
          builder: (context, rankSnapshot) {
            final userRank = rankSnapshot.data;
            final showUserRank = userRank != null && userRank > 5;

            return AppCard.filled(
              padding: const EdgeInsets.all(AppSpacing.lg),
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              backgroundColor: colors.onDarkText.withValues(alpha: 0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.leaderboard,
                        color: colors.warning,
                        size: 24,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Top 5 Today',
                        style: AppTypography.headlineLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.onDarkText,
                        ),
                      ),
                      const Spacer(),
                      AppButton(
                        icon: Icons.refresh,
                        onPressed: () {
                          viewModel.refreshLeaderboard();
                          _refreshLeaderboard();
                        },
                        variant: AppButtonVariant.icon,
                        backgroundColor: Colors.transparent,
                        foregroundColor: colors.onDarkText,
                        semanticsLabel: 'Refresh',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...entries.asMap().entries.map((entry) {
                    final index = entry.key;
                    final leaderboardEntry = entry.value;
                    return _buildLeaderboardItem(index + 1, leaderboardEntry);
                  }),
                  // Show user rank if not in top 5
                  if (showUserRank) ...[
                    const SizedBox(height: AppSpacing.md),
                    Divider(color: colors.onDarkText.withValues(alpha: 0.2)),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                        horizontal: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: colors.info.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                        border: Border.all(
                          color: colors.info.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.person,
                            color: colors.info,
                            size: 24,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              'Your Rank: #$userRank',
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colors.onDarkText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLeaderboardItem(int rank, DailyChallengeLeaderboardEntry entry) {
    return Builder(
      builder: (context) {
        final colors = AppColors.of(context);
        final rankColors = [
          colors.warning, // Gold
          const Color(0xFFC0C0C0), // Silver
          const Color(0xFFCD7F32), // Bronze
          colors.onDarkText,
          colors.onDarkText,
        ];

        return Container(
          padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.md, horizontal: AppSpacing.md,),
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          decoration: BoxDecoration(
            color: colors.onDarkText.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          child: Row(
            children: [
              // Rank
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: rank <= 3 ? rankColors[rank - 1] : Colors.transparent,
                  shape: BoxShape.circle,
                  border: rank > 3
                      ? Border.all(
                          color: colors.onDarkText.withValues(alpha: 0.3),)
                      : null,
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: rank <= 3 ? colors.primaryText : colors.onDarkText,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Name
              Expanded(
                child: Text(
                  entry.displayName ?? 'Anonymous',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.onDarkText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Score
              Text(
                '${entry.score}',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.warning,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Time
              Text(
                '${entry.completionTime}s',
                style: AppTypography.bodyMedium.copyWith(
                  color: colors.onDarkText.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
