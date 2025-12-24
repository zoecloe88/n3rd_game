import 'package:flutter/material.dart';
import 'package:n3rd_game/screens/stats_screen.dart';
import 'package:n3rd_game/screens/leaderboard_screen.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/widgets/unified_background_widget.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';

/// Screen that provides menu to choose between Stats and Leaderboard
class StatsMenuScreen extends StatelessWidget {
  const StatsMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: UnifiedBackgroundWidget(
        // Remove large animation overlay - use icon-sized animations only
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: colors.onDarkText),
                      onPressed: () => NavigationHelper.safePop(context),
                      tooltip: 'Back',
                    ),
                    Text(
                      'Stats & Leaderboard',
                      style: AppTypography.headlineLarge.copyWith(
                        color: colors.onDarkText,
                      ),
                    ),
                  ],
                ),
              ),
              // Menu options
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildMenuOption(
                        context,
                        icon: Icons.bar_chart,
                        title: 'Personal Stats',
                        subtitle: 'View your game statistics and progress',
                        onTap: () {
                          NavigationHelper.safePush(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const StatsScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      _buildMenuOption(
                        context,
                        icon: Icons.leaderboard,
                        title: 'Leaderboard',
                        subtitle: 'See global rankings and compete',
                        onTap: () {
                          NavigationHelper.safePush(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LeaderboardScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          // FIX: Remove white tiles - use transparent/semi-transparent design that blends with blue background
          color: Colors.transparent, // No white background
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2), // Subtle white border
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleLarge.copyWith(
                      color: Colors.white, // White text on blue background
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTypography.bodyMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.8), // Slightly transparent white
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.8)),
          ],
        ),
      ),
    );
  }
}
