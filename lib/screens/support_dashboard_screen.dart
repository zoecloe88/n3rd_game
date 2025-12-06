import 'package:flutter/material.dart';
import 'package:n3rd_game/services/feedback_analytics_service.dart';
import 'package:n3rd_game/services/ai_support_service.dart';
import 'package:n3rd_game/services/user_survey_service.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/widgets/video_player_widget.dart';

class SupportDashboardScreen extends StatefulWidget {
  const SupportDashboardScreen({super.key});

  @override
  State<SupportDashboardScreen> createState() => _SupportDashboardScreenState();
}

class _SupportDashboardScreenState extends State<SupportDashboardScreen> {
  final _feedbackAnalyticsService = FeedbackAnalyticsService();
  final _aiSupportService = AISupportService();
  final _surveyService = UserSurveyService();

  FeedbackAnalytics? _analytics;
  Map<String, dynamic>? _aiAnalytics;
  SurveyAnalytics? _surveyAnalytics;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _feedbackAnalyticsService.getAnalytics(),
        _aiSupportService.getSupportAnalytics(),
        _surveyService.getSurveyAnalytics(),
      ]);

      if (mounted) {
        setState(() {
          _analytics = results[0] as FeedbackAnalytics;
          _aiAnalytics = results[1] as Map<String, dynamic>;
          _surveyAnalytics = results[2] as SurveyAnalytics;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).background,
      body: Stack(
        children: [
          // Video background
          // Video background - fills entire screen perfectly
          const VideoPlayerWidget(
            videoPath: 'assets/videos/settings_video.mp4',
            loop: true,
            autoplay: true,
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
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Support Dashboard',
                        style: AppTypography.headlineLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _loadDashboardData,
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error loading dashboard',
                                style: AppTypography.headlineLarge.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadDashboardData,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _buildDashboard(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overview Cards
          _buildOverviewCards(),
          const SizedBox(height: 24),

          // Feedback Analytics
          if (_analytics != null) _buildFeedbackSection(),
          const SizedBox(height: 24),

          // AI Support Analytics
          if (_aiAnalytics != null) _buildAISection(),
          const SizedBox(height: 24),

          // Survey Analytics
          if (_surveyAnalytics != null) _buildSurveySection(),
        ],
      ),
    );
  }

  Widget _buildOverviewCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Feedback',
            '${_analytics?.totalFeedback ?? 0}',
            Icons.feedback,
            AppColors.info,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'AI Interactions',
            '${_aiAnalytics?['totalAIInteractions'] ?? 0}',
            Icons.smart_toy,
            AppColors.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Avg Rating',
            _surveyAnalytics != null && _surveyAnalytics!.totalSurveys > 0
                ? '${_surveyAnalytics!.averageRating.toStringAsFixed(1)}/5'
                : 'N/A',
            Icons.star,
            AppColors.warning,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTypography.displayMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackSection() {
    final analytics = _analytics!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Feedback Analytics',
            style: AppTypography.headlineLarge.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 20),

          // By Type
          _buildStatRow('Bugs', analytics.bugs, AppColors.error),
          _buildStatRow('Features', analytics.features, AppColors.info),
          _buildStatRow('Errors', analytics.errors, AppColors.warning),
          _buildStatRow('Questions', analytics.questions, AppColors.success),

          const Divider(color: Colors.white24, height: 32),

          // By Priority
          Text(
            'Priority Breakdown',
            style: AppTypography.titleLarge.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 12),
          _buildStatRow('High', analytics.highPriority, AppColors.error),
          _buildStatRow('Medium', analytics.mediumPriority, AppColors.warning),
          _buildStatRow('Low', analytics.lowPriority, AppColors.success),

          const Divider(color: Colors.white24, height: 32),

          // By Status
          Text(
            'Status',
            style: AppTypography.titleLarge.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 12),
          _buildStatRow('New', analytics.newStatus, AppColors.info),
          _buildStatRow('In Progress', analytics.inProgress, AppColors.warning),
          _buildStatRow('Resolved', analytics.resolved, AppColors.success),
        ],
      ),
    );
  }

  Widget _buildAISection() {
    final aiData = _aiAnalytics!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Support Analytics',
            style: AppTypography.headlineLarge.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 20),

          _buildStatRow(
            'Total Interactions',
            aiData['totalAIInteractions'] ?? 0,
            AppColors.info,
          ),
          _buildStatRow(
            'Avg Confidence',
            '${((aiData['avgConfidence'] ?? 0.0) * 100).toStringAsFixed(1)}%',
            AppColors.success,
          ),

          if (aiData['intentsCount'] != null) ...[
            const SizedBox(height: 16),
            Text(
              'Intent Distribution',
              style: AppTypography.titleLarge.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 12),
            ...(aiData['intentsCount'] as Map<String, dynamic>).entries.map((
              entry,
            ) {
              return _buildStatRow(entry.key, entry.value, AppColors.info);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildSurveySection() {
    final survey = _surveyAnalytics!;
    if (survey.totalSurveys == 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              Icons.assessment,
              size: 48,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'No survey data yet',
              style: AppTypography.titleLarge.copyWith(color: Colors.white),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Survey Analytics',
            style: AppTypography.headlineLarge.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 20),

          _buildStatRow('Total Surveys', survey.totalSurveys, AppColors.info),
          _buildStatRow(
            'Average Rating',
            '${survey.averageRating.toStringAsFixed(2)}/5',
            AppColors.warning,
          ),
          _buildStatRow(
            'With Comments',
            survey.withComments,
            AppColors.success,
          ),

          const SizedBox(height: 16),
          Text(
            'Rating Distribution',
            style: AppTypography.titleLarge.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 12),
          _buildStatRow('5 Stars', survey.rating5, AppColors.success),
          _buildStatRow('4 Stars', survey.rating4, AppColors.success),
          _buildStatRow('3 Stars', survey.rating3, AppColors.warning),
          _buildStatRow('2 Stars', survey.rating2, AppColors.warning),
          _buildStatRow('1 Star', survey.rating1, AppColors.error),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, dynamic value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              value.toString(),
              style: AppTypography.labelLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
