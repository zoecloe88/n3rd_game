import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/widgets/video_player_widget.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';

class PerformanceInsightsScreen extends StatelessWidget {
  const PerformanceInsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // NOTE: Subscription access is enforced by RouteGuard in main.dart
    // No need for redundant check here
    return Scaffold(
      backgroundColor: AppColors.of(context).background,
      body: Stack(
        children: [
          // Video background
          const Positioned.fill(
            child: VideoPlayerWidget(
              videoPath: 'assets/videos/settings_video.mp4',
              loop: true,
              autoplay: true,
            ),
          ),

          // Content
          SafeArea(
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
                        'Performance Insights',
                        style: AppTypography.headlineLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // Insights content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Consumer<AnalyticsService>(
                      builder: (context, analyticsService, _) {
                        final categoryBreakdown = analyticsService
                            .getCategoryBreakdown();
                        final improvements = analyticsService
                            .getImprovementTracking();
                        final personalBests = analyticsService
                            .getPersonalBests();

                        // Identify weaknesses (categories with lowest accuracy)
                        final weaknesses = categoryBreakdown.length >= 3
                            ? categoryBreakdown
                                  .sublist(categoryBreakdown.length - 3)
                                  .reversed
                                  .toList()
                            : [];

                        // Identify strengths (categories with highest accuracy)
                        final strengths = categoryBreakdown.length >= 3
                            ? categoryBreakdown.take(3).toList()
                            : [];

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // AI-Powered Analysis Header
                            _buildInsightCard(
                              title: 'AI Analysis',
                              icon: Icons.psychology,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Based on your performance data, here are personalized insights:',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Weaknesses
                            if (weaknesses.isNotEmpty)
                              _buildInsightCard(
                                title: 'Areas for Improvement',
                                icon: Icons.trending_down,
                                color: Colors.orange,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: weaknesses.map((cat) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
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
                                                    color: Colors.white,
                                                  ),
                                            ),
                                          ),
                                          Text(
                                            '${cat.accuracy.toStringAsFixed(1)}%',
                                            style: AppTypography.bodyMedium
                                                .copyWith(color: Colors.orange),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            const SizedBox(height: 16),

                            // Strengths
                            if (strengths.isNotEmpty)
                              _buildInsightCard(
                                title: 'Your Strengths',
                                icon: Icons.trending_up,
                                color: Colors.green,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: strengths.map((cat) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
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
                                                    color: Colors.white,
                                                  ),
                                            ),
                                          ),
                                          Text(
                                            '${cat.accuracy.toStringAsFixed(1)}%',
                                            style: AppTypography.bodyMedium
                                                .copyWith(color: Colors.green),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            const SizedBox(height: 16),

                            // Recommendations
                            _buildInsightCard(
                              title: 'Personalized Recommendations',
                              icon: Icons.lightbulb_outline,
                              color: Colors.amber,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildRecommendation(
                                    'Focus on ${weaknesses.isNotEmpty ? weaknesses.first.category : "your weakest categories"}',
                                    'Practice more questions in this category to improve your overall accuracy.',
                                  ),
                                  const SizedBox(height: 12),
                                  _buildRecommendation(
                                    'Maintain your ${strengths.isNotEmpty ? strengths.first.category : "strongest"} performance',
                                    'You\'re excelling here! Keep up the great work.',
                                  ),
                                  const SizedBox(height: 12),
                                  if (improvements['scoreImprovement'] !=
                                          null &&
                                      improvements['scoreImprovement']! < 0)
                                    _buildRecommendation(
                                      'Your recent performance has declined',
                                      'Consider taking a break or reviewing past questions in Learning Mode.',
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Performance Prediction
                            _buildInsightCard(
                              title: 'Performance Prediction',
                              icon: Icons.auto_graph,
                              color: const Color(0xFF00D9FF),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Based on your current trends:',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  if (improvements['scoreImprovement'] !=
                                          null &&
                                      improvements['scoreImprovement']! > 0)
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.arrow_upward,
                                          color: Colors.green,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Your scores are improving! You\'re on track to beat your personal best soon.',
                                            style: AppTypography.bodyMedium
                                                .copyWith(
                                                  fontSize: 13,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.9),
                                                ),
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.trending_flat,
                                          color: Colors.orange,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Your performance is stable. Try focusing on weaker categories to see improvement.',
                                            style: AppTypography.bodyMedium
                                                .copyWith(
                                                  fontSize: 13,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.9),
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Goal Setting
                            _buildInsightCard(
                              title: 'Set Goals',
                              icon: Icons.flag_outlined,
                              color: Colors.purple,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Current Best: ${personalBests['highestScore']?.toStringAsFixed(0) ?? '0'}',
                                    style: AppTypography.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Set a goal to beat your personal best!',
                                    style: AppTypography.bodyMedium.copyWith(
                                      fontSize: 13,
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton(
                                    onPressed: () {
                                      _showGoalSettingDialog(context);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.purple,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                    ),
                                    child: Text(
                                      'Set Goal',
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
        ],
      ),
    );
  }

  Widget _buildInsightCard({
    required String title,
    required IconData icon,
    required Widget child,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (color ?? Colors.white).withValues(alpha: 0.2),
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
              Icon(icon, color: color ?? Colors.white, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTypography.headlineLarge.copyWith(
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildRecommendation(String title, String description) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: AppTypography.labelSmall.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  void _showGoalSettingDialog(BuildContext context) {
    int targetScore = 0;
    double targetAccuracy = 0.0;
    int targetStreak = 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            'Set Performance Goals',
            style: AppTypography.headlineLarge.copyWith(fontSize: 20),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Target Score',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Slider(
                  value: targetScore.toDouble(),
                  min: 0,
                  max: 1000,
                  divisions: 100,
                  label: targetScore.toString(),
                  onChanged: (value) {
                    setState(() {
                      targetScore = value.toInt();
                    });
                  },
                ),
                Text('$targetScore', style: AppTypography.bodyMedium),
                const SizedBox(height: 16),
                Text(
                  'Target Accuracy (%)',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Slider(
                  value: targetAccuracy,
                  min: 0,
                  max: 100,
                  divisions: 100,
                  label: '${targetAccuracy.toStringAsFixed(1)}%',
                  onChanged: (value) {
                    setState(() {
                      targetAccuracy = value;
                    });
                  },
                ),
                Text(
                  '${targetAccuracy.toStringAsFixed(1)}%',
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  'Target Streak',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Slider(
                  value: targetStreak.toDouble(),
                  min: 0,
                  max: 50,
                  divisions: 50,
                  label: targetStreak.toString(),
                  onChanged: (value) {
                    setState(() {
                      targetStreak = value.toInt();
                    });
                  },
                ),
                Text('$targetStreak', style: AppTypography.bodyMedium),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: AppTypography.bodyMedium),
            ),
            ElevatedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('goal_target_score', targetScore);
                await prefs.setDouble('goal_target_accuracy', targetAccuracy);
                await prefs.setInt('goal_target_streak', targetStreak);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Goals saved successfully!')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
              child: Text(
                'Save Goals',
                style: AppTypography.bodyMedium.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
