import 'package:flutter/material.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/services/haptic_service.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';

/// Widget for toggling between Leaderboard and Personal Stats views
class ViewToggleWidget extends StatelessWidget {

  const ViewToggleWidget({
    super.key,
    required this.showPersonalStats,
    required this.onChanged,
  });
  final bool showPersonalStats;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final localizations = AppLocalizations.of(context);

    return Semantics(
      label: showPersonalStats
          ? localizations?.showLeaderboard ?? 'Show Leaderboard'
          : localizations?.showPersonalStats ?? 'Show Personal Stats',
      button: true,
      child: Container(
        decoration: BoxDecoration(
          color: colors.cardBackground.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colors.secondaryText.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildToggleButton(
              context,
              label: localizations?.leaderboardView ?? 'Leaderboard',
              icon: Icons.leaderboard_outlined,
              isSelected: !showPersonalStats,
              onTap: () {
                if (showPersonalStats) {
                  HapticService().lightImpact();
                  onChanged(false);
                }
              },
            ),
            _buildToggleButton(
              context,
              label: localizations?.personalStatsView ?? 'Personal Stats',
              icon: Icons.person_outline,
              isSelected: showPersonalStats,
              onTap: () {
                if (!showPersonalStats) {
                  HapticService().lightImpact();
                  onChanged(true);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = AppColors.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? colors.info : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : colors.secondaryText,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: isSelected ? Colors.white : colors.secondaryText,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}













