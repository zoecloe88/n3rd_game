import 'package:flutter/material.dart';
import 'package:n3rd_game/services/auth_service.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/utils/provider_helper.dart';

/// Widget that listens to auth state changes and navigates accordingly
///
/// Automatically redirects users to login screen when they log out while
/// on a protected route.
class AuthStateListener extends StatefulWidget {
  const AuthStateListener({required this.child, super.key});

  final Widget child;

  @override
  State<AuthStateListener> createState() => _AuthStateListenerState();
}

class _AuthStateListenerState extends State<AuthStateListener> {
  @override
  void initState() {
    super.initState();
    // Listen to auth state changes after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final authService = ProviderHelper.safeGet<AuthService>(context, listen: false);
        if (authService != null) {
          authService.addListener(_onAuthStateChanged);
        }
      }
    });
  }

  @override
  void dispose() {
    if (mounted) {
      final authService = ProviderHelper.safeGet<AuthService>(context, listen: false);
      if (authService != null) {
        authService.removeListener(_onAuthStateChanged);
      }
    }
    super.dispose();
  }

  void _onAuthStateChanged() {
    // CRITICAL: Check both mounted and context.mounted before proceeding
    if (!mounted || !context.mounted) return;

    final authService = ProviderHelper.safeGet<AuthService>(context, listen: false);
    if (authService == null) return; // Service not available, skip

    // CRITICAL: Use Navigator.maybeOf instead of Navigator.of to handle null cases
    // This prevents crashes when Navigator is not available
    final navigator = Navigator.maybeOf(context);
    if (navigator == null) return; // Navigator not available, skip navigation

    // Get current route
    final currentRoute = ModalRoute.of(context)?.settings.name;

    // List of routes that require authentication
    const protectedRoutes = [
      '/title',
      '/modes',
      '/game',
      '/stats',
      '/leaderboard',
      '/friends',
      '/more',
      '/settings',
      '/word-of-day',
      '/editions',
      '/subscription-management',
    ];

    // If user logged out and is on a protected route, redirect to login
    // Use safeNavigateAndRemoveUntil to clear navigation stack and go to login
    // This works regardless of whether we can pop (removes all routes)
    if (!authService.isAuthenticated &&
        currentRoute != null &&
        protectedRoutes.contains(currentRoute)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Double-check mounted and context.mounted before navigation
        // NavigationHelper handles Navigator availability checks
        if (mounted && context.mounted) {
          NavigationHelper.safeNavigateAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
