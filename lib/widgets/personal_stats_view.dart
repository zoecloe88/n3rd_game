import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/services/stats_service.dart';
import 'package:n3rd_game/widgets/stats_chart_widgets.dart';
import 'package:n3rd_game/widgets/chart_type_selector.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/utils/stats_preferences.dart';
import 'package:n3rd_game/services/analytics_service.dart';

/// Widget that displays personal statistics in the leaderboard context
class PersonalStatsView extends StatefulWidget {
  const PersonalStatsView({super.key});

  @override
  State<PersonalStatsView> createState() => _PersonalStatsViewState();
}

class _PersonalStatsViewState extends State<PersonalStatsView> {
  String _chartType = 'line';
  int _selectedDays = 30;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _trackView();
  }

  void _trackView() {
    // Use WidgetsBinding to ensure context is safe after frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final analyticsService =
          Provider.of<AnalyticsService>(context, listen: false);
      await analyticsService.logCustomEvent(
        'personal_stats_viewed',
        parameters: {
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    });
  }

  Future<void> _loadPreferences() async {
    final chartType = await StatsPreferences.getChartType();
    final timePeriod = await StatsPreferences.getTimePeriod();
    if (mounted) {
      setState(() {
        _chartType = chartType;
        _selectedDays = timePeriod;
        _isLoading = false;
      });
    }
  }

  Future<void> _onChartTypeChanged(String chartType) async {
    await StatsPreferences.setChartType(chartType);

    // Track analytics - check mounted before using context
    if (!mounted) return;
    final analyticsService =
        Provider.of<AnalyticsService>(context, listen: false);
    await analyticsService.logCustomEvent(
      'chart_type_changed',
      parameters: {
        'chart_type': chartType,
      },
    );

    if (mounted) {
      setState(() {
        _chartType = chartType;
      });
    }
  }

  Future<void> _onTimePeriodChanged(int days) async {
    await StatsPreferences.setTimePeriod(days);
    if (mounted) {
      setState(() {
        _selectedDays = days;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Consumer<StatsService>(
      builder: (context, statsService, _) {
        final stats = statsService.stats;
        final localizations = AppLocalizations.of(context);

        return RefreshIndicator(
          onRefresh: () async {
            await statsService.init();
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              // Header with chart type selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    localizations?.personalPerformance ??
                        'Personal Performance',
                    style: AppTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  ChartTypeSelector(
                    selectedChartType: _chartType,
                    onChanged: _onChartTypeChanged,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Stat summary cards
              _buildStatCard(
                '🎮',
                localizations?.gamesPlayed ?? 'Games Played',
                stats.totalGamesPlayed.toString(),
                context,
              ),
              const SizedBox(height: AppSpacing.md),
              _buildStatCard(
                '🏆',
                localizations?.highestScore ?? 'Highest Score',
                stats.highestScore.toString(),
                context,
              ),
              const SizedBox(height: AppSpacing.md),
              _buildStatCard(
                '✅',
                localizations?.correct ?? 'Correct Answers',
                stats.totalCorrectAnswers.toString(),
                context,
              ),
              const SizedBox(height: AppSpacing.md),
              _buildStatCard(
                '📊',
                localizations?.accuracy ?? 'Accuracy',
                '${stats.accuracy.toStringAsFixed(1)}%',
                context,
              ),
              const SizedBox(height: AppSpacing.xl),

              // Time period selector
              Align(
                alignment: Alignment.centerLeft,
                child: TimePeriodSelector(
                  selectedDays: _selectedDays,
                  onChanged: _onTimePeriodChanged,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Score Trend Chart
              ScoreTrendChart(
                dailyStats: stats.dailyStats,
                daysToShow: _selectedDays,
                chartType: _chartType,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Accuracy Trend Chart
              AccuracyTrendChart(
                dailyStats: stats.dailyStats,
                daysToShow: _selectedDays,
                chartType: _chartType,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Accuracy Distribution Chart (always pie chart)
              AccuracyDistributionChart(
                correctAnswers: stats.totalCorrectAnswers,
                wrongAnswers: stats.totalWrongAnswers,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Mode Performance Chart (always bar chart)
              ModePerformanceChart(
                modePlayCounts: stats.modePlayCounts,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        );
      },
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
