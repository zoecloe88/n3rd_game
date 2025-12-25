import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:n3rd_game/widgets/video_background_widget.dart';
import 'package:n3rd_game/services/game_service.dart';
import 'package:n3rd_game/theme/app_colors.dart';
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

  @override
  void initState() {
    super.initState();
    // Randomize transition video from available options
    _randomVideoPath = _getRandomTransitionVideo();
    // Navigate after 3 seconds
    registerTimer(
      Timer(const Duration(seconds: 3), () {
        if (mounted) {
          _navigateToGame();
        }
      }),
    );
  }

  String _getRandomTransitionVideo() {
    // Randomize between available transition videos
    final random = Random();
    final videos = [
      'assets/mode selection transition screen.mp4',
      'assets/mode selection 2.mp4',
      'assets/mode selection 3.mp4',
    ];
    return videos[random.nextInt(videos.length)];
  }

  void _navigateToGame() {
    if (!mounted || !context.mounted) return;

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
      backgroundColor: AppColors.of(context).background,
      body: VideoBackgroundWidget(
        videoPath: _randomVideoPath,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter, // Characters/logos in upper portion
        loop: false,
        autoplay: true,
        child: const SizedBox.shrink(), // No content overlay needed
      ),
    );
  }
}
