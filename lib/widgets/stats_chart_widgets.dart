import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/services/stats_service.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Line chart showing score trends over time
class ScoreTrendChart extends StatelessWidget {
  final List<DailyStats> dailyStats;
  final int daysToShow;

  const ScoreTrendChart({
    super.key,
    required this.dailyStats,
    this.daysToShow = 30,
  });

  @override
  Widget build(BuildContext context) {
    try {
      final colors = AppColors.of(context);
      final recentStats = dailyStats.length > daysToShow
          ? dailyStats.sublist(dailyStats.length - daysToShow)
          : dailyStats;

      if (recentStats.isEmpty) {
        return _buildEmptyState(context, 'No score data available');
      }

      final spots = recentStats.asMap().entries.map((entry) {
        return FlSpot(entry.key.toDouble(), entry.value.score.toDouble());
      }).toList();

      final maxScore = spots.isEmpty
          ? 100.0
          : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Score Trend (Last $daysToShow Days)',
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.primaryText,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: colors.secondaryText.withValues(alpha: 0.1),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: recentStats.length > 7
                            ? (recentStats.length / 7).ceilToDouble()
                            : 1,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= recentStats.length) {
                            return const Text('');
                          }
                          final date = recentStats[value.toInt()].date;
                          return Text(
                            '${date.month}/${date.day}',
                            style: AppTypography.bodyMedium.copyWith(
                              color: colors.secondaryText,
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        interval: maxScore > 0 ? maxScore / 5 : 20,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: AppTypography.bodyMedium.copyWith(
                            color: colors.secondaryText,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(
                      color: colors.secondaryText.withValues(alpha: 0.2),
                    ),
                  ),
                  minX: 0,
                  maxX: (recentStats.length - 1).toDouble(),
                  minY: 0,
                  maxY: maxScore * 1.1,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: colors.info,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(
                          radius: 4,
                          color: colors.info,
                          strokeWidth: 2,
                          strokeColor: colors.cardBackground,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: colors.info.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (touchedSpot) => colors.cardBackground,
                      tooltipRoundedRadius: 8,
                      tooltipPadding: const EdgeInsets.all(8),
                      getTooltipItems: (List<LineBarSpot> touchedSpots) {
                        return touchedSpots.map((spot) {
                          final stat = recentStats[spot.x.toInt()];
                          return LineTooltipItem(
                            '${DateFormat('MMM d').format(stat.date)}\nScore: ${stat.score}\nAccuracy: ${stat.accuracy.toStringAsFixed(1)}%',
                            AppTypography.bodyMedium.copyWith(
                              color: colors.primaryText,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e, stackTrace) {
      // Log error to Crashlytics
      FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'ScoreTrendChart rendering error',
        fatal: false,
      );
      if (kDebugMode) {
        debugPrint('ScoreTrendChart error: $e');
      }
      return _buildEmptyState(context, 'Unable to display chart');
    }
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    final colors = AppColors.of(context);
    return Container(
      height: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          message,
          style: AppTypography.bodyMedium.copyWith(color: colors.secondaryText),
        ),
      ),
    );
  }
}

/// Line chart showing accuracy trends
class AccuracyTrendChart extends StatelessWidget {
  final List<DailyStats> dailyStats;
  final int daysToShow;

  const AccuracyTrendChart({
    super.key,
    required this.dailyStats,
    this.daysToShow = 30,
  });

  @override
  Widget build(BuildContext context) {
    try {
      final colors = AppColors.of(context);
      final recentStats = dailyStats.length > daysToShow
          ? dailyStats.sublist(dailyStats.length - daysToShow)
          : dailyStats;

      if (recentStats.isEmpty) {
        return _buildEmptyState(context, 'No accuracy data available');
      }

      final spots = recentStats.asMap().entries.map((entry) {
        return FlSpot(entry.key.toDouble(), entry.value.accuracy);
      }).toList();

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Accuracy Trend (Last $daysToShow Days)',
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.primaryText,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: colors.secondaryText.withValues(alpha: 0.1),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: recentStats.length > 7
                            ? (recentStats.length / 7).ceilToDouble()
                            : 1,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= recentStats.length) {
                            return const Text('');
                          }
                          final date = recentStats[value.toInt()].date;
                          return Text(
                            '${date.month}/${date.day}',
                            style: AppTypography.bodyMedium.copyWith(
                              color: colors.secondaryText,
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        interval: 20,
                        getTitlesWidget: (value, meta) => Text(
                          '${value.toInt()}%',
                          style: AppTypography.bodyMedium.copyWith(
                            color: colors.secondaryText,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(
                      color: colors.secondaryText.withValues(alpha: 0.2),
                    ),
                  ),
                  minX: 0,
                  maxX: (recentStats.length - 1).toDouble(),
                  minY: 0,
                  maxY: 100,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: colors.success,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(
                          radius: 4,
                          color: colors.success,
                          strokeWidth: 2,
                          strokeColor: colors.cardBackground,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: colors.success.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (touchedSpot) => colors.cardBackground,
                      tooltipRoundedRadius: 8,
                      tooltipPadding: const EdgeInsets.all(8),
                      getTooltipItems: (List<LineBarSpot> touchedSpots) {
                        return touchedSpots.map((spot) {
                          final stat = recentStats[spot.x.toInt()];
                          return LineTooltipItem(
                            '${DateFormat('MMM d').format(stat.date)}\nAccuracy: ${stat.accuracy.toStringAsFixed(1)}%\nCorrect: ${stat.correctAnswers}\nWrong: ${stat.wrongAnswers}',
                            AppTypography.bodyMedium.copyWith(
                              color: colors.primaryText,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e, stackTrace) {
      // Log error to Crashlytics
      FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'AccuracyTrendChart rendering error',
        fatal: false,
      );
      if (kDebugMode) {
        debugPrint('AccuracyTrendChart error: $e');
      }
      return _buildEmptyState(context, 'Unable to display chart');
    }
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    final colors = AppColors.of(context);
    return Container(
      height: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          message,
          style: AppTypography.bodyMedium.copyWith(color: colors.secondaryText),
        ),
      ),
    );
  }
}

/// Bar chart comparing mode performance
class ModePerformanceChart extends StatelessWidget {
  final Map<String, int> modePlayCounts;

  const ModePerformanceChart({super.key, required this.modePlayCounts});

  @override
  Widget build(BuildContext context) {
    try {
      final colors = AppColors.of(context);

      if (modePlayCounts.isEmpty) {
        return _buildEmptyState(context, 'No mode data available');
      }

      final sortedModes = modePlayCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final maxValue = sortedModes.first.value.toDouble();

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mode Performance',
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.primaryText,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxValue * 1.2,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => colors.cardBackground,
                      tooltipRoundedRadius: 8,
                      tooltipPadding: const EdgeInsets.all(8),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final mode = sortedModes[groupIndex].key;
                        final count = sortedModes[groupIndex].value;
                        return BarTooltipItem(
                          '$mode\n$count plays',
                          AppTypography.bodyMedium.copyWith(
                            color: colors.primaryText,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= sortedModes.length) {
                            return const Text('');
                          }
                          final mode = sortedModes[value.toInt()].key;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              mode.length > 8
                                  ? '${mode.substring(0, 8)}...'
                                  : mode,
                              style: AppTypography.bodyMedium.copyWith(
                                color: colors.secondaryText,
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        interval:
                            maxValue > 0 ? (maxValue / 5).ceilToDouble() : 1,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: AppTypography.bodyMedium.copyWith(
                            color: colors.secondaryText,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(
                      color: colors.secondaryText.withValues(alpha: 0.2),
                    ),
                  ),
                  barGroups: sortedModes.asMap().entries.map((entry) {
                    final index = entry.key;
                    final count = entry.value.value;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: count.toDouble(),
                          color: _getColorForMode(entry.value.key, colors),
                          width: 20,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e, stackTrace) {
      // Log error to Crashlytics
      FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'ModePerformanceChart rendering error',
        fatal: false,
      );
      if (kDebugMode) {
        debugPrint('ModePerformanceChart error: $e');
      }
      return _buildEmptyState(context, 'Unable to display chart');
    }
  }

  Color _getColorForMode(String mode, AppColorScheme colors) {
    final colorsList = [
      colors.info,
      colors.success,
      colors.warning,
      colors.error,
      const Color(0xFF9C27B0),
      const Color(0xFF00BCD4),
    ];
    return colorsList[mode.hashCode % colorsList.length];
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    final colors = AppColors.of(context);
    return Container(
      height: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          message,
          style: AppTypography.bodyMedium.copyWith(color: colors.secondaryText),
        ),
      ),
    );
  }
}

/// Pie chart showing success/failure distribution
class AccuracyDistributionChart extends StatelessWidget {
  final int correctAnswers;
  final int wrongAnswers;

  const AccuracyDistributionChart({
    super.key,
    required this.correctAnswers,
    required this.wrongAnswers,
  });

  @override
  Widget build(BuildContext context) {
    try {
      final colors = AppColors.of(context);
      final total = correctAnswers + wrongAnswers;

      if (total == 0) {
        return _buildEmptyState(context, 'No answer data available');
      }

      final correctPercent = (correctAnswers / total * 100);
      final wrongPercent = (wrongAnswers / total * 100);

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Answer Distribution',
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.primaryText,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: correctPercent,
                      title: '${correctPercent.toStringAsFixed(1)}%',
                      color: colors.success,
                      radius: 80,
                      titleStyle: AppTypography.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    PieChartSectionData(
                      value: wrongPercent,
                      title: '${wrongPercent.toStringAsFixed(1)}%',
                      color: colors.error,
                      radius: 80,
                      titleStyle: AppTypography.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {},
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Correct', colors.success, correctAnswers),
                const SizedBox(width: 24),
                _buildLegendItem('Wrong', colors.error, wrongAnswers),
              ],
            ),
          ],
        ),
      );
    } catch (e, stackTrace) {
      // Log error to Crashlytics
      FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'AccuracyDistributionChart rendering error',
        fatal: false,
      );
      if (kDebugMode) {
        debugPrint('AccuracyDistributionChart error: $e');
      }
      return _buildEmptyState(context, 'Unable to display chart');
    }
  }

  Widget _buildLegendItem(String label, Color color, int count) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text('$label: $count', style: AppTypography.bodyMedium),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    final colors = AppColors.of(context);
    return Container(
      height: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          message,
          style: AppTypography.bodyMedium.copyWith(color: colors.secondaryText),
        ),
      ),
    );
  }
}

/// Streak visualization widget
class StreakWidget extends StatelessWidget {
  final int currentStreak;
  final int longestStreak;

  const StreakWidget({
    super.key,
    required this.currentStreak,
    required this.longestStreak,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Streak',
            style: AppTypography.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.primaryText,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: _buildStreakCard(
                  'Current',
                  currentStreak,
                  '🔥',
                  colors.warning,
                  context,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStreakCard(
                  'Longest',
                  longestStreak,
                  '⭐',
                  colors.info,
                  context,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard(
    String label,
    int value,
    String emoji,
    Color color,
    BuildContext context,
  ) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: AppTypography.headlineLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: colors.secondaryText,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Time period selector widget
class TimePeriodSelector extends StatelessWidget {
  final int selectedDays;
  final Function(int) onChanged;

  const TimePeriodSelector({
    super.key,
    required this.selectedDays,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final periods = [
      {'days': 7, 'label': '7 Days'},
      {'days': 30, 'label': '30 Days'},
      {'days': 90, 'label': '90 Days'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: periods.map((period) {
          final isSelected = selectedDays == period['days'];
          return GestureDetector(
            onTap: () => onChanged(period['days'] as int),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? colors.info : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                period['label'] as String,
                style: AppTypography.bodyMedium.copyWith(
                  color: isSelected ? Colors.white : colors.secondaryText,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
