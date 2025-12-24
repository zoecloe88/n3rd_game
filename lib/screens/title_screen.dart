import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/widgets/unified_background_widget.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/utils/responsive_helper.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/widgets/subscription_tier_indicator.dart';
import 'package:n3rd_game/widgets/network_status_indicator.dart';
import 'package:n3rd_game/widgets/tier_progress_indicator.dart';
import 'package:n3rd_game/widgets/feature_tooltip_widget.dart';
import 'package:n3rd_game/services/haptic_service.dart';

class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> {
  Widget _buildMenuButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    final colors = AppColors.of(context);
    final screenWidth = ResponsiveHelper.responsiveWidth(context, 1.0);

    // Responsive padding: 8% of screen width, min 16px, max 48px
    final horizontalPadding =
        ResponsiveHelper.responsiveWidth(context, 0.08).clamp(16.0, 48.0);

    // Responsive button height: 7% of screen height, min 48px, max 64px
    final buttonHeight =
        ResponsiveHelper.responsiveHeight(context, 0.07).clamp(48.0, 64.0);

    // Responsive font size: 4.5% of screen width, min 14px, max 20px
    final fontSize = ResponsiveHelper.responsiveFontSize(
      context,
      baseSize: screenWidth * 0.045,
      minSize: 14.0,
      maxSize: 20.0,
    );

