import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/services/auth_service.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/services/text_to_speech_service.dart';
import 'package:n3rd_game/services/voice_recognition_service.dart';
import 'package:n3rd_game/services/sound_service.dart';
import 'package:n3rd_game/widgets/unified_background_widget.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_shadows.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/screens/feedback_screen.dart';
import 'package:n3rd_game/services/data_export_service.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/utils/responsive_helper.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: UnifiedBackgroundWidget(
        videoPath:
            'assets/animations/Green Neutral Simple Serendipity Phone Wallpaper(1)/setting screen.mp4',
        fit: BoxFit.cover, // Fill screen, logos in upper portion
        alignment: Alignment.topCenter, // Align to top where logos are
        child: SafeArea(
          child: Column(
            children: [
              // Minimal top app bar (logos are in upper portion)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Semantics(
                      label: AppLocalizations.of(context)?.backButton ?? 'Back',
                      button: true,
                      child: IconButton(
                        onPressed: () {
                          // Go back to previous screen, or to title if no back stack
                          if (Navigator.of(context).canPop()) {
                            NavigationHelper.safePop(context);
                          } else {
                            // Navigate to title screen if no back stack
                            NavigationHelper.safeNavigate(context, '/title');
                          }
                        },
                        icon: Icon(Icons.arrow_back, color: colors.onDarkText),
                        tooltip:
                            AppLocalizations.of(context)?.backButton ?? 'Back',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Settings',
                      style: AppTypography.headlineLarge.copyWith(
                        color: colors.onDarkText,
                      ),
                    ),
                  ],
                ),
              ),

              // Spacer to push content to lower portion (logos are in upper portion)
              SizedBox(
                  height: ResponsiveHelper.responsiveHeight(context, 0.15)
                      .clamp(80.0, 150.0)),

              // Profile card
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.cardBackground.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppShadows.light,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: colors.primaryText,
                        child: Text(
                          authService.userEmail
                                  ?.substring(0, 1)
                                  .toUpperCase() ??
                              'U',
                          style: AppTypography.titleLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.buttonText,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              authService.userEmail ?? 'Guest',
                              style: AppTypography.labelLarge.copyWith(
                                fontSize: 15,
                                color: colors.primaryText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppLocalizations.of(context)?.n3rdPlayer ??
                                  'N3RD Player',
                              style: AppTypography.bodyMedium.copyWith(
                                fontSize: 13,
                                color: colors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Settings list
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  children: [
                    // Profile Section
                    Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Column(
                          children: [
                            _buildSectionHeader(
                              context,
                              localizations?.account ?? 'Account',
                            ),
                            _buildSettingTile(
                              context,
                              icon: Icons.person_outline,
                              title:
                                  localizations?.editProfile ?? 'Edit Profile',
                              subtitle: localizations?.editProfileSubtitle ??
                                  'Update display name and avatar',
                              onTap: () =>
                                  _showEditProfileDialog(context, authService),
                            ),
                            _buildSettingTile(
                              context,
                              icon: Icons.email_outlined,
                              title: localizations?.emailSettings ??
                                  'Email Settings',
                              subtitle: localizations?.emailSettingsSubtitle ??
                                  'Manage email notifications',
                              onTap: () => _showEmailSettingsDialog(context),
                            ),
                            const SizedBox(height: AppSpacing.sm),

                            // Premium Features Section
                            _buildSectionHeader(
                              context,
                              localizations?.premiumFeatures ??
                                  'Premium Features',
                            ),
                            _buildSettingTile(
                              context,
                              icon: Icons.notifications_outlined,
                              title: localizations?.notifications ??
                                  'Notifications',
                              subtitle: localizations?.notificationsSubtitle ??
                                  'Push notifications and reminders',
                              onTap: () => _showNotificationsSettings(context),
                            ),
                            _buildSettingTile(
                              context,
                              icon: Icons.emoji_events_outlined,
                              title:
                                  localizations?.achievements ?? 'Achievements',
                              subtitle: localizations?.achievementsSubtitle ??
                                  'View your achievements and badges',
                              onTap: () {
                                NavigationHelper.safeNavigate(
                                  context,
                                  '/achievements',
                                );
                              },
                            ),
                            _buildSettingTile(
                              context,
                              icon: Icons.leaderboard_outlined,
                              title:
                                  localizations?.leaderboard ?? 'Leaderboard',
                              subtitle: localizations?.leaderboardSubtitle ??
                                  'View global rankings',
                              onTap: () {
                                NavigationHelper.safeNavigate(
                                  context,
                                  '/leaderboard',
                                );
                              },
                            ),
                            const SizedBox(height: AppSpacing.sm),

                            // Preferences Section
                            _buildSectionHeader(
                              context,
                              localizations?.preferences ?? 'Preferences',
                            ),
                            _buildSettingTile(
                              context,
                              icon: Icons.volume_up_outlined,
                              title: localizations?.soundAndMusic ??
                                  'Sound & Music',
                              subtitle: localizations?.soundAndMusicSubtitle ??
                                  'Adjust audio settings',
                              onTap: () => _showAudioSettings(context),
                            ),
                            Consumer<SubscriptionService>(
                              builder: (context, subscriptionService, _) {
                                if (!subscriptionService.isPremium) {
                                  return const SizedBox.shrink();
                                }
                                return _buildSettingTile(
                                  context,
                                  icon: Icons.mic_outlined,
                                  title: localizations?.voiceSettings ??
                                      'Voice Settings',
                                  subtitle:
                                      localizations?.voiceSettingsSubtitle ??
                                          'Text-to-speech and voice input',
                                  onTap: () => _showVoiceSettings(context),
                                );
                              },
                            ),
                            Consumer<SubscriptionService>(
                              builder: (context, subscriptionService, _) {
                                if (!subscriptionService.isPremium) {
                                  return const SizedBox.shrink();
                                }
                                return _buildSettingTile(
                                  context,
                                  icon: Icons.record_voice_over_outlined,
                                  title: localizations?.voiceCalibration ??
                                      'Voice Calibration',
                                  subtitle:
                                      localizations?.voiceCalibrationSubtitle ??
                                          'Train voice recognition',
                                  onTap: () => Navigator.of(
                                    context,
                                  ).pushNamed('/voice-calibration'),
                                );
                              },
                            ),
                            _buildSettingTile(
                              context,
                              icon: Icons.dark_mode_outlined,
                              title: localizations?.appearance ?? 'Appearance',
                              subtitle: localizations?.appearanceSubtitle ??
                                  'Theme and display settings',
                              onTap: () => _showAppearanceSettings(context),
                            ),
                            _buildSettingTile(
                              context,
                              icon: Icons.language_outlined,
                              title: localizations?.language ?? 'Language',
                              subtitle: localizations?.languageSubtitle ??
                                  'Change app language',
                              onTap: () => _showLanguageSettings(context),
                            ),
                            _buildSettingTile(
                              context,
                              icon: Icons.tune_outlined,
                              title: localizations?.gameSettingsTitle ??
                                  'Game Settings',
                              subtitle: localizations?.gameSettingsSubtitle ??
                                  'Customize gameplay experience',
                              onTap: () => _showGameSettings(context),
                            ),
                            const SizedBox(height: AppSpacing.sm),

                            // Data & Privacy Section
                            _buildSectionHeader(
                              context,
                              localizations?.dataAndPrivacy ?? 'Data & Privacy',
                            ),
                            _buildSettingTile(
                              context,
                              icon: Icons.privacy_tip_outlined,
                              title: localizations?.privacyPolicy ??
                                  'Privacy Policy',
                              subtitle: localizations?.privacyPolicySubtitle ??
                                  'Read our privacy policy',
                              onTap: () => _showPrivacyPolicy(context),
                            ),
                            _buildSettingTile(
                              context,
                              icon: Icons.description_outlined,
                              title: localizations?.termsOfService ??
                                  'Terms of Service',
                              subtitle: localizations?.termsOfServiceSubtitle ??
                                  'Read our terms of service',
                              onTap: () => _showTermsOfService(context),
                            ),
                            _buildSettingTile(
                              context,
                              icon: Icons.download_outlined,
                              title: localizations?.exportData ?? 'Export Data',
                              subtitle: localizations?.exportDataSubtitle ??
                                  'Download your data',
                              onTap: () => _exportUserData(context),
                            ),
                          ],
                        );
                      },
                    ),
                    _buildSettingTile(
                      context,
                      icon: Icons.delete_outline,
                      title: AppLocalizations.of(context)?.deleteAccount ??
                          'Delete Account',
                      subtitle:
                          AppLocalizations.of(context)?.deleteAccountSubtitle ??
                              'Permanently delete your account',
                      isDestructive: true,
                      onTap: () =>
                          _showDeleteAccountDialog(context, authService),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Support & Help Section
                    _buildSectionHeader(context, 'Support & Help'),
                    _buildSettingTile(
                      context,
                      icon: Icons.help_outline,
                      title: 'Help Center',
                      subtitle: 'FAQs, tips, and guides',
                      onTap: () => NavigationHelper.safeNavigate(
                        context,
                        '/help-center',
                      ),
                    ),
                    _buildSettingTile(
                      context,
                      icon: Icons.feedback_outlined,
                      title: 'Submit Feedback',
                      subtitle: 'Report issues or suggest improvements',
                      onTap: () => showDialog(
                        context: context,
                        builder: (context) => const FeedbackScreen(),
                      ),
                    ),
                    _buildSettingTile(
                      context,
                      icon: Icons.dashboard_outlined,
                      title: 'Support Dashboard',
                      subtitle: 'View support analytics (Admin)',
                      onTap: () => NavigationHelper.safeNavigate(
                          context, '/support-dashboard'),
                    ),
                    _buildSettingTile(
                      context,
                      icon: Icons.info_outline,
                      title: 'About',
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) {
                            final dialogColors = AppColors.of(context);
                            return AlertDialog(
                              backgroundColor: dialogColors.cardBackground,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              title: Text(
                                'N3RD Trivia',
                                style: AppTypography.headlineLarge.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colors.primaryText,
                                ),
                              ),
                              content: Text(
                                'Version 1.0.0\n\nA memory-based trivia game that challenges your brain!\n\nCreated by Gerard',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: colors.secondaryText,
                                  height: 1.5,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                    }
                                  },
                                  child: Text(
                                    'Close',
                                    style: AppTypography.labelLarge.copyWith(
                                      color: colors.primaryText,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // DEBUG: Subscription Tier Tester (only in debug mode)
                    if (kDebugMode) ...[
                      _buildSectionHeader(context, '🧪 Debug (Testing Only)'),
                      Consumer<SubscriptionService>(
                        builder: (context, subscriptionService, _) {
                          return _buildDebugSubscriptionTile(
                            context,
                            subscriptionService,
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    _buildSettingTile(
                      context,
                      icon: Icons.logout,
                      title: 'Sign Out',
                      isDestructive: true,
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) {
                            final dialogColors = AppColors.of(context);
                            return AlertDialog(
                              backgroundColor: dialogColors.cardBackground,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              title: Text(
                                'Sign Out?',
                                style: AppTypography.headlineLarge.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colors.primaryText,
                                ),
                              ),
                              content: Text(
                                'Are you sure you want to sign out?',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: colors.secondaryText,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      NavigationHelper.safePop(context, false),
                                  child: Text(
                                    'Cancel',
                                    style: AppTypography.labelLarge.copyWith(
                                      color: colors.secondaryText,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      NavigationHelper.safePop(context, true),
                                  child: Text(
                                    'Sign Out',
                                    style: AppTypography.labelLarge.copyWith(
                                      color: AppColors.error,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );

                        if (confirm == true) {
                          await authService.signOut();
                          if (context.mounted) {
                            NavigationHelper.safeNavigateAndRemoveUntil(
                              context,
                              '/login',
                              (route) => false,
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
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
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: AppTypography.headlineLarge.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: colors.onDarkText.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.cardBackground.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(12),
            boxShadow: AppShadows.light,
            // No border - removed for cleaner look
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isDestructive ? AppColors.error : colors.primaryText,
                size: 24, // Standard icon size
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.labelLarge.copyWith(
                        fontSize: 15,
                        color: isDestructive
                            ? AppColors.error
                            : colors.primaryText,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xs / 2),
                      Text(
                        subtitle,
                        style: AppTypography.labelSmall.copyWith(
                          color: colors.secondaryText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: colors.tertiaryText,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, AuthService authService) {
    final nameController = TextEditingController(
      text: authService.userEmail?.contains('@') == true
          ? authService.userEmail!.split('@')[0]
          : authService.userEmail ?? '',
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.of(context)?.editProfile ?? 'Edit Profile',
          style: AppTypography.headlineLarge.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Display Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: Text('Cancel', style: AppTypography.labelLarge),
          ),
          ElevatedButton(
            onPressed: () async {
              final displayName = nameController.text.trim();
              if (displayName.isNotEmpty) {
                try {
                  await authService.updateDisplayName(displayName);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(context)?.profileUpdated ??
                              'Profile updated',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${AppLocalizations.of(context)?.failedToUpdateProfile ?? 'Failed to update profile'}: $e',
                        ),
                      ),
                    );
                  }
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.of(context)?.pleaseEnterDisplayName ??
                          'Please enter a display name',
                    ),
                  ),
                );
              }
            },
            child: Text('Save', style: AppTypography.labelLarge),
          ),
        ],
      ),
    );
  }

  void _showEmailSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // Load initial values
          return FutureBuilder<SharedPreferences>(
            future: SharedPreferences.getInstance(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final prefs = snapshot.data!;
              final bool gameNotifications =
                  prefs.getBool('email_game_notifications') ?? true;
              final bool leaderboardUpdates =
                  prefs.getBool('email_leaderboard_updates') ?? true;

              return AlertDialog(
                title: Text(
                  'Email Settings',
                  style: AppTypography.headlineLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      title: Text(
                        'Game Notifications',
                        style: AppTypography.labelLarge,
                      ),
                      subtitle: Text(
                        'Get notified about daily challenges',
                        style: AppTypography.labelSmall,
                      ),
                      value: gameNotifications,
                      onChanged: (value) async {
                        await prefs.setBool('email_game_notifications', value);
                        setState(() {});
                      },
                    ),
                    SwitchListTile(
                      title: Text(
                        'Leaderboard Updates',
                        style: AppTypography.labelLarge,
                      ),
                      subtitle: Text(
                        'Get notified when you rank up',
                        style: AppTypography.labelSmall,
                      ),
                      value: leaderboardUpdates,
                      onChanged: (value) async {
                        await prefs.setBool('email_leaderboard_updates', value);
                        setState(() {});
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    child: Text('Done', style: AppTypography.labelLarge),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showNotificationsSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return FutureBuilder<SharedPreferences>(
            future: SharedPreferences.getInstance(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final prefs = snapshot.data!;
              final bool pushNotifications =
                  prefs.getBool('push_notifications') ?? true;
              final bool dailyReminders =
                  prefs.getBool('daily_reminders') ?? true;
              final bool achievementAlerts =
                  prefs.getBool('achievement_alerts') ?? true;

              return AlertDialog(
                title: Text(
                  'Notifications',
                  style: AppTypography.headlineLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      title: Text(
                        'Push Notifications',
                        style: AppTypography.labelLarge,
                      ),
                      subtitle: Text(
                        'Receive push notifications from the app',
                        style: AppTypography.labelSmall,
                      ),
                      value: pushNotifications,
                      onChanged: (value) async {
                        await prefs.setBool('push_notifications', value);
                        setState(() {});
                      },
                    ),
                    SwitchListTile(
                      title: Text('Daily Reminders',
                          style: AppTypography.labelLarge),
                      subtitle: Text(
                        'Remind me to play daily',
                        style: AppTypography.labelSmall,
                      ),
                      value: dailyReminders,
                      onChanged: (value) async {
                        await prefs.setBool('daily_reminders', value);
                        setState(() {});
                      },
                    ),
                    SwitchListTile(
                      title: Text(
                        'Achievement Alerts',
                        style: AppTypography.labelLarge,
                      ),
                      subtitle: Text(
                        'Get notified when you unlock achievements',
                        style: AppTypography.labelSmall,
                      ),
                      value: achievementAlerts,
                      onChanged: (value) async {
                        await prefs.setBool('achievement_alerts', value);
                        setState(() {});
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    child: Text('Done', style: AppTypography.labelLarge),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showAudioSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Consumer<SoundService>(
          builder: (context, soundService, _) => AlertDialog(
            title: Text(
              'Sound & Music',
              style: AppTypography.headlineLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title:
                        Text('Sound Effects', style: AppTypography.labelLarge),
                    subtitle: Text(
                      'Enable game sound effects',
                      style: AppTypography.labelSmall,
                    ),
                    value: soundService.soundEnabled,
                    onChanged: (value) async {
                      await soundService.setSoundEnabled(value);
                      setState(() {});
                    },
                  ),
                  if (soundService.soundEnabled) ...[
                    ListTile(
                      title:
                          Text('Sound Volume', style: AppTypography.labelLarge),
                      subtitle: Slider(
                        value: soundService.soundVolume,
                        min: 0.0,
                        max: 1.0,
                        divisions: 10,
                        label: '${(soundService.soundVolume * 100).toInt()}%',
                        onChanged: (value) async {
                          await soundService.setSoundVolume(value);
                          setState(() {});
                        },
                      ),
                      trailing: SizedBox(
                        width: 50,
                        child: Text(
                          '${(soundService.soundVolume * 100).toInt()}%',
                          style: AppTypography.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                  SwitchListTile(
                    title: Text('Background Music',
                        style: AppTypography.labelLarge),
                    subtitle: Text(
                      'Enable background music during gameplay',
                      style: AppTypography.labelSmall,
                    ),
                    value: soundService.musicEnabled,
                    onChanged: (value) async {
                      await soundService.setMusicEnabled(value);
                      setState(() {});
                    },
                  ),
                  if (soundService.musicEnabled) ...[
                    ListTile(
                      title:
                          Text('Music Volume', style: AppTypography.labelLarge),
                      subtitle: Slider(
                        value: soundService.musicVolume,
                        min: 0.0,
                        max: 1.0,
                        divisions: 10,
                        label: '${(soundService.musicVolume * 100).toInt()}%',
                        onChanged: (value) async {
                          await soundService.setMusicVolume(value);
                          setState(() {});
                        },
                      ),
                      trailing: SizedBox(
                        width: 50,
                        child: Text(
                          '${(soundService.musicVolume * 100).toInt()}%',
                          style: AppTypography.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                child: Text('Done', style: AppTypography.labelLarge),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVoiceSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) =>
            Consumer2<TextToSpeechService, VoiceRecognitionService>(
          builder: (context, ttsService, voiceService, _) => AlertDialog(
            title: Text(
              'Voice Settings',
              style: AppTypography.headlineLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Text-to-Speech Section
                  Text(
                    'Text-to-Speech',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SwitchListTile(
                    title: Text(
                      'Enable TTS',
                      style: AppTypography.labelLarge,
                    ),
                    subtitle: Text(
                      'Read questions when revealed',
                      style: AppTypography.labelSmall,
                    ),
                    value: ttsService.isEnabled,
                    onChanged: (value) {
                      ttsService.setEnabled(value);
                      setState(() {});
                    },
                  ),
                  if (ttsService.isEnabled) ...[
                    ListTile(
                      title: Text(
                        'Speech Rate',
                        style: AppTypography.bodyMedium,
                      ),
                      trailing: SizedBox(
                        width: 100,
                        child: Slider(
                          value: ttsService.speechRate,
                          min: 0.0,
                          max: 1.0,
                          divisions: 10,
                          label: ttsService.speechRate.toStringAsFixed(1),
                          onChanged: (value) {
                            ttsService.setSpeechRate(value);
                            setState(() {});
                          },
                        ),
                      ),
                    ),
                    ListTile(
                      title: Text(
                        'Volume',
                        style: AppTypography.bodyMedium,
                      ),
                      trailing: SizedBox(
                        width: 100,
                        child: Slider(
                          value: ttsService.volume,
                          min: 0.0,
                          max: 1.0,
                          divisions: 10,
                          label: ttsService.volume.toStringAsFixed(1),
                          onChanged: (value) {
                            ttsService.setVolume(value);
                            setState(() {});
                          },
                        ),
                      ),
                    ),
                    ListTile(
                      title: Text('Pitch', style: AppTypography.bodyMedium),
                      trailing: SizedBox(
                        width: 100,
                        child: Slider(
                          value: ttsService.pitch,
                          min: 0.5,
                          max: 2.0,
                          divisions: 15,
                          label: ttsService.pitch.toStringAsFixed(1),
                          onChanged: (value) {
                            ttsService.setPitch(value);
                            setState(() {});
                          },
                        ),
                      ),
                    ),
                  ],
                  const Divider(),
                  // Speech-to-Text Section
                  Text(
                    'Voice Input',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SwitchListTile(
                    title: Text(
                      'Enable Voice Input',
                      style: AppTypography.labelLarge,
                    ),
                    subtitle: Text(
                      'Speak answers instead of tapping',
                      style: AppTypography.labelSmall,
                    ),
                    value: voiceService.isEnabled,
                    onChanged: voiceService.isAvailable
                        ? (value) {
                            voiceService.setEnabled(value);
                            setState(() {});
                          }
                        : null,
                  ),
                  if (!voiceService.isAvailable)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Voice recognition not available on this device',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  if (voiceService.isEnabled && voiceService.isAvailable) ...[
                    SwitchListTile(
                      title: Text(
                        'Push-to-Talk Mode',
                        style: AppTypography.labelLarge,
                      ),
                      subtitle: Text(
                        'Hold button to speak (vs always-on)',
                        style: AppTypography.labelSmall,
                      ),
                      value: voiceService.pushToTalkMode,
                      onChanged: (value) {
                        voiceService.setPushToTalkMode(value);
                        setState(() {});
                      },
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                child: Text('Done', style: AppTypography.labelLarge),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAppearanceSettings(BuildContext context) {
    String selectedTheme = 'system';
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            'Appearance',
            style: AppTypography.headlineLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: Text('System Default', style: AppTypography.bodyMedium),
                value: 'system',
                // ignore: deprecated_member_use
                groupValue: selectedTheme,
                // ignore: deprecated_member_use
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() {
                      selectedTheme = value;
                    });
                  }
                },
              ),
              RadioListTile<String>(
                title: Text('Light Mode', style: AppTypography.bodyMedium),
                value: 'light',
                // ignore: deprecated_member_use
                groupValue: selectedTheme,
                // ignore: deprecated_member_use
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() {
                      selectedTheme = value;
                    });
                  }
                },
              ),
              RadioListTile<String>(
                title: Text('Dark Mode', style: AppTypography.bodyMedium),
                value: 'dark',
                // ignore: deprecated_member_use
                groupValue: selectedTheme,
                // ignore: deprecated_member_use
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() {
                      selectedTheme = value;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: Text('Done', style: AppTypography.labelLarge),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageSettings(BuildContext context) {
    String selectedLanguage = 'English';
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            'Language',
            style: AppTypography.headlineLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['English', 'Spanish', 'French', 'German'].map((lang) {
              return RadioListTile<String>(
                title: Text(lang, style: AppTypography.bodyMedium),
                value: lang,
                // ignore: deprecated_member_use
                groupValue: selectedLanguage,
                // ignore: deprecated_member_use
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() {
                      selectedLanguage = value;
                    });
                  }
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: Text('Done', style: AppTypography.labelLarge),
            ),
          ],
        ),
      ),
    );
  }

  void _showGameSettings(BuildContext context) {
    double timerSpeed = 1.0; // 0.5x to 2.0x
    double difficulty = 1.0; // 0.5x to 2.0x
    int revealUses = 3;
    int clearUses = 3;
    int skipUses = 3;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            'Game Settings',
            style: AppTypography.headlineLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Timer Speed', style: AppTypography.labelLarge),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: timerSpeed,
                        min: 0.5,
                        max: 2.0,
                        divisions: 6,
                        label: '${timerSpeed.toStringAsFixed(1)}x',
                        onChanged: (value) {
                          setState(() {
                            timerSpeed = value;
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      child: Text(
                        '${timerSpeed.toStringAsFixed(1)}x',
                        style: AppTypography.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Difficulty Multiplier', style: AppTypography.labelLarge),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: difficulty,
                        min: 0.5,
                        max: 2.0,
                        divisions: 6,
                        label: '${difficulty.toStringAsFixed(1)}x',
                        onChanged: (value) {
                          setState(() {
                            difficulty = value;
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      child: Text(
                        '${difficulty.toStringAsFixed(1)}x',
                        style: AppTypography.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Starting Power-ups', style: AppTypography.labelLarge),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Reveal All', style: AppTypography.labelSmall),
                          Slider(
                            value: revealUses.toDouble(),
                            min: 0,
                            max: 10,
                            divisions: 10,
                            label: revealUses.toString(),
                            onChanged: (value) {
                              setState(() {
                                revealUses = value.toInt();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        revealUses.toString(),
                        style: AppTypography.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Clear', style: AppTypography.labelSmall),
                          Slider(
                            value: clearUses.toDouble(),
                            min: 0,
                            max: 10,
                            divisions: 10,
                            label: clearUses.toString(),
                            onChanged: (value) {
                              setState(() {
                                clearUses = value.toInt();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        clearUses.toString(),
                        style: AppTypography.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Skip', style: AppTypography.labelSmall),
                          Slider(
                            value: skipUses.toDouble(),
                            min: 0,
                            max: 10,
                            divisions: 10,
                            label: skipUses.toString(),
                            onChanged: (value) {
                              setState(() {
                                skipUses = value.toInt();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        skipUses.toString(),
                        style: AppTypography.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Note: These settings apply to new games only.',
                  style: AppTypography.labelSmall.copyWith(
                    fontSize: 11,
                    color: AppColors.of(context).tertiaryText,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: Text('Cancel', style: AppTypography.labelLarge),
            ),
            TextButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setDouble('game_timer_speed', timerSpeed);
                await prefs.setDouble('game_difficulty', difficulty);
                await prefs.setInt('game_reveal_uses', revealUses);
                await prefs.setInt('game_clear_uses', clearUses);
                await prefs.setInt('game_skip_uses', skipUses);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(context)?.gameSettingsSaved ??
                            'Game settings saved',
                      ),
                    ),
                  );
                }
              },
              child: Text('Save', style: AppTypography.labelLarge),
            ),
          ],
        ),
      ),
    );
  }

  void _exportUserData(BuildContext context) async {
    try {
      final exportService = Provider.of<DataExportService>(
        context,
        listen: false,
      );

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final filePath = await exportService.exportUserData();

      if (!context.mounted) return;
      NavigationHelper.safePop(context); // Close loading dialog

      if (filePath != null) {
        await exportService.shareExportedData();

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Data exported successfully',
              style: AppTypography.bodyMedium,
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      NavigationHelper.safePop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to export data: ${e.toString()}',
            style: AppTypography.bodyMedium,
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showPrivacyPolicy(BuildContext context) {
    NavigationHelper.safeNavigate(context, '/privacy-policy');
  }

  void _showTermsOfService(BuildContext context) {
    NavigationHelper.safeNavigate(context, '/terms-of-service');
  }

  void _showDeleteAccountDialog(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.of(context)?.deleteAccount ?? 'Delete Account',
          style: AppTypography.headlineLarge.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This action cannot be undone. All your data will be permanently deleted.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppTypography.labelLarge),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // Delete user account from Firebase
                final user = authService.currentUser;
                if (user != null) {
                  await user.delete();
                }
                // Sign out and clear local data
                await authService.signOut();
                if (context.mounted) {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/login', (route) => false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(
                              context,
                            )?.accountDeletedSuccessfully ??
                            'Account deleted successfully',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Failed to delete account. Please re-authenticate and try again.',
                      ),
                    ),
                  );
                }
              }
            },
            child: Text(
              'Delete',
              style: AppTypography.labelLarge.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  /// Build debug subscription tier toggle tile (only visible in debug mode)
  Widget _buildDebugSubscriptionTile(
    BuildContext context,
    SubscriptionService subscriptionService,
  ) {
    final colors = AppColors.of(context);
    final currentTier = subscriptionService.currentTier;
    final tierName = subscriptionService.tierName;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppShadows.light,
          border: Border.all(color: Colors.orange.shade700, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bug_report, color: colors.onDarkText, size: 22),
                const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Test Subscription Tier',
                        style: AppTypography.labelLarge.copyWith(
                          fontSize: 15,
                          color: colors.onDarkText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs / 2),
                      Text(
                        'Current: $tierName (Debug Mode Only)',
                        style: AppTypography.labelSmall.copyWith(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: _buildDebugTierButton(
                    context,
                    subscriptionService,
                    'Free',
                    SubscriptionTier.free,
                    currentTier == SubscriptionTier.free,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _buildDebugTierButton(
                    context,
                    subscriptionService,
                    'Basic',
                    SubscriptionTier.basic,
                    currentTier == SubscriptionTier.basic,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _buildDebugTierButton(
                    context,
                    subscriptionService,
                    'Premium',
                    SubscriptionTier.premium,
                    currentTier == SubscriptionTier.premium,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build individual tier button for debug menu
  Widget _buildDebugTierButton(
    BuildContext context,
    SubscriptionService subscriptionService,
    String label,
    SubscriptionTier tier,
    bool isActive,
  ) {
    return ElevatedButton(
      onPressed: () async {
        // Show confirmation dialog
        final dialogColors = AppColors.of(context);
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: dialogColors.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Text(
              'Switch to $label Tier?',
              style: AppTypography.headlineLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: dialogColors.primaryText,
              ),
            ),
            content: Text(
              'This is for testing only. The tier will be set locally and may not persist after app restart if RevenueCat syncs.',
              style: AppTypography.bodyMedium.copyWith(
                color: dialogColors.secondaryText,
                fontSize: 13,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => NavigationHelper.safePop(context, false),
                child: Text(
                  'Cancel',
                  style: AppTypography.labelLarge.copyWith(
                    color: dialogColors.secondaryText,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => NavigationHelper.safePop(context, true),
                child: Text(
                  'Switch',
                  style: AppTypography.labelLarge.copyWith(
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
        );

        if (confirm == true && context.mounted) {
          try {
            await subscriptionService.setTier(tier);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Switched to $label tier (Debug Mode)',
                    style: AppTypography.bodyMedium,
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Failed to switch tier: $e',
                    style: AppTypography.bodyMedium,
                  ),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? Colors.white : Colors.orange.shade800,
        foregroundColor: isActive ? Colors.orange : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isActive ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
        elevation: isActive ? 4 : 1,
      ),
      child: Text(
        label,
        style: AppTypography.labelLarge.copyWith(fontSize: 13),
      ),
    );
  }
}
