import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:n3rd_game/widgets/video_background_widget.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/services/resource_manager.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';

class YouthTransitionScreen extends StatefulWidget {
  final String? routeAfter;
  final Object? routeArgs;
  final VoidCallback? onFinished;

  const YouthTransitionScreen({
    super.key,
    this.routeAfter,
    this.routeArgs,
    this.onFinished,
  });

  @override
  State<YouthTransitionScreen> createState() => _YouthTransitionScreenState();
}

class _YouthTransitionScreenState extends State<YouthTransitionScreen>
    with ResourceManagerMixin {
  late String _randomVideoPath;

  @override
  void initState() {
    super.initState();
    // Randomize transition video from available options
    _randomVideoPath = _getRandomTransitionVideo();
    registerTimer(
      Timer(const Duration(seconds: 3), () {
        if (!mounted || !context.mounted) return;
        if (widget.onFinished != null) {
          widget.onFinished!.call();
        } else if (widget.routeAfter != null) {
          NavigationHelper.safePushReplacementNamed(
            context,
            widget.routeAfter!,
            arguments: widget.routeArgs,
          );
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
