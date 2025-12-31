import 'package:flutter/material.dart';
import 'package:n3rd_game/utils/unawaited_helper.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/widgets/video_background_widget.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/utils/responsive_helper.dart';
import 'package:n3rd_game/utils/error_handler.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/widgets/subscription_tier_indicator.dart';
import 'package:n3rd_game/widgets/network_status_indicator.dart';
import 'package:n3rd_game/widgets/tier_progress_indicator.dart';
import 'package:n3rd_game/widgets/feature_tooltip_widget.dart';
import 'package:n3rd_game/services/haptic_service.dart';
import 'package:n3rd_game/services/auth_service.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:n3rd_game/utils/accessibility_helper.dart';
import 'package:n3rd_game/utils/provider_helper.dart';

class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> {
  PackageInfo? _packageInfo;
  bool _loadingPackageInfo = false;

  @override
  void initState() {
    super.initState();
    // Load package info for version display
    _loadPackageInfo();
    // Track screen view
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _trackScreenView();
      }
    });
  }

  /// Load package info for version display
  Future<void> _loadPackageInfo() async {
    if (_loadingPackageInfo) return;
    _loadingPackageInfo = true;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _packageInfo = packageInfo;
        });
      }
    } catch (e) {
      // Non-critical - version display will use fallback
      if (mounted) {
        setState(() {
          _packageInfo = null;
        });
      }
    } finally {
      _loadingPackageInfo = false;
    }
  }

  /// Track screen view analytics (non-blocking)
  void _trackScreenView() {
    try {
      final analytics = ProviderHelper.safeGetOrThrow<AnalyticsService>(context, listen: false);
      analytics.logScreenView('title').catchError((e) {
        // Non-critical
      });
    } catch (e) {
      // Analytics not available - non-critical
    }
  }

  /// Track menu drawer open (non-blocking)
  void _trackMenuDrawerOpen() {
    try {
      final analytics = ProviderHelper.safeGetOrThrow<AnalyticsService>(context, listen: false);
      analytics.logCustomEvent('title_menu_drawer_open').catchError((e) {
        // Non-critical
      });
    } catch (e) {
      // Analytics not available - non-critical
    }
  }

  /// Track menu item click (non-blocking)
  void _trackMenuItemClick(String itemName) {
    try {
      final analytics = ProviderHelper.safeGetOrThrow<AnalyticsService>(context, listen: false);
      analytics.logCustomEvent(
        'title_menu_item_click',
        parameters: {
          'item': itemName,
        },
      ).catchError(
        (e) {
          // Non-critical
        },
      );
    } catch (e) {
      // Analytics not available - non-critical
    }
  }

  /// Track upgrade dialog shown (non-blocking)
  void _trackUpgradeDialogShown(String feature) {
    try {
      final analytics = ProviderHelper.safeGetOrThrow<AnalyticsService>(context, listen: false);
      analytics
          .logUpgradeDialogShown(
        source: feature.toLowerCase().replaceAll(' ', '_'),
        targetTier: 'premium',
      )
          .catchError((e) {
        // Non-critical
      });
    } catch (e) {
      // Analytics not available - non-critical
    }
  }

  /// Track about dialog shown (non-blocking)
  void _trackAboutDialogShown() {
    try {
      final analytics = ProviderHelper.safeGetOrThrow<AnalyticsService>(context, listen: false);
      analytics.logCustomEvent('title_about_dialog_shown').catchError((e) {
        // Non-critical
      });
    } catch (e) {
      // Analytics not available - non-critical
    }
  }

  /// Track sign out attempt (non-blocking)
  void _trackSignOutAttempt() {
    try {
      final analytics = ProviderHelper.safeGetOrThrow<AnalyticsService>(context, listen: false);
      analytics.logCustomEvent('title_sign_out_attempt').catchError((e) {
        // Non-critical
      });
    } catch (e) {
      // Analytics not available - non-critical
    }
  }

  Widget _buildMenuButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isPrimary = false,
    Color? backgroundColor,
    Color? foregroundColor,
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

    // Use custom colors if provided, otherwise use default
    final buttonBgColor = backgroundColor ?? colors.primaryButton;
    final buttonFgColor = foregroundColor ?? colors.buttonText;

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
            backgroundColor: buttonBgColor,
            foregroundColor: buttonFgColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide.none,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: buttonFgColor, size: iconSize),
              SizedBox(
                width: ResponsiveHelper.responsiveWidth(context, 0.02)
                    .clamp(4.0, 12.0),
              ),
              Flexible(
                child: Text(
                  label,
                  style: AccessibilityHelper.getScaledTextStyle(
                    context,
                    AppTypography.labelLarge.copyWith(
                      fontSize: fontSize,
                      color: buttonFgColor,
                    ),
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.visible,
                  softWrap: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMenuDrawer(BuildContext context) {
    _trackMenuDrawerOpen();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // Allow full expansion
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height *
                0.9, // Allow up to 90% of screen
          ),
          decoration: BoxDecoration(
            color: AppColors.overlayDark
                .withValues(alpha: 0.7), // Match privacy screen tile color
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.of(context).borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Subscription Tier Indicator
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: SubscriptionTierIndicator(compact: true),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      NetworkStatusIndicator(compact: true),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Tier Progress Indicator (for free users)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: TierProgressIndicator(showIcon: false),
                ),
                const SizedBox(height: AppSpacing.md),
                Divider(color: AppColors.of(context).borderLight),
                // Make drawer scrollable to prevent overflow
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                          label: AppLocalizations.of(context)?.wordOfTheDay ??
                              'Word of the Day',
                          button: true,
                          child: ListTile(
                            leading: _buildLeadingIcon(Icons.book_outlined),
                            title: Text(
                              AppLocalizations.of(context)?.wordOfTheDay ??
                                  'Word of the Day',
                              style: AppTypography.labelLarge.copyWith(
                                color: AppColors.of(context).onDarkText,
                              ),
                            ),
                            onTap: () {
                              HapticService().lightImpact();
                              _trackMenuItemClick('word_of_day');
                              if (context.mounted) {
                                NavigationHelper.safePop(context);
                                if (context.mounted) {
                                  NavigationHelper.safeNavigate(
                                    context,
                                    '/word-of-day',
                                  );
                                }
                              }
                            },
                          ),
                        ),
                        Selector<SubscriptionService, bool>(
                          selector: (_, service) => service.hasEditionsAccess,
                          builder: (context, hasEditionsAccess, _) {
                            if (!hasEditionsAccess) {
                              return FeatureTooltipWidget(
                                featureName: 'Editions',
                                requiresEditionsAccess: true,
                                child: ListTile(
                                  leading: _buildLeadingIcon(
                                    Icons.collections_bookmark_outlined,
                                  ),
                                  title: Text(
                                    AppLocalizations.of(context)?.editions ??
                                        'Editions',
                                    style: AppTypography.labelLarge.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                  trailing:
                                      const Icon(Icons.lock_outline, size: 16),
                                  onTap: () {
                                    HapticService().lightImpact();
                                    _trackMenuItemClick('editions_locked');
                                    _trackUpgradeDialogShown('Editions');
                                    if (context.mounted) {
                                      NavigationHelper.safePop(context);
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
                                Icons.collections_bookmark_outlined,
                              ),
                              title: Text(
                                AppLocalizations.of(context)?.editions ??
                                    'Editions',
                                style: AppTypography.labelLarge.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              onTap: () {
                                HapticService().lightImpact();
                                _trackMenuItemClick('editions');
                                if (context.mounted) {
                                  NavigationHelper.safePop(context);
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
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.of(context).onDarkText,
                            ),
                          ),
                          onTap: () {
                            HapticService().lightImpact();
                            _trackMenuItemClick('leaderboard');
                            if (context.mounted) {
                              NavigationHelper.safePop(context);
                              if (context.mounted) {
                                // Navigate to leaderboard screen
                                NavigationHelper.safeNavigate(
                                    context, '/leaderboard',);
                              }
                            }
                          },
                        ),
                        ListTile(
                          leading: _buildLeadingIcon(Icons.history_outlined),
                          title: Text(
                            AppLocalizations.of(context)?.gameHistory ??
                                'Game History',
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.of(context).onDarkText,
                            ),
                          ),
                          onTap: () {
                            HapticService().lightImpact();
                            _trackMenuItemClick('game_history');
                            if (context.mounted) {
                              NavigationHelper.safePop(context);
                              if (context.mounted) {
                                // Navigate to game history screen
                                NavigationHelper.safeNavigate(
                                    context, '/game-history',);
                              }
                            }
                          },
                        ),
                        Selector<SubscriptionService, bool>(
                          selector: (_, service) => service.isPremium,
                          builder: (context, isPremium, _) {
                            if (!isPremium) {
                              return const SizedBox.shrink();
                            }
                            return ListTile(
                              leading: _buildLeadingIcon(Icons.school_outlined),
                              title: Text(
                                AppLocalizations.of(context)?.learningMode ??
                                    'Learning Mode',
                                style: AppTypography.labelLarge.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              onTap: () {
                                HapticService().lightImpact();
                                _trackMenuItemClick('learning_mode');
                                if (context.mounted) {
                                  NavigationHelper.safePop(context);
                                  if (context.mounted) {
                                    NavigationHelper.safeNavigate(
                                      context,
                                      '/learning',
                                    );
                                  }
                                }
                              },
                            );
                          },
                        ),
                        Selector<SubscriptionService, bool>(
                          selector: (_, service) => service.hasOnlineAccess,
                          builder: (context, hasOnlineAccess, _) {
                            if (!hasOnlineAccess) {
                              return FeatureTooltipWidget(
                                featureName: 'Daily Challenges',
                                requiresOnlineAccess: true,
                                child: ListTile(
                                  leading: _buildLeadingIcon(
                                    Icons.event_available_outlined,
                                  ),
                                  title: Text(
                                    'Daily Challenges',
                                    style: AppTypography.labelLarge.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                  trailing:
                                      const Icon(Icons.lock_outline, size: 16),
                                  onTap: () {
                                    HapticService().lightImpact();
                                    _trackMenuItemClick(
                                        'daily_challenges_locked',);
                                    _trackUpgradeDialogShown(
                                        'Daily Challenges',);
                                    if (context.mounted) {
                                      NavigationHelper.safePop(context);
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
                                Icons.event_available_outlined,
                              ),
                              title: Text(
                                'Daily Challenges',
                                style: AppTypography.labelLarge.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              onTap: () {
                                HapticService().lightImpact();
                                _trackMenuItemClick('daily_challenges');
                                if (context.mounted) {
                                  NavigationHelper.safePop(context);
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
                            AppLocalizations.of(context)?.manageSubscriptions ??
                                'Manage Subscriptions',
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.of(context).onDarkText,
                            ),
                          ),
                          onTap: () {
                            HapticService().lightImpact();
                            _trackMenuItemClick('manage_subscriptions');
                            if (context.mounted) {
                              NavigationHelper.safePop(context);
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
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.of(context).onDarkText,
                            ),
                          ),
                          onTap: () {
                            HapticService().lightImpact();
                            _trackMenuItemClick('about');
                            _trackAboutDialogShown();
                            if (context.mounted) {
                              NavigationHelper.safePop(context);
                              if (context.mounted) {
                                _showAboutDialog(context);
                              }
                            }
                          },
                        ),
                        Divider(
                            color: AppColors.of(context)
                                .borderLight
                                .withValues(alpha: 0.3),),
                        ListTile(
                          leading: _buildLeadingIcon(Icons.logout),
                          title: Text(
                            AppLocalizations.of(context)?.signOut ?? 'Sign Out',
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.of(context).onDarkText,
                            ),
                          ),
                          onTap: () {
                            HapticService().lightImpact();
                            _trackMenuItemClick('sign_out');
                            _trackSignOutAttempt();
                            if (context.mounted) {
                              NavigationHelper.safePop(context);
                              if (context.mounted) {
                                _showSignOutDialog(context);
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
                    AppLocalizations.of(context)
                            ?.copyright(DateTime.now().year) ??
                        'Copyright N3RD Trivia ${DateTime.now().year}',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.of(context)
                          .onDarkText
                          .withValues(alpha: 0.6),
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
    _trackUpgradeDialogShown(feature);
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

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.of(context)?.signOutTitle ?? 'Sign Out?',
          style: AppTypography.displayMedium.copyWith(fontSize: 20),
        ),
        content: Text(
          AppLocalizations.of(context)?.signOutConfirmation ??
              'Are you sure you want to sign out?',
          style: AppTypography.bodyMedium,
        ),
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
            onPressed: () async {
              unawaited(HapticService().lightImpact());
              NavigationHelper.safePop(context);
              // Show loading state during sign out
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.onDarkText,),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          AppLocalizations.of(context)?.loading ?? 'Loading...',
                        ),
                      ],
                    ),
                    duration: const Duration(
                        seconds: 30,), // Long duration for async operation
                  ),
                );
              }
              try {
                final authService =
                    ProviderHelper.safeGetOrThrow<AuthService>(context, listen: false);
                await authService.signOut();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  unawaited(NavigationHelper.safeNavigate(context, '/login',
                      replace: true,),);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ErrorHandler.showSnackBar(context, null, error: e);
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              AppLocalizations.of(context)?.signOut ?? 'Sign Out',
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
          AppLocalizations.of(context)?.aboutN3RD ?? 'About N3RD',
          style: AppTypography.displayMedium.copyWith(fontSize: 24),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)?.appDescription ??
                    'Test your memory with trivia challenges.',
                style: AppTypography.bodyLarge,
              ),
              const SizedBox(height: 16),
              Text(
                '${AppLocalizations.of(context)?.versionWithNumber ?? 'Version'} ${_packageInfo?.version ?? '1.0.0'}',
                style: AppTypography.bodyMedium.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${AppLocalizations.of(context)?.createdByLabel ?? 'Created by'} Girard Clairsaint',
                style: AppTypography.bodyMedium.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)
                        ?.releaseDate('November 18, 2025') ??
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
    // FIXED: Use switchToTab to properly navigate to modes tab (index 1)
    NavigationHelper.switchToTab(context, 1);
  }

  void _switchToMoreTab(BuildContext context) {
    // FIXED: Use switchToTab to properly navigate to more tab (index 4)
    NavigationHelper.switchToTab(context, 4);
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
      body: VideoBackgroundWidget(
        videoPath: 'assets/titlescreen.mp4',
        fit: BoxFit.cover, // CSS object-fit: cover equivalent
        alignment: Alignment.topCenter, // Characters/logos in upper portion
        loop: true,
        autoplay: true,
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  // Top app bar (minimal)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
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
                              // Spacer reduced to move content up ~1/4 inch (logos are in upper portion)
                              SizedBox(
                                height: ResponsiveHelper.responsiveHeight(
                                  context,
                                  0.08,
                                ).clamp(40.0, 80.0),
                              ),

                              // Title - Professional Serif (responsive)
                              Builder(
                                builder: (context) {
                                  final screenWidth =
                                      ResponsiveHelper.responsiveWidth(
                                    context,
                                    1.0,
                                  );
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
                                    context,
                                    0.015,
                                  ).clamp(8.0, 16.0);

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
                                    context,
                                    1.0,
                                  );
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
                                    context,
                                    0.04,
                                  ).clamp(24.0, 40.0);

                                  return Column(
                                    children: [
                                      Text(
                                        (AppLocalizations.of(context)
                                                    ?.appDescription ??
                                                'Test your memory with trivia challenges.')
                                            .replaceAll('. ', '.\n'),
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
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                              ),

                              Builder(
                                builder: (context) {
                                  final buttonSpacing =
                                      ResponsiveHelper.responsiveHeight(
                                    context,
                                    0.015,
                                  ).clamp(8.0, 16.0);
                                  return SizedBox(height: buttonSpacing);
                                },
                              ),

                              // Daily Challenges Button
                              Selector<SubscriptionService, bool>(
                                selector: (_, service) =>
                                    service.hasOnlineAccess,
                                builder: (context, hasOnlineAccess, _) {
                                  if (!hasOnlineAccess) {
                                    return _buildMenuButton(
                                      context,
                                      icon: Icons.event_available_outlined,
                                      label: 'Daily Challenges (Locked)',
                                      onPressed: () => _showUpgradeDialog(
                                        context,
                                        'Daily Challenges',
                                        'Upgrade to Premium to access daily challenges and leaderboards!',
                                      ),
                                      isPrimary: false,
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                    );
                                  }
                                  return _buildMenuButton(
                                    context,
                                    icon: Icons.event_available_outlined,
                                    label: 'Daily Challenges',
                                    onPressed: () {
                                      NavigationHelper.safeNavigate(
                                        context,
                                        '/daily-challenges',
                                      );
                                    },
                                    isPrimary: false,
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                  );
                                },
                              ),

                              Builder(
                                builder: (context) {
                                  final buttonSpacing =
                                      ResponsiveHelper.responsiveHeight(
                                    context,
                                    0.015,
                                  ).clamp(8.0, 16.0);
                                  return SizedBox(height: buttonSpacing);
                                },
                              ),

                              // Connect Button
                              Selector<SubscriptionService, bool>(
                                selector: (_, service) =>
                                    service.hasOnlineAccess,
                                builder: (context, hasOnlineAccess, _) {
                                  if (!hasOnlineAccess) {
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
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
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
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                  );
                                },
                              ),

                              Builder(
                                builder: (context) {
                                  final buttonSpacing =
                                      ResponsiveHelper.responsiveHeight(
                                    context,
                                    0.015,
                                  ).clamp(8.0, 16.0);
                                  return SizedBox(height: buttonSpacing);
                                },
                              ),

                              // Editions Button
                              Selector<SubscriptionService, bool>(
                                selector: (_, service) =>
                                    service.hasEditionsAccess,
                                builder: (context, hasEditionsAccess, _) {
                                  if (!hasEditionsAccess) {
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
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
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
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                  );
                                },
                              ),

                              Builder(
                                builder: (context) {
                                  final buttonSpacing =
                                      ResponsiveHelper.responsiveHeight(
                                    context,
                                    0.015,
                                  ).clamp(8.0, 16.0);
                                  return SizedBox(height: buttonSpacing);
                                },
                              ),

                              // Settings Button - goes to More tab (white with black text)
                              _buildMenuButton(
                                context,
                                icon: Icons.settings_outlined,
                                label: 'Settings',
                                onPressed: () => _switchToMoreTab(context),
                                isPrimary: false,
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
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