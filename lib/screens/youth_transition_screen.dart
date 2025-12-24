import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:n3rd_game/widgets/video_player_widget.dart';
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
    // Randomize transition video
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
    // Use the mode selection transition screen video for youth edition transitions
    // This provides consistent transition animation throughout the app
    return 'assets/animations/Green Neutral Simple Serendipity Phone Wallpaper(1)/mode selection transition screen.mp4';
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
      body: Stack(
        children: [
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
