import 'dart:io' show exit;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/theme/app_colors.dart';

/// Screen displayed when critical initialization fails (e.g., trivia templates)
/// This provides a clear, user-friendly error message instead of crashing
class InitializationErrorScreen extends StatelessWidget {
  final String errorMessage;
  final String? recoveryAction;
  final String? errorDetails;

  const InitializationErrorScreen({
    super.key,
    required this.errorMessage,
    this.recoveryAction,
    this.errorDetails,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFF00D9FF),
                  size: 80,
                ),
                const SizedBox(height: 32),
                Text(
                  'Initialization Error',
                  style: AppTypography.displayLarge.copyWith(
                    color: colors.onDarkText,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  errorMessage,
                  style: AppTypography.bodyLarge.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
                if (recoveryAction != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D9FF).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF00D9FF).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Color(0xFF00D9FF),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            recoveryAction!,
                            style: AppTypography.bodyMedium.copyWith(
                              color: colors.onDarkText.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (errorDetails != null && kDebugMode) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Technical Details (Debug):',
                          style: AppTypography.labelSmall.copyWith(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          child: Text(
                            errorDetails!,
                            style: AppTypography.bodyMedium.copyWith(
                              color: colors.onDarkText.withValues(alpha: 0.7),
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    // Exit app - user needs to restart
                    // On web, navigate to splash instead of exiting
                    if (kIsWeb) {
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/splash', (route) => false);
                    } else {
                      exit(0);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D9FF),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: const Text('Close App'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
