import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:n3rd_game/widgets/video_background_widget.dart';
import 'package:n3rd_game/services/game_service.dart';
import 'package:n3rd_game/services/resource_manager.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';

class ModeTransitionScreen extends StatefulWidget {
  const ModeTransitionScreen({super.key});

  @override
  State<ModeTransitionScreen> createState() => _ModeTransitionScreenState();
}

class _ModeTransitionScreenState extends State<ModeTransitionScreen>
    with ResourceManagerMixin {
  late String _randomVideoPath;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    // Randomize transition video from available options
    _randomVideoPath = _getRandomTransitionVideo();
  }

  String _getRandomTransitionVideo() {
    // Randomize between available transition videos
    final random = Random();
    final videos = [
      'assets/modeselection2.mp4',
      'assets/modeselection3.mp4',
      'assets/modeselectiontransitionscreen.mp4',
    ];
    return videos[random.nextInt(videos.length)];
  }

  void _navigateToGame() async {
    if (!mounted || !context.mounted) return;

    // Ensure minimum 3 seconds have passed since screen was shown
    if (_startTime != null) {
      final elapsed = DateTime.now().difference(_startTime!);
      final remainingSeconds = 3 - elapsed.inSeconds;
      if (remainingSeconds > 0) {
        // Wait for remaining time to reach exactly 3 seconds
        await Future.delayed(Duration(seconds: remainingSeconds));
      }
    } else {
      // If start time is null, wait full 3 seconds
      await Future.delayed(const Duration(seconds: 3));
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
            NavigationHelper.safeNavigate(context, '/game', replace: true);
          }
          return;
        }
      }

      // Navigate with validated arguments
      if (mounted && context.mounted) {
        NavigationHelper.safeNavigate(
          context,
          '/game',
          replace: true,
          arguments: args,
        );
      }
    } catch (e) {
      // Handle navigation error gracefully
      // Try to navigate without arguments as fallback
      if (mounted && context.mounted) {
        try {
          NavigationHelper.safeNavigate(context, '/game', replace: true);
        } catch (fallbackError) {
          // If navigation completely fails, pop back to previous screen
          if (mounted && context.mounted) {
            Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    return Scaffold(
      body: VideoBackgroundWidget(
        videoPath: _randomVideoPath,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter, // Characters/logos in upper portion
        loop: false,
        autoplay: true,
        onVideoCompleted: _navigateToGame, // Navigate when video completes (after 3s minimum)
        child: const SizedBox.shrink(), // No content overlay needed
      ),
    );
  }
}
