import 'package:flutter/material.dart';
import 'package:n3rd_game/screens/friends_screen.dart';
import 'package:n3rd_game/screens/conversations_screen.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/widgets/animated_graphics_widget.dart';

/// Screen that combines Friends and Messages functionality
/// Shows tabs for Friends List and Conversations
class FriendsAndMessagesScreen extends StatefulWidget {
  const FriendsAndMessagesScreen({super.key});

  @override
  State<FriendsAndMessagesScreen> createState() =>
      _FriendsAndMessagesScreenState();
}

class _FriendsAndMessagesScreenState extends State<FriendsAndMessagesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            // Friends animation (150px)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: AnimatedGraphicsWidget(
                category: 'shared',
                width: 120,
                height: 120,
                loop: true,
                autoplay: true,
              ),
            ),
            Text(
              'Friends',
              style: AppTypography.headlineLarge.copyWith(color: Colors.white),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00D9FF),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
          tabs: const [
            Tab(text: 'Friends'),
            Tab(text: 'Messages'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [FriendsScreen(), ConversationsScreen()],
      ),
    );
  }
}
