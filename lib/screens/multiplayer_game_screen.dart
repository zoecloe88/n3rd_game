import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/services/network_service.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/models/game_room.dart';
import 'package:n3rd_game/services/multiplayer_service.dart';
import 'package:n3rd_game/services/chat_service.dart';
import 'package:n3rd_game/services/voice_chat_service.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/services/game_service.dart';
import 'package:n3rd_game/services/trivia_generator_service.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';

class MultiplayerGameScreen extends StatefulWidget {
  const MultiplayerGameScreen({super.key});

  @override
  State<MultiplayerGameScreen> createState() => _MultiplayerGameScreenState();
}

class _MultiplayerGameScreenState extends State<MultiplayerGameScreen>
    with WidgetsBindingObserver {
  bool _showChat = false;
  final _chatController = TextEditingController();
  final _chatScrollController = ScrollController();

  // Pending submission tracking for retry logic
  Map<String, dynamic>? _pendingSubmission;
  bool _isRetryingSubmission = false;
  static const String _pendingSubmissionKey = 'multiplayer_pending_submission';
  static const String _pendingSubmissionRoomKey =
      'multiplayer_pending_submission_room';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // CRITICAL: Check subscription access before initializing game
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final subscriptionService = Provider.of<SubscriptionService>(
        context,
        listen: false,
      );
      if (!subscriptionService.hasOnlineAccess) {
        // User doesn't have online access - show upgrade dialog and navigate back
        _showUpgradeDialogAndNavigateBack();
        return;
      }
      _setupNetworkListener();
      _loadPendingSubmission();
      _initializeGame();
    });
  }

  void _showUpgradeDialogAndNavigateBack() {
    final analyticsService = Provider.of<AnalyticsService>(
      context,
      listen: false,
    );

    analyticsService.logUpgradeDialogShown(
      source: 'multiplayer_game',
      targetTier: 'premium',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Premium Feature'),
        content: const Text(
          'Multiplayer games are available for Premium subscribers. '
          'Upgrade to access online multiplayer features!',
        ),
        actions: [
          TextButton(
            onPressed: () {
              analyticsService.logUpgradeDialogDismissed(
                source: 'multiplayer_game',
                targetTier: 'premium',
              );
              NavigationHelper.safePop(dialogContext);
              NavigationHelper.safePop(context); // Go back to previous screen
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              analyticsService.logConversionFunnelStep(
                step: 3,
                stepName: 'subscription_screen_opened',
                source: 'multiplayer_game',
                targetTier: 'premium',
              );
              NavigationHelper.safePop(dialogContext);
              NavigationHelper.safePop(context); // Go back
              NavigationHelper.safeNavigate(
                  context, '/subscription-management',);
            },
            child: const Text('Upgrade to Premium'),
          ),
        ],
      ),
    );
  }

  /// Load pending submission from persistent storage
  Future<void> _loadPendingSubmission() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final submissionJson = prefs.getString(_pendingSubmissionKey);
      final roomId = prefs.getString(_pendingSubmissionRoomKey);

      if (submissionJson != null && roomId != null) {
        final submission = jsonDecode(submissionJson) as Map<String, dynamic>;

        // Verify we're still in the same room before restoring
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          final multiplayerService = Provider.of<MultiplayerService>(
            context,
            listen: false,
          );

          final currentRoom = multiplayerService.currentRoom;
          if (currentRoom != null && currentRoom.id == roomId) {
            // Same room - restore pending submission
            _pendingSubmission = submission;

            // Try to retry if network is available
            final networkService = Provider.of<NetworkService>(
              context,
              listen: false,
            );
            if (networkService.hasInternetReachability &&
                !_isRetryingSubmission) {
              await _retryPendingSubmission();
            }
          } else {
            // Different room or no room - clear stale submission
            await _clearPendingSubmission();
          }
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to load pending submission: $e');
      }
      // Clear corrupted data
      await _clearPendingSubmission();
    }
  }

  /// Save pending submission to persistent storage
  Future<void> _savePendingSubmission(String roomId) async {
    if (_pendingSubmission == null) {
      await _clearPendingSubmission();
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _pendingSubmissionKey,
        jsonEncode(_pendingSubmission),
      );
      await prefs.setString(_pendingSubmissionRoomKey, roomId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to save pending submission: $e');
      }
    }
  }

  /// Clear pending submission from persistent storage
  Future<void> _clearPendingSubmission() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingSubmissionKey);
      await prefs.remove(_pendingSubmissionRoomKey);
      _pendingSubmission = null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to clear pending submission: $e');
      }
    }
  }

  /// Setup network listener to automatically retry pending submissions when network returns
  void _setupNetworkListener() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final networkService = Provider.of<NetworkService>(
        context,
        listen: false,
      );

      // Listen to network changes via connectivity stream
      // NetworkService extends ChangeNotifier, so we can listen to it
      networkService.addListener(_onNetworkChanged);
    });
  }

  /// Handle network state changes
  void _onNetworkChanged() {
    if (!mounted) return;

    final networkService = Provider.of<NetworkService>(context, listen: false);
    if (networkService.hasInternetReachability &&
        _pendingSubmission != null &&
        !_isRetryingSubmission) {
      // Network restored - automatically retry pending submission
      _retryPendingSubmission();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted) return;

    final networkService = Provider.of<NetworkService>(context, listen: false);

    // Handle app backgrounding/foregrounding for multiplayer
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App is backgrounded - player activity is tracked via lastActive timestamp
      // No explicit action needed as lastActive is updated on room operations
    } else if (state == AppLifecycleState.resumed) {
      // App is foregrounded - check network and reconnect if needed
      if (!networkService.isConnected) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No internet connection. Reconnecting...'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else if (_pendingSubmission != null) {
        // Network restored - automatically retry pending submission
        _retryPendingSubmission();
      }
      // Player activity is automatically updated on next room operation
    }
  }

  /// Retry pending submission when network is restored
  Future<void> _retryPendingSubmission() async {
    if (_pendingSubmission == null || _isRetryingSubmission) return;

    _isRetryingSubmission = true;
    final messenger = ScaffoldMessenger.of(context);

    try {
      final multiplayerService = Provider.of<MultiplayerService>(
        context,
        listen: false,
      );
      final networkService = Provider.of<NetworkService>(
        context,
        listen: false,
      );

      // Verify we're still in a room before retrying
      final currentRoom = multiplayerService.currentRoom;
      if (currentRoom == null) {
        // No longer in a room - clear pending submission
        await _clearPendingSubmission();
        return;
      }

      // Verify room ID matches (prevent submitting to wrong room)
      final prefs = await SharedPreferences.getInstance();
      final savedRoomId = prefs.getString(_pendingSubmissionRoomKey);
      if (savedRoomId != null && savedRoomId != currentRoom.id) {
        // Different room - clear stale submission
        await _clearPendingSubmission();
        return;
      }

      // Check network before retry
      if (!networkService.hasInternetReachability) {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                'No internet connection. Please check your network.',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Retrying submission...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      }

      await multiplayerService.submitRoundAnswer(
        score: _pendingSubmission!['score'] as int,
        correctAnswers: _pendingSubmission!['correctAnswers'] as int,
        wrongAnswers: _pendingSubmission!['wrongAnswers'] as int,
      );

      // Success - clear pending submission from memory and storage
      await _clearPendingSubmission();

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Answer submitted successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Retry failed: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _retryPendingSubmission(),
            ),
          ),
        );
      }
    } finally {
      _isRetryingSubmission = false;
    }
  }

  void _initializeGame() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final multiplayerService = Provider.of<MultiplayerService>(
        context,
        listen: false,
      );
      final chatService = Provider.of<ChatService>(context, listen: false);
      final voiceChatService = Provider.of<VoiceChatService>(
        context,
        listen: false,
      );
      final gameService = Provider.of<GameService>(context, listen: false);
      final generator = Provider.of<TriviaGeneratorService>(
        context,
        listen: false,
      );

      final room = multiplayerService.currentRoom;
      if (room == null) {
        NavigationHelper.safePop(context);
        return;
      }

      // CRITICAL: Validate player membership for security (defense in depth)
      final userId = multiplayerService.currentUserId;
      if (userId != null) {
        final isValidMember = await multiplayerService.validatePlayerMembership(
          room.id,
          userId,
        );
        if (!isValidMember) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'You are not a member of this room. Returning to lobby.',
                ),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
            NavigationHelper.safePop(context);
          }
          return;
        }
      }

      // Start listening to chat
      chatService.startListening(room.id);

      // Initialize and join voice chat
      try {
        await voiceChatService.init();
        await voiceChatService.joinChannel(room.id);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Voice chat initialization failed: $e');
        }
        // Show user-friendly error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Voice chat unavailable. You can still play and use text chat.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        // Continue without voice chat
      }

      // Generate trivia pool for multiplayer (basic tier - uses generator)
      final triviaPool = gameService.generateTriviaPool(generator, count: 50);

      // Initialize game if it's the current player's turn (battle royale)
      if (room.mode == MultiplayerMode.battleRoyale) {
        if (room.currentPlayerId == multiplayerService.currentUserId) {
          gameService.startNewRound(
            triviaPool,
            mode: _getGameModeFromString(room.selectedGameMode),
            difficulty: room.selectedDifficulty,
          );
        }
      } else {
        // Squad showdown - all players play simultaneously
        gameService.startNewRound(
          triviaPool,
          mode: _getGameModeFromString(room.selectedGameMode),
          difficulty: room.selectedDifficulty,
        );
      }
    });
  }

  GameMode _getGameModeFromString(String? modeString) {
    if (modeString == null) return GameMode.classic;
    try {
      return GameMode.values.firstWhere(
        (m) => m.name == modeString.toLowerCase(),
      );
    } catch (e) {
      return GameMode.classic;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final networkService = Provider.of<NetworkService>(context, listen: false);
    networkService.removeListener(_onNetworkChanged);

    // If leaving the room, check if we should clear pending submission
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final multiplayerService = Provider.of<MultiplayerService>(
        context,
        listen: false,
      );
      final currentRoom = multiplayerService.currentRoom;

      // If no longer in a room, clear pending submission (user left the game)
      if (currentRoom == null && _pendingSubmission != null) {
        await _clearPendingSubmission();
      }
    });

    _chatController.dispose();
    _chatScrollController.dispose();
    // Leave voice chat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final voiceChatService = Provider.of<VoiceChatService>(
        context,
        listen: false,
      );
      voiceChatService.leaveChannel();
    });
    super.dispose();
  }

  Future<void> _submitAnswer() async {
    final gameService = Provider.of<GameService>(context, listen: false);
    final multiplayerService = Provider.of<MultiplayerService>(
      context,
      listen: false,
    );
    final networkService = Provider.of<NetworkService>(context, listen: false);
    final room = multiplayerService.currentRoom;

    if (room == null || gameService.currentTrivia == null) return;
    final messenger = ScaffoldMessenger.of(context);

    // Submit answer to game service (for immediate UI feedback)
    gameService.submitAnswers();

    // Calculate score
    final correct = gameService.correctCount;
    final score = correct * 10; // 10 points per correct answer

    // Store submission data for retry if needed
    final submissionData = {
      'score': score,
      'correctAnswers': correct,
      'wrongAnswers': 3 - correct,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Submit to multiplayer service with retry logic
    bool submissionSuccess = false;
    int retryCount = 0;
    const maxRetries = 3;
    const baseDelay = Duration(seconds: 2);

    while (!submissionSuccess && retryCount < maxRetries) {
      try {
        // Check network before attempting submission
        if (!networkService.hasInternetReachability) {
          throw NetworkException('No internet connection available');
        }

        await multiplayerService.submitRoundAnswer(
          score: submissionData['score'] as int,
          correctAnswers: submissionData['correctAnswers'] as int,
          wrongAnswers: submissionData['wrongAnswers'] as int,
        );

        // Success - clear pending submission from memory and storage
        await _clearPendingSubmission();
        submissionSuccess = true;

        if (retryCount > 0 && mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Answer submitted successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        retryCount++;

        if (retryCount < maxRetries) {
          // Exponential backoff: 2s, 4s, 8s
          final delay = Duration(
            milliseconds: baseDelay.inMilliseconds * (1 << (retryCount - 1)),
          );

          if (mounted) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  'Submission failed. Retrying... ($retryCount/$maxRetries)',
                ),
                backgroundColor: Colors.orange,
                duration: delay,
              ),
            );
          }

          await Future.delayed(delay);
        } else {
          // All retries failed - store as pending submission
          _pendingSubmission = submissionData;

          // Persist pending submission for recovery (room is guaranteed non-null due to early return check)
          await _savePendingSubmission(room.id);

          if (mounted) {
            messenger.showSnackBar(
              SnackBar(
                content: const Text(
                  'Failed to submit answer. Tap to retry when connection is restored.',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: () => _retryPendingSubmission(),
                ),
              ),
            );

            final analyticsService = Provider.of<AnalyticsService>(
              context,
              listen: false,
            );
            analyticsService.logError(
              'answer_submission_failed_after_retries',
              e.toString(),
            );
          }
          return;
        }
      }
    }

    // For battle royale, host advances round after all players submit
    // For squad showdown, show results and auto-advance
    if (room.mode == MultiplayerMode.squadShowdown) {
      // Show results for a few seconds, then next round
      await Future.delayed(const Duration(seconds: 3));

      // CRITICAL: Re-fetch room state to prevent race conditions
      // Multiple players may submit simultaneously, so we need the latest state
      final updatedRoom = multiplayerService.currentRoom;
      if (updatedRoom == null || !mounted) return;

      // Double-check we haven't exceeded total rounds (defensive check)
      if (updatedRoom.currentRound >= updatedRoom.totalRounds) {
        return; // Game finished, no need to advance
      }

      // Only host advances the round to prevent race conditions
      // This ensures atomic round advancement even if multiple players submit simultaneously
      if (updatedRoom.hostId == multiplayerService.currentUserId) {
        try {
          // Use transaction-based round advancement (handled in MultiplayerService)
          await multiplayerService.nextRound();

          // Wait for room update to propagate to all clients
          // This ensures all players see the same round state
          await Future.delayed(const Duration(milliseconds: 500));

          // Re-fetch room state after round advancement
          final newRoom = multiplayerService.currentRoom;
          if (newRoom != null &&
              newRoom.currentRound <= newRoom.totalRounds &&
              mounted) {
            final generator = Provider.of<TriviaGeneratorService>(
              context,
              listen: false,
            );
            final triviaPool = gameService.generateTriviaPool(
              generator,
              count: 50,
            );
            gameService.startNewRound(
              triviaPool,
              mode: _getGameModeFromString(newRoom.selectedGameMode),
              difficulty: newRoom.selectedDifficulty,
            );
          }
        } catch (e) {
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  'Error advancing round: ${e.toString().replaceAll('Exception: ', '')}',
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          // Log error for debugging
          if (mounted) {
            final analyticsService = Provider.of<AnalyticsService>(
              context,
              listen: false,
            );
            analyticsService.logError('round_advancement_failed', e.toString());
          }
          return;
        }
      } else {
        // Non-host players wait for room update from host
        // The room listener will trigger a rebuild when round advances
        // This prevents non-hosts from trying to start rounds prematurely
      }
    } else {
      // Battle royale - wait for host to advance round
      // Show waiting message
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _sendChatMessage() async {
    final message = _chatController.text.trim();
    if (message.isEmpty) return;

    final chatService = Provider.of<ChatService>(context, listen: false);
    await chatService.sendMessage(message);
    _chatController.clear();

    // Scroll to bottom
    if (mounted && _chatScrollController.hasClients) {
      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // Background
          Container(
            color: AppColors.of(context).background,
          ),

          // Game content
          SafeArea(
            child: Consumer4<MultiplayerService, GameService, ChatService,
                NetworkService>(
              builder: (
                context,
                multiplayerService,
                gameService,
                chatService,
                networkService,
                _,
              ) {
                final room = multiplayerService.currentRoom;
                if (room == null) {
                  return const Center(
                    child: Text(
                      'Room not found',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }

                if (room.status == RoomStatus.finished) {
                  return _buildGameFinishedScreen(
                    room,
                    multiplayerService,
                  );
                }

                // Check if it's this player's turn (battle royale)
                if (room.mode == MultiplayerMode.battleRoyale) {
                  if (room.currentPlayerId !=
                      multiplayerService.currentUserId) {
                    return _buildWaitingScreen(
                      room,
                      multiplayerService,
                    );
                  }
                }

                // Show game if it's player's turn or squad showdown
                return Stack(
                  children: [
                    // Main game
                    Column(
                      children: [
                        _buildGameHeader(room, multiplayerService),
                        Expanded(
                          child: gameService.currentTrivia == null ||
                                  gameService.shuffledWords.isEmpty
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                )
                              : _buildGameContent(gameService, room),
                        ),
                      ],
                    ),

                    // Chat overlay
                    if (_showChat) _buildChatOverlay(chatService),

                    // Network status indicator
                    if (!networkService.isConnected)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          color: Colors.red,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.wifi_off,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'No Internet Connection',
                                style: AppTypography.labelSmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Ping button for Squad Showdown
                    if (room.mode == MultiplayerMode.squadShowdown)
                      Positioned(
                        bottom: AppSpacing.md,
                        right: AppSpacing.md,
                        child: FloatingActionButton(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(
                              context,
                            );
                            // Get analytics service before async operation
                            final analyticsService =
                                Provider.of<AnalyticsService>(
                              context,
                              listen: false,
                            );
                            try {
                              await multiplayerService.sendPing();
                              // Log analytics (fire-and-forget)
                              unawaited(analyticsService.logPingSent());
                              if (!mounted) return;
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Ping sent!'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Error sending ping: ${e.toString().replaceAll('Exception: ', '')}',
                                  ),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          backgroundColor: AppColors.of(
                            context,
                          ).primaryButton,
                          tooltip: 'Send Ping',
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameHeader(
    GameRoom room,
    MultiplayerService multiplayerService,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Semantics(
            label: AppLocalizations.of(context)?.leaveRoom ?? 'Leave Room',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () async {
                await multiplayerService.leaveRoom();
                if (mounted) {
                  NavigationHelper.safePop(context);
                }
              },
              tooltip: AppLocalizations.of(context)?.leaveRoom ?? 'Leave Room',
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.mode == MultiplayerMode.battleRoyale
                      ? 'NERD BATTLE ROYALE'
                      : 'NERD SQUAD SHOWDOWN',
                  style: AppTypography.headlineLarge.copyWith(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Round ${room.currentRound}/${room.totalRounds}',
                  style: AppTypography.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          // Voice Chat Controls
          Consumer<VoiceChatService>(
            builder: (context, voiceChatService, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    label: voiceChatService.isMuted
                        ? 'Unmute microphone'
                        : 'Mute microphone',
                    button: true,
                    child: IconButton(
                      icon: Icon(
                        voiceChatService.isMuted ? Icons.mic_off : Icons.mic,
                        color: voiceChatService.isMuted
                            ? Colors.red
                            : Colors.white,
                      ),
                      onPressed: () => voiceChatService.toggleMute(),
                      tooltip: voiceChatService.isMuted ? 'Unmute' : 'Mute',
                    ),
                  ),
                  Semantics(
                    label: _showChat ? 'Hide chat' : 'Show chat',
                    button: true,
                    child: IconButton(
                      icon: Icon(
                        _showChat
                            ? Icons.chat_bubble
                            : Icons.chat_bubble_outline,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _showChat = !_showChat;
                        });
                      },
                      tooltip: _showChat ? 'Hide Chat' : 'Show Chat',
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGameContent(GameService service, GameRoom room) {
    return Column(
      children: [
        if (service.phase != GamePhase.memorize) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              service.currentTrivia?.category ?? '',
              style: AppTypography.headlineLarge.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            itemCount: service.shuffledWords.length,
            itemBuilder: (context, index) {
              final word = service.shuffledWords[index];
              final isSelected = service.selectedAnswers.contains(word);
              final isCorrect =
                  service.currentTrivia?.correctAnswers.contains(word) ?? false;

              return InkWell(
                onTap: () => service.toggleTileSelection(word),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isCorrect ? AppColors.success : AppColors.error)
                        : Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Colors.white
                          : AppColors.of(context).borderLight,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      word,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : AppColors.of(context).primaryText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (service.phase == GamePhase.play && service.canSubmit) ...[
          ElevatedButton(
            onPressed: _submitAnswer,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.of(context).primaryButton,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxl,
                vertical: AppSpacing.md,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Submit',
              style: AppTypography.labelLarge.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }

  Widget _buildWaitingScreen(
    GameRoom room,
    MultiplayerService multiplayerService,
  ) {
    final currentPlayer = room.currentPlayer;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: AppSpacing.lg),
          Text(
            "Waiting for ${currentPlayer?.displayName ?? currentPlayer?.email.split('@').first ?? 'player'}...",
            style: AppTypography.bodyLarge.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Round ${room.currentRound}/${room.totalRounds}',
            style: AppTypography.bodyMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameFinishedScreen(
    GameRoom room,
    MultiplayerService multiplayerService,
  ) {
    // Sort players by score
    final sortedPlayers = List<Player>.from(room.players)
      ..sort((a, b) => b.score.compareTo(a.score));

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Text(
            'Game Finished!',
            style: AppTypography.displayMedium.copyWith(
              fontSize: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Expanded(
            child: ListView.builder(
              itemCount: sortedPlayers.length,
              itemBuilder: (context, index) {
                final player = sortedPlayers[index];
                final isCurrentUser =
                    player.userId == multiplayerService.currentUserId;
                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: isCurrentUser
                        ? AppColors.of(context).primaryButton
                        : Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${index + 1}',
                        style: AppTypography.playfairDisplay(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: isCurrentUser
                              ? Colors.white
                              : AppColors.of(context).primaryText,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          player.displayName ?? player.email.split('@').first,
                          style: AppTypography.bodyLarge.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: isCurrentUser
                                ? Colors.white
                                : AppColors.of(context).primaryText,
                          ),
                        ),
                      ),
                      Text(
                        '${player.score} pts',
                        style: AppTypography.bodyLarge.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isCurrentUser
                              ? Colors.white
                              : AppColors.of(context).primaryText,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await multiplayerService.leaveRoom();
              if (mounted) {
                NavigationHelper.safePop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.of(context).primaryButton,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxl,
                vertical: AppSpacing.md,
              ),
            ),
            child: Text(
              'Back to Menu',
              style: AppTypography.labelLarge.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatOverlay(ChatService chatService) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 300,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          ),
        ),
        child: Column(
          children: [
            // Chat header
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Chat',
                    style: AppTypography.labelLarge.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Semantics(
                    label: AppLocalizations.of(context)?.closeButton ??
                        'Close Chat',
                    button: true,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _showChat = false;
                        });
                      },
                      tooltip:
                          AppLocalizations.of(context)?.closeButton ?? 'Close',
                    ),
                  ),
                ],
              ),
            ),

            // Messages
            Expanded(
              child: ListView.builder(
                controller: _chatScrollController,
                padding: const EdgeInsets.all(AppSpacing.sm),
                itemCount: chatService.messages.length,
                itemBuilder: (context, index) {
                  final message = chatService.messages[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.userName,
                                style: AppTypography.labelSmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                message.message,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Input
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.white),
                        ),
                      ),
                      onSubmitted: (_) => _sendChatMessage(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Semantics(
                    label: AppLocalizations.of(context)?.sendMessage ??
                        'Send Message',
                    button: true,
                    enabled: _chatController.text.trim().isNotEmpty,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _chatController.text.trim().isNotEmpty
                          ? _sendChatMessage
                          : null,
                      tooltip:
                          AppLocalizations.of(context)?.sendMessage ?? 'Send',
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
