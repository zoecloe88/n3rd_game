import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/services/stats_service.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/widgets/unified_background_widget.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/widgets/stats_chart_widgets.dart';
import 'package:n3rd_game/utils/responsive_helper.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _selectedDays = 30;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: UnifiedBackgroundWidget(
        videoPath:
            'assets/animations/Green Neutral Simple Serendipity Phone Wallpaper(1)/stat screen.mp4',
        fit: BoxFit.cover, // Fill screen, logos in upper portion
        alignment: Alignment.topCenter, // Align to top where logos are
        child: SafeArea(
          child: Consumer<StatsService>(
            builder: (context, statsService, _) {
              final stats = statsService.stats;
              return Column(
                children: [
                  // Minimal header (logos are in upper portion)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: [
                        // Back button removed - using bottom navigation instead
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          'Statistics',
                          style: AppTypography.headlineLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.of(context).onDarkText,
                          ),
                        ),
                        const Spacer(),
                        // Analytics Dashboard Button (Premium only)
                        Consumer<SubscriptionService>(
                          builder: (context, subscriptionService, _) {
                            if (subscriptionService.isPremium) {
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Semantics(
                                    label: AppLocalizations.of(
                                          context,
                                        )?.analytics ??
                                        'Advanced Analytics',
                                    button: true,
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.analytics_outlined,
                                        color: AppColors.of(context).info,
                                      ),
                                      onPressed: () => Navigator.of(
                                        context,
                                      ).pushNamed('/analytics'),
                                      tooltip: AppLocalizations.of(
                                            context,
                                          )?.analytics ??
                                          'Advanced Analytics',
                                    ),
                                  ),
                                  Semantics(
                                    label: AppLocalizations.of(
                                          context,
                                        )?.performanceInsights ??
                                        'Performance Insights',
                                    button: true,
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.psychology_outlined,
                                        color: AppColors.of(context).info,
                                      ),
                                      onPressed: () => Navigator.of(
                                        context,
                                      ).pushNamed('/performance-insights'),
                                      tooltip: AppLocalizations.of(
                                            context,
                                          )?.performanceInsights ??
                                          'Performance Insights',
                                    ),
                                  ),
                                ],
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                  ),

                  // Spacer to push content to lower portion (logos are in upper portion)
                  SizedBox(
                      height: ResponsiveHelper.responsiveHeight(context, 0.12)
                          .clamp(60.0, 120.0),),

                  // Stats Cards
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: [
                        _buildStatCard(
                          '🎮',
                          'Games Played',
                          stats.totalGamesPlayed.toString(),
                          context,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildStatCard(
                          '🏆',
                          'Highest Score',
                          stats.highestScore.toString(),
                          context,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildStatCard(
                          '✅',
                          'Correct Answers',
                          stats.totalCorrectAnswers.toString(),
                          context,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildStatCard(
                          '❌',
                          'Wrong Answers',
                          stats.totalWrongAnswers.toString(),
                          context,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildStatCard(
                          '📊',
                          'Accuracy',
                          '${stats.accuracy.toStringAsFixed(1)}%',
                          context,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildStatCard(
                          '⏱️',
                          'Time Attack Score',
                          stats.totalTimeAttackScore.toString(),
                          context,
                        ),
                        const SizedBox(height: AppSpacing.xl + 6),
                        // Streak Widget
                        StreakWidget(
                          currentStreak: stats.currentStreak,
                          longestStreak: stats.longestStreak,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        // Charts Section
                        Text(
                          'Performance Analytics',
                          style: AppTypography.titleLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.info,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        // Time Period Selector
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TimePeriodSelector(
                            selectedDays: _selectedDays,
                            onChanged: (days) {
                              setState(() {
                                _selectedDays = days;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        // Score Trend Chart
                        ScoreTrendChart(
                          dailyStats: stats.dailyStats,
                          daysToShow: _selectedDays,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        // Accuracy Trend Chart
                        AccuracyTrendChart(
                          dailyStats: stats.dailyStats,
                          daysToShow: _selectedDays,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        // Accuracy Distribution Chart
                        AccuracyDistributionChart(
                          correctAnswers: stats.totalCorrectAnswers,
                          wrongAnswers: stats.totalWrongAnswers,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        // Mode Performance Chart
                        ModePerformanceChart(
                          modePlayCounts: stats.modePlayCounts,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        // Mode Play Counts
                        if (stats.modePlayCounts.isNotEmpty) ...[
                          Text(
                            'Mode Play Counts',
                            style: AppTypography.titleLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.info,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          ...stats.modePlayCounts.entries.map((entry) {
                            final colors = AppColors.of(context);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: colors.cardBackground,
                                  borderRadius: BorderRadius.circular(12),
                                  // No border - removed
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      entry.key,
                                      style: AppTypography.bodyLarge.copyWith(
                                        color: colors.primaryText,
                                      ),
                                    ),
                                    Text(
                                      '${entry.value} plays',
                                      style: AppTypography.titleLarge.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colors.info,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String emoji,
    String label,
    String value,
    BuildContext context,
  ) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl - 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colors.cardBackground,
        // No border - removed
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(width: AppSpacing.xl - 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.bodyMedium.copyWith(
                    color: colors.secondaryText,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  value,
                  style: AppTypography.headlineMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.info,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
