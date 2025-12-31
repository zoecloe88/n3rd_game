import 'package:flutter/material.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/theme/app_radius.dart';

/// Skeleton loader widget for smooth loading states
/// Provides shimmer effect for better UX during data loading
class SkeletonLoader extends StatefulWidget {

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
    this.baseColor,
    this.highlightColor,
  });
  final double width;
  final double height;
  final double borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor =
        widget.baseColor ?? AppColors.cardBackground.withValues(alpha: 0.3);
    final highlightColor = widget.highlightColor ??
        AppColors.cardBackground.withValues(alpha: 0.5);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: [
                0.0,
                0.5 + (_animation.value * 0.3),
                1.0,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton loader for list items
class SkeletonListItem extends StatelessWidget {

  const SkeletonListItem({
    super.key,
    this.hasAvatar = true,
    this.hasSubtitle = true,
    this.hasTrailing = false,
  });
  final bool hasAvatar;
  final bool hasSubtitle;
  final bool hasTrailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          if (hasAvatar) ...[
            const SkeletonLoader(
              width: 48,
              height: 48,
              borderRadius: AppRadius.pill,
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonLoader(width: double.infinity, height: 16),
                if (hasSubtitle) ...[
                  const SizedBox(height: AppSpacing.sm),
                  SkeletonLoader(
                    width: MediaQuery.of(context).size.width * 0.6,
                    height: 12,
                  ),
                ],
              ],
            ),
          ),
          if (hasTrailing) ...[
            const SizedBox(width: AppSpacing.sm),
            const SkeletonLoader(width: 24, height: 24),
          ],
        ],
      ),
    );
  }
}

/// Skeleton loader for card items
class SkeletonCard extends StatelessWidget {

  const SkeletonCard({
    super.key,
    this.height,
    this.hasImage = false,
    this.lines = 3,
  });
  final double? height;
  final bool hasImage;
  final int lines;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.all(AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      height: height,
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage) ...[
            const SkeletonLoader(
              width: double.infinity,
              height: 120,
              borderRadius: AppRadius.medium,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          const SkeletonLoader(width: double.infinity, height: 20),
          const SizedBox(height: AppSpacing.sm),
          ...List.generate(
            lines,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: SkeletonLoader(
                width: index == lines - 1
                    ? MediaQuery.of(context).size.width * 0.7
                    : double.infinity,
                height: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton loader for form fields
class SkeletonFormField extends StatelessWidget {

  const SkeletonFormField({
    super.key,
    this.hasLabel = true,
    this.hasHelperText = false,
  });
  final bool hasLabel;
  final bool hasHelperText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasLabel) ...[
            const SkeletonLoader(
              width: 100,
              height: 14,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SkeletonLoader(
            width: double.infinity,
            height: 48,
            borderRadius: AppRadius.medium,
          ),
          if (hasHelperText) ...[
            const SizedBox(height: AppSpacing.xs),
            const SkeletonLoader(
              width: 150,
              height: 12,
            ),
          ],
        ],
      ),
    );
  }
}

/// Skeleton loader for grid items
class SkeletonGridItem extends StatelessWidget {

  const SkeletonGridItem({
    super.key,
    this.aspectRatio = 1.0,
  });
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: SkeletonLoader(
              width: double.infinity,
              height: double.infinity,
              borderRadius: AppRadius.medium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonLoader(width: double.infinity, height: 14),
                const SizedBox(height: AppSpacing.xs),
                SkeletonLoader(
                  width: MediaQuery.of(context).size.width * 0.4,
                  height: 12,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
