import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/services/settings_service.dart';
import 'package:n3rd_game/services/notification_service.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/utils/error_handler.dart';
import 'package:n3rd_game/utils/provider_helper.dart';

/// Notifications settings dialog widget
/// Extracted from SettingsScreen for better code organization
class NotificationsSettingsDialog extends StatefulWidget {
  const NotificationsSettingsDialog({super.key});

  @override
  State<NotificationsSettingsDialog> createState() =>
      _NotificationsSettingsDialogState();
}

class _NotificationsSettingsDialogState
    extends State<NotificationsSettingsDialog> {
  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, settingsService, _) {
        if (!settingsService.isInitialized) {
          return const AlertDialog(
            content: Center(child: CircularProgressIndicator()),
          );
        }

        return AlertDialog(
          title: Text(
            AppLocalizations.of(context)?.notifications ?? 'Notifications',
            style: AppTypography.headlineLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: Text(
                  AppLocalizations.of(context)?.pushNotifications ??
                      'Push Notifications',
                  style: AppTypography.labelLarge,
                ),
                subtitle: Text(
                  AppLocalizations.of(context)?.pushNotificationsSubtitle ??
                      'Receive push notifications from the app',
                  style: AppTypography.labelSmall,
                ),
                value: settingsService.pushNotifications,
                onChanged: (value) async {
                  // Save preference first
                  final success =
                      await settingsService.setPushNotifications(value);
                  if (success) {
                    // Enable/disable notifications in NotificationService
                    try {
                      if (!context.mounted) return;
                      final notificationService =
                          ProviderHelper.safeGet<NotificationService>(
                        context,
                        listen: false,
                      );
                      if (notificationService != null) {
                        if (value) {
                          await notificationService.enableNotifications();
                        } else {
                          await notificationService.disableNotifications();
                        }
                      }
                    } catch (e) {
                      LoggerService.debug(
                        'NotificationService not available',
                        error: e,
                      );
                    }
                    setState(() {});
                  } else {
                    if (context.mounted) {
                      ErrorHandler.showSnackBar(
                        context,
                        AppLocalizations.of(context)?.settingsSaveError ??
                            'Failed to save setting. Please try again.',
                      );
                    }
                  }
                },
              ),
              SwitchListTile(
                title: Text(
                  AppLocalizations.of(context)?.dailyReminders ??
                      'Daily Reminders',
                  style: AppTypography.labelLarge,
                ),
                subtitle: Text(
                  AppLocalizations.of(context)?.dailyRemindersSubtitle ??
                      'Remind me to play daily',
                  style: AppTypography.labelSmall,
                ),
                value: settingsService.dailyReminders,
                onChanged: (value) async {
                  final success =
                      await settingsService.setDailyReminders(value);
                  if (success) {
                    setState(() {});
                  } else {
                    if (context.mounted) {
                      ErrorHandler.showSnackBar(
                        context,
                        AppLocalizations.of(context)?.settingsSaveError ??
                            'Failed to save setting. Please try again.',
                      );
                    }
                  }
                },
              ),
              SwitchListTile(
                title: Text(
                  AppLocalizations.of(context)?.achievementAlerts ??
                      'Achievement Alerts',
                  style: AppTypography.labelLarge,
                ),
                subtitle: Text(
                  AppLocalizations.of(context)?.achievementAlertsSubtitle ??
                      'Get notified when you unlock achievements',
                  style: AppTypography.labelSmall,
                ),
                value: settingsService.achievementAlerts,
                onChanged: (value) async {
                  final success =
                      await settingsService.setAchievementAlerts(value);
                  if (success) {
                    setState(() {});
                  } else {
                    if (context.mounted) {
                      ErrorHandler.showSnackBar(
                        context,
                        AppLocalizations.of(context)?.settingsSaveError ??
                            'Failed to save setting. Please try again.',
                      );
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
                AppLocalizations.of(context)?.done ?? 'Done',
                style: AppTypography.labelLarge,
              ),
            ),
          ],
        );
      },
    );
  }
}
















