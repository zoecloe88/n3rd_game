import 'package:flutter/material.dart';

/// Initial loading screen - first screen shown on app launch
/// Uses simple black background - no spinner per user request
class InitialLoadingScreen extends StatelessWidget {
  const InitialLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.shrink(), // No spinner - just black screen
    );
  }
}
