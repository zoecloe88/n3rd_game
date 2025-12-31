import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/widgets/performance_chart_widget.dart';
import 'package:n3rd_game/widgets/heat_map_widget.dart';
import 'package:n3rd_game/models/performance_metric.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/widgets/background_image_widget.dart';
import 'package:n3rd_game/widgets/app_button.dart';
import 'package:n3rd_game/widgets/app_card.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/widgets/error_recovery_widget.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Analytics Dashboard screen displaying comprehensive performance analytics
///
/// Features:
/// - Personal bests tracking
/// - Improvement tracking over time
/// - Weekly and monthly performance trends
/// - Accuracy trends visualization
/// - Category performance breakdown (pie chart)
/// - Time-of-day performance heat map
/// - Requires Premium subscription (enforced by RouteGuard)
///
/// Usage:
/// ```dart
/// Navigator.pushNamed(context, '/analytics');
/// ```
class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() =>
      _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  // Constants
  static const int _maxCategoriesToShow = 8;
  static const double _pieChartHeight = 300.0;
  static const double _pieChartRadius = 80.0;
  static const double _pieChartCenterRadius = 60.0;
  static const double _pieChartSectionsSpace = 2.0;
  static const double _legendIndicatorSize = 12.0;
  static const double _iconSize = 24.0;
  static const String _labelHighestScore = 'Highest Score';
  static const String _labelBestAccuracy = 'Best Accuracy';
  static const String _labelBestDayScore = 'Best Day Score';
  static const String _labelLongestStreak = 'Longest Streak';
  static const String _labelScore = 'Score';
  static const String _labelAccuracy = 'Accuracy';
  static const String _titlePersonalBests = 'Personal Bests';
  static const String _titleImprovementTracking = 'Improvement Tracking';
  static const String _titleCategoryPerformance = 'Category Performance';

  // Pie chart color palette (extracted to avoid duplication)
  static const List<Color> _pieChartColors = [
    Color(0xFF00D9FF), // Accent cyan
    Color(0xFF00FF88), // Success green variant
    Color(0xFFFF00FF), // Magenta
    Color(0xFFFFD700), // Gold
    Color(0xFFFF6B6B), // Coral red
    Color(0xFF4ECDC4), // Teal
    Color(0xFFFFA07A), // Light salmon
    Color(0xFF9370DB), // Medium purple
  ];

  String? _errorMessage;

  // Memoization cache
  List<PerformanceMetric>? _cachedWeeklyTrends;
  List<PerformanceMetric>? _cachedMonthlyTrends;
  List<CategoryPerformance>? _cachedCategoryBreakdown;
  List<TimeOfDayPerformance>? _cachedTimeOfDayData;
  Map<String, double>? _cachedPersonalBests;
  Map<String, double>? _cachedImprovements;

  @override
  Widget build(BuildContext context) {
    // NOTE: Subscription access is enforced by RouteGuard in main.dart
    // No need for redundant check here
    final colors = AppColors.of(context);

    // Show error state if data loading failed
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: colors.background,
        body: ErrorRecoveryWidget(
          errorMessage: _errorMessage!,
          onRetry: () {
            setState(() {
              _errorMessage = null;
            });
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: BackgroundImageWidget(
        imagePath: 'assets/background n3rd.png',
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    AppButton(
                      icon: Icons.arrow_back,
                      onPressed: () => NavigationHelper.safePop(context),
                      variant: AppButtonVariant.icon,
                      backgroundColor: Colors.transparent,
                      foregroundColor: colors.onDarkText,
                      semanticsLabel:
                          'Go back. Double tap to return to previous screen',
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Analytics Dashboard',
                      style: AppTypography.headlineLarge.copyWith(
                        color: colors.onDarkText,
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Consumer<AnalyticsService>(
                    builder: (context, analyticsService, _) {
                      try {
                        // Memoize data fetching
                        final weeklyTrends = analyticsService.getWeeklyTrends();
                        final monthlyTrends =
                            analyticsService.getMonthlyTrends();
                        final categoryBreakdown =
                            analyticsService.getCategoryBreakdown();
                        final timeOfDayData =
                            analyticsService.getTimeOfDayPerformance();
                        final personalBests =
                            analyticsService.getPersonalBests();
                        final improvements =
                            analyticsService.getImprovementTracking();

                        // Update cache if data changed
                        if (_cachedWeeklyTrends != weeklyTrends ||
                            _cachedMonthlyTrends != monthlyTrends ||
                            _cachedCategoryBreakdown != categoryBreakdown ||
                            _cachedTimeOfDayData != timeOfDayData ||
                            _cachedPersonalBests != personalBests ||
                            _cachedImprovements != improvements) {
                          _cachedWeeklyTrends = weeklyTrends;
                          _cachedMonthlyTrends = monthlyTrends;
                          _cachedCategoryBreakdown = categoryBreakdown;
                          _cachedTimeOfDayData = timeOfDayData;
                          _cachedPersonalBests = personalBests;
                          _cachedImprovements = improvements;
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Personal Bests Cards
                            _buildPersonalBestsSection(context, personalBests),
                            const SizedBox(height: AppSpacing.md),

                            // Improvement Tracking
                            _buildImprovementSection(context, improvements),
                            const SizedBox(height: AppSpacing.md),

                            // Weekly Trends
                            if (weeklyTrends.isNotEmpty)
                              Semantics(
                                label:
                                    'Weekly Performance Trends chart. Shows performance over the past week',
                                child: PerformanceChartWidget(
                                  metrics: weeklyTrends,
                                  title: 'Weekly Performance Trends',
                                  showScore: true,
                                ),
                              ),
                            const SizedBox(height: AppSpacing.md),

                            // Monthly Trends
                            if (monthlyTrends.isNotEmpty)
                              Semantics(
                                label:
                                    'Monthly Performance Trends chart. Shows performance over the past month',
                                child: PerformanceChartWidget(
                                  metrics: monthlyTrends,
                                  title: 'Monthly Performance Trends',
                                  showScore: true,
                                ),
                              ),
                            const SizedBox(height: AppSpacing.md),

                            // Accuracy Trends
                            if (weeklyTrends.isNotEmpty)
                              Semantics(
                                label:
                                    'Accuracy Trends chart. Shows accuracy percentage over time',
                                child: PerformanceChartWidget(
                                  metrics: weeklyTrends,
                                  title: 'Accuracy Trends',
                                  showScore: false,
                                  showAccuracy: true,
                                ),
                              ),
                            const SizedBox(height: AppSpacing.md),

                            // Category Breakdown
                            if (categoryBreakdown.isNotEmpty)
                              _buildCategoryBreakdownCard(
                                  context, categoryBreakdown,),
                            const SizedBox(height: AppSpacing.md),

                            // Time-of-Day Heat Map
                            Semantics(
                              label:
                                  'Time of day performance heat map. Shows when you perform best throughout the day',
                              child:
                                  HeatMapWidget(timeOfDayData: timeOfDayData),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                          ],
                        );
                      } catch (e) {
                        LoggerService.error(
                          'AnalyticsDashboardScreen: Error loading analytics',
                          error: e,
                          stack: StackTrace.current,
                          fatal: false,
                        );
                        if (mounted) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() {
                                _errorMessage =
                                    'Failed to load analytics data. Please try again.';
                              });
                            }
                          });
                        }
                        return const SizedBox.shrink();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build personal bests section
  ///
  /// Displays cards showing the user's personal best achievements.
  ///
  /// Parameters:
  /// - [context]: Build context for accessing theme
  /// - [personalBests]: Map containing personal best values
  Widget _buildPersonalBestsSection(
      BuildContext context, Map<String, double> personalBests,) {
    final colors = AppColors.of(context);

    return Semantics(
      label: 'Personal Bests section. Your highest achievements',
      child: AppCard.filled(
        padding: const EdgeInsets.all(AppSpacing.lg),
        backgroundColor: colors.onDarkText.withValues(alpha: 0.05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _titlePersonalBests,
              style: AppTypography.headlineMedium.copyWith(
                color: colors.onDarkText,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _buildBestCard(
                    context: context,
                    label: _labelHighestScore,
                    value: personalBests['highestScore']?.toStringAsFixed(0) ??
                        '0',
                    icon: Icons.emoji_events,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _buildBestCard(
                    context: context,
                    label: _labelBestAccuracy,
                    value:
                        '${personalBests['bestAccuracy']?.toStringAsFixed(1) ?? '0'}%',
                    icon: Icons.track_changes,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _buildBestCard(
                    context: context,
                    label: _labelBestDayScore,
                    value: personalBests['bestDayScore']?.toStringAsFixed(0) ??
                        '0',
                    icon: Icons.calendar_today,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _buildBestCard(
                    context: context,
                    label: _labelLongestStreak,
                    value: personalBests['longestStreak']?.toStringAsFixed(0) ??
                        '0',
                    icon: Icons.local_fire_department,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build best card widget
  ///
  /// Displays a single personal best metric with icon, value, and label.
  ///
  /// Parameters:
  /// - [context]: Build context for accessing theme
  /// - [label]: Label text for the metric
  /// - [value]: Value to display
  /// - [icon]: Icon to display
  Widget _buildBestCard({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
  }) {
    final colors = AppColors.of(context);

    return Semantics(
      label: '$label: $value',
      child: AppCard.filled(
        padding: const EdgeInsets.all(AppSpacing.md),
        backgroundColor: colors.onDarkText.withValues(alpha: 0.05),
        child: Column(
          children: [
            Icon(
              icon,
              color: colors.accent,
              size: _iconSize,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              value,
              style: AppTypography.headlineMedium.copyWith(
                color: colors.onDarkText,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: colors.onDarkText.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build improvement section
  ///
  /// Displays improvement tracking metrics showing score and accuracy changes.
  ///
  /// Parameters:
  /// - [context]: Build context for accessing theme
  /// - [improvements]: Map containing improvement values
  Widget _buildImprovementSection(
      BuildContext context, Map<String, double> improvements,) {
    final colors = AppColors.of(context);
    final scoreImprovement = improvements['scoreImprovement'] ?? 0.0;
    final accuracyImprovement = improvements['accuracyImprovement'] ?? 0.0;
    final isImproving = scoreImprovement > 0 || accuracyImprovement > 0;

    return Semantics(
      label:
          'Improvement Tracking. ${isImproving ? "Improving" : "Declining"} performance',
      child: AppCard.filled(
        padding: const EdgeInsets.all(AppSpacing.lg),
        backgroundColor: colors.onDarkText.withValues(alpha: 0.05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isImproving ? Icons.trending_up : Icons.trending_down,
                  color: isImproving ? colors.success : colors.warning,
                  size: _iconSize,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  _titleImprovementTracking,
                  style: AppTypography.headlineMedium.copyWith(
                    color: colors.onDarkText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _buildImprovementCard(
                    context: context,
                    label: _labelScore,
                    value: scoreImprovement,
                    isPositive: isImproving,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _buildImprovementCard(
                    context: context,
                    label: _labelAccuracy,
                    value: accuracyImprovement,
                    isPositive: isImproving,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build improvement card widget
  ///
  /// Displays a single improvement metric with value and label.
  ///
  /// Parameters:
  /// - [context]: Build context for accessing theme
  /// - [label]: Label text for the metric
  /// - [value]: Improvement value to display
  /// - [isPositive]: Whether the improvement is positive
  Widget _buildImprovementCard({
    required BuildContext context,
    required String label,
    required double value,
    required bool isPositive,
  }) {
    final colors = AppColors.of(context);
    final cardColor =
        (isPositive ? colors.success : colors.warning).withValues(alpha: 0.1);
    final textColor = isPositive ? colors.success : colors.warning;

    return Semantics(
      label:
          '$label improvement: ${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}',
      child: AppCard.filled(
        padding: const EdgeInsets.all(AppSpacing.md),
        backgroundColor: cardColor,
        child: Column(
          children: [
            Text(
              '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}',
              style: AppTypography.headlineMedium.copyWith(
                color: textColor,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: colors.onDarkText.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build category breakdown card
  ///
  /// Displays a pie chart showing performance by category with legend.
  ///
  /// Parameters:
  /// - [context]: Build context for accessing theme
  /// - [categoryBreakdown]: List of category performance data
  Widget _buildCategoryBreakdownCard(
      BuildContext context, List<CategoryPerformance> categoryBreakdown,) {
    final colors = AppColors.of(context);
    final displayCategories =
        categoryBreakdown.take(_maxCategoriesToShow).toList();

    // Build pie chart sections
    final pieSections = displayCategories.asMap().entries.map((entry) {
      final index = entry.key;
      final cat = entry.value;
      return _buildPieChartSection(
        category: cat,
        index: index,
        colors: colors,
      );
    }).toList();

    // Build legend items
    final legendItems = displayCategories.asMap().entries.map((entry) {
      final index = entry.key;
      final cat = entry.value;
      return _buildLegendItem(
        category: cat,
        index: index,
        colors: colors,
      );
    }).toList();

    return Semantics(
      label:
          'Category Performance breakdown. Pie chart showing performance by category',
      child: AppCard.filled(
        padding: const EdgeInsets.all(AppSpacing.lg),
        backgroundColor: colors.onDarkText.withValues(alpha: 0.05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _titleCategoryPerformance,
              style: AppTypography.headlineMedium.copyWith(
                color: colors.onDarkText,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: _pieChartHeight,
              child: PieChart(
                PieChartData(
                  sections: pieSections,
                  sectionsSpace: _pieChartSectionsSpace,
                  centerSpaceRadius: _pieChartCenterRadius,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: legendItems,
            ),
          ],
        ),
      ),
    );
  }

  /// Get pie chart color palette
  ///
  /// Returns the color palette for pie chart sections.
  List<Color> _getPieChartColors() {
    return _pieChartColors;
  }

  /// Build pie chart section
  ///
  /// Creates a pie chart section for a category.
  ///
  /// Parameters:
  /// - [category]: Category performance data
  /// - [index]: Index in the category list
  /// - [colors]: App colors for theming
  PieChartSectionData _buildPieChartSection({
    required CategoryPerformance category,
    required int index,
    required AppColorScheme colors,
  }) {
    final chartColors = _getPieChartColors();
    return PieChartSectionData(
      value: category.accuracy,
      title: '${category.accuracy.toStringAsFixed(0)}%',
      color: chartColors[index % chartColors.length],
      radius: _pieChartRadius,
      titleStyle: AppTypography.bodySmall.copyWith(
        fontWeight: FontWeight.bold,
        color: colors.onDarkText,
      ),
    );
  }

  /// Build legend item
  ///
  /// Creates a legend item for a category with color indicator and label.
  ///
  /// Parameters:
  /// - [category]: Category performance data
  /// - [index]: Index in the category list
  /// - [colors]: App colors for theming
  Widget _buildLegendItem({
    required CategoryPerformance category,
    required int index,
    required AppColorScheme colors,
  }) {
    final chartColors = _getPieChartColors();
    final indicatorColor = chartColors[index % chartColors.length];

    return Semantics(
      label:
          '${category.category}: ${category.accuracy.toStringAsFixed(0)}% accuracy',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: _legendIndicatorSize,
            height: _legendIndicatorSize,
            decoration: BoxDecoration(
              color: indicatorColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '${category.category}: ${category.accuracy.toStringAsFixed(0)}%',
            style: AppTypography.bodySmall.copyWith(
              color: colors.onDarkText.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
