import 'dart:async';
import 'package:n3rd_game/utils/unawaited_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/models/game_room.dart';
import 'package:n3rd_game/services/multiplayer_service.dart';
import 'package:n3rd_game/services/network_service.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_shadows.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/utils/error_handler.dart';
import 'package:n3rd_game/utils/provider_helper.dart';
import 'package:n3rd_game/services/friends_service.dart';
import 'package:n3rd_game/models/friend.dart';
import 'package:share_plus/share_plus.dart';
import 'package:n3rd_game/services/newsfeed_service.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/widgets/upgrade_dialog.dart';
import 'package:n3rd_game/utils/subscription_guard.dart';

class MultiplayerLobbyScreen extends StatefulWidget {
  const MultiplayerLobbyScreen({super.key});

  @override
  State<MultiplayerLobbyScreen> createState() => _MultiplayerLobbyScreenState();
}

class _MultiplayerLobbyScreenState extends State<MultiplayerLobbyScreen> {
  String? _roomCode;
  bool _isCreating = false;
  bool _isJoining = false;
  final _roomCodeController = TextEditingController();
  String? _selectedGameMode;
  String? _selectedDifficulty;
  List<Friend> _invitedFriends = [];
  final bool _friendsOnly = false;
  bool _hasProcessedRouteArgs = false;
  bool _hasSubscriptionAccess = false;

