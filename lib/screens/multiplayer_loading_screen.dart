import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:n3rd_game/widgets/video_player_widget.dart';
import 'package:n3rd_game/models/game_room.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/services/resource_manager.dart';

class MultiplayerLoadingScreen extends StatefulWidget {
  final MultiplayerMode mode;

  const MultiplayerLoadingScreen({super.key, required this.mode});

  @override
  State<MultiplayerLoadingScreen> createState() =>
      _MultiplayerLoadingScreenState();
}

class _MultiplayerLoadingScreenState extends State<MultiplayerLoadingScreen>
    with ResourceManagerMixin {
  late String _randomVideoPath;

  @override
  void initState() {
    super.initState();
    // Randomize transition video
    _randomVideoPath = _getRandomTransitionVideo();
    // Navigate after 3 seconds
    registerTimer(
      Timer(const Duration(seconds: 3), () {
        if (mounted && context.mounted) {
          Navigator.of(
            context,
          ).pushReplacementNamed('/multiplayer-lobby', arguments: widget.mode);
        }
      }),
    );
  }

  String _getRandomTransitionVideo() {
    final random = Random();
    final videos = [
      'assets/videos/transition 1.mp4',
      'assets/videos/transition 2.mp4',
      'assets/videos/transition 3.mp4',
      'assets/videos/transition 4.mp4',
      'assets/videos/transition 5.mp4',
    ];
    return videos[random.nextInt(videos.length)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).background,
      body: Stack(
        children: [
          // Video background
          // Video background - fills entire screen perfectly
          VideoPlayerWidget(
            videoPath: _randomVideoPath,
            loop: false,
            autoplay: true,
          ),
        ],
      ),
    );
  }
}
