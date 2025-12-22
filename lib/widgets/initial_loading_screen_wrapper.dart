import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:n3rd_game/widgets/initial_loading_screen.dart';
import 'package:n3rd_game/widgets/animated_logo_loading_screen_wrapper.dart';

/// Wrapper that shows initial loading screen for 3 seconds, then navigates to logo loading screen
/// Also preloads Google Fonts during the loading period for optimal performance
class InitialLoadingScreenWrapper extends StatefulWidget {
  const InitialLoadingScreenWrapper({super.key});

  @override
  State<InitialLoadingScreenWrapper> createState() =>
      _InitialLoadingScreenWrapperState();
}

class _InitialLoadingScreenWrapperState
    extends State<InitialLoadingScreenWrapper> {
  bool _fontsLoaded = false;
  String? _fontLoadError;

  @override
  void initState() {
    super.initState();
    // Preload fonts during loading screen display and navigate after delay
    _initializeAndNavigate();
  }

  /// Initialize fonts and navigate to next screen with proper error handling
  Future<void> _initializeAndNavigate() async {
    // Preload fonts during loading screen display
    final fontLoadFuture = _preloadFonts();

    try {
      // Show initial loading for 3 seconds, then navigate to logo loading screen
      // Wait for fonts to load or timeout, whichever comes first
      await Future.wait([
        Future.delayed(const Duration(seconds: 3)),
        fontLoadFuture,
      ]);

      // Navigate after successful initialization
      if (mounted && context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const AnimatedLogoLoadingScreenWrapper(),
          ),
        );
      }
    } catch (e) {
      // Even if font loading fails, proceed after 3 seconds
      // Log error for debugging but don't block app startup
      if (kDebugMode) {
        debugPrint(
          '⚠️ Font preloading encountered error during initialization: $e',
        );
      }

      // Ensure we navigate even if font loading fails
      if (mounted && context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const AnimatedLogoLoadingScreenWrapper(),
          ),
        );
      }
    }
  }

  /// Preload Google Fonts during app initialization
  /// This ensures fonts are cached before first use, improving performance
  /// and preventing FOUC (Flash of Unstyled Content)
  Future<void> _preloadFonts() async {
    final startTime = DateTime.now();
    try {
      // Preload primary fonts used throughout the app
      // These are the main fonts defined in AppTypography
      // Using GoogleFonts.pendingFonts() ensures fonts are loaded before use
      await GoogleFonts.pendingFonts([
        GoogleFonts.playfairDisplay(),
        GoogleFonts.lora(),
        GoogleFonts.inter(),
      ]).timeout(const Duration(seconds: 10));

      final loadDuration = DateTime.now().difference(startTime);
      if (mounted) {
        setState(() {
          _fontsLoaded = true;
          _fontLoadError = null;
        });
      }
      if (kDebugMode) {
        debugPrint(
          '✓ Font preloading completed in ${loadDuration.inMilliseconds}ms',
        );
      }

      // Track successful font loading (analytics will be available after init)
      // Note: Analytics service may not be initialized yet, so we'll track this
      // in a post-frame callback after services are ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Analytics tracking will happen when service is available
      });
    } catch (e) {
      final loadDuration = DateTime.now().difference(startTime);
      // Font preloading failure is non-critical - fonts will load on-demand
      // Google Fonts package handles caching automatically
      if (mounted) {
        setState(() {
          _fontsLoaded = false;
          _fontLoadError = e.toString();
        });
      }
      if (kDebugMode) {
        debugPrint(
          '⚠️ Font preloading failed after ${loadDuration.inMilliseconds}ms: $e',
        );
      }

      // Track font load failure for analytics (when service is available)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Analytics tracking will happen when service is available
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const InitialLoadingScreen(),
        // Show font loading status in debug mode or if there's an error
        if (kDebugMode || _fontLoadError != null)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _fontsLoaded
                      ? Colors.green.withValues(alpha: 0.8)
                      : _fontLoadError != null
                          ? Colors.orange.withValues(alpha: 0.8)
                          : Colors.blue.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_fontsLoaded && _fontLoadError == null)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    if (!_fontsLoaded && _fontLoadError == null)
                      const SizedBox(width: 8),
                    Text(
                      _fontsLoaded
                          ? '✓ Fonts loaded'
                          : _fontLoadError != null
                              ? '⚠ Fonts will load on-demand'
                              : 'Loading fonts...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
