import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:n3rd_game/services/game_service.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/services/free_tier_service.dart';
import 'package:n3rd_game/services/ai_mode_service.dart';
import 'package:n3rd_game/services/text_to_speech_service.dart';
import 'package:n3rd_game/services/voice_recognition_service.dart';
import 'package:n3rd_game/services/pronunciation_dictionary_service.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/services/challenge_service.dart';
import 'package:n3rd_game/services/daily_challenge_leaderboard_service.dart';
import 'package:n3rd_game/services/trivia_generator_service.dart';
import 'package:n3rd_game/services/network_service.dart';
import 'package:n3rd_game/services/offline_service.dart';
import 'package:n3rd_game/models/trivia_item.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/utils/game_instructions.dart';
import 'package:n3rd_game/utils/error_handler.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/services/resource_manager.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/services/family_group_service.dart';
import 'package:n3rd_game/utils/responsive_helper.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with ResourceManagerMixin, WidgetsBindingObserver {
  bool _hasShownDoubleTapInstruction = false;
  SubscriptionTier? _initialTier;
  bool _isValidatingSubscription = false; // Race condition protection

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkDoubleTapInstruction();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Context is available in addPostFrameCallback after widget is built
      final buildContext = context;

      final service = Provider.of<GameService>(buildContext, listen: false);
      final subscriptionService = Provider.of<SubscriptionService>(
        buildContext,
        listen: false,
      );
      final freeTierService = Provider.of<FreeTierService>(
        buildContext,
        listen: false,
      );

      // Store initial tier for validation
      _initialTier = subscriptionService.currentTier;

      // Mark game session as active for subscription grace period
      await subscriptionService.markGameSessionActive();

      // Start periodic subscription validation (every 5 minutes)
      registerTimer(
        Timer.periodic(
          const Duration(minutes: 5),
          (timer) => _validateSubscription(buildContext),
        ),
      );

      // Check if free tier user has games remaining
      if (subscriptionService.isFree) {
        if (!freeTierService.canPlay()) {
          if (buildContext.mounted) {
            // Log free tier limit reached
            final analyticsService = Provider.of<AnalyticsService>(
              buildContext,
              listen: false,
            );
            analyticsService.logFreeTierLimitReached();
            _showGameOverLimitDialog(buildContext);
            return;
          }
        }
      }

      if (!buildContext.mounted) return;

      final args = ModalRoute.of(buildContext)?.settings.arguments;
      GameMode? mode;
      String? difficulty;
      List<TriviaItem>? customTriviaPool;

      // Handle both simple GameMode argument and Map argument
      if (args is GameMode) {
        mode = args;
      } else if (args is Map<String, dynamic>) {
        mode = args['mode'] as GameMode?;
        difficulty = args['difficulty'] as String?;
        customTriviaPool = args['triviaPool'] as List<TriviaItem>?;
      }

      // Ensure free tier only uses Classic mode
      if (subscriptionService.isFree && mode != GameMode.classic) {
        mode = GameMode.classic;
      }

      // Check AI mode access (Premium only)
      if (mode == GameMode.ai && !subscriptionService.isPremium) {
        if (buildContext.mounted) {
          // Log game mode selection attempt
          final analyticsService = Provider.of<AnalyticsService>(
            buildContext,
            listen: false,
          );
          analyticsService.logGameModeSelected(
            'ai',
            subscriptionService.tierName,
          );

          _showUpgradeDialog(
            buildContext,
            'AI Mode',
            'AI Mode is only available with Premium subscription. Upgrade to Premium to access personalized, adaptive gameplay!',
          );
        }
        return;
      }

      // Log successful game mode selection
      if (buildContext.mounted) {
        final analyticsService = Provider.of<AnalyticsService>(
          buildContext,
          listen: false,
        );
        analyticsService.logGameModeSelected(
          mode?.name ?? 'unknown',
          subscriptionService.tierName,
        );
      }

      if (!mounted) return;

      // Handle AI mode timing
      if (mode == GameMode.ai) {
        final aiModeService = Provider.of<AIModeService>(
          context,
          listen: false,
        );
        final (memorizeTime, playTime) = aiModeService.getRecommendedTiming();
        // Set initial AI mode timing
        service.setAIModeTiming(memorizeTime, playTime);
      }

      // Use custom trivia pool if provided (e.g., from AI Edition)
      List<TriviaItem> triviaPool;
      try {
        final analyticsService = Provider.of<AnalyticsService>(
          buildContext,
          listen: false,
        );

        if (customTriviaPool != null && customTriviaPool.isNotEmpty) {
          triviaPool = customTriviaPool;
          await analyticsService.logTriviaGeneration('custom', true);
        } else {
          // Generate trivia using Provider service with retry logic
          final generator = Provider.of<TriviaGeneratorService>(
            buildContext,
            listen: false,
          );

          // Try generating with retry and fallback
          triviaPool = await _generateTriviaWithRetry(
            buildContext,
            generator,
            analyticsService,
            mode?.name ?? 'unknown',
          );

          // Validate trivia pool is not empty
          if (triviaPool.isEmpty) {
            await analyticsService.logTriviaGeneration(
              mode?.name ?? 'unknown',
              false,
              error: 'Empty trivia pool after retries',
            );
            // Check buildContext.mounted directly (not State.mounted)
            if (buildContext.mounted) {
              _showTriviaErrorDialog(
                buildContext,
                AppLocalizations.of(buildContext)?.noTriviaContentAvailable ??
                    'No trivia content available after multiple attempts. '
                        'This may indicate a temporary issue. Please try again or restart the app.',
              );
            }
            return;
          }

          await analyticsService.logTriviaGeneration(
            mode?.name ?? 'unknown',
            true,
          );
        }
      } on GameException catch (e) {
        // Handle game-specific errors with user-friendly messages
        if (kDebugMode) {
          debugPrint('Game error: $e');
        }
        if (buildContext.mounted) {
          final catchAnalyticsService = Provider.of<AnalyticsService>(
            buildContext,
            listen: false,
          );
          try {
            await catchAnalyticsService.logTriviaGeneration(
              mode?.name ?? 'unknown',
              false,
              error: e.toString(),
            );
          } catch (_) {
            // Ignore analytics errors
          }
          if (buildContext.mounted) {
            final localizations = AppLocalizations.of(buildContext);
            String errorMessage =
                localizations?.failedToLoadTrivia ??
                'Failed to load trivia content. ';
            if (e.toString().contains('No templates available')) {
              errorMessage +=
                  localizations?.templateInitializationIssue ??
                  'Template initialization issue detected. Please restart the app.';
            } else if (e.toString().contains(
              'Unable to generate unique trivia',
            )) {
              errorMessage +=
                  localizations?.allContentUsed ??
                  'All available content has been used. Try clearing history or selecting a different theme.';
            } else {
              errorMessage += e.message;
            }
            _showTriviaErrorDialog(buildContext, errorMessage);
          }
        }
        return;
      } on ValidationException catch (e) {
        // Handle validation errors (template/content issues)
        if (kDebugMode) {
          debugPrint('Validation error: $e');
        }
        if (buildContext.mounted) {
          final catchAnalyticsService = Provider.of<AnalyticsService>(
            buildContext,
            listen: false,
          );
          try {
            await catchAnalyticsService.logTriviaGeneration(
              mode?.name ?? 'unknown',
              false,
              error: e.toString(),
            );
          } catch (_) {
            // Ignore analytics errors
          }
          if (buildContext.mounted) {
            _showTriviaErrorDialog(
              buildContext,
              AppLocalizations.of(buildContext)?.triviaValidationFailed ??
                  'Trivia content validation failed. Please restart the app or contact support if this persists.',
            );
          }
        }
        return;
      } catch (e) {
        // Handle any other unexpected errors
        if (kDebugMode) {
          debugPrint('Failed to load trivia: $e');
        }
        // Log trivia generation failure
        // Check buildContext.mounted before accessing Provider
        if (buildContext.mounted) {
          final catchAnalyticsService = Provider.of<AnalyticsService>(
            buildContext,
            listen: false,
          );
          try {
            await catchAnalyticsService.logTriviaGeneration(
              mode?.name ?? 'unknown',
              false,
              error: e.toString(),
            );
          } catch (_) {
            // Ignore analytics errors
          }
          // Check buildContext.mounted again after async operation
          if (buildContext.mounted) {
            // Provide more specific error message based on exception type
            final localizations = AppLocalizations.of(buildContext);
            String errorMessage =
                localizations?.failedToLoadTrivia ??
                'Failed to load trivia content. ';
            if (e.toString().contains('No templates available')) {
              errorMessage +=
                  localizations?.templateInitializationIssue ??
                  'Template initialization issue detected. Please restart the app.';
            } else if (e.toString().contains(
              'Unable to generate unique trivia',
            )) {
              errorMessage +=
                  localizations?.allContentUsed ??
                  'All available content has been used. Try clearing history or selecting a different theme.';
            } else {
              errorMessage +=
                  localizations?.checkConnectionAndRetry ??
                  'Please check your connection and try again.';
            }
            _showTriviaErrorDialog(buildContext, errorMessage);
          }
        }
        return;
      }

      // CRITICAL: Attempt to start game FIRST, then record game start only if successful
      // This prevents wasting free tier game slots if startNewRound() throws an exception
      // Flow: Start game → If successful, record slot → Continue
      // If startNewRound() throws, the slot is never recorded, preserving user's daily limit
      try {
        if (mode == GameMode.timeAttack) {
          // Pass List<TriviaItem> for timeAttack
          service.startNewRound(
            triviaPool,
            mode: mode ?? GameMode.classic,
            difficulty: difficulty,
          );
        } else {
          service.startNewRound(
            triviaPool,
            mode: mode ?? GameMode.classic,
            difficulty: difficulty,
          );
        }

        // Game started successfully (no exception thrown) - now record it for free tier users
        if (subscriptionService.isFree) {
          final gameRecorded = await freeTierService.recordGameStart();
          if (!gameRecorded) {
            // This shouldn't happen since we checked canPlay() earlier,
            // but handle it gracefully - game already started successfully, so continue
            if (buildContext.mounted) {
              final analyticsService = Provider.of<AnalyticsService>(
                buildContext,
                listen: false,
              );
              analyticsService.logFreeTierLimitReached();
              // Don't show dialog here since game already started - just log
              if (kDebugMode) {
                debugPrint(
                  '⚠️ Warning: Could not record game start but game already started successfully',
                );
              }
            }
          }
        }

        // Show mode-specific instruction if available (after game starts)
        if (mode != null && buildContext.mounted) {
          _checkAndShowModeInstruction(buildContext, mode);
        }
      } on GameException catch (e) {
        // Game failed to start (startNewRound() threw GameException) - slot is NOT recorded
        // Show user-friendly error dialog directly
        if (kDebugMode) {
          debugPrint(
            'Game failed to start: $e - Game slot NOT recorded (preserving user\'s daily limit)',
          );
        }
        if (buildContext.mounted) {
          _showTriviaErrorDialog(buildContext, e.message);
        }
      } on ValidationException catch (e) {
        // Game failed due to validation error - slot is NOT recorded
        if (kDebugMode) {
          debugPrint(
            'Validation error in game start: $e - Game slot NOT recorded',
          );
        }
        if (buildContext.mounted) {
          _showTriviaErrorDialog(
            buildContext,
            'Trivia content validation failed. Please restart the app.',
          );
        }
      } catch (e) {
        // Game failed to start (unexpected exception) - slot is NOT recorded
        // Re-throw the error to be handled by outer catch block which shows error dialog
        // This ensures user doesn't lose a game slot when trivia validation fails
        if (kDebugMode) {
          debugPrint(
            'Game failed to start: $e - Game slot NOT recorded (preserving user\'s daily limit)',
          );
        }
        rethrow;
      }
    });
  }

  Future<void> _checkDoubleTapInstruction() async {
    final prefs = await SharedPreferences.getInstance();
    final dontShowAgain =
        prefs.getBool('dont_show_double_tap_instruction') ?? false;
    if (!dontShowAgain && !_hasShownDoubleTapInstruction) {
      _hasShownDoubleTapInstruction = true;
      // Show instruction when play phase starts
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showDoubleTapInstruction();
        }
      });
    }
  }

  void _showDoubleTapInstruction() {
    // Wait for play phase to start
    final service = Provider.of<GameService>(context, listen: false);
    if (service.phase == GamePhase.play &&
        !service.currentConfig.showWordsWithQuestion) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _showDoubleTapDialog();
        }
      });
    }
  }

  /// Check and show mode-specific instruction if available
  Future<void> _checkAndShowModeInstruction(
    BuildContext context,
    GameMode mode,
  ) async {
    if (!mounted || !context.mounted) return;

    // Get instruction ID for this mode
    final instructionId = GameInstructions.getInstructionIdForMode(mode);
    if (instructionId == null) return;

    // Check if instruction should be shown
    final shouldShow = await GameInstructions.shouldShowInstruction(
      instructionId,
      context: context,
    );
    if (!shouldShow) return;

    if (!mounted || !context.mounted) return;

    // Wait a bit to avoid conflict with double-tap instruction
    // Show mode instruction after double-tap if both should show
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted || !context.mounted) return;

    final instruction = GameInstructions.getInstruction(instructionId, context);
    if (instruction == null) return;

    await _showModeInstructionDialog(context, instruction);
  }

  /// Show mode-specific instruction dialog
  Future<void> _showModeInstructionDialog(
    BuildContext context,
    InstructionMessage instruction,
  ) async {
    if (!mounted || !context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final dialogColors = AppColors.of(context);
          return AlertDialog(
            backgroundColor: dialogColors.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Row(
              children: [
                Icon(Icons.info_outline, color: dialogColors.info, size: 24),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    instruction.title,
                    style: AppTypography.displayMedium.copyWith(
                      fontSize: 22,
                      color: AppColors.of(context).primaryText,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  instruction.message,
                  style: AppTypography.bodyMedium.copyWith(
                    fontSize: 15,
                    color: AppColors.of(context).secondaryText,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await GameInstructions.markInstructionShown(
                    instruction.id,
                    dontShowAgain: false,
                  );
                  if (!context.mounted) return;
                  NavigationHelper.safePop(context);
                },
                child: Text(
                  AppLocalizations.of(context)?.gotIt ?? 'Got it',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.of(context).primaryText,
                  ),
                ),
              ),
              if (instruction.showOnce)
                TextButton(
                  onPressed: () async {
                    await GameInstructions.markInstructionShown(
                      instruction.id,
                      dontShowAgain: true,
                    );
                    if (!context.mounted) return;
                    NavigationHelper.safePop(context);
                  },
                  child: Text(
                    "Don't show again",
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.of(context).secondaryText,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showDoubleTapDialog() async {
    final shouldShow = await GameInstructions.shouldShowInstruction(
      'double_tap',
      context: context,
    );
    if (!shouldShow) return;

    if (!mounted) return;

    final instruction = GameInstructions.getInstruction('double_tap', context);

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final dialogColors = AppColors.of(context);
          return AlertDialog(
            backgroundColor: dialogColors.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Text(
              instruction?.title ?? 'How to Play',
              style: AppTypography.displayMedium.copyWith(
                fontSize: 24,
                color: AppColors.of(context).primaryText,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select exactly ${GameService.expectedCorrectAnswers} correct answers from the ${GameService.requiredWordsForGameplay} words shown.\n\nTap once to reveal AND SELECT a tile.',
                  style: AppTypography.bodyMedium.copyWith(
                    fontSize: 15,
                    color: AppColors.of(context).secondaryText,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await GameInstructions.markInstructionShown(
                    'double_tap',
                    dontShowAgain: false,
                  );
                  if (!context.mounted) return;
                  NavigationHelper.safePop(context);
                },
                child: Text(
                  AppLocalizations.of(context)?.gotIt ?? 'Got it',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.of(context).primaryText,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  await GameInstructions.markInstructionShown(
                    'double_tap',
                    dontShowAgain: false,
                  );
                  if (!context.mounted) return;
                  NavigationHelper.safePop(context);
                  // Navigate to next or continue game
                },
                child: Text(
                  'Next',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.of(context).primaryText,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Show a helpful tip dialog
  Future<void> _showTipDialog(
    BuildContext context,
    InstructionMessage instruction,
  ) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final dialogColors = AppColors.of(context);
          return AlertDialog(
            backgroundColor: dialogColors.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: dialogColors.warning,
                  size: 24,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    instruction.title,
                    style: AppTypography.displayMedium.copyWith(
                      fontSize: 22,
                      color: AppColors.of(context).primaryText,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  instruction.message,
                  style: AppTypography.bodyMedium.copyWith(
                    fontSize: 15,
                    color: AppColors.of(context).secondaryText,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await GameInstructions.markInstructionShown(
                    instruction.id,
                    dontShowAgain: false,
                  );
                  if (!context.mounted) return;
                  NavigationHelper.safePop(context);
                },
                child: Text(
                  AppLocalizations.of(context)?.gotIt ?? 'Got it',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.of(context).primaryText,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  await GameInstructions.markInstructionShown(
                    instruction.id,
                    dontShowAgain: false,
                  );
                  if (!context.mounted) return;
                  NavigationHelper.safePop(context);
                  // Continue game
                },
                child: Text(
                  'Next',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.of(context).primaryText,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Validate subscription status during gameplay
  /// Protected against race conditions with _isValidatingSubscription flag
  /// Explicitly handles both individual Premium and Family & Friends subscription expiration
  Future<void> _validateSubscription(BuildContext context) async {
    if (!mounted || !context.mounted) return;

    // Prevent concurrent validation (race condition protection)
    if (_isValidatingSubscription) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ Subscription validation already in progress, skipping duplicate call',
        );
      }
      return;
    }

    _isValidatingSubscription = true;

    try {
      final subscriptionService = Provider.of<SubscriptionService>(
        context,
        listen: false,
      );
      final analyticsService = Provider.of<AnalyticsService>(
        context,
        listen: false,
      );
      final gameService = Provider.of<GameService>(context, listen: false);
      
      // Get FamilyGroupService to check family subscription status
      final familyGroupService = Provider.of<FamilyGroupService>(
        context,
        listen: false,
      );

      // Re-sync subscription from RevenueCat/Firestore
      await subscriptionService.init();
      
      // Reload family group to get latest subscription status
      if (familyGroupService.isInGroup) {
        await familyGroupService.init();
      }

      final currentTier = subscriptionService.currentTier;
      final tierChanged = _initialTier != null && currentTier != _initialTier;
      
      // Check if user had premium access (individual or family) and lost it
      final hadPremiumAccess = _initialTier == SubscriptionTier.premium ||
          _initialTier == SubscriptionTier.familyFriends;
      
      // Check current premium access: individual premium OR active family subscription
      final hasIndividualPremium = subscriptionService.isPremium;
      final hasActiveFamilySubscription = familyGroupService.isInGroup &&
          familyGroupService.currentGroup?.isSubscriptionActive == true;
      final hasPremiumAccess = hasIndividualPremium || hasActiveFamilySubscription;
      
      // Check if family subscription expired (user was in family, but subscription is now inactive)
      final familySubscriptionExpired = familyGroupService.isInGroup &&
          familyGroupService.currentGroup != null &&
          !familyGroupService.currentGroup!.isSubscriptionActive &&
          _initialTier == SubscriptionTier.familyFriends;

      // Log subscription validation
      await analyticsService.logSubscriptionValidation(
        tierChanged || !hasPremiumAccess,
        _initialTier?.name,
        currentTier.name,
      );

      // If tier changed or premium access lost, handle it
      if (tierChanged || (hadPremiumAccess && !hasPremiumAccess)) {
        await analyticsService.logSubscriptionTierChange(
          _initialTier?.name ?? 'unknown',
          currentTier.name,
        );

        // If downgraded from Premium/Family to Free/Basic during AI mode game
        if (gameService.currentMode == GameMode.ai && !hasPremiumAccess) {
          if (mounted && context.mounted) {
            // Show warning and end AI mode game
            final message = familySubscriptionExpired
                ? 'Your Family & Friends subscription has expired. AI Mode is no longer available. The game will end after this round.'
                : 'Your Premium subscription has expired. AI Mode is no longer available. The game will end after this round.';
            
            ErrorHandler.showWarning(
              context,
              message,
              title: 'Subscription Expired',
              onConfirm: () {
                // End game after current round completes
                // The game will naturally end when the round completes
                // This prevents users from continuing to play AI mode without subscription
                if (mounted && context.mounted) {
                  NavigationHelper.safePop(context);
                }
              },
            );
            // Log analytics for subscription expiration during AI mode
            await analyticsService.logSubscriptionTierChange(
              _initialTier?.name ?? 'unknown',
              currentTier.name,
            );
          }
        }

        _initialTier = currentTier;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Subscription validation error: $e');
      }
    } finally {
      // Always reset flag, even on error
      _isValidatingSubscription = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cache screen size using ResponsiveHelper for consistency
    final screenWidth = ResponsiveHelper.responsiveWidth(context, 1.0);
    final screenHeight = ResponsiveHelper.responsiveHeight(context, 1.0);
    final screenSize = Size(screenWidth, screenHeight);

    return Consumer<GameService>(
      builder: (context, service, _) {
        // Check for save failure notifications and show warnings
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          // Check for core state save failures
          if (service.needsSaveFailureNotification) {
            service.clearSaveFailureNotification();
            _showSaveFailureWarning(
              context,
              'Game state may not be saved',
              'There was a problem saving your game progress. Your score and progress may be lost if the app closes. Please try saving again or contact support if this persists.',
            );
          }

          // Check for extended state save failures
          if (service.needsExtendedStateFailureNotification) {
            service.clearExtendedStateFailureNotification();
            _showSaveFailureWarning(
              context,
              'Partial game state saved',
              'Your game progress was saved, but some details (like power-ups and round state) may not be fully restored if you close the app. Your score and lives are safe.',
            );
          }
        });

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            if (!mounted) return;

            // Capture context references before any async calls
            final scaffoldMessenger = ScaffoldMessenger.of(context);

            // Check if competitive challenge is active by checking if we can submit
            // We'll use a workaround since _competitiveChallengeId is private
            final args = ModalRoute.of(context)?.settings.arguments;
            final isCompetitive =
                args is Map<String, dynamic> &&
                args['competitiveChallengeId'] != null;

            if (isCompetitive) {
              // Show confirmation dialog
              if (!mounted || !context.mounted) return;
              final shouldPop = await showDialog<bool>(
                context: context,
                builder: (dialogContext) {
                  final localizations = AppLocalizations.of(context);
                  return AlertDialog(
                    title: Text(
                      localizations?.exitChallenge ?? 'Exit Challenge?',
                    ),
                    content: Text(
                      localizations?.exitChallengeMessage ??
                          'Your progress will be saved, but your score won\'t be submitted to the leaderboard.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            NavigationHelper.safePop(dialogContext, false),
                        child: Text(localizations?.cancel ?? 'Cancel'),
                      ),
                      TextButton(
                        onPressed: () =>
                            NavigationHelper.safePop(dialogContext, true),
                        child: Text(localizations?.exit ?? 'Exit'),
                      ),
                    ],
                  );
                },
              );

              if (shouldPop == true) {
                if (!mounted || !context.mounted) return;
                // Submit score before exiting
                final response = await service
                    .submitCompetitiveChallengeScore();
                if (!mounted || !context.mounted) return;

                // Show appropriate message based on result
                if (response.isSuccess) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        response.message ?? 'Score submitted to leaderboard!',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  // Show error message
                  String errorMsg =
                      response.message ?? 'Failed to submit score';
                  Color bgColor = Colors.orange;

                  switch (response.result) {
                    case SubmissionResult.networkError:
                      errorMsg =
                          'Network error. Your score will be saved for retry.';
                      bgColor = Colors.orange;
                      break;
                    case SubmissionResult.maxAttemptsReached:
                      errorMsg = 'Maximum attempts reached.';
                      bgColor = Colors.red;
                      break;
                    case SubmissionResult.scoreNotImproved:
                      errorMsg = response.message ?? 'Score did not improve.';
                      bgColor = Colors.orange;
                      break;
                    case SubmissionResult.permissionDenied:
                      errorMsg =
                          'Permission denied. Please check your account.';
                      bgColor = Colors.red;
                      break;
                    case SubmissionResult.challengeInvalid:
                      errorMsg =
                          response.message ?? 'Challenge expired or invalid.';
                      bgColor = Colors.red;
                      break;
                    default:
                      errorMsg = response.message ?? 'Unable to submit score.';
                      bgColor = Colors.orange;
                  }
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(errorMsg),
                      backgroundColor: bgColor,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
                if (mounted && context.mounted) {
                  NavigationHelper.safePop(context);
                }
              } else {
                if (mounted && context.mounted) {
                  NavigationHelper.safePop(context);
                }
              }
            } else {
              // Non-competitive mode: check if game is active
              final gameService = Provider.of<GameService>(context, listen: false);
              final isGameActive = !gameService.state.isGameOver && 
                                   (gameService.phase == GamePhase.memorize || 
                                    gameService.phase == GamePhase.play);
              
              if (isGameActive) {
                // Show confirmation dialog for active games
                if (!mounted || !context.mounted) return;
                final shouldPop = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) {
                    final localizations = AppLocalizations.of(context);
                    return AlertDialog(
                      title: Text(
                        localizations?.exitGame ?? 'Exit Game?',
                      ),
                      content: Text(
                        localizations?.exitGameConfirmation ??
                            'Are you sure you want to exit? Your progress will be lost.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              NavigationHelper.safePop(dialogContext, false),
                          child: Text(localizations?.cancel ?? 'Cancel'),
                        ),
                        TextButton(
                          onPressed: () =>
                              NavigationHelper.safePop(dialogContext, true),
                          child: Text(localizations?.exit ?? 'Exit'),
                        ),
                      ],
                    );
                  },
                );

                if (shouldPop == true && mounted && context.mounted) {
                  NavigationHelper.safePop(context);
                }
              } else {
                // Game over or not started: just pop
                if (mounted && context.mounted) {
                  NavigationHelper.safePop(context);
                }
              }
            }
          },
          child: Scaffold(
            body: Stack(
              children: [
                // Image background - optimized for performance
                Positioned.fill(
                  child: RepaintBoundary(
                    child: Image.asset(
                      'assets/images/Green Neutral Simple Serendipity Phone Wallpaper.jpg',
                      fit: BoxFit.cover,
                      // Optimize memory usage by caching at screen resolution
                      cacheWidth: screenSize.width.toInt(),
                      cacheHeight: screenSize.height.toInt(),
                      errorBuilder: (context, error, stackTrace) {
                        // Log error for debugging
                        if (kDebugMode) {
                          debugPrint(
                            'Failed to load game screen background image: $error',
                          );
                        }
                        // Fallback to black background if image not found
                        return Container(color: Colors.black);
                      },
                      // Prevent image from being disposed when off-screen
                      gaplessPlayback: true,
                    ),
                  ),
                ),
                SafeArea(
                  child: Consumer<GameService>(
                    builder: (context, service, _) {
                      // Show Precision mode error feedback
                      if (service.precisionError != null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(service.precisionError!),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        });
                      }

                      if (service.state.isGameOver) {
                        return _buildGameOverScreen(context, service);
                      }
                      return _buildGameplayScreen(context, service);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGameplayScreen(BuildContext context, GameService service) {
    // Check if competitive challenge
    final args = ModalRoute.of(context)?.settings.arguments;
    final isCompetitive =
        args is Map<String, dynamic> && args['competitiveChallengeId'] != null;
    final targetRounds = isCompetitive ? (args['targetRounds'] as int?) : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: EdgeInsets.zero, // Remove all padding to fit screen
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAppBar(
                service,
                isCompetitive: isCompetitive,
                targetRounds: targetRounds,
              ),
              _buildTimer(context, service),
              const SizedBox(height: AppSpacing.sm),
              if (service.phase != GamePhase.memorize) ...[
                _buildCategory(context, service),
                const SizedBox(height: AppSpacing.sm),
              ],
              _buildPhaseInstruction(context, service),
              // Show Flip Mode reveal setting indicator
              if (service.isFlipMode && service.phase == GamePhase.play)
                _buildFlipModeRevealIndicator(service),
              const SizedBox(height: AppSpacing.sm),
              Expanded(child: _buildTiles(context, service)),
              if (service.phase == GamePhase.play) ...[
                _buildActionButtons(service),
                _buildAdvancedPowerUps(service),
                _buildSubmitButton(service),
              ],
              if (service.phase == GamePhase.result) ...[
                _buildNextRoundButton(context, service),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppBar(
    GameService service, {
    bool isCompetitive = false,
    int? targetRounds,
  }) {
    return Consumer<SubscriptionService>(
      builder: (context, subscriptionService, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            children: [
              // Competitive challenge indicator
              if (isCompetitive && targetRounds != null)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm + 4,
                    vertical: AppSpacing.xs + 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.emoji_events,
                        color: Color(0xFFFFD700),
                        size: 16,
                      ),
                      const SizedBox(width: AppSpacing.xs + 2),
                      Text(
                        'Daily Challenge: Round ${service.state.round}/$targetRounds',
                        style: AppTypography.labelSmall.copyWith(
                          fontSize: 12,
                          color: const Color(0xFFFFD700),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Score
                  Text(
                    '${service.state.score}',
                    style: AppTypography.displayMedium.copyWith(
                      fontSize: ResponsiveHelper.responsiveFontSize(
                        context,
                        baseSize: ResponsiveHelper.responsiveWidth(context, 0.075),
                        minSize: 20.0,
                        maxSize: 32.0,
                      ),
                      color: Colors.white,
                    ),
                  ),
                  // Lives
                  Row(
                    children: List.generate(
                      service.state.lives,
                      (index) => const Padding(
                        padding: EdgeInsets.only(left: AppSpacing.xs),
                        child: Icon(
                          Icons.favorite,
                          color: AppColors.error,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Mode-specific indicators
              if (service.currentMode == GameMode.streak &&
                  service.streakMultiplier > 1)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.local_fire_department,
                              color: Color(0xFFFFD700),
                              size: 16,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              '${service.streakMultiplier}x',
                              style: AppTypography.labelSmall.copyWith(
                                fontSize: 12,
                                color: const Color(0xFFFFD700),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              if (service.currentMode == GameMode.survival &&
                  service.survivalPerfectCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.favorite,
                              color: Colors.green,
                              size: 16,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              '${service.survivalPerfectCount}/3',
                              style: AppTypography.labelSmall.copyWith(
                                fontSize: 12,
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'for life',
                              style: AppTypography.labelSmall.copyWith(
                                fontSize: 10,
                                color: Colors.green.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              // Round, Help, and Settings buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Round ${service.state.round}',
                    style: AppTypography.labelSmall.copyWith(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Semantics(
                    label: 'Get a tip',
                    button: true,
                    child: IconButton(
                      icon: const Icon(
                        Icons.help_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () async {
                        if (!mounted) return;
                        // Capture context before async call
                        final capturedContext = context;
                        final tip = await GameInstructions.getRandomTip(
                          context,
                        );
                        // Check context.mounted after async gap
                        if (!capturedContext.mounted) return;
                        if (tip != null) {
                          _showTipDialog(capturedContext, tip);
                        }
                      },
                      tooltip:
                          AppLocalizations.of(context)?.hintButton ??
                          'Get a tip',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                  Semantics(
                    label:
                        AppLocalizations.of(context)?.gameSettings ??
                        'Game settings',
                    button: true,
                    child: IconButton(
                      icon: const Icon(
                        Icons.settings_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () =>
                          NavigationHelper.safeNavigate(context, '/settings'),
                      tooltip:
                          AppLocalizations.of(context)?.settingsButton ??
                          'Settings',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimer(BuildContext context, GameService service) {
    final colors = AppColors.of(context);
    // Responsive timer font size: 12% of screen width, min 36px, max 64px
    final timerFontSize = ResponsiveHelper.responsiveFontSize(
      context,
      baseSize: ResponsiveHelper.responsiveWidth(context, 0.12),
      minSize: 36.0,
      maxSize: 64.0,
    );
    // Responsive label font size: 3% of screen width, min 9px, max 14px
    final labelFontSize = ResponsiveHelper.responsiveFontSize(
      context,
      baseSize: ResponsiveHelper.responsiveWidth(context, 0.03),
      minSize: 9.0,
      maxSize: 14.0,
    );
    
    // Time Attack timer
    if (service.currentMode == GameMode.timeAttack &&
        service.timeAttackSecondsLeft != null) {
      return Column(
        children: [
          Text(
            'TIME ATTACK',
            style: AppTypography.labelSmall.copyWith(
              fontSize: labelFontSize,
              color: Colors.white.withValues(alpha: 0.7),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Stack(
            alignment: Alignment.center,
            children: [
              Text(
                '${service.timeAttackSecondsLeft}',
                style: AppTypography.displayLarge.copyWith(
                  fontSize: timerFontSize,
                  color: service.timeAttackSecondsLeft! <= 10
                      ? colors.error
                      : Colors.white,
                ),
              ),
              // Time freeze indicator
              if (service.isTimeFrozen)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: Colors.cyan.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'FROZEN',
                    style: AppTypography.labelSmall.copyWith(
                      fontSize: 8,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
    }

    // Regular timer
    final isUrgent =
        (service.phase == GamePhase.memorize &&
            service.memorizeTimeLeft <= 3) ||
        (service.phase == GamePhase.play && service.playTimeLeft <= 5);
    final timeLeft = service.phase == GamePhase.memorize
        ? service.memorizeTimeLeft
        : service.playTimeLeft;
    final label = service.phase == GamePhase.memorize ? 'MEMORIZE' : 'RECALL';
    
    return Column(
      children: [
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            fontSize: labelFontSize,
            color: Colors.white.withValues(alpha: 0.7),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '$timeLeft',
              style: AppTypography.displayLarge.copyWith(
                fontSize: timerFontSize,
                color: isUrgent ? colors.error : Colors.white,
              ),
            ),
            // Time freeze indicator
            if (service.isTimeFrozen && service.phase == GamePhase.play)
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: Colors.cyan.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'FROZEN',
                  style: AppTypography.labelSmall.copyWith(
                    fontSize: 8,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategory(BuildContext context, GameService service) {
    // Responsive category font size: 7.5% of screen width, min 20px, max 32px
    final categoryFontSize = ResponsiveHelper.responsiveFontSize(
      context,
      baseSize: ResponsiveHelper.responsiveWidth(context, 0.075),
      minSize: 20.0,
      maxSize: 32.0,
    );
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Text(
        service.currentTrivia?.category ?? '',
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.displayMedium.copyWith(
          fontSize: categoryFontSize,
          color: Colors.white,
          height: 1.3,
        ),
      ),
    );
  }

  Widget _buildPhaseInstruction(BuildContext context, GameService service) {
    String instruction = '';

    if (service.phase == GamePhase.memorize) {
      final localizations = AppLocalizations.of(context);
      instruction = service.currentMode == GameMode.shuffle
          ? (localizations?.memorizeTheseWillShuffle ??
                'Memorize—these will shuffle')
          : (localizations?.memorizeTheseWords ?? 'Memorize these words');
      // Read instruction with TTS if enabled (premium only)
      // Capture context and mounted before callback
      final capturedContext = context;
      final isMounted = mounted;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!isMounted) return;
        final subscriptionService = Provider.of<SubscriptionService>(
          capturedContext,
          listen: false,
        );
        if (subscriptionService.isPremium) {
          final ttsService = Provider.of<TextToSpeechService>(
            capturedContext,
            listen: false,
          );
          final currentTrivia = service.currentTrivia;
          if (ttsService.isEnabled && currentTrivia != null) {
            // Read the category/question
            ttsService.speak('${currentTrivia.category}. $instruction');
          }
        }
      });
    } else if (service.phase == GamePhase.play) {
      // Show play phase instruction
      instruction =
          AppLocalizations.of(context)?.instructionPlayPhaseMessage ??
          'Select ${GameService.expectedCorrectAnswers} correct answers';
      // Read instruction with TTS if enabled (premium only)
      // Capture context and mounted before callback
      final capturedContext = context;
      final isMounted = mounted;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!isMounted) return;
        final subscriptionService = Provider.of<SubscriptionService>(
          capturedContext,
          listen: false,
        );
        if (subscriptionService.isPremium) {
          final ttsService = Provider.of<TextToSpeechService>(
            capturedContext,
            listen: false,
          );
          if (ttsService.isEnabled) {
            ttsService.speak(
              'Select exactly 3 correct answers from the 6 words shown.',
            );
          }
        }
      });
    } else {
      final expectedCorrect =
          service.currentTrivia?.correctAnswers.length ??
          GameService.expectedCorrectAnswers;
      if (service.correctCount == expectedCorrect) {
        instruction = 'Perfect! +${expectedCorrect * 10} points';
      } else if (service.correctCount == 0) {
        instruction = service.currentMode == GameMode.timeAttack
            ? 'Incorrect—keep going'
            : 'Lost a life';
      } else {
        instruction = 'Correct: ${service.correctCount}/$expectedCorrect';
      }
    }

    if (instruction.isEmpty) {
      return const SizedBox.shrink();
    }

    final colors = AppColors.of(context);
    return Text(
      instruction,
      textAlign: TextAlign.center,
      style: AppTypography.bodyMedium.copyWith(
        fontSize: 14,
        color:
            service.phase == GamePhase.result &&
                service.correctCount ==
                    (service.currentTrivia?.correctAnswers.length ??
                        GameService.expectedCorrectAnswers)
            ? colors.success
            : Colors.white.withValues(alpha: 0.9),
        letterSpacing: 0.3,
      ),
    );
  }

  /// Build Flip Mode reveal setting indicator (shows current reveal mode)
  Widget _buildFlipModeRevealIndicator(GameService service) {
    final revealMode = service.flipRevealMode;
    String modeText = '';
    IconData icon = Icons.visibility;

    if (revealMode == 'instant') {
      modeText = 'Instant Reveal';
      icon = Icons.flash_on;
    } else if (revealMode == 'blind') {
      modeText = 'Blind Mode';
      icon = Icons.visibility_off;
    } else if (revealMode == 'random') {
      modeText = 'Random Reveal';
      icon = Icons.shuffle;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 16,
            color: AppColors.of(context).secondaryText.withValues(alpha: 0.7),
          ),
          const SizedBox(width: AppSpacing.xs + 2),
          Text(
            modeText,
            style: AppTypography.labelSmall.copyWith(
              fontSize: 12,
              color: AppColors.of(context).secondaryText.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTiles(BuildContext context, GameService service) {
    // Ensure we have exactly 6 tiles
    final tileCount = service.shuffledWords.length.clamp(0, 6);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
      ), // Minimal padding
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          tileCount,
          (index) => Expanded(
            child: _buildTile(context, service, service.shuffledWords[index]),
          ),
        ),
      ),
    );
  }

  Widget _buildTile(BuildContext context, GameService service, String word) {
    // Responsive tile font size: 5.5% of screen width, min 16px, max 26px
    final tileFontSize = ResponsiveHelper.responsiveFontSize(
      context,
      baseSize: ResponsiveHelper.responsiveWidth(context, 0.055),
      minSize: 16.0,
      maxSize: 26.0,
    );
    final isSelected = service.selectedAnswers.contains(word);
    final isRevealed = service.revealedWords.contains(word);
    final isMemorize = service.phase == GamePhase.memorize;
    final isPlay = service.phase == GamePhase.play;
    final isResult = service.phase == GamePhase.result;
    final isFlipMode = service.isFlipMode;

    // Flip Mode: Check if tile is face-up or face-down
    // Use Map for O(1) lookup performance (optimized from O(n) indexOf)
    bool isFlippedUp = true; // Default to face-up
    if (isFlipMode) {
      final tileIndex =
          service.shuffledWordsMap[word] ?? service.shuffledWords.indexOf(word);
      if (tileIndex >= 0 && tileIndex < service.flippedTiles.length) {
        isFlippedUp = service.flippedTiles[tileIndex];
      }
    }

    bool showWord =
        isMemorize || service.currentConfig.showWordsWithQuestion || isRevealed;

    // Flip Mode: In play phase, only show word if tile is face-up (or revealed/selected)
    if (isFlipMode && isPlay && !isResult) {
      showWord = isFlippedUp || isRevealed || isSelected;
    }

    // Default: black background, white text
    Color backgroundColor = Colors.black.withValues(alpha: 0.8);
    Color textColor = Colors.white;

    if (isResult) {
      final colors = AppColors.of(context);
      final isCorrect = service.lastCorrectAnswers.contains(word);
      final wasSelected = service.lastSelectedAnswers.contains(word);
      // Only show correct answers and wrong selected answers
      if (isCorrect && wasSelected) {
        // Correct answer selected - green
        backgroundColor = colors.success.withValues(alpha: 0.9);
        textColor = Colors.white;
        showWord = true; // Show the word
      } else if (!isCorrect && wasSelected) {
        // Wrong answer selected - red with X
        backgroundColor = colors.error.withValues(alpha: 0.9);
        textColor = Colors.white;
        showWord = true; // Show the word with X
      } else if (isCorrect && !wasSelected) {
        // Correct answer missed - green
        backgroundColor = colors.success.withValues(alpha: 0.9);
        textColor = Colors.white;
        showWord = true; // Show the word
      } else {
        // Other words - don't reveal
        showWord = false;
      }
    } else if (isSelected && isPlay) {
      backgroundColor = Colors.white.withValues(alpha: 0.3);
      textColor = Colors.white;
    }

    // Minimal shuffle indicator
    final isShuffling =
        service.isShuffling && service.currentMode == GameMode.shuffle;

    // Flip Mode: Show card back if face-down
    final showCardBack =
        isFlipMode && isPlay && !isFlippedUp && !isRevealed && !isSelected;

    // Flip Mode: Adjust background for face-down cards
    if (showCardBack) {
      backgroundColor = Colors.grey[800]!.withValues(alpha: 0.9);
      showWord = false; // Hide word on card back
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xs,
      ), // Slightly larger tiles
      child: AnimatedContainer(
        duration: Duration(milliseconds: isShuffling ? 150 : 200),
        curve: Curves.easeInOut,
        transform: isShuffling
            ? (Matrix4.identity()..translateByDouble(
                (service.shuffleCount % 2 == 0 ? 1.0 : -1.0),
                0.0,
                0.0,
                1.0,
              ))
            : Matrix4.identity(),
        child: Semantics(
          label: showWord
              ? 'Word tile: $word${isSelected ? " (selected)" : ""}'
              : 'Hidden word tile',
          hint: isPlay
              ? 'Tap to reveal and select this word'
              : 'Word tile (memorize phase)',
          button: isPlay,
          child: GestureDetector(
            onTap: isPlay
                ? () {
                    // Tap once to reveal AND SELECT
                    if (!showWord) {
                      service.revealWord(word);
                      // Read word with TTS if enabled (premium only)
                      // Capture context and mounted before callback
                      final capturedContext = context;
                      final isMounted = mounted;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!isMounted) return;
                        final subscriptionService =
                            Provider.of<SubscriptionService>(
                              capturedContext,
                              listen: false,
                            );
                        if (subscriptionService.isPremium) {
                          final ttsService = Provider.of<TextToSpeechService>(
                            capturedContext,
                            listen: false,
                          );
                          if (ttsService.isEnabled) {
                            ttsService.speak(word);
                          }
                        }
                      });
                    }
                    // If word is revealed or was just revealed, select it
                    if (service.revealedWords.contains(word) ||
                        service.currentTrivia?.correctAnswers.contains(word) ==
                            true) {
                      service.toggleTileSelection(word);
                    }
                  }
                : null,
            child: InkWell(
              onTap: null, // Handled by GestureDetector
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: showCardBack
                          ? Icon(
                              Icons.help_outline,
                              color: Colors.white.withValues(alpha: 0.7),
                              size: 40,
                            )
                          : isResult &&
                                !service.lastCorrectAnswers.contains(word) &&
                                service.lastSelectedAnswers.contains(word)
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      word,
                                      style: AppTypography.labelLarge.copyWith(
                                        fontSize: tileFontSize,
                                        color: textColor,
                                        letterSpacing: 0.3,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.visible,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ],
                            )
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                showWord ? word : '?',
                                style: AppTypography.labelLarge.copyWith(
                                  fontSize: tileFontSize,
                                  color: textColor,
                                  letterSpacing: 0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.visible,
                              ),
                            ),
                    ),
                  ),
                  // Info icon - only show in result phase when word is visible
                  if (isResult && showWord)
                    Positioned(
                      top: AppSpacing.xs,
                      right: AppSpacing.xs,
                      child: Semantics(
                        label: 'Word information for $word',
                        button: true,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () =>
                                _showWordInfoDialog(context, word, service),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(AppSpacing.xs),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.info_outline,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(GameService service) {
    return Consumer<SubscriptionService>(
      builder: (context, subscriptionService, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg - 4,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Reveal All button
              Semantics(
                label:
                    'Reveal all correct answers. ${service.revealAllUses} uses remaining',
                button: true,
                enabled: service.revealAllUses > 0,
                child: TextButton.icon(
                  onPressed: service.revealAllUses > 0
                      ? () {
                          service.revealAllWords();
                          // Read revealed words with TTS if enabled (premium only)
                          if (subscriptionService.isPremium) {
                            final ttsService = Provider.of<TextToSpeechService>(
                              context,
                              listen: false,
                            );
                            final currentTrivia = service.currentTrivia;
                            if (ttsService.isEnabled && currentTrivia != null) {
                              final words = currentTrivia.correctAnswers.join(
                                ', ',
                              );
                              ttsService.speak(words);
                            }
                          }
                        }
                      : null,
                  icon: const Icon(
                    Icons.visibility_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: Text(
                    'Reveal (${service.revealAllUses})',
                    style: AppTypography.bodyMedium.copyWith(
                      fontSize: 14,
                      color: Colors.white.withValues(
                        alpha: service.revealAllUses > 0 ? 1.0 : 0.5,
                      ),
                    ),
                  ),
                ),
              ),
              // Clear button
              Semantics(
                label:
                    'Clear all selections. ${service.clearUses} uses remaining',
                button: true,
                enabled: service.clearUses > 0,
                child: TextButton.icon(
                  onPressed: service.clearUses > 0
                      ? () => service.clearSelections()
                      : null,
                  icon: const Icon(
                    Icons.clear_all,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: Text(
                    'Clear (${service.clearUses})',
                    style: AppTypography.bodyMedium.copyWith(
                      fontSize: 14,
                      color: Colors.white.withValues(
                        alpha: service.clearUses > 0 ? 1.0 : 0.5,
                      ),
                    ),
                  ),
                ),
              ),
              // Skip button
              Semantics(
                label: 'Skip current round. ${service.skipUses} uses remaining',
                button: true,
                enabled: service.skipUses > 0,
                child: TextButton.icon(
                  onPressed: service.skipUses > 0
                      ? () async {
                          if (!mounted) return;
                          final buildContext = context;
                          try {
                            final generator =
                                Provider.of<TriviaGeneratorService>(
                                  buildContext,
                                  listen: false,
                                );
                            final analyticsService =
                                Provider.of<AnalyticsService>(
                                  buildContext,
                                  listen: false,
                                );

                            // Use retry logic for better reliability
                            final triviaPool = await _generateTriviaWithRetry(
                              buildContext,
                              generator,
                              analyticsService,
                              service.currentMode.name,
                            );

                            if (!mounted || !buildContext.mounted) return;
                            if (triviaPool.isNotEmpty) {
                              service.skipRound(triviaPool);
                            } else {
                              _showTriviaErrorDialog(
                                buildContext,
                                'No trivia content available after multiple attempts. Please try again.',
                              );
                            }
                          } catch (e) {
                            if (!mounted || !buildContext.mounted) return;
                            if (kDebugMode) {
                              debugPrint('Failed to load trivia for skip: $e');
                            }
                            // Provide specific error message
                            String errorMessage =
                                'Failed to load trivia content. ';
                            if (e.toString().contains(
                              'No templates available',
                            )) {
                              errorMessage +=
                                  'Template initialization issue. Please restart the app.';
                            } else {
                              errorMessage += 'Please try again.';
                            }
                            _showTriviaErrorDialog(buildContext, errorMessage);
                          }
                        }
                      : null,
                  icon: const Icon(
                    Icons.skip_next,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: Text(
                    'Skip (${service.skipUses})',
                    style: AppTypography.bodyMedium.copyWith(
                      fontSize: 14,
                      color: Colors.white.withValues(
                        alpha: service.skipUses > 0 ? 1.0 : 0.5,
                      ),
                    ),
                  ),
                ),
              ),
              // Voice input button (Premium only)
              if (subscriptionService.isPremium)
                Consumer2<
                  VoiceRecognitionService,
                  PronunciationDictionaryService
                >(
                  builder: (context, voiceService, pronunciationService, _) {
                    return Semantics(
                      label: 'Voice Input',
                      button: true,
                      enabled:
                          voiceService.isEnabled && voiceService.isAvailable,
                      child: IconButton(
                        onPressed:
                            voiceService.isEnabled && voiceService.isAvailable
                            ? () => _handleVoiceInput(
                                context,
                                service,
                                voiceService,
                                pronunciationService,
                              )
                            : null,
                        icon: Icon(
                          voiceService.isListening ? Icons.mic : Icons.mic_none,
                          color: voiceService.isListening
                              ? AppColors.of(context).error
                              : Colors.white.withValues(
                                  alpha: voiceService.isEnabled ? 1.0 : 0.5,
                                ),
                          size: 24,
                        ),
                        tooltip:
                            AppLocalizations.of(context)?.hintButton ??
                            'Voice Input',
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // Advanced power-ups row (Premium only)
  Widget _buildAdvancedPowerUps(GameService service) {
    return Consumer<SubscriptionService>(
      builder: (context, subscriptionService, _) {
        if (!subscriptionService.isPremium) return const SizedBox.shrink();
        final colors = AppColors.of(context);

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg - 4,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Streak Shield
              Semantics(
                label:
                    'Streak Shield power-up. ${service.streakShieldUses} uses remaining',
                button: true,
                enabled:
                    service.streakShieldUses > 0 && !service.hasStreakShield,
                child: IconButton(
                  onPressed:
                      service.streakShieldUses > 0 && !service.hasStreakShield
                      ? () => service.activateStreakShield()
                      : null,
                  icon: Icon(
                    Icons.shield,
                    color: service.hasStreakShield
                        ? colors.warning
                        : Colors.white.withValues(
                            alpha: service.streakShieldUses > 0 ? 1.0 : 0.5,
                          ),
                    size: 20,
                  ),
                  tooltip: 'Streak Shield (${service.streakShieldUses})',
                ),
              ),
              // Time Freeze
              Semantics(
                label:
                    'Time Freeze power-up. ${service.timeFreezeUses} uses remaining',
                button: true,
                enabled: service.timeFreezeUses > 0 && !service.isTimeFrozen,
                child: IconButton(
                  onPressed: service.timeFreezeUses > 0 && !service.isTimeFrozen
                      ? () => service.activateTimeFreeze()
                      : null,
                  icon: Icon(
                    Icons.pause_circle_outline,
                    color: service.isTimeFrozen
                        ? Colors.cyan
                        : Colors.white.withValues(
                            alpha: service.timeFreezeUses > 0 ? 1.0 : 0.5,
                          ),
                    size: 20,
                  ),
                  tooltip: 'Time Freeze (${service.timeFreezeUses})',
                ),
              ),
              // Hint
              Semantics(
                label: 'Hint power-up. ${service.hintUses} uses remaining',
                button: true,
                enabled: service.hintUses > 0,
                child: IconButton(
                  onPressed: service.hintUses > 0
                      ? () => service.activateHint()
                      : null,
                  icon: Icon(
                    Icons.lightbulb_outline,
                    color: Colors.white.withValues(
                      alpha: service.hintUses > 0 ? 1.0 : 0.5,
                    ),
                    size: 20,
                  ),
                  tooltip:
                      AppLocalizations.of(context)?.hintButton ??
                      'Hint (${service.hintUses})',
                ),
              ),
              // Double Score
              Semantics(
                label:
                    'Double Score power-up. ${service.doubleScoreUses} uses remaining',
                button: true,
                enabled: service.doubleScoreUses > 0 && !service.hasDoubleScore,
                child: IconButton(
                  onPressed:
                      service.doubleScoreUses > 0 && !service.hasDoubleScore
                      ? () => service.activateDoubleScore()
                      : null,
                  icon: Icon(
                    Icons.stars,
                    color: service.hasDoubleScore
                        ? colors.warning
                        : Colors.white.withValues(
                            alpha: service.doubleScoreUses > 0 ? 1.0 : 0.5,
                          ),
                    size: 20,
                  ),
                  tooltip: 'Double Score (${service.doubleScoreUses})',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleVoiceInput(
    BuildContext context,
    GameService gameService,
    VoiceRecognitionService voiceService,
    PronunciationDictionaryService pronunciationService,
  ) {
    // Capture context and mounted before callbacks
    final capturedContext = context;
    final isMounted = mounted;

    if (voiceService.isListening) {
      voiceService.stop();
    } else {
      voiceService.startListening(
        onResult: (spokenText) {
          if (!isMounted) return;

          // Match spoken text to available words
          final availableWords = gameService.shuffledWords;
          final matchedWord = voiceService.matchSpokenWord(
            spokenText,
            availableWords,
          );

          if (matchedWord != null) {
            // Reveal and select the matched word
            if (!gameService.revealedWords.contains(matchedWord)) {
              gameService.revealWord(matchedWord);
            }
            gameService.toggleTileSelection(matchedWord);

            // Provide feedback with TTS
            if (!isMounted) return;
            final subscriptionService = Provider.of<SubscriptionService>(
              capturedContext,
              listen: false,
            );
            if (subscriptionService.isPremium) {
              final ttsService = Provider.of<TextToSpeechService>(
                capturedContext,
                listen: false,
              );
              if (ttsService.isEnabled) {
                ttsService.speak('Selected $matchedWord');
              }
            }
          } else {
            // No match found
            if (!isMounted) return;
            final subscriptionService = Provider.of<SubscriptionService>(
              capturedContext,
              listen: false,
            );
            if (subscriptionService.isPremium) {
              final ttsService = Provider.of<TextToSpeechService>(
                capturedContext,
                listen: false,
              );
              if (ttsService.isEnabled) {
                ttsService.speak('Word not recognized');
              }
            }
          }
        },
      );
    }
  }

  Widget _buildSubmitButton(GameService service) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: Semantics(
          label: 'Submit answers',
          button: true,
          enabled: service.canSubmit,
          child: ElevatedButton(
            onPressed: service.canSubmit ? () => service.submitAnswers() : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.of(context).primaryButton,
              foregroundColor: AppColors.of(context).buttonText,
              disabledBackgroundColor: AppColors.of(context).tertiaryText,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Submit', style: AppTypography.labelLarge),
          ),
        ),
      ),
    );
  }

  Widget _buildNextRoundButton(BuildContext context, GameService service) {
    // Capture context and mounted before callbacks
    final capturedContext = context;
    final isMounted = mounted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: Semantics(
          label: AppLocalizations.of(context)?.nextRound ?? 'Next round',
          button: true,
          child: ElevatedButton(
            onPressed: () async {
              if (!isMounted) return;
              // Capture context references before async calls
              final scaffoldMessenger = ScaffoldMessenger.of(capturedContext);

              // Track AI mode performance before next round
              if (service.currentMode == GameMode.ai) {
                if (!isMounted) return;
                final aiModeService = Provider.of<AIModeService>(
                  capturedContext,
                  listen: false,
                );
                final currentTrivia = service.currentTrivia;
                if (currentTrivia != null) {
                  final numCorrect = service.correctCount;
                  final wasCorrect = numCorrect == 3;
                  final category = currentTrivia.category;

                  // Calculate actual response time from round start
                  final actualResponseTime =
                      service.aiModeResponseTime ??
                      30.0; // Fallback to 30s if not available
                  final config = service.currentConfig;

                  await aiModeService.updatePerformance(
                    wasCorrect: wasCorrect,
                    category: category,
                    responseTime: actualResponseTime,
                    memorizeTime: config.memorizeTime,
                    playTime: config.playTime,
                  );

                  // Check mounted after async operation
                  if (!isMounted || !capturedContext.mounted) return;

                  // Get updated timing for next round
                  final (newMemorizeTime, newPlayTime) = aiModeService
                      .getRecommendedTiming();

                  // Update game service timing for AI mode
                  service.setAIModeTiming(newMemorizeTime, newPlayTime);
                }
              }

              try {
                final generator = Provider.of<TriviaGeneratorService>(
                  capturedContext,
                  listen: false,
                );
                final analyticsService = Provider.of<AnalyticsService>(
                  capturedContext,
                  listen: false,
                );

                // Use retry logic for better reliability
                final triviaPool = await _generateTriviaWithRetry(
                  capturedContext,
                  generator,
                  analyticsService,
                  service.currentMode.name,
                );

                if (triviaPool.isNotEmpty) {
                  service.nextRound(triviaPool);
                } else {
                  if (isMounted && capturedContext.mounted) {
                    _showTriviaErrorDialog(
                      capturedContext,
                      'No trivia content available after multiple attempts. Please try again.',
                    );
                  }
                }
              } catch (e) {
                if (isMounted && capturedContext.mounted) {
                  if (kDebugMode) {
                    debugPrint('Failed to load trivia for next round: $e');
                  }
                  // Provide specific error message
                  String errorMessage = 'Failed to load trivia content. ';
                  if (e.toString().contains('No templates available')) {
                    errorMessage +=
                        'Template initialization issue. Please restart the app.';
                  } else if (e.toString().contains(
                    'Unable to generate unique trivia',
                  )) {
                    errorMessage +=
                        'All available content has been used. Try clearing history.';
                  } else {
                    errorMessage += 'Please try again.';
                  }
                  _showTriviaErrorDialog(capturedContext, errorMessage);
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(errorMessage),
                      backgroundColor: AppColors.error,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.of(context).cardBackground,
              foregroundColor: AppColors.of(context).primaryText,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Next Round', style: AppTypography.labelLarge),
          ),
        ),
      ),
    );
  }

  Widget _buildGameOverScreen(BuildContext context, GameService service) {
    // Check if competitive challenge
    final args = ModalRoute.of(context)?.settings.arguments;
    final isCompetitive =
        args is Map<String, dynamic> && args['competitiveChallengeId'] != null;

    // Submit competitive challenge score and show feedback
    if (isCompetitive) {
      final challengeId = args['competitiveChallengeId'] as String?;
      // Capture context and mounted before callback
      final capturedContext = context;
      final isMounted = mounted;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!isMounted || !capturedContext.mounted) return;
        final scaffoldMessenger = ScaffoldMessenger.of(capturedContext);
        final challengeService = Provider.of<ChallengeService>(
          capturedContext,
          listen: false,
        );

        final response = await service.submitCompetitiveChallengeScore();
        if (!isMounted || !capturedContext.mounted) return;

        // Mark challenge as completed if score was submitted successfully
        if (response.isSuccess && challengeId != null) {
          try {
            await challengeService.completeChallenge(challengeId);
            if (!isMounted || !capturedContext.mounted) return;
          } catch (e) {
            if (kDebugMode) {
              debugPrint('Error marking challenge as completed: $e');
            }
            if (!isMounted || !capturedContext.mounted) {
              return; // Check after catch
            }
          }
        }

        // Show appropriate message based on result
        if (!isMounted || !capturedContext.mounted) return;
        if (response.isSuccess) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                response.message ?? 'Score submitted to leaderboard!',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          String errorMsg = response.message ?? 'Failed to submit score';
          Color bgColor = Colors.orange;

          switch (response.result) {
            case SubmissionResult.maxAttemptsReached:
              errorMsg = 'Maximum attempts (5) reached for this challenge.';
              bgColor = Colors.red;
              break;
            case SubmissionResult.scoreNotImproved:
              errorMsg = response.message ?? 'Score did not improve.';
              bgColor = Colors.orange;
              break;
            case SubmissionResult.networkError:
              errorMsg = 'Network error. Your score will be saved for retry.';
              bgColor = Colors.orange;
              break;
            case SubmissionResult.permissionDenied:
              errorMsg = 'Permission denied. Please check your account.';
              bgColor = Colors.red;
              break;
            case SubmissionResult.challengeInvalid:
              errorMsg = response.message ?? 'Challenge expired or invalid.';
              bgColor = Colors.red;
              break;
            default:
              errorMsg = response.message ?? 'Unable to submit score.';
          }

          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: bgColor,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      });
    }

    // Record analytics when game over screen is shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // CRITICAL: Check if widget is still mounted before accessing context/Provider
      if (!mounted || !context.mounted) return;

      try {
        final analyticsService = Provider.of<AnalyticsService>(
          context,
          listen: false,
        );

        // Game tracking for free tier is done when game starts, not when it ends
        // This ensures users get exactly 5 games per day regardless of outcome

        final totalAnswers =
            service.sessionCorrectAnswers + service.sessionWrongAnswers;
        final accuracy = totalAnswers > 0
            ? (service.sessionCorrectAnswers / totalAnswers) * 100.0
            : 0.0;

        final currentTrivia = service.currentTrivia;
        if (currentTrivia != null) {
          analyticsService.recordGameSession(
            score: service.state.score.toDouble(),
            accuracy: accuracy,
            gamesPlayed: service.state.round - 1,
            category: currentTrivia.category,
            triviaItem: currentTrivia,
          );
        }
      } catch (e) {
        // Provider might not be available if widget tree was disposed
        // Silently fail - analytics are non-critical
        if (kDebugMode) {
          debugPrint('Failed to record analytics in game over: $e');
        }
      }
    });

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.emoji_events_outlined,
              size: 80,
              color: Colors.white,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Game Over',
              style: AppTypography.displayLarge.copyWith(
                fontSize: 36,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            // Final Score
            Text(
              'Final Score',
              style: AppTypography.bodyMedium.copyWith(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.8),
                letterSpacing: 1.0,
              ),
            ),
            Text(
              '${service.state.score}',
              style: AppTypography.displayLarge.copyWith(
                fontSize: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            // Additional Statistics
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg - 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildStatRow('Rounds Played', '${service.state.round - 1}'),
                  const SizedBox(height: AppSpacing.sm + 4),
                  _buildStatRow(
                    'Correct Answers',
                    '${service.sessionCorrectAnswers}',
                  ),
                  const SizedBox(height: AppSpacing.sm + 4),
                  _buildStatRow(
                    'Wrong Answers',
                    '${service.sessionWrongAnswers}',
                  ),
                  const SizedBox(height: AppSpacing.sm + 4),
                  _buildStatRow(
                    'Accuracy',
                    service.sessionCorrectAnswers +
                                service.sessionWrongAnswers >
                            0
                        ? '${((service.sessionCorrectAnswers / (service.sessionCorrectAnswers + service.sessionWrongAnswers)) * 100).toStringAsFixed(1)}%'
                        : '0%',
                  ),
                  if (service.state.perfectStreak > 0) ...[
                    const SizedBox(height: AppSpacing.sm + 4),
                    _buildStatRow(
                      'Perfect Streak',
                      '${service.state.perfectStreak}',
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => NavigationHelper.safeNavigate(
                  context,
                  '/general-transition',
                  arguments: {'routeAfter': '/title', 'routeArgs': null},
                  replace: true,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.of(context).cardBackground,
                  foregroundColor: AppColors.of(context).primaryText,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context)?.backToMenu ?? 'Back to Menu',
                  style: AppTypography.labelLarge,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Generate trivia with retry logic and fallback themes
  /// Attempts to generate trivia, falling back to different themes if initial attempt fails
  /// Includes offline mode support - checks for downloaded packs if network fails
  Future<List<TriviaItem>> _generateTriviaWithRetry(
    BuildContext context,
    TriviaGeneratorService generator,
    AnalyticsService analyticsService,
    String mode,
  ) async {
    const maxRetries = 3;
    final networkService = Provider.of<NetworkService>(context, listen: false);
    final offlineService = Provider.of<OfflineService>(context, listen: false);

    // First attempt: try with no theme (all templates)
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final pool = generator.generateBatch(50);
        if (pool.isNotEmpty) {
          return pool;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            'Trivia generation attempt ${attempt + 1}/$maxRetries failed: $e',
          );
        }

        // If it's a theme-specific error, try different themes
        if (e.toString().contains('No templates available for theme')) {
          // Get available themes and try a random one
          final availableThemes = generator.getAvailableThemes();
          if (availableThemes.isNotEmpty) {
            final randomTheme =
                availableThemes[DateTime.now().millisecondsSinceEpoch %
                    availableThemes.length];
            try {
              final pool = generator.generateBatch(50, theme: randomTheme);
              if (pool.isNotEmpty) {
                if (kDebugMode) {
                  debugPrint(
                    'Successfully generated trivia with fallback theme: $randomTheme',
                  );
                }
                return pool;
              }
            } catch (_) {
              // Continue to next attempt
            }
          }
        }

        // Wait before retry (exponential backoff)
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(milliseconds: 100 * (attempt + 1)));
        }
      }
    }

    // All retries failed - check for offline packs if network is unavailable
    if (!networkService.isConnected &&
        offlineService.downloadedPacks.isNotEmpty) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ Network unavailable. Attempting to load offline trivia pack.',
        );
      }

      // Try to load the most recently downloaded pack
      // CRITICAL: Check list is not empty before accessing .last to prevent crash
      if (offlineService.downloadedPacks.isNotEmpty) {
        try {
          final mostRecentPack = offlineService.downloadedPacks.last;
          final offlineTrivia = await offlineService.loadPack(mostRecentPack);
          if (offlineTrivia != null && offlineTrivia.isNotEmpty) {
            if (kDebugMode) {
              debugPrint(
                '✓ Loaded offline trivia pack: $mostRecentPack (${offlineTrivia.length} items)',
              );
            }
            return offlineTrivia;
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Failed to load offline pack: $e');
          }
        }
      }

      // Try all downloaded packs
      for (final packId in offlineService.downloadedPacks.reversed) {
        try {
          final offlineTrivia = await offlineService.loadPack(packId);
          if (offlineTrivia != null && offlineTrivia.isNotEmpty) {
            if (kDebugMode) {
              debugPrint(
                '✓ Loaded offline trivia pack: $packId (${offlineTrivia.length} items)',
              );
            }
            return offlineTrivia;
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Failed to load offline pack $packId: $e');
          }
        }
      }
    }

    // All retries failed - use emergency fallback trivia
    if (kDebugMode) {
      debugPrint(
        '⚠️ All trivia generation attempts failed. Using emergency fallback trivia.',
      );
    }

    // Emergency fallback: Generate basic trivia from any available templates
    try {
      final emergencyPool = generator.generateBatch(
        10,
        theme: null, // Use all themes
      );
      if (emergencyPool.isNotEmpty) {
        if (kDebugMode) {
          debugPrint(
            '✓ Emergency fallback trivia generated successfully (${emergencyPool.length} items)',
          );
        }
        return emergencyPool;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Emergency fallback also failed: $e');
      }
    }

    // Last resort: Create minimal trivia items manually
    final lastResortTrivia = [
      TriviaItem(
        category: 'General Knowledge',
        words: ['Paris', 'London', 'Tokyo', 'Berlin', 'Madrid', 'Rome'],
        correctAnswers: ['Paris', 'London', 'Tokyo'],
      ),
      TriviaItem(
        category: 'Colors',
        words: ['Red', 'Blue', 'Green', 'Yellow', 'Orange', 'Purple'],
        correctAnswers: ['Red', 'Blue', 'Green'],
      ),
      TriviaItem(
        category: 'Animals',
        words: ['Dog', 'Cat', 'Bird', 'Fish', 'Lion', 'Tiger'],
        correctAnswers: ['Dog', 'Cat', 'Bird'],
      ),
    ];

    if (kDebugMode) {
      debugPrint(
        '⚠️ Using last resort hardcoded trivia (${lastResortTrivia.length} items)',
      );
    }

    return lastResortTrivia;
  }

  /// Show save failure warning dialog
  Future<void> _showSaveFailureWarning(
    BuildContext context,
    String title,
    String message,
  ) async {
    if (!mounted || !context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final dialogColors = AppColors.of(dialogContext);
        return AlertDialog(
          backgroundColor: dialogColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: dialogColors.warning,
                size: 24,
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  title,
                  style: AppTypography.headlineMedium.copyWith(
                    color: dialogColors.primaryText,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: AppTypography.bodyMedium.copyWith(
              color: dialogColors.secondaryText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => NavigationHelper.safePop(dialogContext),
              child: Text(
                AppLocalizations.of(context)?.ok ?? 'OK',
                style: AppTypography.labelLarge.copyWith(
                  color: dialogColors.primaryButton,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showTriviaErrorDialog(
    BuildContext context,
    String message,
  ) async {
    if (!mounted || !context.mounted) return;

    // Log trivia error analytics
    try {
      final analyticsService = Provider.of<AnalyticsService>(
        context,
        listen: false,
      );
      await analyticsService.logError('trivia_error_dialog', message);
    } catch (e) {
      // Ignore analytics errors - don't block dialog display
      if (kDebugMode) {
        debugPrint('Failed to log trivia error analytics: $e');
      }
    }

    // Check mounted after async operation
    if (!mounted || !context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final dialogColors = AppColors.of(dialogContext);
        return AlertDialog(
          backgroundColor: dialogColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 24),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Trivia Error',
                style: AppTypography.displayMedium.copyWith(
                  fontSize: 20,
                  color: AppColors.of(context).primaryText,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: AppTypography.bodyMedium.copyWith(
              fontSize: 15,
              color: AppColors.of(context).secondaryText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (!context.mounted) return;
                NavigationHelper.safePop(dialogContext);
                // Navigate back to title screen
                NavigationHelper.safePop(context);
              },
              child: Text(
                'Go Back',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.of(context).primaryText,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                if (!context.mounted) return;
                NavigationHelper.safePop(dialogContext);
                // Retry by navigating back and triggering reinit
                NavigationHelper.safePop(context);
              },
              child: Text(
                'Retry',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.of(context).primaryButton,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showUpgradeDialog(
    BuildContext context,
    String feature,
    String message,
  ) async {
    if (!mounted || !context.mounted) return;

    // Log subscription prompt analytics
    try {
      final analyticsService = Provider.of<AnalyticsService>(
        context,
        listen: false,
      );
      final subscriptionService = Provider.of<SubscriptionService>(
        context,
        listen: false,
      );
      await analyticsService.logError(
        'subscription_required_dialog',
        'Feature: $feature, Current tier: ${subscriptionService.tierName}',
      );
    } catch (e) {
      // Ignore analytics errors - don't block dialog display
      if (kDebugMode) {
        debugPrint('Failed to log subscription prompt analytics: $e');
      }
    }

    // Check mounted after async operation
    if (!mounted || !context.mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '$feature - Premium Feature',
          style: AppTypography.displayMedium.copyWith(fontSize: 20),
        ),
        content: Text(message, style: AppTypography.bodyMedium),
        actions: [
          TextButton(
            onPressed: () {
              if (context.mounted) NavigationHelper.safePop(context);
            },
            child: Text(
              AppLocalizations.of(context)?.cancel ?? 'Cancel',
              style: AppTypography.labelLarge,
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (context.mounted) {
                NavigationHelper.safePop(context); // Close dialog
                NavigationHelper.safeNavigate(
                  context,
                  '/subscription-management',
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.of(context).primaryButton,
            ),
            child: Text(
              AppLocalizations.of(context)?.upgrade ?? 'Upgrade',
              style: AppTypography.labelLarge.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showGameOverLimitDialog(BuildContext context) async {
    final freeTierService = Provider.of<FreeTierService>(
      context,
      listen: false,
    );
    final analyticsService = Provider.of<AnalyticsService>(
      context,
      listen: false,
    );

    // Log funnel step 1: Viewed locked feature
    await analyticsService.logConversionFunnelStep(
      step: 1,
      stepName: 'viewed_locked_feature',
      source: 'daily_limit',
    );

    // Log upgrade dialog shown
    await analyticsService.logUpgradeDialogShown(
      source: 'daily_limit',
      targetTier: 'basic', // Basic unlocks unlimited games
    );

    // Check if widget is still mounted before using context
    if (!mounted || !context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          'Daily Game Limit Reached',
          style: AppTypography.displayMedium.copyWith(fontSize: 20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have reached your daily limit of ${freeTierService.maxGamesPerDay} games for today.',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Games reset: ${freeTierService.getNextResetString()}',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.of(context).secondaryText,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Upgrade to Basic or Premium for unlimited play!',
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Log upgrade dialog dismissed
              analyticsService.logUpgradeDialogDismissed(
                source: 'daily_limit',
                targetTier: 'basic',
              );
              if (context.mounted) {
                NavigationHelper.safePop(context); // Go back to mode selection
              }
            },
            child: Text(
              AppLocalizations.of(context)?.cancel ?? 'Cancel',
              style: AppTypography.labelLarge,
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (context.mounted) {
                NavigationHelper.safePop(context); // Close dialog
                NavigationHelper.safeNavigate(
                  context,
                  '/subscription-management',
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.of(context).primaryButton,
            ),
            child: Text(
              AppLocalizations.of(context)?.upgrade ?? 'Upgrade',
              style: AppTypography.labelLarge.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.bodyMedium.copyWith(
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        Text(
          value,
          style: AppTypography.headlineLarge.copyWith(
            fontSize: 18,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  void _showWordInfoDialog(
    BuildContext context,
    String word,
    GameService service,
  ) {
    final trivia = service.currentTrivia;
    final isCorrect = service.lastCorrectAnswers.contains(word);

    showDialog(
      context: context,
      builder: (context) {
        final dialogColors = AppColors.of(context);
        return AlertDialog(
          backgroundColor: dialogColors.cardBackground,
          title: Text(
            word,
            style: AppTypography.headlineLarge.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick description if available
                if (trivia != null && isCorrect)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md - 4),
                      decoration: BoxDecoration(
                        color: dialogColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: dialogColors.success.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Correct Answer',
                            style: AppTypography.labelSmall.copyWith(
                              color: dialogColors.success,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'This is one of the correct answers for: ${trivia.category}',
                            style: AppTypography.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),

                const Divider(),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Look up information:',
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md - 4),

                // Google Search
                ListTile(
                  leading: Icon(Icons.search, color: dialogColors.info),
                  title: const Text('Google Search'),
                  contentPadding: EdgeInsets.zero,
                  onTap: () async {
                    try {
                      final url = Uri.parse(
                        'https://www.google.com/search?q=${Uri.encodeComponent(word)}',
                      );
                      if (await canLaunchUrl(url)) {
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not open Google Search'),
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Error opening Google Search'),
                          ),
                        );
                      }
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                ),

                // Wikipedia
                ListTile(
                  leading: const Icon(Icons.article, color: Colors.green),
                  title: const Text('Wikipedia'),
                  contentPadding: EdgeInsets.zero,
                  onTap: () async {
                    try {
                      final url = Uri.parse(
                        'https://en.wikipedia.org/wiki/${Uri.encodeComponent(word)}',
                      );
                      if (await canLaunchUrl(url)) {
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not open Wikipedia'),
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Error opening Wikipedia'),
                          ),
                        );
                      }
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                ),

                // Dictionary.com
                ListTile(
                  leading: const Icon(Icons.book, color: Colors.orange),
                  title: const Text('Dictionary.com'),
                  contentPadding: EdgeInsets.zero,
                  onTap: () async {
                    try {
                      final url = Uri.parse(
                        'https://www.dictionary.com/browse/${Uri.encodeComponent(word)}',
                      );
                      if (await canLaunchUrl(url)) {
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not open Dictionary.com'),
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Error opening Dictionary.com'),
                          ),
                        );
                      }
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                ),

                // Merriam-Webster
                ListTile(
                  leading: const Icon(Icons.menu_book, color: Colors.purple),
                  title: const Text('Merriam-Webster'),
                  contentPadding: EdgeInsets.zero,
                  onTap: () async {
                    try {
                      final url = Uri.parse(
                        'https://www.merriam-webster.com/dictionary/${Uri.encodeComponent(word)}',
                      );
                      if (await canLaunchUrl(url)) {
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not open Merriam-Webster'),
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Error opening Merriam-Webster'),
                          ),
                        );
                      }
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(
                AppLocalizations.of(context)?.close ?? 'Close',
                style: AppTypography.labelLarge,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // CRITICAL: Check mounted before any context operations
    if (!mounted || !context.mounted) return;

    final gameService = Provider.of<GameService>(context, listen: false);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Pause game when app backgrounds or becomes inactive
      // This ensures timers don't continue running when user switches apps
      LoggerService.debug('App backgrounded - pausing game timers');
      // CRITICAL: Check context.mounted before service operations that might trigger UI updates
      if (mounted && context.mounted) {
        gameService.pauseGame();
      }
    } else if (state == AppLifecycleState.resumed) {
      // Resume game when app comes to foreground
      // This restores timers and game state
      LoggerService.debug('App foregrounded - resuming game timers');

      // CRITICAL: Check context.mounted before accessing context
      if (!mounted || !context.mounted) return;

      // Check if game state was recovered (game is in progress)
      final hasActiveGame =
          !gameService.state.isGameOver && gameService.currentTrivia != null;

      if (hasActiveGame && mounted && context.mounted) {
        // Show subtle notification that game state was recovered
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Game state recovered'),
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.of(context).success,
          ),
        );
      }

      // CRITICAL: Check context.mounted before resuming game
      if (mounted && context.mounted) {
        gameService.resumeGame();
      }
    }
  }
}
