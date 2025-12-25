import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/widgets/performance_chart_widget.dart';
import 'package:n3rd_game/widgets/heat_map_widget.dart';
import 'package:n3rd_game/models/performance_metric.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';

class AnalyticsDashboardScreen extends StatelessWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // NOTE: Subscription access is enforced by RouteGuard in main.dart
    // No need for redundant check here
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => NavigationHelper.safePop(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Analytics Dashboard',
                      style: AppTypography.headlineLarge.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Consumer<AnalyticsService>(
                    builder: (context, analyticsService, _) {
                      final weeklyTrends = analyticsService.getWeeklyTrends();
                      final monthlyTrends = analyticsService.getMonthlyTrends();
                      final categoryBreakdown =
                          analyticsService.getCategoryBreakdown();
                      final timeOfDayData =
                          analyticsService.getTimeOfDayPerformance();
                      final personalBests = analyticsService.getPersonalBests();
                      final improvements =
                          analyticsService.getImprovementTracking();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Personal Bests Cards
                          _buildPersonalBestsSection(personalBests),
                          const SizedBox(height: 16),

                          // Improvement Tracking
                          _buildImprovementSection(improvements),
                          const SizedBox(height: 16),

                          // Weekly Trends
                          if (weeklyTrends.isNotEmpty)
                            PerformanceChartWidget(
                              metrics: weeklyTrends,
                              title: 'Weekly Performance Trends',
                              showScore: true,
                            ),
                          const SizedBox(height: 16),

                          // Monthly Trends
                          if (monthlyTrends.isNotEmpty)
                            PerformanceChartWidget(
                              metrics: monthlyTrends,
                              title: 'Monthly Performance Trends',
                              showScore: true,
                            ),
                          const SizedBox(height: 16),

                          // Accuracy Trends
                          if (weeklyTrends.isNotEmpty)
                            PerformanceChartWidget(
                              metrics: weeklyTrends,
                              title: 'Accuracy Trends',
                              showScore: false,
                              showAccuracy: true,
                            ),
                          const SizedBox(height: 16),

                          // Category Breakdown
                          if (categoryBreakdown.isNotEmpty)
                            _buildCategoryBreakdownCard(categoryBreakdown),
                          const SizedBox(height: 16),

                          // Time-of-Day Heat Map
                          HeatMapWidget(timeOfDayData: timeOfDayData),
                          const SizedBox(height: 32),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
      ),
    );
  }

  Widget _buildPersonalBestsSection(Map<String, double> personalBests) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
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
          Text(
            'Personal Bests',
            style: AppTypography.headlineLarge.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildBestCard(
                  'Highest Score',
                  personalBests['highestScore']?.toStringAsFixed(0) ?? '0',
                  Icons.emoji_events,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBestCard(
                  'Best Accuracy',
                  '${personalBests['bestAccuracy']?.toStringAsFixed(1) ?? '0'}%',
                  Icons.track_changes,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildBestCard(
                  'Best Day Score',
                  personalBests['bestDayScore']?.toStringAsFixed(0) ?? '0',
                  Icons.calendar_today,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBestCard(
                  'Longest Streak',
                  personalBests['longestStreak']?.toStringAsFixed(0) ?? '0',
                  Icons.local_fire_department,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBestCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00D9FF).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF00D9FF), size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.bodyMedium.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImprovementSection(Map<String, double> improvements) {
    final scoreImprovement = improvements['scoreImprovement'] ?? 0.0;
    final accuracyImprovement = improvements['accuracyImprovement'] ?? 0.0;
    final isImproving = scoreImprovement > 0 || accuracyImprovement > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isImproving ? Colors.green : Colors.orange).withValues(
            alpha: 0.3,
          ),
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
              Icon(
                isImproving ? Icons.trending_up : Icons.trending_down,
                color: isImproving ? Colors.green : Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Improvement Tracking',
                style: AppTypography.headlineLarge.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildImprovementCard(
                  'Score',
                  scoreImprovement,
                  isImproving,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildImprovementCard(
                  'Accuracy',
                  accuracyImprovement,
                  isImproving,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImprovementCard(String label, double value, bool isPositive) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (isPositive ? Colors.green : Colors.orange).withValues(
          alpha: 0.1,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isPositive ? Colors.green : Colors.orange).withValues(
            alpha: 0.3,
          ),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}',
            style: AppTypography.bodyMedium.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isPositive ? Colors.green : Colors.orange,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdownCard(List categoryBreakdown) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
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
          Text(
            'Category Performance',
            style: AppTypography.headlineLarge.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: PieChart(
              PieChartData(
                sections: categoryBreakdown
                    .take(8)
                    .toList()
                    .asMap()
                    .entries
                    .map((entry) {
                  final index = entry.key;
                  final cat = entry.value as CategoryPerformance;
                  final colors = [
                    const Color(0xFF00D9FF),
                    const Color(0xFF00FF88),
                    const Color(0xFFFF00FF),
                    const Color(0xFFFFD700),
                    const Color(0xFFFF6B6B),
                    const Color(0xFF4ECDC4),
                    const Color(0xFFFFA07A),
                    const Color(0xFF9370DB),
                  ];
                  return PieChartSectionData(
                    value: cat.accuracy,
                    title: '${cat.accuracy.toStringAsFixed(0)}%',
                    color: colors[index % colors.length],
                    radius: 80,
                    titleStyle: AppTypography.bodyMedium.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 60,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: categoryBreakdown.take(8).toList().asMap().entries.map((
              entry,
            ) {
              final index = entry.key;
              final cat = entry.value as CategoryPerformance;
              final colors = [
                const Color(0xFF00D9FF),
                const Color(0xFF00FF88),
                const Color(0xFFFF00FF),
                const Color(0xFFFFD700),
                const Color(0xFFFF6B6B),
                const Color(0xFF4ECDC4),
                const Color(0xFFFFA07A),
                const Color(0xFF9370DB),
              ];
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colors[index % colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${cat.category}: ${cat.accuracy.toStringAsFixed(0)}%',
                    style: AppTypography.bodyMedium.copyWith(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
