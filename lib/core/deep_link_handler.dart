import 'package:flutter/material.dart';
import 'package:n3rd_game/config/route_config.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/services/multiplayer_service.dart';
import 'package:n3rd_game/services/family_group_service.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'dart:async' show unawaited;
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/utils/security_helper.dart';
import 'package:n3rd_game/screens/multiplayer_lobby_screen.dart';
import 'package:n3rd_game/screens/family_invitation_screen.dart';

/// Handles deep link routing and validation
class DeepLinkHandler {
  /// Check group invitation permission
  static Future<bool> checkGroupInvitationPermission(
    String groupId,
    BuildContext context,
  ) async {
    try {
      final familyService = Provider.of<FamilyGroupService>(
        context,
        listen: false,
      );
      return await familyService.canAccessGroupInvitation(groupId);
    } catch (e) {
      LoggerService.warning(
        'Error checking group invitation permission',
        error: e,
      );
      return false;
    }
  }

  /// Handle multiplayer lobby deep link
  static Route<dynamic>? handleMultiplayerLobby(
    RouteSettings settings,
    BuildContext context,
  ) {
    final args = settings.arguments;
    String? roomCode;

    // Check if joinRoom is in arguments (from deep link)
    if (args is Map<String, dynamic> && args.containsKey('joinRoom')) {
      roomCode = args['joinRoom'] as String?;
    } else if (args is String) {
      // Direct room code as argument
      roomCode = args;
    }

    if (roomCode != null && roomCode.isNotEmpty) {
      // Auto-join room after short delay
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 500));
        if (context.mounted) {
          final multiplayerService = Provider.of<MultiplayerService>(
            context,
            listen: false,
          );
          try {
            await multiplayerService.init();
            await multiplayerService.joinRoom(roomCode!);
            if (context.mounted) {
              unawaited(
                NavigationHelper.safeNavigate(
                  context,
                  '/multiplayer-game',
                  replace: true,
                ),
              );
            }
          } catch (e) {
            LoggerService.warning(
              'Failed to auto-join room from deep link: $roomCode',
              error: e,
            );
            // Stay on lobby screen, user can manually join
          }
        }
      });
    }

    return RouteRegistry.createRoute(
      path: settings.name ?? '/multiplayer-lobby',
      page: const MultiplayerLobbyScreen(),
      settings: settings,
      arguments: settings.arguments,
    );
  }

  /// Handle family invitation deep link
  static Route<dynamic>? handleFamilyInvitation(
    RouteSettings settings,
    BuildContext context,
  ) {
    String? groupId;
    final routeName = settings.name;

    // Check if groupId is in query parameters or path
    if (settings.arguments is Map) {
      final args = settings.arguments as Map<String, dynamic>;

      // Security: Validate deep link parameters
      if (!SecurityHelper.validateDeepLinkParams(args)) {
        LoggerService.warning(
          'Deep link validation failed for family invitation',
        );
        return _buildInvalidLinkRoute(settings);
      }

      groupId = args['groupId'] as String?;
    } else if (settings.arguments is String) {
      groupId = settings.arguments as String;
    } else if (routeName != null && routeName.contains('?')) {
      // Extract from query string with validation
      final uri = Uri.tryParse(routeName);
      if (uri != null && uri.hasQuery) {
        final rawGroupId = uri.queryParameters['groupId'];
        // Validate: Firestore document IDs are alphanumeric with underscores/hyphens, 1-512 chars
        if (rawGroupId != null &&
            rawGroupId.isNotEmpty &&
            rawGroupId.length <= 512 &&
            RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(rawGroupId)) {
          groupId = rawGroupId;
        } else if (rawGroupId != null) {
          LoggerService.warning(
            'Invalid groupId format in deep link',
            error: Exception(
              'groupId format validation failed: ${rawGroupId.substring(0, rawGroupId.length.clamp(0, 50))}',
            ),
          );
        }
      }
    } else if (routeName != null) {
      final parts = routeName.split('/');
      if (parts.length >= 3) {
        // Extract from path: /family-invitation/groupId with validation
        final rawGroupId = parts[2];
        // Validate path parameter format
        if (rawGroupId.isNotEmpty &&
            rawGroupId.length <= 512 &&
            RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(rawGroupId)) {
          groupId = rawGroupId;
        } else {
          LoggerService.warning(
            'Invalid groupId format in deep link path',
            error: Exception('groupId format validation failed'),
          );
        }
      }
    }

    // CRITICAL: Validate user has permission to access this group invitation
    if (groupId != null && groupId.isNotEmpty) {
      final validatedGroupId = groupId;
      // Check permissions asynchronously - show loading screen first
      return RouteRegistry.createRoute(
        path: '/family-invitation',
        page: Builder(
          builder: (context) {
            // Use FutureBuilder to check permissions
            return FutureBuilder<bool>(
              future: checkGroupInvitationPermission(validatedGroupId, context),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    backgroundColor: Colors.black,
                    body: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError || !snapshot.hasData || !snapshot.data!) {
                  // Permission denied or error
                  return _buildErrorScreen(
                    'Invalid Invitation',
                    snapshot.hasError
                        ? 'Unable to verify invitation. Please check your connection and try again.'
                        : 'This invitation link is invalid or has expired.',
                    '/title',
                  );
                }

                // Permission granted - show invitation screen
                return FamilyInvitationScreen(groupId: groupId);
              },
            );
          },
        ),
        settings: settings,
        arguments: settings.arguments,
      );
    }

    // No groupId provided - show error
    return RouteRegistry.createRoute(
      path: '/family-invitation',
      page: _buildErrorScreen(
        'Invalid Invitation Link',
        'The invitation link is missing required information.',
        '/title',
      ),
      settings: settings,
    );
  }

  /// Build invalid link route
  static Route<dynamic> _buildInvalidLinkRoute(RouteSettings settings) {
    return RouteRegistry.createRoute(
      path: '/family-invitation',
      page: _buildErrorScreen(
        'Invalid Link',
        'This invitation link contains invalid parameters.',
        '/title',
      ),
      settings: settings,
    );
  }

  /// Build error screen widget
  static Widget _buildErrorScreen(
    String title,
    String message,
    String fallbackRoute,
  ) {
    return Builder(
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      NavigationHelper.safeNavigate(
                        context,
                        fallbackRoute,
                        replace: true,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                    child: const Text('Go Home'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
