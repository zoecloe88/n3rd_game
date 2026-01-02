import 'dart:async';
import 'package:n3rd_game/utils/unawaited_helper.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/services/network_service.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/models/game_room.dart';
import 'package:n3rd_game/services/multiplayer_service.dart';
import 'package:n3rd_game/services/chat_service.dart';
import 'package:n3rd_game/services/voice_chat_service.dart';
import 'package:n3rd_game/services/live_video_service.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/services/friends_service.dart';
import 'package:n3rd_game/services/newsfeed_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/services/game_service.dart';
import 'package:n3rd_game/models/game_mode_config.dart';
import 'package:n3rd_game/services/trivia_generator_service.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/theme/app_radius.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/utils/feedback_helper.dart';
import 'package:n3rd_game/utils/list_helper.dart';
import 'package:n3rd_game/widgets/upgrade_dialog.dart';
import 'package:n3rd_game/utils/provider_helper.dart';
import 'package:n3rd_game/utils/subscription_guard.dart';
import 'package:n3rd_game/widgets/app_button.dart';
import 'package:n3rd_game/widgets/app_text_field.dart';
import 'package:n3rd_game/widgets/app_card.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';

class MultiplayerGameScreen extends StatefulWidget {
  const MultiplayerGameScreen({super.key});

  @override
  State<MultiplayerGameScreen> createState() => _MultiplayerGameScreenState();
}

