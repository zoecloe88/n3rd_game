import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/services/auth_service.dart';
import 'package:n3rd_game/services/onboarding_service.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/screens/title_screen.dart';
import 'package:n3rd_game/screens/mode_selection_screen.dart';
import 'package:n3rd_game/screens/stats_menu_screen.dart';
import 'package:n3rd_game/screens/friends_and_messages_screen.dart';
import 'package:n3rd_game/screens/more_menu_screen.dart';

/// Main navigation wrapper that provides persistent bottom navigation
/// Only shown for authenticated users after login
class MainNavigationWrapper extends StatefulWidget {
  final int initialIndex;
  final Widget? child;

  const MainNavigationWrapper({super.key, this.initialIndex = 0, this.child});

  @override
  State<MainNavigationWrapper> createState() => MainNavigationWrapperState();
}

class MainNavigationWrapperState extends State<MainNavigationWrapper> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  bool _checkingOnboarding = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _checkOnboardingStatus();
    if (widget.initialIndex > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(widget.initialIndex);
        }
      });
    }
  }

  Future<void> _checkOnboardingStatus() async {
    try {
      final onboardingService = OnboardingService();
      final hasCompletedOnboarding =
          await onboardingService.hasCompletedOnboarding();

      if (!hasCompletedOnboarding && mounted && context.mounted) {
        // Redirect to onboarding
        Navigator.of(context).pushReplacementNamed('/onboarding');
        return;
      }

      if (mounted) {
        setState(() {
          _checkingOnboarding = false;
        });
      }
    } catch (e) {
      // Onboarding check failed - log error but allow access (fail-open to prevent blocking users)
      if (kDebugMode) {
        debugPrint('⚠️ Onboarding check failed in MainNavigationWrapper: $e');
      }
      // Continue with normal flow - don't block user if onboarding check fails
      if (mounted) {
        setState(() {
          _checkingOnboarding = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void switchToTab(int index) {
    if (_currentIndex == index) return; // Already on this tab

    // Check if PageController is attached before animating
    if (!_pageController.hasClients) {
      // If not attached yet, just update the index
      setState(() {
        _currentIndex = index;
      });
      return;
    }

    setState(() {
      _currentIndex = index;
    });

    // Animate to the selected page
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onTabTapped(int index) {
    switchToTab(index);
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    // Handle unauthenticated state - redirect to login or show child
    if (!authService.isAuthenticated) {
      // If child is provided, show it (for screens that don't require auth)
      if (widget.child != null) {
        return widget.child!;
      }
      // Otherwise, redirect to login
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
        ),
      );
    }

    // Check onboarding status - show loading while checking
    if (_checkingOnboarding) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
        ),
      );
    }

    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // Disable swipe
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: const [
          TitleScreen(),
          ModeSelectionScreen(),
          StatsMenuScreen(),
          FriendsAndMessagesScreen(),
          MoreMenuScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.95),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 65,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home',
                index: 0,
              ),
              _buildNavItem(
                icon: Icons.play_circle_outline,
                activeIcon: Icons.play_circle,
                label: 'Play',
                index: 1,
              ),
              _buildNavItem(
                icon: Icons.bar_chart_outlined,
                activeIcon: Icons.bar_chart,
                label: 'Stats',
                index: 2,
              ),
              _buildNavItem(
                icon: Icons.people_outlined,
                activeIcon: Icons.people,
                label: 'Friends',
                index: 3,
              ),
              _buildNavItem(
                icon: Icons.more_horiz,
                activeIcon: Icons.more_horiz,
                label: 'More',
                index: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isActive = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color:
                  isActive ? Colors.white : Colors.white.withValues(alpha: 0.6),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: isActive
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper to get initial index from route
int getInitialIndexFromRoute(String? routeName) {
  switch (routeName) {
    case '/title':
      return 0;
    case '/modes':
      return 1;
    case '/stats':
    case '/leaderboard':
      return 2;
    case '/friends':
      return 3;
    case '/settings':
    case '/help-center':
    case '/daily-challenges':
    case '/subscription-management':
      return 4; // More tab
    default:
      return 0;
  }
}
