import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/services/theme_service.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/widgets/video_player_widget.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_shadows.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';

class ThemesScreen extends StatelessWidget {
  const ThemesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final subscriptionService = Provider.of<SubscriptionService>(context);

    // Check if user has premium access
    final colors = AppColors.of(context);
    if (!subscriptionService.isPremium) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Stack(
          children: [
            // Video background - fills entire screen perfectly
            const VideoPlayerWidget(
              videoPath: 'assets/videos/settings_video.mp4',
              loop: true,
              autoplay: true,
            ),
            SafeArea(
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: colors.cardBackground.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppShadows.large,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 64,
                        color: colors.tertiaryText,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Premium Feature',
                        style: AppTypography.headlineLarge.copyWith(
                          fontSize: 24,
                          color: colors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Premium themes are available for Premium subscribers.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium.copyWith(
                          fontSize: 14,
                          color: colors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(
                            context,
                          ).pushNamed('/subscription-management');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primaryButton,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                        child: Text(
                          'Upgrade to Premium',
                          style: AppTypography.labelLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
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
                        'Themes',
                        style: AppTypography.headlineLarge.copyWith(
                          fontSize: 24,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // Themes list
                Expanded(
                  child: Consumer<ThemeService>(
                    builder: (context, themeService, _) {
                      final availableThemes = themeService.getAvailableThemes();
                      final currentTheme = themeService.currentTheme;

                      return ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          // Current theme indicator
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Current Theme',
                                        style: AppTypography.labelSmall
                                            .copyWith(
                                              fontSize: 12,
                                              color: Colors.white.withValues(
                                                alpha: 0.7,
                                              ),
                                            ),
                                      ),
                                      Text(
                                        currentTheme.name,
                                        style: AppTypography.titleLarge
                                            .copyWith(
                                              fontSize: 18,
                                              color: Colors.white,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Theme grid
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 0.85,
                                ),
                            itemCount: availableThemes.length,
                            itemBuilder: (context, index) {
                              final theme = availableThemes[index];
                              final isSelected = theme.id == currentTheme.id;

                              return GestureDetector(
                                onTap: () {
                                  themeService.setTheme(theme);
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? theme.colors['accent'] ??
                                                Colors.white
                                          : Colors.white.withValues(alpha: 0.2),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Color preview
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color:
                                              theme.colors['accent'] ??
                                              Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  (theme.colors['accent'] ??
                                                          Colors.white)
                                                      .withValues(alpha: 0.5),
                                              blurRadius: 10,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        theme.name,
                                        style: AppTypography.titleLarge
                                            .copyWith(
                                              fontSize: 16,
                                              color: Colors.white,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        theme.description,
                                        textAlign: TextAlign.center,
                                        style: AppTypography.bodyMedium
                                            .copyWith(
                                              fontSize: 11,
                                              color: Colors.white.withValues(
                                                alpha: 0.7,
                                              ),
                                            ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (theme.isSeasonal) ...[
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withValues(
                                              alpha: 0.3,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            theme.season?.toUpperCase() ??
                                                'SEASONAL',
                                            style: AppTypography.labelSmall
                                                .copyWith(
                                                  fontSize: 8,
                                                  color: Colors.amber,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 32),
                        ],
                      );
                    },
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
