import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/widgets/video_player_widget.dart';
import 'package:n3rd_game/models/game_room.dart';
import 'package:n3rd_game/services/multiplayer_service.dart';
import 'package:n3rd_game/services/network_service.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_shadows.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';

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

  @override
  void initState() {
    super.initState();
    // Check if user has online access
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final subscriptionService = Provider.of<SubscriptionService>(
        context,
        listen: false,
      );
      if (!subscriptionService.hasOnlineAccess) {
        _showUpgradeDialog(context);
        return;
      }
    });
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is MultiplayerMode) {
      _mode = args;
    }
  }

  void _showUpgradeDialog(BuildContext context) {
    final analyticsService = Provider.of<AnalyticsService>(
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Multiplayer - Premium Feature'),
        content: const Text(
          'Upgrade to Premium to access multiplayer features!',
        ),
        actions: [
          TextButton(
            onPressed: () {
              analyticsService.logUpgradeDialogDismissed(
                source: 'multiplayer',
                targetTier: 'premium',
              );
              NavigationHelper.safePop(dialogContext);
              NavigationHelper.safePop(dialogContext); // Go back
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              analyticsService.logConversionFunnelStep(
                step: 3,
                stepName: 'subscription_screen_opened',
                source: 'multiplayer',
                targetTier: 'premium',
              );
              NavigationHelper.safePop(dialogContext);
              NavigationHelper.safePop(dialogContext); // Go back
              NavigationHelper.safeNavigate(
                dialogContext,
                '/subscription-management',
              );
            },
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
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
    final networkService = Provider.of<NetworkService>(context, listen: false);
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
      final multiplayerService = Provider.of<MultiplayerService>(
        context,
        listen: false,
      );
      final analyticsService = Provider.of<AnalyticsService>(
        context,
        listen: false,
      );
      await multiplayerService.init();

      final maxPlayers = _mode == MultiplayerMode.battleRoyale ? 4 : 6;
      final room = await multiplayerService.createRoom(
        mode: _mode!,
        maxPlayers: maxPlayers,
      );

      // Log analytics (fire-and-forget)
      unawaited(analyticsService.logRoomCreated());

      if (mounted) {
        setState(() {
          _roomCode = room.id;
          _isCreating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        final errorMessage = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating room: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        // Log error to analytics
        final analyticsService = Provider.of<AnalyticsService>(
          context,
          listen: false,
        );
        analyticsService.logError('room_creation_failed', errorMessage);
      }
    }
  }

  Future<void> _joinRoom() async {
    final roomCode = _roomCodeController.text.trim();
    if (roomCode.isEmpty) return;

    // Check network connection
    final networkService = Provider.of<NetworkService>(context, listen: false);
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
      final multiplayerService = Provider.of<MultiplayerService>(
        context,
        listen: false,
      );
      // Get analytics service before async operations
      final analyticsService = Provider.of<AnalyticsService>(
        context,
        listen: false,
      );
      await multiplayerService.init();

      await multiplayerService.joinRoom(roomCode);

      // Log analytics (fire-and-forget)
      unawaited(analyticsService.logRoomJoined());

      if (mounted) {
        NavigationHelper.safeNavigate(
          context,
          '/multiplayer-game',
          replace: true,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isJoining = false);
        final errorMessage = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error joining room: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        // Log error to analytics
        final analyticsService = Provider.of<AnalyticsService>(
          context,
          listen: false,
        );
        analyticsService.logError('room_join_failed', errorMessage);
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
          // Video background - fills entire screen perfectly
          const VideoPlayerWidget(
            videoPath: 'assets/videos/mode_selection_video.mp4',
            loop: true,
            autoplay: true,
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
                          tooltip:
                              AppLocalizations.of(context)?.backButton ??
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
                            final isCurrentUser =
                                player.userId ==
                                multiplayerService.currentUserId;
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
                                        style: AppTypography.labelSmall
                                            .copyWith(
                                              fontSize: 10,
                                              color: Colors.white,
                                            ),
                                      ),
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
                        orElse: () => room.players.first, // Safe - checked isEmpty
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
                                Provider.of<AnalyticsService>(
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
                              NavigationHelper.safeNavigate(
                                navigatorContext,
                                '/multiplayer-game',
                                replace: true,
                              );
                            } catch (e) {
                              if (!mounted) return;
                              final errorMessage = e.toString().replaceAll(
                                'Exception: ',
                                '',
                              );
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Error starting game: $errorMessage',
                                  ),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                              // Log error to analytics
                              analyticsService.logError(
                                'game_start_failed',
                                errorMessage,
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
