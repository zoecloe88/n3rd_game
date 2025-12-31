import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/widgets/background_image_widget.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/widgets/app_button.dart';
import 'package:n3rd_game/widgets/app_card.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/theme/app_radius.dart';
import 'package:n3rd_game/utils/feedback_helper.dart';
import 'package:n3rd_game/widgets/error_recovery_widget.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/models/performance_metric.dart';
import 'package:n3rd_game/utils/unawaited_helper.dart';

/// Performance Insights screen displaying AI-powered analysis
///
/// Features:
/// - Category breakdown (strengths and weaknesses)
/// - Personalized recommendations
/// - Performance predictions
/// - Goal setting and tracking
/// - Requires Premium subscription (enforced by RouteGuard)
///
/// Usage:
/// ```dart
/// Navigator.pushNamed(context, '/performance-insights');
/// ```
class PerformanceInsightsScreen extends StatefulWidget {
  const PerformanceInsightsScreen({super.key});

  @override
  State<PerformanceInsightsScreen> createState() =>
      _PerformanceInsightsScreenState();
}

class _PerformanceInsightsScreenState extends State<PerformanceInsightsScreen> {
  // Constants
  static const int _minTopCategories = 3;
  static const int _maxScoreGoal = 1000;
  static const int _maxStreakGoal = 50;
  static const int _scoreSliderDivisions = 100;
  static const int _accuracySliderDivisions = 100;
  static const int _streakSliderDivisions = 50;
  static const double _defaultIconSize = 24.0;
  static const double _smallIconSize = 20.0;
  static const String _goalScoreKey = 'goal_target_score';
  static const String _goalAccuracyKey = 'goal_target_accuracy';
  static const String _goalStreakKey = 'goal_target_streak';

  // Memoization cache
  List<CategoryPerformance>? _cachedCategoryBreakdown;
  Map<String, double>? _cachedImprovements;
  Map<String, double>? _cachedPersonalBests;
  List<CategoryPerformance>? _cachedWeaknesses;
  List<CategoryPerformance>? _cachedStrengths;
  final bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    // NOTE: Subscription access is enforced by RouteGuard in main.dart
    // No need for redundant check here
    final colors = AppColors.of(context);

