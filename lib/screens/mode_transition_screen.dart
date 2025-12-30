import 'dart:math';
import 'package:n3rd_game/utils/unawaited_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:n3rd_game/widgets/video_background_widget.dart';
import 'package:n3rd_game/models/game_mode_config.dart';
import 'package:n3rd_game/services/resource_manager.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/config/app_config.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/widgets/app_button.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/widgets/error_recovery_widget.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Transition screen shown before starting a game mode
///
/// Displays a random transition video and navigates to the game screen
/// after a minimum delay. Users can skip the video after the minimum delay.
///
/// Features:
/// - Random video selection from available transition videos
/// - Minimum delay enforcement (3 seconds)
/// - Skip functionality after minimum delay
/// - Argument validation for game mode
/// - Error handling and recovery
class ModeTransitionScreen extends StatefulWidget {
  const ModeTransitionScreen({super.key});

  @override
  State<ModeTransitionScreen> createState() => _ModeTransitionScreenState();
}

class _ModeTransitionScreenState extends State<ModeTransitionScreen>
    with ResourceManagerMixin {
  late String _randomVideoPath;
  DateTime? _startTime;
  bool _canSkip = false;
  bool _videoCompleted = false;
  String? _errorMessage;

  // Constants
  static const List<String> _transitionVideos = [
    'assets/modeselection2.mp4',
    'assets/modeselection3.mp4',
    'assets/modeselectiontransitionscreen.mp4',
  ];

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    // Randomize transition video from available options
    _randomVideoPath = _getRandomTransitionVideo();

    // Enable skip after minimum delay
    if (AppConfig.allowSkipTransition) {
      Future.delayed(AppConfig.minModeTransitionDelay, () {
        if (mounted) {
          setState(() {
            _canSkip = true;
          });
        }
      });
    }
  }

  /// Get a random transition video from available options
  ///
  /// Returns one of the predefined transition video paths
  String _getRandomTransitionVideo() {
    final random = Random();
    return _transitionVideos[random.nextInt(_transitionVideos.length)];
  }

  /// Navigate to game screen with validated arguments
  ///
  /// Ensures minimum delay has passed before navigation.
  /// Validates game mode arguments and handles errors gracefully.
  void _navigateToGame() async {
    if (!mounted || !context.mounted) return;

    // Ensure minimum delay has passed since screen was shown
    if (_startTime != null) {
      final elapsed = DateTime.now().difference(_startTime!);
      final remaining = AppConfig.minModeTransitionDelay - elapsed;
      if (remaining.inMilliseconds > 0) {
        // Wait for remaining time to reach minimum delay
        await Future.delayed(remaining);
      }
    } else {
      // If start time is null, wait full minimum delay
      await Future.delayed(AppConfig.minModeTransitionDelay);
    }

    if (!mounted || !context.mounted) return;

    try {
      // Get the game mode arguments passed from mode selection screen
      final args = ModalRoute.of(context)?.settings.arguments;

      // Validate arguments - should be GameMode or Map with 'mode' key
      if (args != null) {
        if (args is! GameMode && args is! Map) {
          // Invalid argument type - navigate to game without arguments (will use default)
          if (mounted && context.mounted) {
            unawaited(NavigationHelper.safeNavigate(context, '/game', replace: true));
          }
          return;
        }
      }

      // Navigate with validated arguments
      if (mounted && context.mounted) {
        unawaited(NavigationHelper.safeNavigate(
          context,
          '/game',
          replace: true,
          arguments: args,
        ),);
      }
    } catch (e) {
      // Handle navigation error gracefully
      LoggerService.error(
        'ModeTransitionScreen: Navigation error',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
      // Try to navigate without arguments as fallback
      if (mounted && context.mounted) {
        try {
          unawaited(NavigationHelper.safeNavigate(context, '/game', replace: true));
        } catch (fallbackError) {
          LoggerService.error(
            'ModeTransitionScreen: Fallback navigation also failed',
            error: fallbackError,
            stack: StackTrace.current,
            fatal: false,
          );
          // If navigation completely fails, pop back to previous screen
          if (mounted && context.mounted) {
            setState(() {
              _errorMessage = 'Failed to navigate to game. Please try again.';
            });
            // Auto-navigate after short delay
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted && context.mounted) {
                NavigationHelper.safePop(context);
              }
            });
          }
        }
      }
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    ); // Restore normal mode
    super.dispose();
  }

  /// Handle video completion callback
  ///
  /// Navigates to game if early transition is allowed and minimum delay has passed
  void _onVideoCompleted() {
    if (mounted) {
      setState(() {
        _videoCompleted = true;
      });
      // Navigate immediately if video completed and minimum delay passed
      if (AppConfig.allowEarlyTransition) {
        _navigateToGame();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Show error state if navigation failed
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.of(context).background,
        body: ErrorRecoveryWidget(
          errorMessage: _errorMessage!,
          onRetry: () {
            setState(() {
              _errorMessage = null;
            });
            _navigateToGame();
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.of(context).background,
      body: Stack(
        children: [
          Semantics(
            label: 'Transition video playing',
            child: VideoBackgroundWidget(
              videoPath: _randomVideoPath,
              fit: BoxFit.cover,
              alignment:
                  Alignment.topCenter, // Characters/logos in upper portion
              loop: false,
              autoplay: true,
              onVideoCompleted:
                  _onVideoCompleted, // Navigate when video completes (after minimum delay)
              child: const SizedBox.shrink(), // No content overlay needed
            ),
          ),
          // Skip button (shown after minimum delay if video hasn't completed)
          if (_canSkip && !_videoCompleted)
            Positioned(
              top: AppSpacing.xl,
              right: AppSpacing.lg,
              child: AppButton(
                label: AppLocalizations.of(context)?.skip ?? 'Skip',
                onPressed: _navigateToGame,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                backgroundColor: AppColors.overlayDark.withValues(alpha: 0.5),
                foregroundColor: AppColors.of(context).onDarkText,
                semanticsLabel:
                    '${AppLocalizations.of(context)?.skip ?? 'Skip'} transition video. Double tap to skip to game',
              ),
            ),
        ],
      ),
    );
  }
}