import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:n3rd_game/theme/app_typography.dart';

/// Global error widget customizer that displays user-friendly error screens
///
/// **Design Notes:**
/// - This widget customizes Flutter's global `ErrorWidget.builder`, replacing the
///   default red error screen with a branded, user-friendly UI
/// - Unlike React's ErrorBoundary, Flutter's `ErrorWidget.builder` is global, not
///   scoped to a widget subtree. This widget acts as an initializer for the global
///   error widget customizer
/// - Typically used at the root of the app (in main.dart) to provide consistent
///   error UI throughout the application
///
/// **Error Handling Architecture:**
/// Flutter uses two separate error handling mechanisms:
/// 1. `ErrorWidget.builder` (handled here) - Called when a widget BUILD fails
///    synchronously. Shows the custom error UI instead of the red screen.
/// 2. `FlutterError.onError` (handled in main.dart) - Called for all Flutter framework
///    errors including async errors, render errors, and other runtime exceptions.
///    Logs to Crashlytics for production error tracking.
///
/// Both mechanisms work together: ErrorWidget.builder handles UI display for build
/// errors, while FlutterError.onError ensures all errors are logged to analytics.
///
/// **Important**: This widget should typically be placed once at the root of the app.
/// If multiple instances exist, reference counting ensures proper cleanup when all
/// instances are disposed (though this is uncommon in practice).
class ErrorBoundary extends StatefulWidget {
  final Widget child;

  const ErrorBoundary({super.key, required this.child});

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  static ErrorWidgetBuilder? _originalErrorWidgetBuilder;
  static int _instanceCount = 0;

  @override
  void initState() {
    super.initState();
    _instanceCount++;

    // Store original ErrorWidget.builder if not already stored
    // Use static to ensure we only store it once across all instances
    _originalErrorWidgetBuilder ??= ErrorWidget.builder;

    // Set custom error widget builder for widget build errors
    // This is a GLOBAL setting that affects the entire app
    // ErrorWidget.builder is called automatically when a widget build fails
    // synchronously, replacing the default red error screen with our custom UI
    ErrorWidget.builder = (FlutterErrorDetails details) {
      // Log error to console in debug mode
      // Note: Context is not directly available here, so analytics are handled
      // via FlutterError.onError in main.dart which logs to Crashlytics
      if (kDebugMode) {
        debugPrint('Widget build error: ${details.exception}');
        debugPrint('Stack: ${details.stack}');
      }

      // Return custom error widget instead of default red screen
      return _CustomErrorWidget(errorDetails: details);
    };
  }

  @override
  void dispose() {
    _instanceCount--;

    // Restore original ErrorWidget.builder when last instance is disposed
    // Use reference counting to handle multiple ErrorBoundary instances correctly
    // Note: In practice, this widget is typically at the root and never disposed,
    // but this ensures correct cleanup if used in nested contexts
    if (_instanceCount == 0 && _originalErrorWidgetBuilder != null) {
      ErrorWidget.builder = _originalErrorWidgetBuilder!;
      _originalErrorWidgetBuilder = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ErrorWidget.builder is a global setting - it automatically handles
    // errors in any widget tree. We just return the child; the custom
    // error widget will be shown if any widget fails to build
    return widget.child;
  }
}

/// Custom error widget that displays a user-friendly error screen
/// This replaces the default red error screen with a branded error UI
class _CustomErrorWidget extends StatelessWidget {
  final FlutterErrorDetails errorDetails;

  const _CustomErrorWidget({required this.errorDetails});

  @override
  Widget build(BuildContext context) {
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
                  color: Color(0xFF00D9FF),
                  size: 64,
                ),
                const SizedBox(height: 24),
                Text(
                  'Something went wrong',
                  style: AppTypography.displayMedium.copyWith(
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'We\'re sorry for the inconvenience. Please try restarting the app.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    // Try to navigate back to home
                    // Note: This may fail if the error occurred in navigation system
                    try {
                      final navigator = Navigator.maybeOf(context);
                      if (navigator != null) {
                        navigator.pushNamedAndRemoveUntil(
                          '/title',
                          (route) => false,
                        );
                      }
                    } catch (e) {
                      // If navigation fails, user may need to restart app
                      if (kDebugMode) {
                        debugPrint('Navigation failed: $e');
                      }
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
                  child: const Text('Go to Home'),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Debug Info:',
                          style: AppTypography.labelSmall.copyWith(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          child: Text(
                            errorDetails.exception.toString(),
                            style: AppTypography.bodyMedium.copyWith(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
