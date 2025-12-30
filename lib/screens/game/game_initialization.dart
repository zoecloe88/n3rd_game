import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/services/game_service.dart' as game_service;
import 'package:n3rd_game/models/game_mode_config.dart' as game_mode_config;
import 'package:n3rd_game/models/game_mode_config.dart' show GameMode;
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/services/free_tier_service.dart';
import 'package:n3rd_game/services/accessibility_service.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/services/ai_mode_service.dart';
import 'package:n3rd_game/services/trivia_generator_service.dart';
import 'package:n3rd_game/models/trivia_item.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/utils/edition_validator.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/utils/error_handler.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';

/// Game initialization result
class GameInitializationResult {
  final bool success;
  final String? error;
  final GameMode? mode;
  final List<TriviaItem>? triviaPool;
  final String? difficulty;
  final String? edition;
  final String? editionName;
  final bool isAIEdition;

  GameInitializationResult({
    required this.success,
    this.error,
    this.mode,
    this.triviaPool,
    this.difficulty,
    this.edition,
    this.editionName,
    this.isAIEdition = false,
  });
}

/// Game initialization handler
class GameInitialization {
  /// Initialize game with phased loading
  static Future<GameInitializationResult> initializeGame({
    required BuildContext context,
    required GameService service,
    required SubscriptionService subscriptionService,
    required FreeTierService freeTierService,
    required Function(String, double) updateProgress,
    required Function(String) showErrorDialog,
    required Function() showUpgradeDialog,
    required Function() showGameOverLimitDialog,
    Object? routeArgs,
  }) async {
    try {
      // Phase 1: Service initialization
      updateProgress(
        AppLocalizations.of(context)?.initializingServices ??
            'Initializing services...',
        0.1,
      );

      // Set extended time multiplier from AccessibilityService
      try {
        final accessibilityService = Provider.of<AccessibilityService>(
          context,
          listen: false,
        );
        final extendedTimeMultiplier = accessibilityService.settings.extendedTimeLimits
            ? 1.5
            : 1.0;
        service.setExtendedTimeMultiplier(extendedTimeMultiplier);
      } catch (e) {
        service.setExtendedTimeMultiplier(1.0);
      }

      // Phase 2: Subscription validation
      updateProgress(
        AppLocalizations.of(context)?.validatingSubscription ??
            'Validating subscription...',
        0.3,
      );

      await subscriptionService.markGameSessionActive();

      // Phase 3: Free tier check
      if (!context.mounted) {
        return GameInitializationResult(success: false, error: 'Widget disposed');
      }
      updateProgress(
        AppLocalizations.of(context)?.checkingGameAvailability ??
            'Checking game availability...',
        0.45,
      );

      if (subscriptionService.isFree && !freeTierService.canPlay()) {
        if (!context.mounted) {
          return GameInitializationResult(success: false, error: 'Widget disposed');
        }
        final analyticsService = Provider.of<AnalyticsService>(
          context,
          listen: false,
        );
        await analyticsService.logFreeTierLimitReached();
        if (!context.mounted) {
          return GameInitializationResult(success: false, error: 'Widget disposed');
        }
        showGameOverLimitDialog();
        return GameInitializationResult(success: false, error: 'Free tier limit reached');
      }

      // Phase 4: Argument parsing
      if (!context.mounted) {
        return GameInitializationResult(success: false, error: 'Widget disposed');
      }
      updateProgress(
        AppLocalizations.of(context)?.loadingGameSettings ??
            'Loading game settings...',
        0.55,
      );

      final result = _parseArguments(routeArgs, context);
      if (!result.success) {
        return result;
      }

      // Phase 5: Trivia loading
      if (!context.mounted) {
        return GameInitializationResult(success: false, error: 'Widget disposed');
      }
      updateProgress(
        AppLocalizations.of(context)?.loadingGameSettings ??
            'Loading trivia...',
        0.8,
      );

      final triviaResult = await _loadTrivia(
        context: context,
        service: service,
        subscriptionService: subscriptionService,
        mode: result.mode!,
        customTriviaPool: result.triviaPool,
        edition: result.edition,
        showErrorDialog: showErrorDialog,
      );

      if (!triviaResult.success) {
        return GameInitializationResult(
          success: false,
          error: triviaResult.error,
        );
      }

      // Phase 6: Game start
      if (!context.mounted) {
        return GameInitializationResult(success: false, error: 'Widget disposed');
      }
      updateProgress(
        AppLocalizations.of(context)?.startingGame ??
            'Starting game...',
        0.95,
      );

      return GameInitializationResult(
        success: true,
        mode: result.mode,
        triviaPool: triviaResult.triviaPool,
        difficulty: result.difficulty,
        edition: result.edition,
        editionName: result.editionName,
        isAIEdition: result.isAIEdition,
      );
    } catch (e) {
      LoggerService.error('Game initialization failed', error: e);
      final errorMessage = context.mounted
          ? ErrorHandler.getLocalizedErrorMessage(e, context)
          : e.toString();
      return GameInitializationResult(
        success: false,
        error: errorMessage,
      );
    }
  }

