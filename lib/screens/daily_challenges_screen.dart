import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:n3rd_game/services/challenge_service.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/services/daily_challenge_leaderboard_service.dart';
import 'package:n3rd_game/services/game_service.dart';
import 'package:n3rd_game/models/daily_challenge.dart';
import 'package:n3rd_game/widgets/unified_background_widget.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_shadows.dart';
import 'package:n3rd_game/widgets/empty_state_widget.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';

class DailyChallengesScreen extends StatefulWidget {
  const DailyChallengesScreen({super.key});

  @override
  State<DailyChallengesScreen> createState() => _DailyChallengesScreenState();
}

class _DailyChallengesScreenState extends State<DailyChallengesScreen>
    with WidgetsBindingObserver {
  int _leaderboardRefreshKey = 0;
  final Set<String> _loadingChallenges =
      {}; // Track challenges being loaded to prevent race condition

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh leaderboard when app comes to foreground
      // This ensures leaderboard is up-to-date after returning from game screen
      // The refresh is lightweight (just updates FutureBuilder key)
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
            backgroundColor: colors.background,
            body: UnifiedBackgroundWidget(
              child: SafeArea(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppShadows.large,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 64,
                          color: colors.tertiaryText,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Premium Feature',
                          style: AppTypography.headlineLarge.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: colors.primaryText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Daily Challenges are available for Premium subscribers.',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium.copyWith(
                            fontSize: 14,
                            color: colors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            NavigationHelper.safeNavigate(
                              context,
                              '/subscription-management',
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primaryButton,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                          ),
                          child: Text(
                            'Upgrade to Premium',
                            style: AppTypography.bodyMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: colors.background,
          body: UnifiedBackgroundWidget(
            child: SafeArea(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => NavigationHelper.safePop(context),
                          tooltip: AppLocalizations.of(context)?.backButton ??
                              'Back',
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Daily Challenges',
                          style: AppTypography.headlineLarge.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Challenges list
                  Expanded(
                    child: Consumer<ChallengeService>(
                      builder: (context, challengeService, _) {
                        final todayChallenges =
                            challengeService.todayChallenges;

                        if (todayChallenges.isEmpty) {
                          return EmptyStateWidget(
                            icon: Icons.event_available,
                            title: AppLocalizations.of(context)?.noChallenges ??
                                'No challenges available',
                            description: AppLocalizations.of(
                                  context,
                                )?.noChallengesDescription ??
                                'Check back tomorrow for new challenges!',
                          );
                        }

                        // Find competitive challenge
                        final competitiveChallenge = todayChallenges
                            .where(
                                (c) => c.type == ChallengeType.dailyCompetitive)
                            .firstOrNull;

                        return ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            // Top 5 Leaderboard (only for competitive challenge)
                            if (competitiveChallenge != null)
                              _buildTop5Leaderboard(
                                competitiveChallenge.id,
                                _leaderboardRefreshKey,
                              ),
                            const SizedBox(height: 16),
                            Text(
                              'Complete challenges to earn rewards!',
                              style: AppTypography.bodyMedium.copyWith(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ...todayChallenges.map(
                              (challenge) => _buildChallengeCard(challenge),
                            ),
                            const SizedBox(height: 32),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChallengeCard(DailyChallenge challenge) {
    final progress = challenge.progress.toDouble();
    final target = (challenge.target['count'] ??
            challenge.target['streak'] ??
            challenge.target['score'] ??
            1)
        .toDouble();
    final progressPercent =
        target > 0 ? (progress / target).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: challenge.isCompleted
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: challenge.isCompleted
              ? Colors.green.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
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
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      challenge.description,
                      style: AppTypography.bodyMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              if (challenge.isCompleted)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progressPercent,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                challenge.isCompleted ? Colors.green : const Color(0xFF00D9FF),
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${progress.toInt()}/${target.toInt()}',
                style: AppTypography.bodyMedium.copyWith(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.stars, size: 16, color: Color(0xFFFFD700)),
                  const SizedBox(width: 4),
                  Text(
                    '${challenge.rewardPoints} pts',
                    style: AppTypography.bodyMedium.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFFD700),
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
              future: DailyChallengeLeaderboardService().getAttemptCount(
                challenge.id,
                null,
              ),
              builder: (context, snapshot) {
                final attemptCount = snapshot.data ?? 0;
                final maxAttempts = 5;
                final remainingAttempts = maxAttempts - attemptCount;
                final canPlay = remainingAttempts > 0;

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
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (canPlay &&
                                !_loadingChallenges.contains(challenge.id))
                            ? () =>
                                _playCompetitiveChallenge(context, challenge)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              canPlay ? const Color(0xFFFFD700) : Colors.grey,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.play_arrow, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              canPlay
                                  ? 'Play Challenge'
                                  : 'Max Attempts Reached',
                              style: AppTypography.bodyMedium.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
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

  void _playCompetitiveChallenge(
    BuildContext context,
    DailyChallenge challenge,
  ) async {
    // Prevent race condition - disable button immediately
    if (_loadingChallenges.contains(challenge.id)) {
      return; // Already loading
    }

    setState(() {
      _loadingChallenges.add(challenge.id);
    });

    // Store context references before async calls
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // Check if user is logged in
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Please log in to play competitive challenges.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Double-check attempt count right before playing to prevent race condition
      final leaderboardService = DailyChallengeLeaderboardService();
      final attemptCount = await leaderboardService.getAttemptCount(
        challenge.id,
        null,
      );
      if (!mounted) return;
      if (attemptCount >= 5) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Maximum attempts (5) reached for this challenge.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Validate challenge type is competitive
      if (challenge.type != ChallengeType.dailyCompetitive) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Invalid challenge type. Only competitive challenges can be played.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Validate challenge is for today (using UTC for consistency)
      final today = DateTime.now().toUtc();
      final challengeDate = challenge.date.toUtc();
      if (challengeDate.year != today.year ||
          challengeDate.month != today.month ||
          challengeDate.day != today.day) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('This challenge is not available today.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final targetMode = challenge.target['mode'] as String?;
      final targetRounds = challenge.target['rounds'] as int? ?? 5;

      // Map challenge mode string to GameMode with validation
      GameMode? gameMode;
      switch (targetMode) {
        case 'Blitz':
          gameMode = GameMode.blitz;
          break;
        case 'Speed':
          gameMode = GameMode.speed;
          break;
        case 'Classic':
          gameMode = GameMode.classic;
          break;
        case 'Streak':
          gameMode = GameMode.streak;
          break;
        case 'Shuffle':
          gameMode = GameMode.shuffle;
          break;
        default:
          // Show error if mode is invalid
          debugPrint('Invalid challenge mode: $targetMode');
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Invalid challenge mode. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
      }

      // Navigate to game with challenge info (setCompetitiveChallenge will be called in game screen)
      if (!mounted) return;
      final navigatorContext = context;
      if (!navigatorContext.mounted) return;
      await NavigationHelper.safeNavigate(
        navigatorContext,
        '/game',
        arguments: {
          'mode': gameMode,
          'competitiveChallengeId': challenge.id,
          'targetRounds': targetRounds,
        },
      );

      // Refresh leaderboard when returning from game
      if (mounted) {
        _refreshLeaderboard();
      }
    } finally {
      // Always remove from loading set
      if (mounted) {
        setState(() {
          _loadingChallenges.remove(challenge.id);
        });
      }
    }
  }

  Widget _buildTop5Leaderboard(String challengeId, int refreshKey) {
    final leaderboardService = DailyChallengeLeaderboardService();

    return FutureBuilder<List<DailyChallengeLeaderboardEntry>>(
      key: ValueKey(refreshKey),
      future: leaderboardService.getTop5Leaderboard(challengeId: challengeId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.leaderboard,
                      color: Colors.white.withValues(alpha: 0.7),
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Top 5 Today',
                      style: AppTypography.headlineLarge.copyWith(
                        fontSize: 20,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'No scores yet. Be the first!',
                  style: AppTypography.bodyMedium.copyWith(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.7),
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
          userRankFuture = leaderboardService.getUserRank(
            challengeId: challengeId,
            userId: userId,
          );
        }

        return FutureBuilder<int?>(
          future: userRankFuture,
          builder: (context, rankSnapshot) {
            final userRank = rankSnapshot.data;
            final showUserRank = userRank != null && userRank > 5;

            return Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.leaderboard,
                        color: Color(0xFFFFD700),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Top 5 Today',
                        style: AppTypography.headlineLarge.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          Icons.refresh,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: _refreshLeaderboard,
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...entries.asMap().entries.map((entry) {
                    final index = entry.key;
                    final leaderboardEntry = entry.value;
                    return _buildLeaderboardItem(index + 1, leaderboardEntry);
                  }),
                  // Show user rank if not in top 5
                  if (showUserRank) ...[
                    const SizedBox(height: 12),
                    Divider(color: Colors.white.withValues(alpha: 0.2)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.person,
                            color: Colors.blue,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Your Rank: #$userRank',
                              style: AppTypography.bodyMedium.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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
    final rankColors = [
      const Color(0xFFFFD700), // Gold
      const Color(0xFFC0C0C0), // Silver
      const Color(0xFFCD7F32), // Bronze
      Colors.white,
      Colors.white,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
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
                  ? Border.all(color: Colors.white.withValues(alpha: 0.3))
                  : null,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: AppTypography.bodyMedium.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: rank <= 3 ? Colors.black : Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name
          Expanded(
            child: Text(
              entry.displayName ?? 'Anonymous',
              style: AppTypography.bodyMedium.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Score
          Text(
            '${entry.score}',
            style: AppTypography.bodyMedium.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFFFD700),
            ),
          ),
          const SizedBox(width: 8),
          // Time
          Text(
            '${entry.completionTime}s',
            style: AppTypography.bodyMedium.copyWith(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
