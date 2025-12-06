import 'package:flutter/material.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/services/achievement_service.dart';
import 'package:n3rd_game/models/achievement.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/services/haptic_service.dart';
import 'package:n3rd_game/widgets/empty_state_widget.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final AchievementService _achievementService = AchievementService();
  Map<String, dynamic> _userAchievements = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    setState(() => _loading = true);

    try {
      final achievements = await _achievementService.getUserAchievements();
      setState(() {
        _userAchievements = achievements;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allAchievements = _achievementService.getAllAchievements();
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.primaryText),
          onPressed: () {
            HapticService().lightImpact();
            NavigationHelper.safePop(context);
          },
          tooltip: AppLocalizations.of(context)?.backButton ?? 'Back',
        ),
        title: Text(
          'Achievements',
          style: AppTypography.headlineLarge.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: colors.primaryText,
          ),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : allAchievements.isEmpty
            ? EmptyStateWidget(
                icon: Icons.emoji_events_outlined,
                title:
                    AppLocalizations.of(context)?.noAchievements ??
                    'No achievements yet',
                description:
                    AppLocalizations.of(context)?.noAchievementsDescription ??
                    'Keep playing to unlock achievements!',
              )
            : ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: allAchievements.length,
                itemBuilder: (context, index) {
                  final achievement = allAchievements[index];
                  final userAchievement = _userAchievements[achievement.id];
                  final isUnlocked = userAchievement?.unlocked ?? false;
                  final progress = userAchievement?.progress ?? 0;

                  return _buildAchievementCard(
                    context,
                    achievement,
                    isUnlocked,
                    progress,
                  );
                },
              ),
      ),
    );
  }

  Widget _buildAchievementCard(
    BuildContext context,
    Achievement achievement,
    bool isUnlocked,
    int progress,
  ) {
    final progressPercent = (progress / achievement.targetValue).clamp(
      0.0,
      1.0,
    );
    final cardColors = AppColors.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isUnlocked
            ? cardColors.primaryButton.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        border: isUnlocked
            ? Border.all(color: cardColors.primaryButton, width: 2)
            : Border.all(color: cardColors.tertiaryText),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isUnlocked
                  ? cardColors.primaryButton
                  : cardColors.tertiaryText.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                achievement.icon,
                style: const TextStyle(fontSize: 32),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: AppTypography.headlineLarge.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isUnlocked
                        ? cardColors.primaryButton
                        : cardColors.primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  achievement.description,
                  style: AppTypography.bodyMedium.copyWith(
                    fontSize: 14,
                    color: cardColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 8),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressPercent,
                    backgroundColor: cardColors.tertiaryText.withValues(
                      alpha: 0.2,
                    ),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isUnlocked
                          ? cardColors.primaryButton
                          : cardColors.tertiaryText,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$progress / ${achievement.targetValue}',
                  style: AppTypography.bodyMedium.copyWith(
                    fontSize: 12,
                    color: cardColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),

          // Unlocked badge
          if (isUnlocked)
            Icon(Icons.check_circle, color: cardColors.primaryButton, size: 32),
        ],
      ),
    );
  }
}