    // Responsive icon size: proportional to font size with reasonable bounds
    // Ensures icons are not too small on small screens or too large on tablets
    final iconSize = (fontSize * 1.1).clamp(16.0, 28.0);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: SizedBox(
        width: double.infinity,
        height: buttonHeight,
        child: ElevatedButton(
          onPressed: () {
            HapticService().lightImpact();
            onPressed();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primaryButton,
            foregroundColor: colors.buttonText,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide.none,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: colors.buttonText, size: iconSize),
              SizedBox(
                  width: ResponsiveHelper.responsiveWidth(context, 0.02)
                      .clamp(4.0, 12.0),),
              Flexible(
                child: Text(
                  label,
                  style: AppTypography.labelLarge.copyWith(fontSize: fontSize),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMenuDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // Allow full expansion
      builder: (context) {
        final colors = AppColors.of(context);
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height *
                0.9, // Allow up to 90% of screen
          ),
          decoration: BoxDecoration(
            color: colors.cardBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                // Subscription Tier Indicator
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: SubscriptionTierIndicator(compact: true),
                      ),
                      SizedBox(width: 8),
                      NetworkStatusIndicator(compact: true),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Tier Progress Indicator (for free users)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: TierProgressIndicator(showIcon: false),
                ),
                const SizedBox(height: 16),
                const Divider(),
                // Make drawer scrollable to prevent overflow
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: _buildLeadingIcon(Icons.book_outlined),
                          title: Text(
                            AppLocalizations.of(context)?.wordOfTheDay ??
                                'Word of the Day',
                            style: AppTypography.labelLarge,
                          ),
                          onTap: () {
                            HapticService().lightImpact();
                            if (context.mounted) {
                              Navigator.pop(context);
                              if (context.mounted) {
                                NavigationHelper.safeNavigate(
                                    context, '/word-of-day',);
                              }
                            }
                          },
                        ),
                        Consumer<SubscriptionService>(
                          builder: (context, subscriptionService, _) {
                            if (!subscriptionService.hasEditionsAccess) {
                              return FeatureTooltipWidget(
                                featureName: 'Editions',
                                requiresEditionsAccess: true,
                                child: ListTile(
                                  leading: _buildLeadingIcon(
                                      Icons.collections_bookmark_outlined,),
                                  title: Text(
                                    AppLocalizations.of(context)?.editions ??
                                        'Editions',
                                    style: AppTypography.labelLarge,
                                  ),
                                  trailing:
                                      const Icon(Icons.lock_outline, size: 16),
                                  onTap: () {
                                    HapticService().lightImpact();
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      if (context.mounted) {
                                        _showUpgradeDialog(
                                          context,
                                          'Editions',
                                          'Upgrade to Premium to access all editions!',
                                        );
                                      }
                                    }
                                  },
                                ),
                              );
                            }
                            return ListTile(
                              leading: _buildLeadingIcon(
                                  Icons.collections_bookmark_outlined,),
                              title: Text(
                                AppLocalizations.of(context)?.editions ??
                                    'Editions',
                                style: AppTypography.labelLarge,
                              ),
                              onTap: () {
                                HapticService().lightImpact();
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  if (context.mounted) {
                                    NavigationHelper.safeNavigate(
                                      context,
                                      '/general-transition',
                                      arguments: {
                                        'routeAfter': '/editions-selection',
                                        'routeArgs': null,
                                      },
                                    );
                                  }
                                }
                              },
                            );
                          },
                        ),
                        ListTile(
                          leading:
                              _buildLeadingIcon(Icons.leaderboard_outlined),
                          title: Text(
                            AppLocalizations.of(context)?.leaderboard ??
                                'Leaderboard',
                            style: AppTypography.labelLarge,
                          ),
                          onTap: () {
                            HapticService().lightImpact();
                            if (context.mounted) {
                              Navigator.pop(context);
                              if (context.mounted) {
                                NavigationHelper.switchToTab(context, 3);
                              }
                            }
                          },
                        ),
                        ListTile(
                          leading: _buildLeadingIcon(Icons.history_outlined),
                          title: Text(
                            AppLocalizations.of(context)?.gameHistory ??
                                'Game History',
                            style: AppTypography.labelLarge,
                          ),
                          onTap: () {
                            HapticService().lightImpact();
                            if (context.mounted) {
                              Navigator.pop(context);
                              if (context.mounted) {
                                NavigationHelper.switchToTab(context, 2);
                              }
                            }
                          },
                        ),
                        Consumer<SubscriptionService>(
                          builder: (context, subscriptionService, _) {
                            if (!subscriptionService.isPremium) {
                              return const SizedBox.shrink();
                            }
                            return ListTile(
                              leading: _buildLeadingIcon(Icons.school_outlined),
                              title: Text(
                                AppLocalizations.of(context)?.learningMode ??
                                    'Learning Mode',
                                style: AppTypography.labelLarge,
                              ),
                              onTap: () {
                                HapticService().lightImpact();
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  if (context.mounted) {
                                    NavigationHelper.safeNavigate(
                                        context, '/learning',);
                                  }
                                }
                              },
                            );
                          },
                        ),
                        Consumer<SubscriptionService>(
                          builder: (context, subscriptionService, _) {
                            if (!subscriptionService.hasOnlineAccess) {
                              return FeatureTooltipWidget(
                                featureName: 'Daily Challenges',
                                requiresOnlineAccess: true,
                                child: ListTile(
                                  leading: _buildLeadingIcon(
                                      Icons.event_available_outlined,),
                                  title: Text(
                                    'Daily Challenges',
                                    style: AppTypography.labelLarge,
                                  ),
                                  trailing:
                                      const Icon(Icons.lock_outline, size: 16),
                                  onTap: () {
                                    HapticService().lightImpact();
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      if (context.mounted) {
                                        _showUpgradeDialog(
                                          context,
                                          'Daily Challenges',
                                          'Upgrade to Premium to access daily challenges and leaderboards!',
                                        );
                                      }
                                    }
                                  },
                                ),
                              );
                            }
                            return ListTile(
                              leading: _buildLeadingIcon(
                                  Icons.event_available_outlined,),
                              title: Text(
                                'Daily Challenges',
                                style: AppTypography.labelLarge,
                              ),
                              onTap: () {
                                HapticService().lightImpact();
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  if (context.mounted) {
                                    NavigationHelper.safeNavigate(
                                      context,
                                      '/daily-challenges',
                                    );
                                  }
                                }
                              },
                            );
                          },
                        ),
                        ListTile(
                          leading:
                              _buildLeadingIcon(Icons.card_membership_outlined),
                          title: Text(
                            'Manage Subscriptions',
                            style: AppTypography.labelLarge,
                          ),
                          onTap: () {
                            HapticService().lightImpact();
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
                        ),
                        ListTile(
                          leading: _buildLeadingIcon(Icons.info_outline),
                          title: Text(
                            AppLocalizations.of(context)?.about ?? 'About',
                            style: AppTypography.labelLarge,
                          ),
                          onTap: () {
                            HapticService().lightImpact();
                            if (context.mounted) {
                              Navigator.pop(context);
                              if (context.mounted) {
                                _showAboutDialog(context);
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                // Bottom copyright
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    'Copyright N3RD Trivia ${DateTime.now().year}',
                    style: AppTypography.labelSmall.copyWith(
                      fontSize: 11,
                      color: colors.onDarkText.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showUpgradeDialog(
    BuildContext context,
    String feature,
    String message,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '$feature - ${AppLocalizations.of(context)?.premiumFeature ?? 'Premium Feature'}',
          style: AppTypography.displayMedium.copyWith(fontSize: 20),
        ),
        content: Text(message, style: AppTypography.bodyMedium),
        actions: [
          TextButton(
            onPressed: () {
              HapticService().lightImpact();
              NavigationHelper.safePop(context);
            },
            child: Text(
              AppLocalizations.of(context)?.cancel ?? 'Cancel',
              style: AppTypography.labelLarge,
            ),
          ),
          ElevatedButton(
            onPressed: () {
              HapticService().lightImpact();
              NavigationHelper.safePop(context);
              NavigationHelper.safeNavigate(
                context,
                '/subscription-management',
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: Text(
              AppLocalizations.of(context)?.upgrade ?? 'Upgrade',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.of(context).onDarkText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'About N3RD',
          style: AppTypography.displayMedium.copyWith(fontSize: 24),
        ),
        content: SingleChildScrollView(
          child: Column(
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
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Created by Gerard',
                style: AppTypography.bodyMedium.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'November 18, 2025',
                style: AppTypography.bodyMedium.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => NavigationHelper.safePop(context),
            child: Text(
              AppLocalizations.of(context)?.close ?? 'Close',
              style: AppTypography.labelLarge,
            ),
          ),
        ],
      ),
    );
  }

  void _switchToModeTab(BuildContext context) {
    // Use pushReplacementNamed to switch to modes tab
    NavigationHelper.safeNavigate(context, '/modes', replace: true);
  }

  void _switchToStatsTab(BuildContext context) {
    NavigationHelper.safeNavigate(context, '/stats', replace: true);
  }

  void _switchToLeaderboardTab(BuildContext context) {
    NavigationHelper.safeNavigate(context, '/leaderboard', replace: true);
  }

  void _switchToMoreTab(BuildContext context) {
    NavigationHelper.safeNavigate(context, '/more', replace: true);
  }

  /// Helper to build leading icon
  Widget _buildLeadingIcon(IconData icon, {double size = 24}) {
    final colors = AppColors.of(context);
    return Icon(icon, size: size, color: colors.primaryText);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: UnifiedBackgroundWidget(
        videoPath:
            'assets/animations/Green Neutral Simple Serendipity Phone Wallpaper(1)/title screen.mp4',
        fit: BoxFit.cover, // Fill screen, logos in upper portion
        alignment: Alignment.topCenter, // Align to top where logos are
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  // Top app bar (minimal)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Menu button - opens drawer with options
                        Semantics(
                          label: AppLocalizations.of(context)?.menuButton ??
                              'Menu',
                          button: true,
                          child: IconButton(
                            icon: Icon(Icons.menu, color: colors.onDarkText),
                            onPressed: () => _showMenuDrawer(context),
                            tooltip: AppLocalizations.of(context)?.menuButton ??
                                'Menu',
                          ),
                        ),
                        // Settings button - goes to More tab
                        Semantics(
                          label: AppLocalizations.of(context)?.settingsButton ??
                              'Settings',
                          button: true,
                          child: IconButton(
                            icon: Icon(
                              Icons.settings_outlined,
                              color: colors.onDarkText,
                            ),
                            onPressed: () => _switchToMoreTab(context),
                            tooltip:
                                AppLocalizations.of(context)?.settingsButton ??
                                    'Settings',
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Center content - scrollable to ensure all buttons are visible
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Responsive padding: 4% of screen width/height, min 8px, max 24px
                        final horizontalPadding =
                            ResponsiveHelper.responsiveWidth(context, 0.04)
                                .clamp(8.0, 24.0);
                        final verticalPadding =
                            ResponsiveHelper.responsiveHeight(context, 0.025)
                                .clamp(12.0, 24.0);

                        return SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: verticalPadding,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Spacer to push content to lower portion (logos are in upper portion)
                              SizedBox(
                                  height: ResponsiveHelper.responsiveHeight(
                                          context, 0.35,)
                                      .clamp(200.0, 400.0),),

                              // Title - Professional Serif (responsive)
                              Builder(
                                builder: (context) {
                                  final screenWidth =
                                      ResponsiveHelper.responsiveWidth(
                                          context, 1.0,);
                                  // Responsive title font size: 11% of screen width, min 28px, max 56px
                                  final titleFontSize =
                                      ResponsiveHelper.responsiveFontSize(
                                    context,
                                    baseSize: screenWidth * 0.11,
                                    minSize: 28.0,
                                    maxSize: 56.0,
                                  );
                                  // Responsive spacing
                                  final titleSpacing =
                                      ResponsiveHelper.responsiveHeight(
                                              context, 0.015,)
                                          .clamp(8.0, 16.0);

                                  return Column(
                                    children: [
                                      Text(
                                        'N3RD Trivia',
                                        style:
                                            AppTypography.displayLarge.copyWith(
                                          fontSize: titleFontSize,
                                          color: colors.onDarkText,
                                          letterSpacing: 2.0,
                                        ),
                                      ),
                                      SizedBox(height: titleSpacing),
                                    ],
                                  );
                                },
                              ),

                              // Subtitle - Elegant Serif (responsive)
                              Builder(
                                builder: (context) {
                                  final screenWidth =
                                      ResponsiveHelper.responsiveWidth(
                                          context, 1.0,);
                                  // Responsive subtitle font size: 4.2% of screen width, min 14px, max 20px
                                  final subtitleFontSize =
                                      ResponsiveHelper.responsiveFontSize(
                                    context,
                                    baseSize: screenWidth * 0.042,
                                    minSize: 14.0,
                                    maxSize: 20.0,
                                  );
                                  final sectionSpacing =
                                      ResponsiveHelper.responsiveHeight(
                                              context, 0.04,)
                                          .clamp(24.0, 40.0);

                                  return Column(
                                    children: [
                                      Text(
                                        'Test your memory with\ntrivia challenges.',
                                        textAlign: TextAlign.center,
                                        style: AppTypography.bodyLarge.copyWith(
                                          fontSize: subtitleFontSize,
                                          color: colors.onDarkText.withValues(
                                            alpha: 0.9,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: sectionSpacing),
                                    ],
                                  );
                                },
                              ),

                              // Buttons - all visible and scrollable
                              // Choose Mode Button
                              _buildMenuButton(
                                context,
                                icon: Icons.swap_horiz,
                                label: 'Choose Mode',
                                onPressed: () => _switchToModeTab(context),
                                isPrimary: true,
                              ),

                              Builder(
                                builder: (context) {
                                  final buttonSpacing =
                                      ResponsiveHelper.responsiveHeight(
                                              context, 0.015,)
                                          .clamp(8.0, 16.0);
                                  return SizedBox(height: buttonSpacing);
                                },
                              ),

                              // Stats Button
                              _buildMenuButton(
                                context,
                                icon: Icons.bar_chart_outlined,
                                label: 'Stats',
                                onPressed: () => _switchToStatsTab(context),
                                isPrimary: false,
                              ),

                              Builder(
                                builder: (context) {
                                  final buttonSpacing =
                                      ResponsiveHelper.responsiveHeight(
                                              context, 0.015,)
                                          .clamp(8.0, 16.0);
                                  return SizedBox(height: buttonSpacing);
                                },
                              ),

                              // Leaderboard Button
                              _buildMenuButton(
                                context,
                                icon: Icons.leaderboard_outlined,
                                label: 'Leaderboard',
                                onPressed: () =>
                                    _switchToLeaderboardTab(context),
                                isPrimary: false,
                              ),

                              Builder(
                                builder: (context) {
                                  final buttonSpacing =
                                      ResponsiveHelper.responsiveHeight(
                                              context, 0.015,)
                                          .clamp(8.0, 16.0);
                                  return SizedBox(height: buttonSpacing);
                                },
                              ),

                              // Connect Button
                              Consumer<SubscriptionService>(
                                builder: (context, subscriptionService, _) {
                                  if (!subscriptionService.hasOnlineAccess) {
                                    return _buildMenuButton(
                                      context,
                                      icon: Icons.people_outline,
                                      label: 'Connect (Locked)',
                                      onPressed: () => _showUpgradeDialog(
                                        context,
                                        'Connect',
                                        'Upgrade to Premium to access multiplayer and social features!',
                                      ),
                                      isPrimary: false,
                                    );
                                  }
                                  return _buildMenuButton(
                                    context,
                                    icon: Icons.people_outline,
                                    label: 'Connect',
                                    onPressed: () {
                                      // Navigate to Friends tab instead of direct message
                                      NavigationHelper.switchToTab(context, 3);
                                    },
                                    isPrimary: false,
                                  );
                                },
                              ),

                              Builder(
                                builder: (context) {
                                  final buttonSpacing =
                                      ResponsiveHelper.responsiveHeight(
                                              context, 0.015,)
                                          .clamp(8.0, 16.0);
                                  return SizedBox(height: buttonSpacing);
                                },
                              ),

                              // Editions Button
                              Consumer<SubscriptionService>(
                                builder: (context, subscriptionService, _) {
                                  if (!subscriptionService.hasEditionsAccess) {
                                    return _buildMenuButton(
                                      context,
                                      icon: Icons.collections_bookmark_outlined,
                                      label: 'Editions (Locked)',
                                      onPressed: () => _showUpgradeDialog(
                                        context,
                                        'Editions',
                                        'Upgrade to Premium to access all editions!',
                                      ),
                                      isPrimary: false,
                                    );
                                  }
                                  return _buildMenuButton(
                                    context,
                                    icon: Icons.collections_bookmark_outlined,
                                    label: 'Editions',
                                    onPressed: () =>
                                        NavigationHelper.safeNavigate(
                                      context,
                                      '/general-transition',
                                      arguments: {
                                        'routeAfter': '/editions-selection',
                                        'routeArgs': null,
                                      },
                                    ),
                                    isPrimary: false,
                                  );
                                },
                              ),

                              Builder(
                                builder: (context) {
                                  final buttonSpacing =
                                      ResponsiveHelper.responsiveHeight(
                                              context, 0.015,)
                                          .clamp(8.0, 16.0);
                                  return SizedBox(height: buttonSpacing);
                                },
                              ),

                              // Settings Button - goes to More tab
                              _buildMenuButton(
                                context,
                                icon: Icons.settings_outlined,
                                label: 'Settings',
                                onPressed: () => _switchToMoreTab(context),
                                isPrimary: false,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
