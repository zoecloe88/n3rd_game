import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:n3rd_game/widgets/video_background_widget.dart';
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
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    // Randomize transition video from available options
    _randomVideoPath = _getRandomTransitionVideo();
  }

  void _handleVideoCompleted() async {
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

    if (widget.onFinished != null) {
      widget.onFinished!.call();
    } else if (widget.routeAfter != null) {
      NavigationHelper.safePushReplacementNamed(
        context,
        widget.routeAfter!,
        arguments: widget.routeArgs,
      );
    }
  }

  String _getRandomTransitionVideo() {
    // Randomize between available transition videos
    final random = Random();
    final videos = [
      'assets/modeselectiontransitionscreen.mp4',
      'assets/modeselection2.mp4',
      'assets/modeselection3.mp4',
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
      body: VideoBackgroundWidget(
        videoPath: _randomVideoPath,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter, // Characters/logos in upper portion
        loop: false,
        autoplay: true,
        onVideoCompleted: _handleVideoCompleted, // Navigate when video completes (after 3s minimum)
        child: const SizedBox.shrink(), // No content overlay needed
      ),
    );
  }
}
