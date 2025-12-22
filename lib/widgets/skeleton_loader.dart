import 'package:flutter/material.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/theme/app_radius.dart';
import 'package:n3rd_game/widgets/shimmer.dart';

/// Skeleton loader widget for list items
/// Provides consistent loading states for list screens
class SkeletonLoader extends StatelessWidget {
  final int itemCount;
  final double? itemHeight;
  final EdgeInsets? padding;
  final bool showAvatar;
  final bool showSubtitle;

  const SkeletonLoader({
    super.key,
    this.itemCount = 3,
    this.itemHeight,
    this.padding,
    this.showAvatar = false,
    this.showSubtitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final defaultHeight = itemHeight ?? 72.0;
    final defaultPadding = padding ?? const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    );

    return ListView.builder(
      padding: defaultPadding,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _SkeletonItem(
            height: defaultHeight,
            showAvatar: showAvatar,
            showSubtitle: showSubtitle,
            colors: colors,
          ),
        );
      },
    );
  }
}

class _SkeletonItem extends StatelessWidget {
  final double height;
  final bool showAvatar;
  final bool showSubtitle;
  final AppColorScheme colors;

  const _SkeletonItem({
    required this.height,
    required this.showAvatar,
    required this.showSubtitle,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Container(
        height: height,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: Row(
          children: [
            if (showAvatar) ...[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.borderLight,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 16,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colors.borderLight,
                      borderRadius: BorderRadius.circular(AppRadius.small),
                    ),
                  ),
                  if (showSubtitle) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      height: 12,
                      width: MediaQuery.of(context).size.width * 0.6,
                      decoration: BoxDecoration(
                        color: colors.borderLight,
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton loader for card-based layouts
class SkeletonCardLoader extends StatelessWidget {
  final int itemCount;
  final double? cardHeight;
  final EdgeInsets? padding;

  const SkeletonCardLoader({
    super.key,
    this.itemCount = 3,
    this.cardHeight,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final defaultHeight = cardHeight ?? 120.0;
    final defaultPadding = padding ?? const EdgeInsets.all(AppSpacing.md);

    return GridView.builder(
      padding: defaultPadding,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.85,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Shimmer(
          child: Container(
            height: defaultHeight,
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.borderLight,
                      borderRadius: BorderRadius.circular(AppRadius.small),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    height: 16,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colors.borderLight,
                      borderRadius: BorderRadius.circular(AppRadius.small),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    height: 12,
                    width: MediaQuery.of(context).size.width * 0.3,
                    decoration: BoxDecoration(
                      color: colors.borderLight,
                      borderRadius: BorderRadius.circular(AppRadius.small),
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
}