    // Show error state if data loading failed
    if (_errorMessage != null && !_isLoading) {
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
                      'Performance Insights',
                      style: AppTypography.headlineLarge.copyWith(
                        color: colors.onDarkText,
                      ),
                    ),
                  ],
                ),
              ),

              // Insights content
              Expanded(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Consumer<AnalyticsService>(
                    builder: (context, analyticsService, _) {
                      // Memoize data fetching
                      try {
                        final categoryBreakdown =
                            analyticsService.getCategoryBreakdown();
                        final improvements =
                            analyticsService.getImprovementTracking();
                        final personalBests =
                            analyticsService.getPersonalBests();

                        // Update cache if data changed
                        if (_cachedCategoryBreakdown != categoryBreakdown ||
                            _cachedImprovements != improvements ||
                            _cachedPersonalBests != personalBests) {
                          _cachedCategoryBreakdown = categoryBreakdown;
                          _cachedImprovements = improvements;
                          _cachedPersonalBests = personalBests;
                          _cachedWeaknesses =
                              _computeWeaknesses(categoryBreakdown);
                          _cachedStrengths =
                              _computeStrengths(categoryBreakdown);
                        }

                        final weaknesses = _cachedWeaknesses ?? [];
                        final strengths = _cachedStrengths ?? [];

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // AI-Powered Analysis Header
                            _buildInsightCard(
                              context: context,
                              title: 'AI Analysis',
                              icon: Icons.psychology,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Based on your performance data, here are personalized insights:',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: colors.onDarkText
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),

                            // Weaknesses
                            if (weaknesses.isNotEmpty)
                              _buildInsightCard(
                                context: context,
                                title: 'Areas for Improvement',
                                icon: Icons.trending_down,
                                color: colors.warning,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: weaknesses.map((cat) {
                                    return Semantics(
                                      label:
                                          'Category: ${cat.category}. Accuracy: ${cat.accuracy.toStringAsFixed(1)}%',
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                            bottom: AppSpacing.sm,),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                cat.category,
                                                style: AppTypography.bodyMedium
                                                    .copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: colors.onDarkText,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '${cat.accuracy.toStringAsFixed(1)}%',
                                              style: AppTypography.bodyMedium
                                                  .copyWith(
                                                color: colors.warning,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            const SizedBox(height: AppSpacing.md),

                            // Strengths
                            if (strengths.isNotEmpty)
                              _buildInsightCard(
                                context: context,
                                title: 'Your Strengths',
                                icon: Icons.trending_up,
                                color: colors.success,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: strengths.map((cat) {
                                    return Semantics(
                                      label:
                                          'Category: ${cat.category}. Accuracy: ${cat.accuracy.toStringAsFixed(1)}%',
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                            bottom: AppSpacing.sm,),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                cat.category,
                                                style: AppTypography.bodyMedium
                                                    .copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: colors.onDarkText,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '${cat.accuracy.toStringAsFixed(1)}%',
                                              style: AppTypography.bodyMedium
                                                  .copyWith(
                                                color: colors.success,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            const SizedBox(height: AppSpacing.md),

                            // Recommendations
                            _buildInsightCard(
                              context: context,
                              title: 'Personalized Recommendations',
                              icon: Icons.lightbulb_outline,
                              color: colors.warning,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildRecommendation(
                                    context: context,
                                    title:
                                        'Focus on ${weaknesses.isNotEmpty ? weaknesses.first.category : "your weakest categories"}',
                                    description:
                                        'Practice more questions in this category to improve your overall accuracy.',
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  _buildRecommendation(
                                    context: context,
                                    title:
                                        'Maintain your ${strengths.isNotEmpty ? strengths.first.category : "strongest"} performance',
                                    description:
                                        'You\'re excelling here! Keep up the great work.',
                                  ),
                                  if (improvements['scoreImprovement'] !=
                                          null &&
                                      improvements['scoreImprovement']! <
                                          0) ...[
                                    const SizedBox(height: AppSpacing.sm),
                                    _buildRecommendation(
                                      context: context,
                                      title:
                                          'Your recent performance has declined',
                                      description:
                                          'Consider taking a break or reviewing past questions in Learning Mode.',
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),

                            // Performance Prediction
                            _buildInsightCard(
                              context: context,
                              title: 'Performance Prediction',
                              icon: Icons.auto_graph,
                              color: colors.accent,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Based on your current trends:',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: colors.onDarkText
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  if (improvements['scoreImprovement'] !=
                                          null &&
                                      improvements['scoreImprovement']! > 0)
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.arrow_upward,
                                          color: colors.success,
                                          size: _smallIconSize,
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        Expanded(
                                          child: Text(
                                            'Your scores are improving! You\'re on track to beat your personal best soon.',
                                            style: AppTypography.bodySmall
                                                .copyWith(
                                              color: colors.onDarkText
                                                  .withValues(alpha: 0.9),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.trending_flat,
                                          color: colors.warning,
                                          size: _smallIconSize,
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        Expanded(
                                          child: Text(
                                            'Your performance is stable. Try focusing on weaker categories to see improvement.',
                                            style: AppTypography.bodySmall
                                                .copyWith(
                                              color: colors.onDarkText
                                                  .withValues(alpha: 0.9),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),

                            // Goal Setting
                            _buildInsightCard(
                              context: context,
                              title: 'Set Goals',
                              icon: Icons.flag_outlined,
                              color: colors.accentVariant,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Current Best: ${personalBests['highestScore']?.toStringAsFixed(0) ?? '0'}',
                                    style: AppTypography.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: colors.onDarkText,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    'Set a goal to beat your personal best!',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: colors.onDarkText
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  AppButton.primary(
                                    label: 'Set Goal',
                                    onPressed: () {
                                      _showGoalSettingDialog(context);
                                    },
                                    size: AppButtonSize.medium,
                                    semanticsLabel:
                                        'Set performance goals. Double tap to open goal setting dialog',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                          ],
                        );
                      } catch (e) {
                        LoggerService.error(
                          'PerformanceInsightsScreen: Error loading insights',
                          error: e,
                          stack: StackTrace.current,
                          fatal: false,
                        );
                        if (mounted) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() {
                                _errorMessage =
                                    'Failed to load performance insights. Please try again.';
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

  /// Compute weaknesses (lowest accuracy categories)
  List<CategoryPerformance> _computeWeaknesses(
      List<CategoryPerformance> categoryBreakdown,) {
    if (categoryBreakdown.length >= _minTopCategories) {
      return categoryBreakdown
          .sublist(categoryBreakdown.length - _minTopCategories)
          .reversed
          .toList();
    } else if (categoryBreakdown.isNotEmpty) {
      return categoryBreakdown.reversed.toList();
    }
    return [];
  }

  /// Compute strengths (highest accuracy categories)
  List<CategoryPerformance> _computeStrengths(
      List<CategoryPerformance> categoryBreakdown,) {
    if (categoryBreakdown.length >= _minTopCategories) {
      return categoryBreakdown.take(_minTopCategories).toList();
    } else if (categoryBreakdown.isNotEmpty) {
      return categoryBreakdown.take(categoryBreakdown.length).toList();
    }
    return [];
  }

  /// Build insight card with title, icon, and content
  ///
  /// Parameters:
  /// - [context]: Build context for accessing theme
  /// - [title]: Card title
  /// - [icon]: Icon to display
  /// - [child]: Card content widget
  /// - [color]: Optional accent color for icon and border
  Widget _buildInsightCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget child,
    Color? color,
  }) {
    final colors = AppColors.of(context);
    final effectiveColor = color ?? colors.onDarkText;

    return Semantics(
      label: 'Insight card: $title',
      child: AppCard.filled(
        padding: const EdgeInsets.all(AppSpacing.lg),
        backgroundColor: colors.onDarkText.withValues(alpha: 0.05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: effectiveColor,
                  size: _defaultIconSize,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  title,
                  style: AppTypography.headlineMedium.copyWith(
                    color: colors.onDarkText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }

  /// Build recommendation item with title and description
  ///
  /// Parameters:
  /// - [context]: Build context for accessing theme
  /// - [title]: Recommendation title
  /// - [description]: Recommendation description
  Widget _buildRecommendation({
    required BuildContext context,
    required String title,
    required String description,
  }) {
    final colors = AppColors.of(context);

    return Semantics(
      label: 'Recommendation: $title. $description',
      child: AppCard.filled(
        padding: const EdgeInsets.all(AppSpacing.sm),
        backgroundColor: colors.onDarkText.withValues(alpha: 0.05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.onDarkText,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              description,
              style: AppTypography.labelSmall.copyWith(
                color: colors.onDarkText.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show goal setting dialog
  ///
  /// Allows users to set performance goals for score, accuracy, and streak.
  /// Goals are saved to SharedPreferences and persist across sessions.
  void _showGoalSettingDialog(BuildContext context) async {
    // Load saved goals first
    int targetScore = 0;
    double targetAccuracy = 0.0;
    int targetStreak = 0;

    try {
      final prefs = await SharedPreferences.getInstance();
      targetScore = prefs.getInt(_goalScoreKey) ?? 0;
      targetAccuracy = prefs.getDouble(_goalAccuracyKey) ?? 0.0;
      targetStreak = prefs.getInt(_goalStreakKey) ?? 0;
    } catch (e) {
      LoggerService.warning(
        'PerformanceInsightsScreen: Failed to load saved goals',
        error: e,
      );
    }

    if (!context.mounted) return;

    unawaited(showDialog(
      context: context,
      builder: (context) => _GoalSettingDialog(
        initialScore: targetScore,
        initialAccuracy: targetAccuracy,
        initialStreak: targetStreak,
        onSave: (score, accuracy, streak) async {
          try {
            final prefs = await SharedPreferences.getInstance();
            final scoreSaved = await prefs.setInt(_goalScoreKey, score);
            final accuracySaved =
                await prefs.setDouble(_goalAccuracyKey, accuracy);
            final streakSaved = await prefs.setInt(_goalStreakKey, streak);

            if (context.mounted) {
              if (scoreSaved && accuracySaved && streakSaved) {
                NavigationHelper.safePop(context);
                FeedbackHelper.showSuccess(
                  context,
                  'Goals saved successfully!',
                );
              } else {
                FeedbackHelper.showError(
                  context,
                  'Failed to save some goals. Please try again.',
                );
              }
            }
          } catch (e) {
            LoggerService.error(
              'PerformanceInsightsScreen: Failed to save goals',
              error: e,
              stack: StackTrace.current,
              fatal: false,
            );
            if (context.mounted) {
              FeedbackHelper.showError(
                context,
                AppLocalizations.of(context)?.goalsSaveError ??
                    'Failed to save goals. Please try again.',
              );
            }
          }
        },
      ),
    ),);
  }
}

/// Goal setting dialog widget
///
/// Displays sliders for setting performance goals (score, accuracy, streak).
class _GoalSettingDialog extends StatefulWidget {

  const _GoalSettingDialog({
    required this.initialScore,
    required this.initialAccuracy,
    required this.initialStreak,
    required this.onSave,
  });
  final int initialScore;
  final double initialAccuracy;
  final int initialStreak;
  final Future<void> Function(int score, double accuracy, int streak) onSave;

  @override
  State<_GoalSettingDialog> createState() => _GoalSettingDialogState();
}

class _GoalSettingDialogState extends State<_GoalSettingDialog> {
  late int _targetScore;
  late double _targetAccuracy;
  late int _targetStreak;
  final FocusNode _scoreFocusNode = FocusNode();
  final FocusNode _accuracyFocusNode = FocusNode();
  final FocusNode _streakFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _targetScore = widget.initialScore;
    _targetAccuracy = widget.initialAccuracy;
    _targetStreak = widget.initialStreak;
  }

  @override
  void dispose() {
    _scoreFocusNode.dispose();
    _accuracyFocusNode.dispose();
    _streakFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Dialog(
      backgroundColor: colors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Set Performance Goals',
              style: AppTypography.headlineMedium.copyWith(
                color: colors.primaryText,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGoalSlider(
                      context: context,
                      label: 'Target Score',
                      value: _targetScore.toDouble(),
                      min: 0,
                      max: _PerformanceInsightsScreenState._maxScoreGoal
                          .toDouble(),
                      divisions:
                          _PerformanceInsightsScreenState._scoreSliderDivisions,
                      onChanged: (value) {
                        setState(() {
                          _targetScore = value.toInt();
                        });
                      },
                      displayValue: _targetScore.toString(),
                      focusNode: _scoreFocusNode,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildGoalSlider(
                      context: context,
                      label: 'Target Accuracy (%)',
                      value: _targetAccuracy,
                      min: 0,
                      max: 100,
                      divisions: _PerformanceInsightsScreenState
                          ._accuracySliderDivisions,
                      onChanged: (value) {
                        setState(() {
                          _targetAccuracy = value;
                        });
                      },
                      displayValue: '${_targetAccuracy.toStringAsFixed(1)}%',
                      focusNode: _accuracyFocusNode,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildGoalSlider(
                      context: context,
                      label: 'Target Streak',
                      value: _targetStreak.toDouble(),
                      min: 0,
                      max: _PerformanceInsightsScreenState._maxStreakGoal
                          .toDouble(),
                      divisions: _PerformanceInsightsScreenState
                          ._streakSliderDivisions,
                      onChanged: (value) {
                        setState(() {
                          _targetStreak = value.toInt();
                        });
                      },
                      displayValue: _targetStreak.toString(),
                      focusNode: _streakFocusNode,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton.text(
                  label: 'Cancel',
                  onPressed: () => NavigationHelper.safePop(context),
                  semanticsLabel: 'Cancel goal setting',
                ),
                const SizedBox(width: AppSpacing.sm),
                AppButton.primary(
                  label: 'Save Goals',
                  onPressed: () => widget.onSave(
                      _targetScore, _targetAccuracy, _targetStreak,),
                  semanticsLabel: 'Save performance goals',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build goal slider with label and value display
  Widget _buildGoalSlider({
    required BuildContext context,
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required String displayValue,
    required FocusNode focusNode,
  }) {
    final colors = AppColors.of(context);

    return Semantics(
      label: '$label: $displayValue',
      hint: 'Use slider to adjust $label',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.primaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: displayValue,
            onChanged: onChanged,
            focusNode: focusNode,
          ),
          Text(
            displayValue,
            style: AppTypography.bodyMedium.copyWith(
              color: colors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}
