import 'package:flutter/material.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/theme/app_colors.dart';

/// Reusable empty state widget for displaying "no data" messages
///
/// **Usage:**
/// ```dart
/// EmptyStateWidget(
///   icon: Icons.inbox,
///   title: AppLocalizations.of(context)!.noFriends,
///   description: AppLocalizations.of(context)!.noFriendsDescription,
///   actionLabel: 'Add Friend',
///   onAction: () => _addFriend(),
/// )
/// ```
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Semantics(
      label: '$title. $description',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Semantics(
                label: 'Empty state icon',
                excludeSemantics: true,
                child: Icon(icon, size: 64, color: colors.tertiaryText),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: AppTypography.headlineMedium.copyWith(
                  color: colors.primaryText,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: AppTypography.bodyMedium.copyWith(
                  color: colors.secondaryText,
                ),
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 24),
                Semantics(
                  label: actionLabel!,
                  button: true,
                  child: ElevatedButton(
                    onPressed: onAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primaryButton,
                      foregroundColor: colors.buttonText,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: Text(actionLabel!, style: AppTypography.labelLarge),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
