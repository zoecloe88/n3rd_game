import 'dart:async';
import 'package:flutter/material.dart';
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
  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).background,
      body: Stack(
        children: [
          // Background
          Container(
            color: AppColors.of(context).background,
          ),
        ],
      ),
    );
  }
}
