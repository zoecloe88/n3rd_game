import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/screens/settings_screen.dart';
import 'package:n3rd_game/screens/feedback_screen.dart';
import 'package:n3rd_game/widgets/background_image_widget.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/services/auth_service.dart';

class MoreMenuScreen extends StatelessWidget {
  const MoreMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Black fallback - static background will cover
      body: BackgroundImageWidget(
        imagePath: 'assets/background n3rd.png',
        child: SafeArea(
            child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              // Menu items (header removed - redundant since bottom nav shows "More")
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    // Account Section
                    _buildSectionHeader(context, 'Account'),
                    _buildMenuItem(
                      context,
                      icon: Icons.person_outline,
                      title: 'Profile',
                      subtitle: 'Edit profile and account settings',
                      onTap: () => NavigationHelper.safePush(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      ),
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.card_membership_outlined,
                      title: 'Subscriptions',
                      subtitle: 'Manage your subscription',
                      onTap: () => Navigator.of(
                        context,
                      ).pushNamed('/subscription-management'),
                    ),
                    const SizedBox(height: 8),

                    // Features Section
                    _buildSectionHeader(context, 'Features'),
                    _buildMenuItem(
                      context,
                      icon: Icons.event_available_outlined,
                      title: 'Daily Challenges',
                      subtitle: 'Complete daily challenges',
                      onTap: () => NavigationHelper.safeNavigate(
                          context, '/daily-challenges',),
                    ),
                    Consumer<SubscriptionService>(
                      builder: (context, subscriptionService, _) {
                        if (!subscriptionService.isPremium) {
                          return const SizedBox.shrink();
                        }
                        return _buildMenuItem(
                          context,
                          icon: Icons.school_outlined,
                          title: 'Learning Mode',
                          subtitle: 'Review missed questions',
                          onTap: () => NavigationHelper.safeNavigate(
                            context,
                            '/learning',
                          ),
                        );
                      },
                    ),
                    Consumer<SubscriptionService>(
                      builder: (context, subscriptionService, _) {
                        if (!subscriptionService.isPremium) {
                          return const SizedBox.shrink();
                        }
                        return _buildMenuItem(
                          context,
                          icon: Icons.trending_up_outlined,
                          title: 'Performance Insights',
                          subtitle: 'Detailed analytics',
                          onTap: () => NavigationHelper.safeNavigate(
                            context,
                            '/performance-insights',
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.fitness_center_outlined,
                      title: 'Practice Mode',
                      subtitle: 'Practice without scoring',
                      onTap: () =>
                          NavigationHelper.safeNavigate(context, '/practice'),
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.create_outlined,
                      title: 'Trivia Creator',
                      subtitle: 'Create your own trivia',
                      onTap: () => NavigationHelper.safeNavigate(
                        context,
                        '/trivia-creator',
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Support Section
                    _buildSectionHeader(context, 'Support'),
                    _buildMenuItem(
                      context,
                      icon: Icons.help_outline,
                      title: 'Help Center',
                      subtitle: 'FAQs, tips, and guides',
                      onTap: () => NavigationHelper.safeNavigate(
                        context,
                        '/help-center',
                      ),
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.feedback_outlined,
                      title: 'Submit Feedback',
                      subtitle: 'Report issues or suggest improvements',
                      onTap: () => showDialog(
                        context: context,
                        builder: (context) => const FeedbackScreen(),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Settings Section
                    _buildSectionHeader(context, 'Settings'),
                    _buildMenuItem(
                      context,
                      icon: Icons.settings_outlined,
                      title: 'Settings',
                      subtitle: 'App preferences and options',
                      onTap: () => NavigationHelper.safePush(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // About Section
                    _buildSectionHeader(context, 'About'),
                    _buildMenuItem(
                      context,
                      icon: Icons.info_outline,
                      title: 'About N3RD Trivia',
                      subtitle: 'Version 1.0.0',
                      onTap: () => _showAboutDialog(context),
                    ),
                    const SizedBox(height: 8),
                    const Divider(color: Colors.white24),
                    _buildMenuItem(
                      context,
                      icon: Icons.logout,
                      title: 'Sign Out',
                      subtitle: 'Sign out of your account',
                      onTap: () => _showSignOutDialog(context),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final headerColors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: AppTypography.labelSmall.copyWith(
          color: headerColors.onDarkText.withValues(alpha: 0.7),
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.transparent, // Transparent background to match Stats tab
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2), // White border to match Stats tab
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white, size: 24), // White icons
        title: Text(
          title,
          style: AppTypography.titleLarge.copyWith(
            color: Colors.white, // White text
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTypography.bodyMedium.copyWith(
            color: Colors.white.withValues(alpha: 0.8), // White text with opacity
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Colors.white.withValues(alpha: 0.8), // White chevron
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    final dialogColors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dialogColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Sign Out?', style: AppTypography.headlineLarge),
        content: Text(
          'Are you sure you want to sign out?',
          style: AppTypography.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppTypography.labelLarge),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final authService = Provider.of<AuthService>(context, listen: false);
                await authService.signOut();
                if (context.mounted) {
                  NavigationHelper.safeNavigate(context, '/login', replace: true);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error signing out: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              'Sign Out',
              style: AppTypography.labelLarge.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    final dialogColors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dialogColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('N3RD Trivia', style: AppTypography.headlineLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Test your memory with trivia challenges.',
              style: AppTypography.bodyLarge,
            ),
            const SizedBox(height: 16),
            Text(
              'Version 1.0.0',
              style: AppTypography.bodyMedium.copyWith(
                color: dialogColors.secondaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Created by Girard Clairsaint',
              style: AppTypography.bodyMedium.copyWith(
                color: dialogColors.secondaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Copyright N3RD Trivia ${DateTime.now().year}',
              style: AppTypography.bodyMedium.copyWith(
                color: dialogColors.secondaryText,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: AppTypography.labelLarge),
          ),
        ],
      ),
    );
  }
}