class _MultiplayerGameScreenState extends State<MultiplayerGameScreen>
    with WidgetsBindingObserver {
  bool _showChat = false;
  bool _showVideo = false;
  final _chatController = TextEditingController();
  final _chatScrollController = ScrollController();
  RTCVideoRenderer? _localVideoRenderer;

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
      final subscriptionService = ProviderHelper.safeGetOrThrow<SubscriptionService>(
        context,
        listen: false,
      );
      // Use SubscriptionGuard for consistent access checking
      if (!SubscriptionGuard.canAccessFeature(
        subscriptionService: subscriptionService,
        requiresOnlineAccess: true,
      )) {
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
    final analyticsService = ProviderHelper.safeGetOrThrow<AnalyticsService>(
      context,
      listen: false,
    );

    analyticsService.logUpgradeDialogShown(
      source: 'multiplayer_game',
      targetTier: 'premium',
    );

    final localizations = AppLocalizations.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => UpgradeDialog(
        title: localizations?.premiumFeature ?? 'Premium Feature',
        message: localizations?.premiumFeatureDescription ??
            'Multiplayer games are available for Premium subscribers. '
                'Upgrade to access online multiplayer features!',
        targetTier: 'premium',
        source: 'multiplayer_game',
        features: [
          'Real-time multiplayer gameplay',
          'Battle Royale and Squad Showdown modes',
          'Play with friends and family',
          'Competitive leaderboards',
        ],
      ),
    ).then((_) {
      // Navigate back after dialog is dismissed
      NavigationHelper.safePop(context);
    });
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
          final multiplayerService = ProviderHelper.safeGetOrThrow<MultiplayerService>(
            context,
            listen: false,
          );

          final currentRoom = multiplayerService.currentRoom;
          if (currentRoom != null && currentRoom.id == roomId) {
            // Same room - restore pending submission
            _pendingSubmission = submission;

            // Try to retry if network is available
            final networkService = ProviderHelper.safeGetOrThrow<NetworkService>(
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
      LoggerService.error('Failed to load pending submission', error: e);
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
      LoggerService.error('Failed to save pending submission', error: e);
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
      LoggerService.error('Failed to clear pending submission', error: e);
    }
  }

  /// Setup network listener to automatically retry pending submissions when network returns
  void _setupNetworkListener() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final networkService = ProviderHelper.safeGetOrThrow<NetworkService>(
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

    final networkService = ProviderHelper.safeGetOrThrow<NetworkService>(context, listen: false);
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

    final networkService = ProviderHelper.safeGetOrThrow<NetworkService>(context, listen: false);

    // Handle app backgrounding/foregrounding for multiplayer
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App is backgrounded - player activity is tracked via lastActive timestamp
      // No explicit action needed as lastActive is updated on room operations
    } else if (state == AppLifecycleState.resumed) {
      // App is foregrounded - check network and reconnect if needed
      if (!networkService.isConnected) {
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          FeedbackHelper.showWarning(
            context,
            localizations?.noInternetReconnecting ??
                'No internet connection. Reconnecting...',
            duration: const Duration(seconds: 3),
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

    try {
      final multiplayerService = ProviderHelper.safeGetOrThrow<MultiplayerService>(
        context,
        listen: false,
      );
      final networkService = ProviderHelper.safeGetOrThrow<NetworkService>(
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
          FeedbackHelper.showError(
            context,
            'No internet connection. Please check your network.',
            duration: const Duration(seconds: 3),
          );
        }
        return;
      }

      if (mounted) {
        final localizations = AppLocalizations.of(context);
        FeedbackHelper.showInfo(
          context,
          localizations?.retryingSubmission ?? 'Retrying submission...',
          duration: const Duration(seconds: 2),
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
        final localizations = AppLocalizations.of(context);
        FeedbackHelper.showSuccess(
          context,
          localizations?.answerSubmittedSuccessfully ??
              'Answer submitted successfully!',
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (mounted) {
        final colors = AppColors.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.error,
                  color: colors.error,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)?.multiplayerRoundError ??
                        'Round operation failed. Please try again.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: colors.onDarkText,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: colors.cardBackground,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              textColor: colors.onDarkText,
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
      final multiplayerService = ProviderHelper.safeGetOrThrow<MultiplayerService>(
        context,
        listen: false,
      );
      final voiceChatService = ProviderHelper.safeGetOrThrow<VoiceChatService>(
        context,
        listen: false,
      );
      final gameService = ProviderHelper.safeGetOrThrow<GameService>(context, listen: false);
      // Safely get TriviaGeneratorService with fallback
      TriviaGeneratorService generator;
      try {
        generator = ProviderHelper.safeGetOrThrow<TriviaGeneratorService>(
          context,
          listen: false,
        );
      } catch (e) {
        LoggerService.warning(
          'TriviaGeneratorService not found in provider tree, creating fallback instance',
          error: e,
        );
        try {
          generator = TriviaGeneratorService();
        } catch (e2) {
          LoggerService.error('Failed to create TriviaGeneratorService fallback', error: e2);
          generator = TriviaGeneratorService.fallback();
        }
      }

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
            FeedbackHelper.showError(
              context,
              'You are not a member of this room. Returning to lobby.',
              duration: const Duration(seconds: 3),
            );
            NavigationHelper.safePop(context);
          }
          return;
        }
      }

      // Chat messages are accessed via StreamBuilder using getMessages()

      // Initialize and join voice chat
      try {
        await voiceChatService.init();
        await voiceChatService.joinChannel(room.id);
      } catch (e) {
        LoggerService.error('Voice chat initialization failed', error: e);
        // Show user-friendly error message
        if (mounted) {
          FeedbackHelper.showWarning(
            context,
            'Voice chat unavailable. You can still play and use text chat.',
            duration: const Duration(seconds: 3),
          );
        }
        // Continue without voice chat
      }

      // Initialize live video (if available for user's tier)
      await _initializeLiveVideo(room.id);
      if (!mounted) return;

      // Log game started activity
      final newsfeedService =
          ProviderHelper.safeGetOrThrow<NewsfeedService>(context, listen: false);
      unawaited(
        newsfeedService.logMultiplayerActivity(
          activityType: NewsfeedActivityType.multiplayerGameStarted,
          metadata: {
            'roomId': room.id,
            'mode': room.mode.name,
            'playerCount': room.players.length,
            'gameMode': room.selectedGameMode,
          },
        ),
      );

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

  Future<void> _initializeLiveVideo(String roomId) async {
    try {
      final liveVideoService = ProviderHelper.safeGetOrThrow<LiveVideoService>(
        context,
        listen: false,
      );
      final subscriptionService = ProviderHelper.safeGetOrThrow<SubscriptionService>(
        context,
        listen: false,
      );

      // Set subscription service for tier checking
      liveVideoService.setSubscriptionService(subscriptionService);

      // Check if user can use live video
      if (!liveVideoService.canUseLiveVideo()) {
        // Free tier - video not available, continue without it
        return;
      }

      // Initialize video service
      await liveVideoService.init();
      if (!mounted) return;

      // Get current participant count from room
      final multiplayerService = ProviderHelper.safeGetOrThrow<MultiplayerService>(
        context,
        listen: false,
      );
      final room = multiplayerService.currentRoom;
      final participantCount = room?.players.length ?? 0;

      // Join video session
      await liveVideoService.joinSession(roomId,
          currentParticipantCount: participantCount,);
      if (!mounted) return;

      // Log analytics
      final analyticsService = ProviderHelper.safeGetOrThrow<AnalyticsService>(
        context,
        listen: false,
      );
      unawaited(
        analyticsService.logCustomEvent(
          'live_video_enabled',
          parameters: {'roomId': roomId},
        ),
      );
    } catch (e) {
      LoggerService.warning(
        'Live video initialization failed, continuing without video',
        error: e,
      );
      // Continue without video - not critical for gameplay
    }
  }

  Future<void> _toggleVideo() async {
    try {
      final liveVideoService = ProviderHelper.safeGetOrThrow<LiveVideoService>(
        context,
        listen: false,
      );

      if (!liveVideoService.canUseLiveVideo()) {
        if (mounted) {
          FeedbackHelper.showWarning(
            context,
            'Live video is not available for your subscription tier.',
            duration: const Duration(seconds: 3),
          );
        }
        return;
      }

      if (!liveVideoService.isInSession) {
        // Initialize if not already in session
        final multiplayerService = ProviderHelper.safeGetOrThrow<MultiplayerService>(
          context,
          listen: false,
        );
        final room = multiplayerService.currentRoom;
        if (room != null) {
          await _initializeLiveVideo(room.id);
        }
      }

      if (mounted) {
        setState(() {
          _showVideo = !_showVideo;
        });
      }
    } catch (e) {
      LoggerService.warning('Failed to toggle video', error: e);
      if (mounted) {
        FeedbackHelper.showError(
          context,
          'Failed to toggle video',
          duration: const Duration(seconds: 2),
        );
      }
    }
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
    final networkService = ProviderHelper.safeGetOrThrow<NetworkService>(context, listen: false);
    networkService.removeListener(_onNetworkChanged);

    // If leaving the room, check if we should clear pending submission
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final multiplayerService = ProviderHelper.safeGetOrThrow<MultiplayerService>(
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
      final voiceChatService = ProviderHelper.safeGetOrThrow<VoiceChatService>(
        context,
        listen: false,
      );
      voiceChatService.leaveChannel();

      // Leave live video session
      try {
        final liveVideoService = ProviderHelper.safeGetOrThrow<LiveVideoService>(
          context,
          listen: false,
        );
        if (liveVideoService.isInSession) {
          liveVideoService.leaveSession();
        }
      } catch (e) {
        // Ignore errors during dispose
      }

      // Dispose video renderer
      _localVideoRenderer?.dispose();
      _localVideoRenderer = null;
    });
    super.dispose();
  }

  Future<void> _submitAnswer() async {
    final gameService = ProviderHelper.safeGetOrThrow<GameService>(context, listen: false);
    final multiplayerService = ProviderHelper.safeGetOrThrow<MultiplayerService>(
      context,
      listen: false,
    );
    final networkService = ProviderHelper.safeGetOrThrow<NetworkService>(context, listen: false);
    final room = multiplayerService.currentRoom;

    if (room == null || gameService.currentTrivia == null) return;

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
          final localizations = AppLocalizations.of(context);
          FeedbackHelper.showSuccess(
            context,
            localizations?.answerSubmittedSuccessfully ??
                'Answer submitted successfully!',
            duration: const Duration(seconds: 2),
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
            FeedbackHelper.showWarning(
              context,
              'Submission failed. Retrying... ($retryCount/$maxRetries)',
              duration: delay,
            );
          }

          await Future.delayed(delay);
        } else {
          // All retries failed - store as pending submission
          _pendingSubmission = submissionData;

          // Persist pending submission for recovery (room is guaranteed non-null due to early return check)
          await _savePendingSubmission(room.id);

          if (mounted) {
            final colors = AppColors.of(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(
                      Icons.error,
                      color: colors.error,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Failed to submit answer. Tap to retry when connection is restored.',
                        style: AppTypography.bodyMedium.copyWith(
                          color: colors.onDarkText,
                        ),
                      ),
                    ),
                  ],
                ),
                backgroundColor: colors.cardBackground,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'Retry',
                  textColor: colors.onDarkText,
                  onPressed: () => _retryPendingSubmission(),
                ),
              ),
            );

            final analyticsService = ProviderHelper.safeGetOrThrow<AnalyticsService>(
              context,
              listen: false,
            );
            unawaited(analyticsService.logError(
              'answer_submission_failed_after_retries',
              e.toString(),
            ),);
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
            // Safely get TriviaGeneratorService with fallback
            TriviaGeneratorService generator;
            try {
              generator = ProviderHelper.safeGetOrThrow<TriviaGeneratorService>(
                context,
                listen: false,
              );
            } catch (e) {
              LoggerService.warning(
                'TriviaGeneratorService not found in provider tree, creating fallback instance',
                error: e,
              );
              generator = TriviaGeneratorService();
            }
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
            FeedbackHelper.showWarning(
              context,
              AppLocalizations.of(context)?.multiplayerRoundError ??
                  'Round operation failed. Please try again.',
              duration: const Duration(seconds: 3),
            );
          }
          // Log error for debugging
          if (mounted) {
            final analyticsService = ProviderHelper.safeGetOrThrow<AnalyticsService>(
              context,
              listen: false,
            );
            unawaited(analyticsService.logError('round_advancement_failed', e.toString()));
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

    final chatService = ProviderHelper.safeGetOrThrow<ChatService>(context, listen: false);
    final multiplayerService = ProviderHelper.safeGetOrThrow<MultiplayerService>(context, listen: false);
    final room = multiplayerService.currentRoom;
    if (room != null) {
      await chatService.sendMessage(
        lobbyId: room.id,
        message: message,
      );
      _chatController.clear();
    }

    // Scroll to bottom
    if (mounted && _chatScrollController.hasClients) {
      unawaited(_chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      ),);
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
                  // Log game completed activity when screen is shown
                  final newsfeedService =
                      ProviderHelper.safeGetOrThrow<NewsfeedService>(context, listen: false);
                  final sortedPlayers = List<Player>.from(room.players)
                    ..sort((a, b) => b.score.compareTo(a.score));
                  final winner = ListHelper.safeFirst(sortedPlayers);
                  unawaited(
                    newsfeedService.logMultiplayerActivity(
                      activityType:
                          NewsfeedActivityType.multiplayerGameCompleted,
                      metadata: {
                        'roomId': room.id,
                        'mode': room.mode.name,
                        'playerCount': room.players.length,
                        'winner': winner?.userId,
                        'winnerScore': winner?.score,
                      },
                    ),
                  );

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

                    // Video overlay
                    if (_showVideo) _buildVideoOverlay(),

                    // Network status indicator
                    if (!networkService.isConnected)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          color: AppColors.of(context).error,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.wifi_off,
                                color: AppColors.of(context).onDarkText,
                                size: 16,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'No Internet Connection',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.of(context).onDarkText,
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
                        child: AppButton(
                          icon: Icons.location_on,
                          onPressed: () async {
                            // Get analytics service before async operation
                            final analyticsService =
                                ProviderHelper.safeGetOrThrow<AnalyticsService>(
                              context,
                              listen: false,
                            );
                            try {
                              await multiplayerService.sendPing();
                              // Log analytics (fire-and-forget)
                              unawaited(analyticsService.logPingSent());
                              if (!mounted || !context.mounted) return;
                              final localizations =
                                  AppLocalizations.of(context);
                              FeedbackHelper.showSuccess(
                                context,
                                localizations?.pingSent ?? 'Ping sent!',
                                duration: const Duration(seconds: 1),
                              );
                            } catch (e) {
                              if (!mounted || !context.mounted) return;
                              final localizations =
                                  AppLocalizations.of(context);
                              FeedbackHelper.showError(
                                context,
                                localizations?.multiplayerPingError ??
                                    'Failed to send ping. Please try again.',
                                duration: const Duration(seconds: 2),
                              );
                            }
                          },
                          variant: AppButtonVariant.icon,
                          backgroundColor: AppColors.of(context).primaryButton,
                          foregroundColor: Colors.white,
                          semanticsLabel: 'Send Ping',
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
          AppButton(
            icon: Icons.arrow_back,
            onPressed: () async {
              await multiplayerService.leaveRoom();
              if (mounted) {
                NavigationHelper.safePop(context);
              }
            },
            variant: AppButtonVariant.icon,
            semanticsLabel:
                AppLocalizations.of(context)?.leaveRoom ?? 'Leave Room',
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
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
                  AppButton(
                    icon: voiceChatService.isMuted ? Icons.mic_off : Icons.mic,
                    onPressed: () => voiceChatService.toggleMute(),
                    variant: AppButtonVariant.icon,
                    semanticsLabel: voiceChatService.isMuted
                        ? 'Unmute microphone'
                        : 'Mute microphone',
                    backgroundColor: Colors.transparent,
                    foregroundColor:
                        voiceChatService.isMuted ? Colors.red : Colors.white,
                  ),
                  AppButton(
                    icon: _showChat
                        ? Icons.chat_bubble
                        : Icons.chat_bubble_outline,
                    onPressed: () {
                      setState(() {
                        _showChat = !_showChat;
                      });
                    },
                    variant: AppButtonVariant.icon,
                    semanticsLabel: _showChat ? 'Hide chat' : 'Show chat',
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                  ),
                  // Video toggle button (only if user can use live video)
                  Consumer<LiveVideoService>(
                    builder: (context, liveVideoService, _) {
                      if (!liveVideoService.canUseLiveVideo()) {
                        return const SizedBox.shrink();
                      }
                      return AppButton(
                        icon: _showVideo ? Icons.videocam : Icons.videocam_off,
                        onPressed: _toggleVideo,
                        variant: AppButtonVariant.icon,
                        semanticsLabel:
                            _showVideo ? 'Hide video' : 'Show video',
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                      );
                    },
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
                    borderRadius: BorderRadius.circular(AppRadius.large),
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
          AppButton.primary(
            label: 'Submit',
            onPressed: _submitAnswer,
            isFullWidth: false,
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
                return AppCard(
                  variant: AppCardVariant.filled,
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  backgroundColor: isCurrentUser
                      ? AppColors.of(context).primaryButton
                      : Colors.white.withValues(alpha: 0.9),
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
          const SizedBox(height: AppSpacing.md),
          // Post-game actions
          _buildGameOverActions(room, multiplayerService, sortedPlayers),
          const SizedBox(height: AppSpacing.md),
          AppButton.primary(
            label: 'Back to Menu',
            onPressed: () async {
              await multiplayerService.leaveRoom();
              if (mounted) {
                NavigationHelper.safePop(context);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGameOverActions(
    GameRoom room,
    MultiplayerService multiplayerService,
    List<Player> sortedPlayers,
  ) {
    final currentUserId = multiplayerService.currentUserId;
      final friendsService = ProviderHelper.safeGetOrThrow<FriendsService>(context, listen: false);
    final allFriends = friendsService.friends;
    final friendIds = allFriends.map((f) => f.userId).toSet();

    // Get non-friend players
    final nonFriendPlayers = sortedPlayers.where((player) {
      return player.userId != currentUserId &&
          !friendIds.contains(player.userId);
    }).toList();

    return Column(
      children: [
        // Rematch button
        AppButton(
          label: 'Rematch',
          icon: Icons.refresh,
          onPressed: () => _createRematch(room),
          variant: AppButtonVariant.primary,
        ),
        const SizedBox(height: AppSpacing.md),
        // Share Result button
        AppButton(
          label: 'Share Result',
          icon: Icons.share,
          onPressed: () => _shareGameResult(room, sortedPlayers),
          variant: AppButtonVariant.primary,
          backgroundColor:
              AppColors.of(context).primaryButton.withValues(alpha: 0.7),
        ),
        // Add Friends section
        if (nonFriendPlayers.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Add Friends',
            style: AppTypography.titleLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...nonFriendPlayers.map((player) {
            final isFriend = friendIds.contains(player.userId);
            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      player.displayName ?? player.email.split('@').first,
                      style: AppTypography.bodyMedium.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (!isFriend)
                    AppButton.primary(
                      label: 'Add Friend',
                      onPressed: () => _addFriendAfterGame(player),
                      size: AppButtonSize.small,
                    )
                  else
                    const Icon(Icons.check, color: Colors.green),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Future<void> _createRematch(GameRoom originalRoom) async {
    try {
      final multiplayerService = ProviderHelper.safeGetOrThrow<MultiplayerService>(
        context,
        listen: false,
      );
      final analyticsService = ProviderHelper.safeGetOrThrow<AnalyticsService>(
        context,
        listen: false,
      );

      // Create new room with same mode and settings
      final newRoom = await multiplayerService.createRoom(
        mode: originalRoom.mode,
        maxPlayers: originalRoom.maxPlayers,
        friendsOnly: originalRoom.friendsOnly,
        allowedPlayers: originalRoom.allowedPlayers,
      );

      // Invite all previous players
      for (final player in originalRoom.players) {
        if (player.userId != multiplayerService.currentUserId) {
          try {
            await multiplayerService.sendRoomInvitation(
                newRoom.id, player.userId,);
          } catch (e) {
            LoggerService.warning('Failed to invite player to rematch',
                error: e,);
          }
        }
      }

      // Log analytics
      unawaited(
        analyticsService.logCustomEvent(
          'rematch_created',
          parameters: {
            'originalRoomId': originalRoom.id,
            'newRoomId': newRoom.id,
          },
        ),
      );

      // Navigate to new room lobby
      if (mounted) {
        await multiplayerService.leaveRoom();
        if (!mounted) return;
        unawaited(NavigationHelper.safeNavigate(
          context,
          '/multiplayer-lobby',
          replace: true,
        ),);
      }
    } catch (e) {
      if (mounted) {
        FeedbackHelper.showError(
          context,
          'Failed to create rematch: ${e.toString()}',
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  Future<void> _addFriendAfterGame(Player player) async {
    try {
      final friendsService = ProviderHelper.safeGetOrThrow<FriendsService>(
        context,
        listen: false,
      );
      final analyticsService = ProviderHelper.safeGetOrThrow<AnalyticsService>(
        context,
        listen: false,
      );

      await friendsService.sendFriendRequest(player.userId);

      // Log analytics
      unawaited(
        analyticsService.logCustomEvent(
          'friend_added_from_lobby',
          parameters: {'userId': player.userId},
        ),
      );

      if (mounted) {
        FeedbackHelper.showSuccess(
          context,
          'Friend request sent to ${player.displayName ?? player.email.split('@').first}',
          duration: const Duration(seconds: 2),
        );
        // Refresh UI
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        FeedbackHelper.showError(
          context,
          'Failed to send friend request: ${e.toString()}',
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  Future<void> _shareGameResult(
      GameRoom room, List<Player> sortedPlayers,) async {
    try {
      final winner = ListHelper.safeFirst(sortedPlayers);
      if (winner == null) {
        LoggerService.warning('Cannot share game result: no players found');
        return;
      }
      final winnerName = winner.displayName ?? winner.email.split('@').first;
      final currentUserId = ProviderHelper.safeGetOrThrow<MultiplayerService>(context, listen: false)
          .currentUserId;
      final myPlayer = sortedPlayers.firstWhere(
        (p) => p.userId == currentUserId,
        orElse: () {
          final lastPlayer = ListHelper.safeLast(sortedPlayers);
          if (lastPlayer != null) return lastPlayer;
          // Fallback: return first player if list is not empty
          final firstPlayer = ListHelper.safeFirst(sortedPlayers);
          if (firstPlayer != null) return firstPlayer;
          throw Exception('No players found in sortedPlayers');
        },
      );
      final myScore = myPlayer.score;

      final shareText = 'Just played N3RD Trivia multiplayer!\n\n'
          'Winner: $winnerName (${winner.score} pts)\n'
          'My Score: $myScore pts\n'
          'Mode: ${room.mode.name}\n\n'
          'Download N3RD Trivia and challenge me!';

      await Share.share(shareText);
      if (!mounted) return;

      // Log analytics
      final analyticsService = ProviderHelper.safeGetOrThrow<AnalyticsService>(
        context,
        listen: false,
      );
      unawaited(
        analyticsService.logCustomEvent(
          'game_result_shared',
          parameters: {
            'roomId': room.id,
            'winner': winner.userId,
            'myScore': myScore,
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        FeedbackHelper.showError(
          context,
          'Failed to share result: ${e.toString()}',
          duration: const Duration(seconds: 2),
        );
      }
    }
  }

  Widget _buildVideoOverlay() {
    return Consumer<LiveVideoService>(
      builder: (context, liveVideoService, _) {
        if (!liveVideoService.isInSession ||
            liveVideoService.localStream == null ||
            _localVideoRenderer == null) {
          return const SizedBox.shrink();
        }

        // Update renderer source if needed
        if (_localVideoRenderer!.srcObject != liveVideoService.localStream) {
          _localVideoRenderer!.srcObject = liveVideoService.localStream;
        }

        return Positioned(
          top: AppSpacing.md,
          right: AppSpacing.md,
          child: Container(
            width: 120,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(AppRadius.large),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              child: RTCVideoView(
                _localVideoRenderer!,
                mirror: true,
              ),
            ),
          ),
        );
      },
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
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.xLarge),),
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
                  AppButton(
                    icon: Icons.close,
                    onPressed: () {
                      setState(() {
                        _showChat = false;
                      });
                    },
                    variant: AppButtonVariant.icon,
                    semanticsLabel: AppLocalizations.of(context)?.closeButton ??
                        'Close Chat',
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    size: AppButtonSize.small,
                  ),
                ],
              ),
            ),

            // Messages
            Expanded(
              child: Builder(
                builder: (context) {
                  final multiplayerService = ProviderHelper.safeGetOrThrow<MultiplayerService>(
                    context,
                    listen: false,
                  );
                  final room = multiplayerService.currentRoom;
                  if (room == null) {
                    return const Center(
                      child: Text(
                        'No room available',
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  }
                  return StreamBuilder<List<ChatMessage>>(
                    stream: chatService.getMessages(room.id),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      }
                      final messages = snapshot.data!;
                      return ListView.builder(
                        controller: _chatScrollController,
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
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
                                        message.displayName,
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
                      );
                    },
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
                    child: AppTextField(
                      controller: _chatController,
                      hint: 'Type a message...',
                      onSubmitted: (value) => _sendChatMessage(),
                      textInputAction: TextInputAction.send,
                      semanticsLabel:
                          AppLocalizations.of(context)?.sendMessage ??
                              'Type a message',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppButton(
                    icon: Icons.send,
                    onPressed: _chatController.text.trim().isNotEmpty
                        ? _sendChatMessage
                        : null,
                    variant: AppButtonVariant.icon,
                    semanticsLabel: AppLocalizations.of(context)?.sendMessage ??
                        'Send Message',
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
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