  @override
  void initState() {
    super.initState();
    // Check if user has online access
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final subscriptionService = ProviderHelper.safeGetOrThrow<SubscriptionService>(
        context,
        listen: false,
      );
      // Use SubscriptionGuard for consistent access checking
      if (!SubscriptionGuard.canAccessFeature(
        subscriptionService: subscriptionService,
        requiresOnlineAccess: true,
      )) {
        _hasSubscriptionAccess = false;
        _showUpgradeDialog(context);
        return;
      }
      _hasSubscriptionAccess = true;
    });
    // Route arguments will be processed in didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Process route arguments only once after widget tree is built
    if (!_hasProcessedRouteArgs) {
      _hasProcessedRouteArgs = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is MultiplayerMode) {
        _mode = args;
      } else if (args is Map<String, dynamic> && args.containsKey('joinRoom')) {
        // Handle deep link - auto-populate room code and join (only if subscription access granted)
        if (_hasSubscriptionAccess) {
          final roomCode = args['joinRoom'] as String?;
          if (roomCode != null && roomCode.isNotEmpty) {
            _roomCodeController.text = roomCode;
            // Auto-join after short delay
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await Future.delayed(const Duration(milliseconds: 500));
              if (mounted) {
                unawaited(_joinRoom());
              }
            });
          }
        }
      } else if (args is String && args.isNotEmpty) {
        // Direct room code as argument (only if subscription access granted)
        if (_hasSubscriptionAccess) {
          _roomCodeController.text = args;
          // Auto-join after short delay
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await Future.delayed(const Duration(milliseconds: 500));
            if (mounted) {
              unawaited(_joinRoom());
            }
          });
        }
      }
    }
  }

  void _showUpgradeDialog(BuildContext context) {
    final analyticsService = ProviderHelper.safeGetOrThrow<AnalyticsService>(
      context,
      listen: false,
    );

    // Log funnel step 1: Viewed locked feature
    analyticsService.logConversionFunnelStep(
      step: 1,
      stepName: 'viewed_locked_feature',
      source: 'multiplayer',
    );

    // Log upgrade dialog shown
    analyticsService.logUpgradeDialogShown(
      source: 'multiplayer',
      targetTier: 'premium',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const UpgradeDialog(
        title: 'Multiplayer - Premium Feature',
        message: 'Upgrade to Premium to create and join game lobbies!',
        targetTier: 'premium',
        source: 'multiplayer',
        features: [
          'Create and join multiplayer game lobbies',
          'Battle Royale mode',
          'Squad Showdown mode',
          'Team-based gameplay',
        ],
      ),
    ).then((_) {
      // Navigate back after dialog is dismissed
      if (!mounted || !context.mounted) return;
      NavigationHelper.safePop(context);
    });
  }

  MultiplayerMode? _mode;

  @override
  void dispose() {
    _roomCodeController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    if (_mode == null) return;

    // Check network connection
    final networkService = ProviderHelper.safeGetOrThrow<NetworkService>(context, listen: false);
    if (!networkService.isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No internet connection. Please check your network and try again.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    setState(() => _isCreating = true);

    try {
      // Get all services before async operations
      final multiplayerService = ProviderHelper.safeGetOrThrow<MultiplayerService>(
        context,
        listen: false,
      );
      final analyticsService = ProviderHelper.safeGetOrThrow<AnalyticsService>(
        context,
        listen: false,
      );
      final subscriptionService = ProviderHelper.safeGetOrThrow<SubscriptionService>(
        context,
        listen: false,
      );
      await multiplayerService.init();

      final maxPlayers = _mode == MultiplayerMode.battleRoyale ? 4 : 6;
      final room = await multiplayerService.createRoom(
        mode: _mode!,
        maxPlayers: maxPlayers,
        friendsOnly: _friendsOnly,
        subscriptionService: subscriptionService,
      );

      // Log newsfeed activity for room creation
      if (mounted) {
        final newsfeedService =
            ProviderHelper.safeGetOrThrow<NewsfeedService>(context, listen: false);
        unawaited(
          newsfeedService.logMultiplayerActivity(
            activityType: NewsfeedActivityType.roomCreated,
            metadata: {
              'roomId': room.id,
              'mode': _mode!.name,
              'maxPlayers': maxPlayers,
              'friendsOnly': _friendsOnly,
            },
          ),
        );

        // Log analytics for friend-only room creation
        if (_friendsOnly) {
          unawaited(
            analyticsService.logCustomEvent(
              'friend_only_room_created',
              parameters: {'roomId': room.id},
            ),
          );
        }
      }

      // Load invited friends after room creation
      if (mounted) {
        await _loadInvitedFriends(room.id);
      }

      // Log analytics (fire-and-forget)
      unawaited(analyticsService.logRoomCreated());

      if (mounted) {
        setState(() {
          _roomCode = room.id;
          _isCreating = false;
        });
      }
    } catch (e) {
      LoggerService.error('Failed to create room', error: e);
      if (mounted) {
        setState(() => _isCreating = false);
        final errorMessage = ErrorHandler.getLocalizedErrorMessage(e, context);
        ErrorHandler.showSnackBar(context, errorMessage);
        // Log error to analytics
        try {
          final analyticsService = ProviderHelper.safeGetOrThrow<AnalyticsService>(
            context,
            listen: false,
          );
          unawaited(analyticsService.logError('room_creation_failed', errorMessage));
        } catch (analyticsError) {
          // Analytics not available - non-critical
        }
      }
    }
  }

  Future<void> _joinRoom() async {
    final roomCode = _roomCodeController.text.trim();
    if (roomCode.isEmpty) return;

    // Check network connection
    final networkService = ProviderHelper.safeGetOrThrow<NetworkService>(context, listen: false);
    if (!networkService.isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No internet connection. Please check your network and try again.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    setState(() => _isJoining = true);

    try {
      final multiplayerService = ProviderHelper.safeGetOrThrow<MultiplayerService>(
        context,
        listen: false,
      );
      // Get analytics service before async operations
      final analyticsService = ProviderHelper.safeGetOrThrow<AnalyticsService>(
        context,
        listen: false,
      );
      final subscriptionService = ProviderHelper.safeGetOrThrow<SubscriptionService>(
        context,
        listen: false,
      );
      await multiplayerService.init();

      await multiplayerService.joinRoom(
        roomCode,
        subscriptionService: subscriptionService,
      );

      // Log analytics (fire-and-forget)
      unawaited(analyticsService.logRoomJoined());

      if (mounted) {
        unawaited(NavigationHelper.safeNavigate(
          context,
          '/multiplayer-game',
          replace: true,
        ),);
      }
    } catch (e) {
      LoggerService.error('Failed to join room', error: e);
      if (mounted) {
        setState(() => _isJoining = false);
        final errorMessage = ErrorHandler.getLocalizedErrorMessage(e, context);
        ErrorHandler.showSnackBar(context, errorMessage);
        // Log error to analytics
        try {
          final analyticsService = ProviderHelper.safeGetOrThrow<AnalyticsService>(
            context,
            listen: false,
          );
          unawaited(analyticsService.logError('room_join_failed', errorMessage));
        } catch (analyticsError) {
          // Analytics not available - non-critical
        }
      }
    }
  }

  Future<void> _loadInvitedFriends(String roomId) async {
    try {
      final multiplayerService = ProviderHelper.safeGetOrThrow<MultiplayerService>(
        context,
        listen: false,
      );
      final invitations = await multiplayerService.getRoomInvitations(roomId);
      if (!mounted) return;

      // Get FriendsService to get friend details
      final friendsService = ProviderHelper.safeGetOrThrow<FriendsService>(
        context,
        listen: false,
      );
      await friendsService.init();
      if (!mounted) return;
      final allFriends = friendsService.friends;

      final invitedFriendIds =
          invitations.map((inv) => inv.friendUserId).toList();
      final invitedFriendsList = allFriends
          .where((friend) => invitedFriendIds.contains(friend.userId))
          .toList();

      if (mounted) {
        setState(() {
          _invitedFriends = invitedFriendsList;
        });
      }
    } catch (e) {
      LoggerService.warning('Failed to load invited friends', error: e);
    }
  }

  Future<void> _showFriendInviteDialog() async {
    try {
      final friendsService = ProviderHelper.safeGetOrThrow<FriendsService>(
        context,
        listen: false,
      );
      await friendsService.init();
      final friends = friendsService.friends;

      // Filter to only online friends
      final onlineFriends = friends.where((f) => f.isOnline).toList();

      if (!mounted) return;

      unawaited(showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            'Invite Friends',
            style: AppTypography.headlineLarge,
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: onlineFriends.isEmpty
                ? const Text(
                    'No online friends available',
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: onlineFriends.length,
                    itemBuilder: (context, index) {
                      final friend = onlineFriends[index];
                      final isInvited =
                          _invitedFriends.any((f) => f.userId == friend.userId);

                      return ListTile(
                        title: Text(
                          friend.displayName ??
                              friend.email?.split('@').first ??
                              'Unknown',
                          style: AppTypography.bodyLarge,
                        ),
                        trailing: isInvited
                            ? const Icon(Icons.check, color: Colors.green)
                            : ElevatedButton(
                                onPressed: isInvited
                                    ? null
                                    : () {
                                        NavigationHelper.safePop(dialogContext);
                                        _inviteFriend(friend);
                                      },
                                child: const Text(
                                  'Invite',
                                ),
                              ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => NavigationHelper.safePop(dialogContext),
              child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel'),
            ),
          ],
        ),
      ),);
    } catch (e) {
      if (mounted) {
        ErrorHandler.showSnackBar(
          context,
          ErrorHandler.getLocalizedErrorMessage(e, context),
        );
      }
    }
  }

  Future<void> _inviteFriend(Friend friend) async {
    if (_roomCode == null) return;

    try {
      final multiplayerService = ProviderHelper.safeGetOrThrow<MultiplayerService>(
        context,
        listen: false,
      );
      final analyticsService = ProviderHelper.safeGetOrThrow<AnalyticsService>(
        context,
        listen: false,
      );

      await multiplayerService.sendRoomInvitation(_roomCode!, friend.userId);
      if (!mounted) return;

      // Log newsfeed activity
      final newsfeedService =
          ProviderHelper.safeGetOrThrow<NewsfeedService>(context, listen: false);
      unawaited(
        newsfeedService.logMultiplayerActivity(
          activityType: NewsfeedActivityType.friendInvitedToGame,
          metadata: {
            'roomId': _roomCode!,
            'friendUserId': friend.userId,
          },
        ),
      );

      // Log analytics
      unawaited(
        analyticsService.logCustomEvent(
          'room_invitation_sent',
          parameters: {
            'roomId': _roomCode!,
            'friendUserId': friend.userId,
          },
        ),
      );

      if (mounted) {
        setState(() {
          _invitedFriends.add(friend);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Invited ${friend.displayName ?? friend.email?.split("@").first ?? "friend"}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showSnackBar(
          context,
          ErrorHandler.getLocalizedErrorMessage(e, context),
        );
      }
    }
  }

  Future<void> _cancelInvite(String friendUserId) async {
    if (_roomCode == null) return;

    try {
      final multiplayerService = ProviderHelper.safeGetOrThrow<MultiplayerService>(
        context,
        listen: false,
      );
      final invitations =
          await multiplayerService.getRoomInvitations(_roomCode!);
      final invitation = invitations.firstWhere(
        (inv) => inv.friendUserId == friendUserId,
      );

      await multiplayerService.cancelRoomInvitation(invitation.id);

      if (mounted) {
        setState(() {
          _invitedFriends.removeWhere((f) => f.userId == friendUserId);
        });
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showSnackBar(
          context,
          ErrorHandler.getLocalizedErrorMessage(e, context),
        );
      }
    }
  }

  Future<void> _addFriendFromLobby(String userId) async {
    try {
      final friendsService = ProviderHelper.safeGetOrThrow<FriendsService>(
        context,
        listen: false,
      );
      await friendsService.sendFriendRequest(userId);
      if (!mounted) return;

      // Log analytics
      final analyticsService = ProviderHelper.safeGetOrThrow<AnalyticsService>(
        context,
        listen: false,
      );
      unawaited(
        analyticsService.logCustomEvent(
          'friend_added_from_lobby',
          parameters: {'userId': userId},
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request sent'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showSnackBar(
          context,
          ErrorHandler.getLocalizedErrorMessage(e, context),
        );
      }
    }
  }

  Future<void> _shareRoomCode(String roomCode) async {
    try {
      final deepLink = 'n3rdgame://multiplayer/join?room=$roomCode';
      final shareText =
          'Join my N3RD Trivia game! Room Code: $roomCode\n\n$deepLink';

      await Share.share(shareText);
      if (!mounted) return;

      // Log analytics
      final analyticsService = ProviderHelper.safeGetOrThrow<AnalyticsService>(
        context,
        listen: false,
      );
      unawaited(
        analyticsService.logCustomEvent(
          'room_code_shared',
          parameters: {
            'roomId': roomCode,
            'method': 'native_share',
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        ErrorHandler.showSnackBar(
          context,
          ErrorHandler.getLocalizedErrorMessage(e, context),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // Video background
          // Background
          Container(
            color: colors.background,
          ),

          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Semantics(
                        label:
                            AppLocalizations.of(context)?.backButton ?? 'Back',
                        button: true,
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed: () => NavigationHelper.safePop(context),
                          tooltip: AppLocalizations.of(context)?.backButton ??
                              'Back',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _mode == MultiplayerMode.battleRoyale
                              ? 'NERD BATTLE ROYALE'
                              : 'NERD SQUAD SHOWDOWN',
                          style: AppTypography.headlineLarge.copyWith(
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: _roomCode == null
                      ? _buildCreateOrJoin()
                      : _buildRoomLobby(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateOrJoin() {
    final createColors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Create Room
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppShadows.medium,
            ),
            child: Column(
              children: [
                Text(
                  'Create Room',
                  style: AppTypography.headlineLarge.copyWith(
                    color: createColors.primaryText,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isCreating ? null : _createRoom,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: createColors.primaryButton,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isCreating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Create',
                          style: AppTypography.labelLarge.copyWith(
                            color: Colors.white,
                          ),
                        ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Join Room
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppShadows.medium,
            ),
            child: Column(
              children: [
                Text(
                  'Join Room',
                  style: AppTypography.headlineLarge.copyWith(
                    color: createColors.primaryText,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _roomCodeController,
                  decoration: InputDecoration(
                    labelText: 'Room Code',
                    hintText: 'Enter room code',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isJoining ? null : _joinRoom,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: createColors.primaryButton,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isJoining
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Join',
                          style: AppTypography.labelLarge.copyWith(
                            color: Colors.white,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomLobby() {
    final lobbyColors = AppColors.of(context);
    return Consumer<MultiplayerService>(
      builder: (context, multiplayerService, _) {
        final room = multiplayerService.currentRoom;
        if (room == null) {
          return const Center(child: Text('Room not found'));
        }

        final isHost = room.hostId == multiplayerService.currentUserId;
        final allReady = room.canStart;

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Room Code
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppShadows.medium,
                ),
                child: Column(
                  children: [
                    Text(
                      'Room Code',
                      style: AppTypography.bodyMedium.copyWith(
                        color: lobbyColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      room.id.toUpperCase(),
                      style: AppTypography.playfairDisplay(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: lobbyColors.primaryButton,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Share Code Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _shareRoomCode(room.id),
                          icon: const Icon(Icons.share),
                          label: const Text(
                            'Share',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: lobbyColors.primaryButton,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Friend Invite Section (Host only)
              if (isHost)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppShadows.medium,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invite Friends',
                        style: AppTypography.headlineLarge.copyWith(
                          fontSize: 18,
                          color: lobbyColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _showFriendInviteDialog,
                              icon: const Icon(Icons.person_add),
                              label: const Text(
                                'Friends List',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: lobbyColors.primaryButton,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _shareRoomCode(room.id),
                              icon: const Icon(Icons.share),
                              label: const Text(
                                'Share Code',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: lobbyColors.primaryButton
                                    .withValues(alpha: 0.7),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_invitedFriends.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _invitedFriends.map((friend) {
                            return Chip(
                              label: Text(
                                friend.displayName ??
                                    friend.email?.split('@').first ??
                                    'Unknown',
                              ),
                              onDeleted: () => _cancelInvite(friend.userId),
                              deleteIcon: const Icon(Icons.cancel, size: 18),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // Players List
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppShadows.medium,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Players (${room.players.length}/${room.maxPlayers})',
                        style: AppTypography.headlineLarge.copyWith(
                          fontSize: 20,
                          color: lobbyColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          itemCount: room.players.length,
                          itemBuilder: (context, index) {
                            final player = room.players[index];
                            final isCurrentUser = player.userId ==
                                multiplayerService.currentUserId;

                            // Check if player is a friend
                            final friendsService = ProviderHelper.safeGetOrThrow<FriendsService>(
                              context,
                              listen: false,
                            );
                            final isFriend = friendsService.friends
                                .any((f) => f.userId == player.userId);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isCurrentUser
                                    ? lobbyColors.primaryButton.withValues(
                                        alpha: 0.1,
                                      )
                                    : lobbyColors.cardBackgroundAlt,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isCurrentUser
                                      ? lobbyColors.primaryButton
                                      : lobbyColors.borderLight,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    player.isReady
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color: player.isReady
                                        ? AppColors.success
                                        : lobbyColors.tertiaryText,
                                  ),
                                  const SizedBox(width: 12),
                                  if (isFriend && !isCurrentUser)
                                    const Icon(
                                      Icons.favorite,
                                      color: Colors.red,
                                      size: 16,
                                    ),
                                  if (isFriend && !isCurrentUser)
                                    const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      player.displayName ??
                                          player.email.split('@').first,
                                      style: AppTypography.bodyLarge.copyWith(
                                        fontWeight: FontWeight.w500,
                                        color: lobbyColors.primaryText,
                                      ),
                                    ),
                                  ),
                                  if (player.userId == room.hostId)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: lobbyColors.primaryButton,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'HOST',
                                        style:
                                            AppTypography.labelSmall.copyWith(
                                          fontSize: 10,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  if (!isFriend &&
                                      !isCurrentUser &&
                                      player.userId != room.hostId)
                                    IconButton(
                                      icon: const Icon(Icons.person_add,
                                          size: 18,),
                                      onPressed: () =>
                                          _addFriendFromLobby(player.userId),
                                      tooltip: 'Add Friend',
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Game Mode Selection (Host only)
              if (isHost && _selectedGameMode == null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppShadows.medium,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Game Mode',
                        style: AppTypography.headlineLarge.copyWith(
                          fontSize: 18,
                          color: lobbyColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildGameModeOption(
                        context,
                        'classic',
                        'Classic',
                        '10s memorize, 20s play',
                      ),
                      const SizedBox(height: 8),
                      _buildGameModeOption(
                        context,
                        'speed',
                        'Speed',
                        '0s memorize, 7s play',
                      ),
                      const SizedBox(height: 8),
                      _buildGameModeOption(
                        context,
                        'regular',
                        'Regular',
                        '0s memorize, 15s play',
                      ),
                      const SizedBox(height: 8),
                      _buildGameModeOption(
                        context,
                        'shuffle',
                        'Shuffle',
                        'Tiles shuffle during play',
                      ),
                    ],
                  ),
                ),

              if (isHost &&
                  _selectedGameMode == 'shuffle' &&
                  _selectedDifficulty == null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppShadows.medium,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Difficulty',
                        style: AppTypography.headlineLarge.copyWith(
                          fontSize: 18,
                          color: lobbyColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDifficultyOption(
                        context,
                        'easy',
                        'Easy',
                        'Slow shuffles',
                      ),
                      const SizedBox(height: 8),
                      _buildDifficultyOption(
                        context,
                        'medium',
                        'Medium',
                        'Moderate shuffles',
                      ),
                      const SizedBox(height: 8),
                      _buildDifficultyOption(
                        context,
                        'hard',
                        'Hard',
                        'Fast shuffles',
                      ),
                      const SizedBox(height: 8),
                      _buildDifficultyOption(
                        context,
                        'insane',
                        'Insane',
                        'Chaos mode',
                      ),
                    ],
                  ),
                ),

              if (isHost && _selectedGameMode != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: lobbyColors.primaryButton.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: lobbyColors.primaryButton),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selected: ${_selectedGameMode!.toUpperCase()}',
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: lobbyColors.primaryButton,
                              ),
                            ),
                            if (_selectedDifficulty != null)
                              Text(
                                'Difficulty: ${_selectedDifficulty!.toUpperCase()}',
                                style: AppTypography.labelSmall.copyWith(
                                  color: lobbyColors.secondaryText,
                                ),
                              ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedGameMode = null;
                            _selectedDifficulty = null;
                          });
                        },
                        child: Text(
                          'Change',
                          style: AppTypography.bodyMedium.copyWith(
                            color: lobbyColors.primaryButton,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Ready Button / Start Button
              if (!isHost)
                SizedBox(
                  width: double.infinity,
                  child: Builder(
                    builder: (context) {
                      // CRITICAL: Safely get current player with defensive checks
                      // Check players list is not empty before accessing first element
                      if (room.players.isEmpty) {
                        return ElevatedButton(
                          onPressed: null, // Disable if no players
                          style: ElevatedButton.styleFrom(
                            backgroundColor: lobbyColors.primaryButton,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Ready',
                            style: AppTypography.labelLarge.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        );
                      }

                      // Safe to access - we've checked isEmpty above
                      final currentPlayer = room.players.firstWhere(
                        (p) => p.userId == multiplayerService.currentUserId,
                        orElse: () =>
                            room.players.first, // Safe - checked isEmpty
                      );
                      final isReady = currentPlayer.isReady;

                      return ElevatedButton(
                        onPressed: () async {
                          await multiplayerService.setPlayerReady(!isReady);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isReady
                              ? AppColors.secondaryButton
                              : lobbyColors.primaryButton,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          isReady ? 'Not Ready' : 'Ready',
                          style: AppTypography.labelLarge.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                ),

              if (isHost)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: allReady
                        ? () async {
                            final messenger = ScaffoldMessenger.of(context);
                            if (_selectedGameMode == null) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Please select a game mode'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }
                            // Get analytics service before async operation
                            final analyticsService =
                                ProviderHelper.safeGetOrThrow<AnalyticsService>(
                              context,
                              listen: false,
                            );
                            try {
                              await multiplayerService.startGame(
                                gameMode: _selectedGameMode,
                                difficulty: _selectedDifficulty,
                              );
                              // Log analytics (fire-and-forget)
                              unawaited(analyticsService.logGameStart());
                              if (!mounted) return;
                              final navigatorContext = context;
                              if (!navigatorContext.mounted) return;
                              unawaited(NavigationHelper.safeNavigate(
                                navigatorContext,
                                '/multiplayer-game',
                                replace: true,
                              ),);
                            } catch (e) {
                              if (!mounted) return;
                              // Log error to analytics (use technical error)
                              unawaited(analyticsService.logError(
                                'multiplayer_game_start_failed',
                                e.toString().replaceAll('Exception: ', ''),
                              ),);
                              // Show localized error to user
                              ErrorHandler.showSnackBar(
                                context,
                                null,
                                error: e,
                              );
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: allReady
                          ? lobbyColors.primaryButton
                          : lobbyColors.tertiaryText,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      allReady ? 'Start Game' : 'Waiting for players...',
                      style: AppTypography.labelLarge.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGameModeOption(
    BuildContext context,
    String value,
    String title,
    String description,
  ) {
    final optionColors = AppColors.of(context);
    return InkWell(
      onTap: () {
        setState(() {
          _selectedGameMode = value;
          if (value != 'shuffle') {
            _selectedDifficulty = null;
          }
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _selectedGameMode == value
              ? optionColors.primaryButton.withValues(alpha: 0.1)
              : optionColors.cardBackgroundAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _selectedGameMode == value
                ? optionColors.primaryButton
                : optionColors.borderLight,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _selectedGameMode == value
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: _selectedGameMode == value
                  ? optionColors.primaryButton
                  : optionColors.tertiaryText,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: optionColors.primaryText,
                    ),
                  ),
                  Text(
                    description,
                    style: AppTypography.labelSmall.copyWith(
                      color: optionColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyOption(
    BuildContext context,
    String value,
    String title,
    String description,
  ) {
    final difficultyColors = AppColors.of(context);
    return InkWell(
      onTap: () {
        setState(() {
          _selectedDifficulty = value;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _selectedDifficulty == value
              ? difficultyColors.primaryButton.withValues(alpha: 0.1)
              : difficultyColors.cardBackgroundAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _selectedDifficulty == value
                ? difficultyColors.primaryButton
                : difficultyColors.borderLight,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _selectedDifficulty == value
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: _selectedDifficulty == value
                  ? difficultyColors.primaryButton
                  : difficultyColors.tertiaryText,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: difficultyColors.primaryText,
                    ),
                  ),
                  Text(
                    description,
                    style: AppTypography.labelSmall.copyWith(
                      color: difficultyColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}