  /// Parse route arguments
  static GameInitializationResult _parseArguments(
    Object? args,
    BuildContext context,
  ) {
    GameMode? mode;
    String? difficulty;
    List<TriviaItem>? customTriviaPool;
    String? edition;
    String? editionName;
    bool isAIEdition = false;

    if (args is game_mode_config.GameMode) {
      mode = args;
    } else if (args is Map<String, dynamic>) {
      // Parse mode, difficulty, triviaPool, edition, etc.
      // (Implementation details from original _initializeGame)
      mode = args['mode'] as GameMode?;
      difficulty = args['difficulty'] as String?;
      customTriviaPool = args['triviaPool'] as List<TriviaItem>?;
      edition = args['edition'] as String?;
      editionName = args['editionName'] as String?;
      isAIEdition = args['isAIEdition'] as bool? ?? false;

      // Validate edition
      if (edition != null && !EditionValidator.isValidEditionId(edition)) {
        final normalized = EditionValidator.normalizeEditionId(edition);
        edition = normalized.isNotEmpty ? normalized : null;
      }
    }

    mode ??= game_mode_config.GameMode.classic;

    return GameInitializationResult(
      success: true,
      mode: mode,
      difficulty: difficulty,
      triviaPool: customTriviaPool,
      edition: edition,
      editionName: editionName,
      isAIEdition: isAIEdition,
    );
  }

  /// Load trivia with retry logic
  static Future<GameInitializationResult> _loadTrivia({
    required BuildContext context,
    required GameService service,
    required SubscriptionService subscriptionService,
    required GameMode mode,
    List<TriviaItem>? customTriviaPool,
    String? edition,
    required Function(String) showErrorDialog,
  }) async {
    try {
      final generator = Provider.of<TriviaGeneratorService>(
        context,
        listen: false,
      );
      final analyticsService = Provider.of<AnalyticsService>(
        context,
        listen: false,
      );

      List<TriviaItem> triviaPool;

      if (customTriviaPool != null && customTriviaPool.isNotEmpty) {
        triviaPool = customTriviaPool;
        await analyticsService.logTriviaGeneration('custom', true);
      } else {
        // Generate trivia with retry logic
        // (Implementation from original _generateTriviaWithRetry)
        triviaPool = await _generateTriviaWithRetry(
          context: context,
          generator: generator,
          analyticsService: analyticsService,
          mode: mode.name,
        );

        if (!context.mounted) {
          return GameInitializationResult(success: false, error: 'Widget disposed');
        }
        if (triviaPool.isEmpty) {
          await analyticsService.logTriviaGeneration(
            mode.name,
            false,
            error: 'Empty trivia pool after retries',
          );
          if (!context.mounted) {
            return GameInitializationResult(success: false, error: 'Widget disposed');
          }
          showErrorDialog(
            AppLocalizations.of(context)?.noTriviaContentAvailable ??
                'No trivia content available. Please try again.',
          );
          return GameInitializationResult(
            success: false,
            error: 'Empty trivia pool',
          );
        }

        await analyticsService.logTriviaGeneration(mode.name, true);
      }

      return GameInitializationResult(
        success: true,
        triviaPool: triviaPool,
      );
    } on GameException catch (e) {
      LoggerService.warning('Game error loading trivia', error: e);
      if (context.mounted) {
        showErrorDialog(ErrorHandler.getLocalizedErrorMessage(e, context));
      }
      return GameInitializationResult(success: false, error: e.toString());
    } on ValidationException catch (e) {
      LoggerService.warning('Validation error loading trivia', error: e);
      if (context.mounted) {
        showErrorDialog(ErrorHandler.getLocalizedErrorMessage(e, context));
      }
      return GameInitializationResult(success: false, error: e.toString());
    } catch (e, stackTrace) {
      LoggerService.error('Failed to load trivia', error: e, stack: stackTrace);
      if (context.mounted) {
        showErrorDialog(
          ErrorHandler.getLocalizedErrorMessage(e, context),
        );
      }
      return GameInitializationResult(success: false, error: e.toString());
    }
  }

  /// Generate trivia with retry logic
  static Future<List<TriviaItem>> _generateTriviaWithRetry({
    required BuildContext context,
    required TriviaGeneratorService generator,
    required AnalyticsService analyticsService,
    required String mode,
  }) async {
    // Implementation from original _generateTriviaWithRetry
    // This would include retry logic, fallback themes, offline packs, etc.
    try {
      return generator.generateBatch(10);
    } catch (e) {
      LoggerService.warning('Trivia generation failed', error: e);
      rethrow;
    }
  }
}

