import 'package:flutter/material.dart';
import 'package:n3rd_game/screens/friends_screen.dart';
import 'package:n3rd_game/screens/conversations_screen.dart';
import 'package:n3rd_game/screens/friends_more_screen.dart';
import 'package:n3rd_game/widgets/background_image_widget.dart';

/// Screen that combines Friends, Messages, and More functionality
/// Shows tabs for Friends List, Conversations, and More
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
    _tabController = TabController(length: 3, vsync: this); // Changed from 2 to 3
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Black fallback - static background will cover
      body: BackgroundImageWidget(
        imagePath: 'assets/background n3rd.png',
        child: SafeArea(
          child: Column(
          children: [
            // Tabs at the top with proper styling
            Container(
              color: const Color(0xFF00D9FF), // Cyan background for tabs
              child: TabBar(
                controller: _tabController,
                indicatorColor: Colors.black,
                indicatorWeight: 3,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.black.withValues(alpha: 0.6),
                tabs: const [
                  Tab(text: 'Friends'),
                  Tab(text: 'Messages'),
                  Tab(text: 'More'),
                ],
              ),
            ),
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  FriendsScreen(),
                  ConversationsScreen(),
                  FriendsMoreScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
