import 'package:n3rd_game/utils/unawaited_helper.dart';
import 'package:flutter/material.dart';
import 'package:n3rd_game/services/auth_service.dart';
import 'package:n3rd_game/services/onboarding_service.dart';
import 'package:n3rd_game/services/accessibility_service.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/screens/title_screen.dart';
import 'package:n3rd_game/screens/mode_selection_screen.dart';
import 'package:n3rd_game/screens/stats_menu_screen.dart';
import 'package:n3rd_game/screens/friends_and_messages_screen.dart';
import 'package:n3rd_game/screens/more_menu_screen.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/utils/provider_helper.dart';

/// Main navigation wrapper that provides persistent bottom navigation
/// Only shown for authenticated users after login
class MainNavigationWrapper extends StatefulWidget {

  const MainNavigationWrapper({super.key, this.initialIndex = 0, this.child});
  final int initialIndex;
  final Widget? child;

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
        unawaited(NavigationHelper.safeNavigate(context, '/onboarding', replace: true));
        return;
      }

      if (mounted) {
        setState(() {
          _checkingOnboarding = false;
        });
      }
    } catch (e) {
      // Onboarding check failed - log error but allow access (fail-open to prevent blocking users)
      LoggerService.warning(
        'Onboarding check failed in MainNavigationWrapper',
        error: e,
      );
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

    // Check if PageController is attached before navigating
    if (!_pageController.hasClients) {
      // If not attached yet, just update the index
      setState(() {
        _currentIndex = index;
      });
      return;
    }

    // Update index immediately to prevent cycling through tabs
    setState(() {
      _currentIndex = index;
    });

    // Use jumpToPage for instant navigation to prevent tab cycling
    _pageController.jumpToPage(index);
  }

  void _onTabTapped(int index) {
    // Unfocus any focused widgets to prevent focus traversal
    FocusScope.of(context).unfocus();
    switchToTab(index);
  }

  @override
  Widget build(BuildContext context) {
    final authService = ProviderHelper.safeGet<AuthService>(context, listen: false);

    // If AuthService is not available yet, show loading
    if (authService == null) {
      return Scaffold(
        body: Center(
          child: Semantics(
            label: 'Initializing',
            child: const CircularProgressIndicator(color: Color(0xFF00D9FF)),
          ),
        ),
      );
    }

    // Handle unauthenticated state - redirect to login or show child
    if (!authService.isAuthenticated) {
      // If child is provided, show it (for screens that don't require auth)
      if (widget.child != null) {
        return widget.child!;
      }
      // Otherwise, redirect to login
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.mounted) {
          NavigationHelper.safePushReplacementNamed(context, '/login');
        }
      });
      return Scaffold(
        body: Center(
          child: Semantics(
            label: 'Checking authentication',
            child: const CircularProgressIndicator(color: Color(0xFF00D9FF)),
          ),
        ),
      );
    }

    // Check onboarding status - show loading while checking
    if (_checkingOnboarding) {
      return Scaffold(
        body: Center(
          child: Semantics(
            label: 'Checking onboarding status',
            child: const CircularProgressIndicator(color: Color(0xFF00D9FF)),
          ),
        ),
      );
    }

    return Scaffold(
      body: Semantics(
        liveRegion: true,
        label: _getTabLabel(_currentIndex),
        child: PageView(
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
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  String _getTabLabel(int index) {
    switch (index) {
      case 0:
        return 'Home tab';
      case 1:
        return 'Play tab';
      case 2:
        return 'Stats tab';
      case 3:
        return 'Friends tab';
      case 4:
        return 'More tab';
      default:
        return 'Tab ${index + 1}';
    }
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
    
    // Check if larger touch targets should be enforced
    bool largerTouchTargets = false;
    final accessibilityService = ProviderHelper.safeGet<AccessibilityService>(
      context,
      listen: false,
    );
    if (accessibilityService != null) {
      largerTouchTargets = accessibilityService.settings.largerTouchTargets;
    }

    Widget navItem = GestureDetector(
      onTap: () {
        // Unfocus before switching to prevent focus traversal
        FocusScope.of(context).unfocus();
        _onTabTapped(index);
      },
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
    );
    
    // Enforce minimum touch target size if setting is enabled
    if (largerTouchTargets) {
      navItem = ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 48,
          minHeight: 48,
        ),
        child: navItem,
      );
    }
    
    // Wrap with Semantics for accessibility
    // Note: onTap is handled by GestureDetector to prevent double-tap and focus traversal
    return Expanded(
      child: Semantics(
        label: '$label tab',
        hint: isActive ? 'Currently selected' : 'Tap to switch to $label',
        button: true,
        selected: isActive,
        child: navItem,
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