import 'package:flutter/material.dart';

/// Initial loading screen - first screen shown on app launch
/// Uses simple black background
class InitialLoadingScreen extends StatelessWidget {
  const InitialLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00D9FF)),
        ),
      ),
    );
  }
}
