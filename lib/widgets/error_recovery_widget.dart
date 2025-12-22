import 'package:flutter/material.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/theme/app_spacing.dart';

/// Standardized error recovery widget with retry functionality
/// Supports automatic retry with exponential backoff
class ErrorRecoveryWidget extends StatefulWidget {
  final String? title;
  final String errorMessage;
  final VoidCallback? onRetry;
  final String retryButtonText;
  final IconData icon;
  final Color iconColor;
  final bool showRetryButton;
  final int? maxRetries;
  final bool autoRetry;

  const ErrorRecoveryWidget({
    super.key,
    this.title,
    String? errorMessage,
    String? message, // Backward compatibility
    this.onRetry,
    this.retryButtonText = 'Retry',
    this.icon = Icons.error_outline,
    this.iconColor = Colors.red,
    this.showRetryButton = true,
    this.maxRetries,
    this.autoRetry = false,
  }) : errorMessage = errorMessage ?? message ?? 'An error occurred';

  @override
  State<ErrorRecoveryWidget> createState() => _ErrorRecoveryWidgetState();
}

class _ErrorRecoveryWidgetState extends State<ErrorRecoveryWidget> {
  int _retryCount = 0;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoRetry && widget.onRetry != null) {
      _performAutoRetry();
    }
  }

  Future<void> _performAutoRetry() async {
    if (widget.maxRetries != null && _retryCount >= widget.maxRetries!) {
      return;
    }

    // Exponential backoff: 1s, 2s, 4s, 8s
    final delay = Duration(seconds: 1 << _retryCount);
    await Future.delayed(delay);

    if (!mounted) return;

    setState(() {
      _isRetrying = true;
      _retryCount++;
    });

    try {
      widget.onRetry?.call();
      // Wait a bit to allow async operations to start
      await Future.delayed(const Duration(milliseconds: 100));
    } finally {
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
      }
    }
  }

  Future<void> _handleRetry() async {
    if (widget.maxRetries != null && _retryCount >= widget.maxRetries!) {
      // Show max retries reached message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Maximum retry attempts reached. Please try again later.',
            ),
            backgroundColor: AppColors.of(context).error,
          ),
        );
      }
      return;
    }

    setState(() {
      _isRetrying = true;
      _retryCount++;
    });

    try {
      widget.onRetry?.call();
      // Wait a bit to allow async operations to start
      await Future.delayed(const Duration(milliseconds: 100));
    } finally {
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.icon,
              color: widget.iconColor,
              size: 64,
            ),
            const SizedBox(height: AppSpacing.md),
            if (widget.title != null) ...[
              Text(
                widget.title!,
                style: AppTypography.headlineLarge.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colors.primaryText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Text(
              widget.errorMessage,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                fontSize: 16,
                color: colors.secondaryText,
              ),
            ),
            if (widget.maxRetries != null && _retryCount > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Retry attempt $_retryCount/${widget.maxRetries}',
                style: AppTypography.labelSmall.copyWith(
                  color: colors.secondaryText,
                ),
              ),
            ],
            if (widget.showRetryButton && widget.onRetry != null) ...[
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton.icon(
                onPressed: _isRetrying ? null : _handleRetry,
                icon: _isRetrying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.refresh),
                label: Text(
                  _isRetrying ? 'Retrying...' : widget.retryButtonText,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primaryButton,
                  foregroundColor: colors.buttonText,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.md,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
