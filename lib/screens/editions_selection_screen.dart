import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/widgets/unified_background_widget.dart';
import 'package:n3rd_game/config/screen_animations_config.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_shadows.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';

class EditionsSelectionScreen extends StatelessWidget {
  const EditionsSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final subscriptionService = Provider.of<SubscriptionService>(context);

    // Block editions access for non-Premium users
    final colors = AppColors.of(context);
    if (!subscriptionService.hasEditionsAccess) {
      final route = ModalRoute.of(context)?.settings.name;
      final animationPath = ScreenAnimationsConfig.getAnimationForRoute(route);

      return Scaffold(
        backgroundColor: colors.background,
        body: UnifiedBackgroundWidget(
          animationPath: animationPath,
          animationAlignment: Alignment.bottomCenter,
          animationPadding: const EdgeInsets.only(bottom: 20),
          child: SafeArea(
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
                      'Editions - Premium Feature',
                      style: AppTypography.headlineLarge.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colors.primaryText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Editions are only available with Premium subscription. Upgrade to Premium to access all specialized trivia categories and editions!',
                      style: AppTypography.bodyMedium.copyWith(
                        fontSize: 16,
                        color: colors.secondaryText,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () => NavigationHelper.safePop(context),
                          child: Text(
                            'Cancel',
                            style: AppTypography.bodyMedium.copyWith(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () {
                            NavigationHelper.safePop(context);
                            Navigator.of(
                              context,
                            ).pushNamed('/subscription-management');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primaryButton,
                          ),
                          child: Text(
                            'Upgrade to Premium',
                            style: AppTypography.bodyMedium.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final route = ModalRoute.of(context)?.settings.name;
    final animationPath = ScreenAnimationsConfig.getAnimationForRoute(route);

    return Scaffold(
      backgroundColor: colors.background,
      body: UnifiedBackgroundWidget(
        animationPath: animationPath,
        animationAlignment: Alignment.bottomCenter,
        animationPadding: const EdgeInsets.only(bottom: 20),
        child: SafeArea(
          child: Column(
            children: [
              // Top app bar
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
                      'Editions',
                      style: AppTypography.headlineLarge.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Selection cards
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Regular Editions Card
                        Consumer<SubscriptionService>(
                          builder: (context, subscriptionService, _) {
                            final hasAccess =
                                subscriptionService.hasEditionsAccess;
                            return _buildEditionOption(
                              context,
                              title: 'Regular Editions',
                              description: hasAccess
                                  ? '100+ themed editions for adults'
                                  : 'Premium feature - Upgrade to access',
                              icon: Icons.collections_bookmark,
                              color: Colors.blue,
                              isLocked: !hasAccess,
                              onTap: hasAccess
                                  ? () {
                                      Navigator.of(
                                        context,
                                      ).pushNamed('/editions');
                                    }
                                  : () {
                                      _showUpgradeDialog(context);
                                    },
                            );
                          },
                        ),

                        const SizedBox(height: 24),

                        // Youth Editions Card
                        Consumer<SubscriptionService>(
                          builder: (context, subscriptionService, _) {
                            final hasAccess =
                                subscriptionService.hasEditionsAccess;
                            return _buildEditionOption(
                              context,
                              title: 'Youth Editions',
                              description: hasAccess
                                  ? 'Age-appropriate content for kids'
                                  : 'Premium feature - Upgrade to access',
                              icon: Icons.child_care,
                              color: Colors.orange,
                              isLocked: !hasAccess,
                              onTap: hasAccess
                                  ? () {
                                      Navigator.of(
                                        context,
                                      ).pushNamed('/youth-editions');
                                    }
                                  : () {
                                      _showUpgradeDialog(context);
                                    },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Premium Required',
          style: AppTypography.headlineLarge.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Editions are only available with Premium subscription. Upgrade to Premium to access 100+ themed editions!',
          style: AppTypography.bodyMedium.copyWith(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: Text('Cancel', style: AppTypography.bodyMedium.copyWith()),
          ),
          ElevatedButton(
            onPressed: () {
              if (context.mounted) {
                Navigator.pop(context);
                if (context.mounted) {
                  NavigationHelper.safeNavigate(
                    context,
                    '/subscription-management',
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.of(context).primaryButton,
            ),
            child: Text(
              'Upgrade',
              style: AppTypography.bodyMedium.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditionOption(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    bool isLocked = false,
    required VoidCallback onTap,
  }) {
    final optionColors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppShadows.large,
          // No border - removed
        ),
        child: Column(
          children: [
            // Icon with colored background
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isLocked ? Icons.lock_outline : icon,
                color: isLocked ? optionColors.tertiaryText : color,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            // Title
            Text(
              title,
              style: AppTypography.headlineLarge.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isLocked ? optionColors.tertiaryText : color,
              ),
            ),
            const SizedBox(height: 8),
            // Description
            Text(
              description,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                fontSize: 16,
                color: optionColors.secondaryText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            // Arrow or lock icon
            Icon(
              isLocked ? Icons.lock_outline : Icons.arrow_forward_ios,
              color: isLocked ? AppColors.error : color,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
