import 'package:flutter/material.dart';
import 'package:n3rd_game/widgets/unified_background_widget.dart';

/// Initial loading screen - first screen shown on app launch
/// Uses static background with animation overlay
class InitialLoadingScreen extends StatelessWidget {
  const InitialLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: UnifiedBackgroundWidget(
        // Remove large animation - use background only for initial loading
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00D9FF)),
          ),
        ),
      ),
    );
  }
}
