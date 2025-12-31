import 'package:flutter/material.dart';
import 'package:n3rd_game/theme/app_typography.dart';

/// Handles error screen generation for app errors
class AppErrorHandler {
  /// Build unknown route error screen
  static Widget buildUnknownRouteScreen(String? routeName) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Page Not Found',
                    style: AppTypography.headlineLarge.copyWith(
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The page "${routeName ?? 'unknown'}" could not be found.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),
                  Builder(
                    builder: (ctx) => ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pushReplacementNamed('/title');
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                      child: Text(
                        'Go Home',
                        style: AppTypography.labelLarge,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build initialization error screen
  static Widget buildInitializationErrorScreen({
    required String errorMessage,
    required String recoveryAction,
    String? errorDetails,
  }) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 24),
                Text(
                  'Initialization Error',
                  style: AppTypography.headlineLarge.copyWith(
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  errorMessage,
                  style: AppTypography.bodyMedium.copyWith(
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (errorDetails != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    errorDetails,
                    style: AppTypography.bodySmall.copyWith(
                      color: Colors.white54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  recoveryAction,
                  style: AppTypography.bodyMedium.copyWith(
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
