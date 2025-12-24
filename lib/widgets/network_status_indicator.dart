import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/services/network_service.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/theme/app_spacing.dart';

/// Widget to display network connectivity status
/// Shows online/offline indicator with icon
class NetworkStatusIndicator extends StatelessWidget {
  final bool compact;

  const NetworkStatusIndicator({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final networkService = Provider.of<NetworkService>(context);
    final isOnline = networkService.hasInternetReachability;

    if (compact) {
      return Tooltip(
        message: isOnline ? 'Online' : 'Offline',
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isOnline
                ? colors.success.withValues(alpha: 0.2)
                : colors.error.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isOnline ? Icons.cloud_done : Icons.cloud_off,
            size: 14,
            color: isOnline ? colors.success : colors.error,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: isOnline
            ? colors.success.withValues(alpha: 0.15)
            : colors.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOnline ? colors.success : colors.error,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOnline ? Icons.cloud_done : Icons.cloud_off,
            size: 16,
            color: isOnline ? colors.success : colors.error,
          ),
          const SizedBox(width: 4),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: AppTypography.labelSmall.copyWith(
              color: isOnline ? colors.success : colors.error,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}






