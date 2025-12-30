import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/services/settings_service.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/utils/error_handler.dart';

/// Email settings dialog widget
/// Extracted from SettingsScreen for better code organization
class EmailSettingsDialog extends StatefulWidget {
  const EmailSettingsDialog({super.key});

  @override
  State<EmailSettingsDialog> createState() => _EmailSettingsDialogState();
}

class _EmailSettingsDialogState extends State<EmailSettingsDialog> {
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
            AppLocalizations.of(context)?.emailSettings ?? 'Email Settings',
            style: AppTypography.headlineLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: Text(
                  AppLocalizations.of(context)?.gameNotifications ??
                      'Game Notifications',
                  style: AppTypography.labelLarge,
                ),
                subtitle: Text(
                  AppLocalizations.of(context)?.gameNotificationsSubtitle ??
                      'Get notified about daily challenges',
                  style: AppTypography.labelSmall,
                ),
                value: settingsService.emailGameNotifications,
                onChanged: (value) async {
                  final success =
                      await settingsService.setEmailGameNotifications(value);
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
                  AppLocalizations.of(context)?.leaderboardUpdates ??
                      'Leaderboard Updates',
                  style: AppTypography.labelLarge,
                ),
                subtitle: Text(
                  AppLocalizations.of(context)?.leaderboardUpdatesSubtitle ??
                      'Get notified when you rank up',
                  style: AppTypography.labelSmall,
                ),
                value: settingsService.emailLeaderboardUpdates,
                onChanged: (value) async {
                  final success =
                      await settingsService.setEmailLeaderboardUpdates(value);
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













