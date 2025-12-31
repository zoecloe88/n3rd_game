import 'dart:async';
import 'package:n3rd_game/utils/unawaited_helper.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:n3rd_game/widgets/video_background_widget.dart';
import 'package:n3rd_game/services/resource_manager.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/config/app_config.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Youth-specific transition screen
///
/// Displays a transition video and either calls a callback or navigates
/// to a specified route after a minimum delay.
///
/// Features:
/// - Random video selection
/// - Supports both callback and navigation patterns
/// - Minimum delay enforcement
class YouthTransitionScreen extends StatefulWidget {

  const YouthTransitionScreen({
    super.key,
    this.routeAfter,
    this.routeArgs,
    this.onFinished,
  });
  final String? routeAfter;
  final Object? routeArgs;
  final VoidCallback? onFinished;

  @override
  State<YouthTransitionScreen> createState() => _YouthTransitionScreenState();
}

class _YouthTransitionScreenState extends State<YouthTransitionScreen>
    with ResourceManagerMixin {
  late String _randomVideoPath;
  DateTime? _startTime;

  // Constants
  static const List<String> _transitionVideos = [
    'assets/modeselectiontransitionscreen.mp4',
    'assets/modeselection2.mp4',
    'assets/modeselection3.mp4',
  ];

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    // Randomize transition video from available options
    _randomVideoPath = _getRandomTransitionVideo();
  }

  /// Handle video completion
  ///
  /// Ensures minimum delay has passed, then either calls callback
  /// or navigates to specified route
  void _handleVideoCompleted() async {
    if (!mounted || !context.mounted) return;

    // Ensure minimum delay has passed (use AppConfig for consistency)
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
      if (widget.onFinished != null) {
        widget.onFinished!.call();
      } else if (widget.routeAfter != null) {
        unawaited(NavigationHelper.safePushReplacementNamed(
          context,
          widget.routeAfter!,
          arguments: widget.routeArgs,
        ),);
      }
    } catch (e) {
      LoggerService.error(
        'YouthTransitionScreen: Navigation error',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
      // If navigation fails, pop back to previous screen
      if (mounted && context.mounted) {
        NavigationHelper.safePop(context);
      }
    }
  }

  /// Get a random transition video from available options
  ///
  /// Returns one of the predefined transition video paths
  String _getRandomTransitionVideo() {
    final random = Random();
    return _transitionVideos[random.nextInt(_transitionVideos.length)];
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    ); // Restore normal mode
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Semantics(
        label: 'Transition video playing',
        child: VideoBackgroundWidget(
          videoPath: _randomVideoPath,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter, // Characters/logos in upper portion
          loop: false,
          autoplay: true,
          onVideoCompleted:
              _handleVideoCompleted, // Navigate when video completes (after minimum delay)
          child: const SizedBox.shrink(), // No content overlay needed
        ),
      ),
    );
  }
}