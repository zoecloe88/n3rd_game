import 'dart:io';
import 'package:n3rd_game/utils/unawaited_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:n3rd_game/services/auth_service.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/services/text_to_speech_service.dart';
import 'package:n3rd_game/services/voice_recognition_service.dart';
import 'package:n3rd_game/services/voice_calibration_service.dart';
import 'package:n3rd_game/services/sound_service.dart';
import 'package:n3rd_game/services/theme_service.dart';
import 'package:n3rd_game/services/language_service.dart';
import 'package:n3rd_game/services/logger_service.dart';
// ignore: unused_import
import 'package:n3rd_game/services/game_service.dart';
import 'package:n3rd_game/widgets/video_background_widget.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_shadows.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/screens/feedback_screen.dart';
import 'package:n3rd_game/services/data_export_service.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/utils/provider_helper.dart';
import 'package:n3rd_game/utils/error_handler.dart';
import 'package:n3rd_game/utils/responsive_helper.dart';
import 'package:n3rd_game/widgets/settings/email_settings_dialog.dart';
import 'package:n3rd_game/widgets/settings/notifications_settings_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    // Use Consumer to listen for auth state changes
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        return Scaffold(
          backgroundColor: AppColors.overlayDark, // Black fallback
          body: VideoBackgroundWidget(
            videoPath: 'assets/settingscreen.mp4',
            fit: BoxFit.cover, // CSS object-fit: cover equivalent
            alignment: Alignment.topCenter, // Characters/logos in upper portion
            loop: true,
            autoplay: true,
            child: SafeArea(
              child: Column(
                children: [
                  // Minimal top app bar - moved closer to top
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      AppSpacing.md,
                      AppSpacing.sm, // Reduced top padding
                      AppSpacing.md,
                      AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        Semantics(
                          label: AppLocalizations.of(context)?.backButton ??
                              'Back',
                          button: true,
                          child: IconButton(
                            onPressed: () {
                              // Go back to previous screen
                              // If accessed from More menu, this will pop back to MoreMenuScreen
                              // If accessed as standalone route, navigate to More tab (index 4)
                              if (Navigator.of(context).canPop()) {
                                NavigationHelper.safePop(context);
                              } else {
                                // No back stack - navigate to More tab (where Settings is typically accessed)
                                NavigationHelper.switchToTab(context, 4);
                              }
                            },
                            icon: Icon(
                              Icons.arrow_back,
                              color: colors.onDarkText,
                            ),
                            tooltip: AppLocalizations.of(context)?.backButton ??
                                'Back',
                          ),
                        ),
                        // Settings header removed per user request
                        const Spacer(),
                      ],
                    ),
                  ),

                  // Reduced spacer to move content closer to top
                  SizedBox(
                    height: ResponsiveHelper.responsiveHeight(context, 0.05)
                        .clamp(20.0, 40.0),
                  ), // Reduced from 0.15 to 0.05

                  // Profile card
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
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
                                  (AppLocalizations.of(context)?.userInitial ??
                                      'U'),
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
                                  authService.userEmail ??
                                      (AppLocalizations.of(context)?.guest ??
                                          'Guest'),
                                  style: AppTypography.labelLarge.copyWith(
                                    fontSize: 15,
                                    color: colors.primaryText,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.visible,
                                  softWrap: true,
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
                      // Performance optimization: Add cache extent for better scroll performance
                      cacheExtent: 200.0,
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
                                  title: localizations?.editProfile ??
                                      'Edit Profile',
                                  subtitle:
                                      localizations?.editProfileSubtitle ??
                                          'Update display name and avatar',
                                  onTap: () => _showEditProfileDialog(
                                    context,
                                    authService,
                                  ),
                                ),
                                _buildSettingTile(
                                  context,
                                  icon: Icons.email_outlined,
                                  title: localizations?.emailSettings ??
                                      'Email Settings',
                                  subtitle:
                                      localizations?.emailSettingsSubtitle ??
                                          'Manage email notifications',
                                  onTap: () =>
                                      _showEmailSettingsDialog(context),
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
                                  subtitle:
                                      localizations?.notificationsSubtitle ??
                                          'Push notifications and reminders',
                                  onTap: () =>
                                      _showNotificationsSettings(context),
                                ),
                                _buildSettingTile(
                                  context,
                                  icon: Icons.emoji_events_outlined,
                                  title: localizations?.achievements ??
                                      'Achievements',
                                  subtitle:
                                      localizations?.achievementsSubtitle ??
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
                                  title: localizations?.leaderboard ??
                                      'Leaderboard',
                                  subtitle:
                                      localizations?.leaderboardSubtitle ??
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
                                  subtitle:
                                      localizations?.soundAndMusicSubtitle ??
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
                                      subtitle: localizations
                                              ?.voiceSettingsSubtitle ??
                                          'Text-to-speech and voice input',
                                      onTap: () => _showVoiceSettings(context),
                                    );
                                  },
                                ),
                                Consumer2<SubscriptionService,
                                    VoiceCalibrationService>(
                                  builder: (
                                    context,
                                    subscriptionService,
                                    calibrationService,
                                    _,
                                  ) {
                                    if (!subscriptionService.isPremium) {
                                      return const SizedBox.shrink();
                                    }
                                    final isCalibrated =
                                        calibrationService.isCalibrated;
                                    final accuracyScore =
                                        calibrationService.profile?.accuracyScore;
                                    final calibrationStatus = isCalibrated
                                        ? (localizations
                                                ?.voiceCalibrationStatusCalibrated ??
                                            'Voice recognition trained') +
                                            (accuracyScore != null
                                                ? ' (${(accuracyScore * 100).toInt()}%)'
                                                : '')
                                        : (localizations
                                                ?.voiceCalibrationStatusNotCalibrated ??
                                            'Train voice recognition for better accuracy');
                                    return Semantics(
                                      label: '${localizations?.voiceCalibration ?? 'Voice Calibration'}. $calibrationStatus',
                                      button: true,
                                      child: ListTile(
                                        leading: Icon(
                                          Icons.record_voice_over_outlined,
                                          color: AppColors.of(context).onDarkText,
                                        ),
                                        title: Text(
                                          localizations?.voiceCalibration ??
                                              'Voice Calibration',
                                          style: AppTypography.bodyLarge.copyWith(
                                            color: AppColors.of(context).onDarkText,
                                          ),
                                        ),
                                        subtitle: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                isCalibrated
                                                    ? (localizations
                                                            ?.voiceCalibrationStatusCalibrated ??
                                                        'Voice recognition trained') +
                                                        (accuracyScore != null
                                                            ? ' (${(accuracyScore * 100).toInt()}%)'
                                                            : '')
                                                    : (localizations
                                                            ?.voiceCalibrationStatusNotCalibrated ??
                                                        'Train voice recognition for better accuracy'),
                                                style: AppTypography.bodyMedium.copyWith(
                                                  color: AppColors.of(context)
                                                      .secondaryText,
                                                ),
                                              ),
                                            ),
                                            if (isCalibrated)
                                              const Icon(
                                                Icons.check_circle,
                                                color: Colors.green,
                                                size: 20,
                                              )
                                            else
                                              const Icon(
                                                Icons.warning_amber_rounded,
                                                color: Colors.orange,
                                                size: 20,
                                              ),
                                          ],
                                        ),
                                        onTap: () =>
                                            NavigationHelper.safeNavigate(
                                          context,
                                          '/voice-calibration',
                                          source: NavigationSource.buttonTap,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                _buildSettingTile(
                                  context,
                                  icon: Icons.dark_mode_outlined,
                                  title:
                                      localizations?.appearance ?? 'Appearance',
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
                                  subtitle:
                                      localizations?.gameSettingsSubtitle ??
                                          'Customize gameplay experience',
                                  onTap: () => _showGameSettings(context),
                                ),
                                const SizedBox(height: AppSpacing.sm),

                                // Data & Privacy Section
                                _buildSectionHeader(
                                  context,
                                  localizations?.dataAndPrivacy ??
                                      'Data & Privacy',
                                ),
                                _buildSettingTile(
                                  context,
                                  icon: Icons.privacy_tip_outlined,
                                  title: localizations?.privacyPolicy ??
                                      'Privacy Policy',
                                  subtitle:
                                      localizations?.privacyPolicySubtitle ??
                                          'Read our privacy policy',
                                  onTap: () => _showPrivacyPolicy(context),
                                ),
                                _buildSettingTile(
                                  context,
                                  icon: Icons.description_outlined,
                                  title: localizations?.termsOfService ??
                                      'Terms of Service',
                                  subtitle:
                                      localizations?.termsOfServiceSubtitle ??
                                          'Read our terms of service',
                                  onTap: () => _showTermsOfService(context),
                                ),
                                _buildSettingTile(
                                  context,
                                  icon: Icons.download_outlined,
                                  title: localizations?.exportData ??
                                      'Export Data',
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
                          subtitle: AppLocalizations.of(context)
                                  ?.deleteAccountSubtitle ??
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
                            context,
                            '/support-dashboard',
                          ),
                        ),
                        _buildSettingTile(
                          context,
                          icon: Icons.info_outline,
                          title: AppLocalizations.of(context)?.about ?? 'About',
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) {
                                final dialogColors = AppColors.of(context);
                                final localizations =
                                    AppLocalizations.of(context);
                                return AlertDialog(
                                  backgroundColor: dialogColors.cardBackground,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  title: Text(
                                    localizations?.appName ?? 'N3RD Trivia',
                                    style: AppTypography.headlineLarge.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colors.primaryText,
                                    ),
                                  ),
                                  content: Text(
                                    '${localizations?.version ?? 'Version 1.0.0'}\n\n${localizations?.appDescription ?? 'A memory-based trivia game that challenges your brain!'}\n\n${localizations?.createdBy ?? 'Created by Girard Clairsaint'}',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: colors.secondaryText,
                                      height: 1.5,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        if (context.mounted) {
                                          NavigationHelper.safePop(context);
                                        }
                                      },
                                      child: Text(
                                        localizations?.close ?? 'Close',
                                        style:
                                            AppTypography.labelLarge.copyWith(
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
                          _buildSectionHeader(
                            context,
                            '🧪 Debug (Testing Only)',
                          ),
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
                                      onPressed: () => NavigationHelper.safePop(
                                        context,
                                        false,
                                      ),
                                      child: Text(
                                        'Cancel',
                                        style:
                                            AppTypography.labelLarge.copyWith(
                                          color: colors.secondaryText,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => NavigationHelper.safePop(
                                        context,
                                        true,
                                      ),
                                      child: Text(
                                        'Sign Out',
                                        style:
                                            AppTypography.labelLarge.copyWith(
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
                                unawaited(NavigationHelper.safeNavigateAndRemoveUntil(
                                  context,
                                  '/login',
                                  (route) => false,
                                ),);
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
      },
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
      child: Semantics(
        label: subtitle != null ? '$title. $subtitle' : title,
        button: true,
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
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (context) => _EditProfileDialog(authService: authService),
    );
  }

  void _showEmailSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const EmailSettingsDialog(),
    );
  }

  void _showNotificationsSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const NotificationsSettingsDialog(),
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
                          style: AppTypography.bodyMedium.copyWith(),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                  SwitchListTile(
                    title: Text(
                      'Background Music',
                      style: AppTypography.labelLarge,
                    ),
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
                    NavigationHelper.safePop(context);
                  }
                },
                child: Text(
                  AppLocalizations.of(context)?.done ?? 'Done',
                  style: AppTypography.labelLarge,
                ),
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
                    NavigationHelper.safePop(context);
                  }
                },
                child: Text(
                  AppLocalizations.of(context)?.done ?? 'Done',
                  style: AppTypography.labelLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAppearanceSettings(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    String selectedTheme = themeService.isDarkMode ? 'dark' : 'light';

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
              // ignore: deprecated_member_use
              RadioListTile<String>(
                title: Text('Light Mode', style: AppTypography.bodyMedium),
                value: 'light',
                // ignore: deprecated_member_use
                groupValue: selectedTheme,
                // ignore: deprecated_member_use
                onChanged: (value) async {
                  if (value != null) {
                    setState(() {
                      selectedTheme = value;
                    });
                    try {
                      await themeService.setDarkMode(false);
                      if (context.mounted) {
                        NavigationHelper.safePop(context);
                      }
                    } catch (e) {
                      LoggerService.warning('Failed to set dark mode to false', error: e);
                    }
                  }
                },
              ),
              // ignore: deprecated_member_use
              RadioListTile<String>(
                title: Text('Dark Mode', style: AppTypography.bodyMedium),
                value: 'dark',
                // ignore: deprecated_member_use
                groupValue: selectedTheme,
                // ignore: deprecated_member_use
                onChanged: (value) async {
                  if (value != null) {
                    setState(() {
                      selectedTheme = value;
                    });
                    try {
                      await themeService.setDarkMode(true);
                      if (context.mounted) {
                        NavigationHelper.safePop(context);
                      }
                    } catch (e) {
                      LoggerService.warning('Failed to set dark mode to true', error: e);
                    }
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (context.mounted) {
                  NavigationHelper.safePop(context);
                }
              },
              child: Text(
                AppLocalizations.of(context)?.cancel ?? 'Cancel',
                style: AppTypography.labelLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageSettings(BuildContext context) async {
    if (!context.mounted) return;
    final languageService =
        ProviderHelper.safeGetOrThrow<LanguageService>(context, listen: false);
    String selectedLanguage = 'English';
    // Get current language from service
    final currentLocale = languageService.currentLocale;
    if (currentLocale.languageCode == 'es') {
      selectedLanguage = 'Spanish';
    } else if (currentLocale.languageCode == 'fr') {
      selectedLanguage = 'French';
    } else if (currentLocale.languageCode == 'de') {
      selectedLanguage = 'German';
    }

    if (!context.mounted) return;
    unawaited(showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
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
                  onChanged: (value) async {
                    if (value != null) {
                      try {
                        // Update dialog state
                        setDialogState(() {
                          selectedLanguage = value;
                        });
                        // Change language immediately using LanguageService
                        await languageService.setLanguage(value);
                        // Close dialog first
                        if (dialogContext.mounted) {
                          NavigationHelper.safePop(dialogContext);
                        }
                        // Show message in the original context
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Language changed to $value. Restart the app to see changes.',
                              ),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      } catch (e) {
                        LoggerService.error('Failed to change language', error: e);
                        if (dialogContext.mounted) {
                          ErrorHandler.showSnackBar(
                            dialogContext,
                            'Failed to change language. Please try again.',
                            error: e,
                          );
                        }
                      }
                    }
                  },
                );
              }).toList(),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (dialogContext.mounted) {
                    NavigationHelper.safePop(dialogContext);
                  }
                },
                child: Text(
                  AppLocalizations.of(context)?.done ?? 'Done',
                  style: AppTypography.labelLarge,
                ),
              ),
            ],
          );
        },
      ),
    ),);
  }

  void _showGameSettings(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (!context.mounted) return;
    double timerSpeed =
        prefs.getDouble('game_timer_speed') ?? 1.0; // 0.5x to 2.0x
    int revealUses = prefs.getInt('game_reveal_uses') ?? 3;
    int clearUses = prefs.getInt('game_clear_uses') ?? 3;
    int skipUses = prefs.getInt('game_skip_uses') ?? 3;

    if (!context.mounted) return;
    unawaited(showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            AppLocalizations.of(context)?.gameSettingsTitle ?? 'Game Settings',
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
                        onChanged: (value) async {
                          setState(() {
                            timerSpeed = value;
                          });
                          await prefs.setDouble('game_timer_speed', value);
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
                            onChanged: (value) async {
                              setState(() {
                                revealUses = value.toInt();
                              });
                              await prefs.setInt(
                                  'game_reveal_uses', value.toInt(),);
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
                            onChanged: (value) async {
                              setState(() {
                                clearUses = value.toInt();
                              });
                              await prefs.setInt(
                                  'game_clear_uses', value.toInt(),);
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
                            onChanged: (value) async {
                              setState(() {
                                skipUses = value.toInt();
                              });
                              await prefs.setInt(
                                  'game_skip_uses', value.toInt(),);
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
                  AppLocalizations.of(context)?.gameSettingsNote ??
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
                  NavigationHelper.safePop(context);
                }
              },
              child: Text(
                AppLocalizations.of(context)?.cancel ?? 'Cancel',
                style: AppTypography.labelLarge,
              ),
            ),
            TextButton(
              onPressed: () async {
                // Show loading indicator
                unawaited(showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),);
                try {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setDouble('game_timer_speed', timerSpeed);
                  await prefs.setInt('game_reveal_uses', revealUses);
                  await prefs.setInt('game_clear_uses', clearUses);
                  await prefs.setInt('game_skip_uses', skipUses);
                  if (context.mounted) {
                    NavigationHelper.safePop(context); // Close loading
                    NavigationHelper.safePop(context); // Close dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(context)?.gameSettingsSaved ??
                              'Game settings saved',
                        ),
                      ),
                    );
                    // Reload game settings in GameService
                    final gameService =
                        ProviderHelper.safeGetOrThrow<GameService>(context, listen: false);
                    await gameService.loadGameSettings();
                  }
                } catch (e) {
                  if (context.mounted) {
                    NavigationHelper.safePop(context); // Close loading
                    ErrorHandler.showSnackBar(
                      context,
                      AppLocalizations.of(context)?.gameSettingsSaveError ??
                          'Failed to save game settings. Please try again.',
                      error: e,
                    );
                  }
                }
              },
              child: Text('Save', style: AppTypography.labelLarge),
            ),
          ],
        ),
      ),
    ),);
  }

  void _exportUserData(BuildContext context) async {
    try {
      final exportService = ProviderHelper.safeGetOrThrow<DataExportService>(
        context,
        listen: false,
      );

      unawaited(showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      ),);

      final filePath = await exportService.exportUserData();

      if (!context.mounted) return;
      NavigationHelper.safePop(context); // Close loading dialog

      if (filePath != null) {
        // Use Share.shareXFiles directly with the file path
        final file = File(filePath);
        if (file.existsSync()) {
          if (!context.mounted) return;
          final shareText = AppLocalizations.of(context)?.dataExportShareText ??
              'My N3RD Trivia Data Export';
          await Share.shareXFiles(
            [XFile(filePath)],
            text: shareText,
          );

          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)?.dataExportSuccess ??
                    'Data exported successfully',
                style: AppTypography.bodyMedium,
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          if (!context.mounted) return;
          ErrorHandler.showSnackBar(
            context,
            AppLocalizations.of(context)?.dataExportFileNotFound ??
                'Export file not found',
          );
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      NavigationHelper.safePop(context); // Close loading dialog
      ErrorHandler.showSnackBar(
        context,
        AppLocalizations.of(context)?.dataExportError ??
            'Failed to export data. Please try again.',
        error: e,
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
          AppLocalizations.of(context)?.deleteAccountWarning ??
              'This action cannot be undone. All your data will be permanently deleted.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => NavigationHelper.safePop(context),
            child: Text(
              AppLocalizations.of(context)?.cancel ?? 'Cancel',
              style: AppTypography.labelLarge,
            ),
          ),
          TextButton(
            onPressed: () async {
              NavigationHelper.safePop(context);
              try {
                // Delete user account from Firebase
                final user = authService.currentUser;
                if (user != null) {
                  await user.delete();
                }
                // Sign out and clear local data
                await authService.signOut();
                if (context.mounted) {
                  unawaited(NavigationHelper.safeNavigateAndRemoveUntil(
                    context,
                    '/login',
                    (route) => false,
                    source: NavigationSource.programmatic,
                  ),);
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
                  ErrorHandler.showSnackBar(
                    context,
                    AppLocalizations.of(context)?.accountDeleteError ??
                        'Failed to delete account. Please re-authenticate and try again.',
                    error: e,
                  );
                }
              }
            },
            child: Text(
              AppLocalizations.of(context)?.delete ?? 'Delete',
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
                          color: AppColors.onDarkText.withValues(alpha: 0.9),
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
    return Semantics(
      label: 'Switch to $label tier',
      button: true,
      child: ElevatedButton(
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
              Semantics(
                label: AppLocalizations.of(context)?.cancel ?? 'Cancel',
                button: true,
                child: TextButton(
                  onPressed: () => NavigationHelper.safePop(context, false),
                  child: Text(
                    'Cancel',
                    style: AppTypography.labelLarge.copyWith(
                      color: dialogColors.secondaryText,
                    ),
                  ),
                ),
              ),
              Semantics(
                label: 'Switch to $label tier',
                button: true,
                child: TextButton(
                  onPressed: () => NavigationHelper.safePop(context, true),
                  child: Text(
                    'Switch',
                    style: AppTypography.labelLarge.copyWith(
                      color: Colors.orange,
                    ),
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
      ),
    );
  }
}

/// Stateful dialog for editing profile with avatar upload
class _EditProfileDialog extends StatefulWidget {
  final AuthService authService;

  const _EditProfileDialog({required this.authService});

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late TextEditingController _nameController;
  File? _selectedImage;
  String? _imageUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final userEmail = widget.authService.userEmail;
    _nameController = TextEditingController(
      text: userEmail != null && userEmail.contains('@')
          ? userEmail.split('@')[0]
          : userEmail ?? '',
    );
    // Load existing profile image if available
    final currentUser = widget.authService.currentUser;
    if (currentUser?.photoURL != null) {
      _imageUrl = currentUser!.photoURL;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Check and request permissions based on source
      if (source == ImageSource.camera) {
        // Check camera permission
        final cameraStatus = await Permission.camera.status;
        if (!cameraStatus.isGranted) {
          final result = await Permission.camera.request();
          if (!result.isGranted) {
            if (mounted && context.mounted) {
              ErrorHandler.showSnackBar(
                context,
                'Camera permission is required to take photos. Please enable it in settings.',
              );
            }
            return;
          }
        }
      } else if (source == ImageSource.gallery) {
        // Check photos permission (iOS) or storage permission (Android)
        Permission permission;
        if (Platform.isIOS) {
          permission = Permission.photos;
        } else {
          permission = Permission.storage;
        }
        final status = await permission.status;
        if (!status.isGranted) {
          final result = await permission.request();
          if (!result.isGranted) {
            if (mounted && context.mounted) {
              ErrorHandler.showSnackBar(
                context,
                'Storage permission is required to access photos. Please enable it in settings.',
              );
            }
            return;
          }
        }
      }

      // Proceed with image picking
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() {
          _selectedImage = File(image.path);
          _imageUrl = null; // Clear existing URL when new image is selected
        });
      }
    } catch (e) {
      LoggerService.error('Failed to pick image', error: e);
      if (mounted && context.mounted) {
        ErrorHandler.showSnackBar(
          context,
          AppLocalizations.of(context)?.imagePickError ??
              'Failed to pick image. Please try again.',
          error: e,
        );
      }
    }
  }

  Future<void> _showImageSourceDialog() async {
    if (!mounted) return;
    final choice = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.of(context)?.selectImageSource ??
              'Select Image Source',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (choice != null) {
      await _pickImage(choice);
    }
  }

  Future<void> _uploadAndSave() async {
    final displayName = _nameController.text.trim();
    if (displayName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.pleaseEnterDisplayName ??
                  'Please enter a display name',
            ),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).clearSnackBars();
              },
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // Upload image if selected
      if (_selectedImage != null) {
        await widget.authService.updateProfileImage(_selectedImage!);
      }

      // Update display name
      await widget.authService.updateDisplayName(displayName);

      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.profileUpdated ?? 'Profile updated',
            ),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).clearSnackBars();
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ErrorHandler.showSnackBar(
          context,
          AppLocalizations.of(context)?.failedToUpdateProfile ??
              'Failed to update profile. Please try again.',
          error: e,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.transparent,
      contentPadding: EdgeInsets.zero,
      content: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background n3rd.png'),
            fit: BoxFit.cover,
          ),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        padding: const EdgeInsetsDirectional.fromSTEB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)?.editProfile ?? 'Edit Profile',
              style: AppTypography.headlineLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.onDarkText,
              ),
            ),
            const SizedBox(height: 16),
            // Avatar upload
            Center(
              child: GestureDetector(
                onTap: _isUploading ? null : _showImageSourceDialog,
                child: _isUploading
                    ? const CircleAvatar(
                        radius: 50,
                        backgroundColor: AppColors.onDarkText,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                        ),
                      )
                    : CircleAvatar(
                        radius: 50,
                        backgroundColor:
                            AppColors.onDarkText.withValues(alpha: 0.2),
                        backgroundImage: _selectedImage != null
                            ? FileImage(_selectedImage!)
                            : (_imageUrl != null
                                ? NetworkImage(_imageUrl!) as ImageProvider
                                : null),
                        child: _selectedImage == null && _imageUrl == null
                            ? const Icon(
                                Icons.person,
                                size: 50,
                                color: AppColors.onDarkText,
                              )
                            : null,
                      ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.onDarkText,
              ),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)?.displayName ??
                    'Display Name',
                labelStyle: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onDarkText.withValues(alpha: 0.7),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppColors.onDarkText.withValues(alpha: 0.7),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppColors.onDarkText.withValues(alpha: 0.7),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppColors.of(context).focus,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isUploading
                      ? null
                      : () {
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                  child: Text(
                    AppLocalizations.of(context)?.cancel ?? 'Cancel',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.onDarkText,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isUploading ? null : _uploadAndSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    AppLocalizations.of(context)?.save ?? 'Save',
                    style: AppTypography.labelLarge,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}