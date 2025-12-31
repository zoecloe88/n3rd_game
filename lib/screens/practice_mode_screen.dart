import 'dart:math';
import 'package:n3rd_game/utils/unawaited_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/services/game_service.dart';
import 'package:n3rd_game/models/game_mode_config.dart';
import 'package:n3rd_game/services/trivia_generator_service.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/models/trivia_item.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/utils/provider_helper.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/widgets/video_background_widget.dart';
import 'package:n3rd_game/widgets/app_button.dart';
import 'package:n3rd_game/widgets/app_card.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/theme/app_radius.dart';
import 'package:n3rd_game/utils/feedback_helper.dart';
import 'package:n3rd_game/widgets/error_recovery_widget.dart';
import 'package:n3rd_game/widgets/standardized_loading_widget.dart';

/// Practice Mode screen for unlimited practice rounds
///
/// Features:
/// - Unlimited practice rounds with no score penalties
/// - Progressive hint levels (No Hints, Level 1, Level 2, Show Answer)
/// - Focus on learning without pressure
/// - Requires Premium subscription (enforced by RouteGuard)
///
/// Usage:
/// ```dart
/// Navigator.pushNamed(context, '/practice');
/// ```
///
/// Hint Levels:
/// - 0: No Hints - Standard gameplay
/// - 1: Hint Level 1 - Eliminate 1 wrong answer
/// - 2: Hint Level 2 - Eliminate 2 wrong answers
/// - 3: Show Answer - Reveal correct answers
class PracticeModeScreen extends StatefulWidget {
  const PracticeModeScreen({super.key});

  @override
  State<PracticeModeScreen> createState() => _PracticeModeScreenState();
}

class _PracticeModeScreenState extends State<PracticeModeScreen> {
  int _hintLevel =
      0; // 0 = no hint, 1 = eliminate 1 wrong, 2 = eliminate 2 wrong, 3 = show answer
  bool _isLoading = false;
  String? _errorMessage;

  // Constants
  static const int _defaultHintLevel = 0;
  static const int _triviaBatchSize = 50;
  static const int _maxRetryAttempts = 3;
  static const Duration _retryDelay = Duration(seconds: 1);
  static const Duration _errorSnackbarDuration = Duration(seconds: 4);
  static const String _videoPath = 'assets/modeselectionscreen.mp4';
  static const String _practiceTheme = 'practice';

  @override
  Widget build(BuildContext context) {
    // NOTE: Subscription access is enforced by RouteGuard in main.dart
    // No need for redundant check here
    final colors = AppColors.of(context);

    // Show error state if trivia generation failed completely
    if (_errorMessage != null && !_isLoading) {
      return Scaffold(
        backgroundColor: colors.background,
        body: ErrorRecoveryWidget(
          errorMessage: _errorMessage!,
          onRetry: () {
            setState(() {
              _errorMessage = null;
            });
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // Video background
          Positioned.fill(
            child: Semantics(
              label: 'Practice mode background video',
              child: const VideoBackgroundWidget(
                videoPath: _videoPath,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                loop: true,
                autoplay: true,
                child: SizedBox.shrink(),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Consumer<GameService>(
              builder: (context, gameService, _) {
                return Column(
                  children: [
                    // Practice game area
                    Expanded(
                      child: Center(
                        child: _isLoading
                            ? const StandardizedLoadingWidget(
                                message: 'Loading practice mode...',
                              )
                            : _buildPracticeCard(context, colors, gameService),
                      ),
                    ),
                    // Header with back button and hint selector
                    _buildHeader(context, colors),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Build practice card with content
  Widget _buildPracticeCard(
      BuildContext context, AppColorScheme colors, GameService gameService,) {
    return AppCard.filled(
      margin: const EdgeInsets.all(AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.xl),
      backgroundColor: colors.onDarkText.withValues(alpha: 0.1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.school,
            size: AppSpacing.xxxl,
            color: Colors.white,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Unlimited practice rounds with progressive hints.\nNo score penalties - focus on learning!',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton.primary(
            label: 'Start Practice',
            onPressed:
                _isLoading ? null : () => _startPractice(context, gameService),
            size: AppButtonSize.large,
            semanticsLabel:
                'Start practice game. Double tap to begin unlimited practice rounds',
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Hint Levels:\n• Level 1: Eliminate 1 wrong answer\n• Level 2: Eliminate 2 wrong answers\n• Show Answer: Reveal correct answers',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Build header with back button and hint level selector
  Widget _buildHeader(BuildContext context, AppColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          AppButton(
            icon: Icons.arrow_back,
            onPressed: () => NavigationHelper.safePop(context),
            variant: AppButtonVariant.icon,
            backgroundColor: Colors.transparent,
            foregroundColor: colors.onDarkText,
            semanticsLabel: 'Go back. Double tap to return to previous screen',
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Practice Mode',
            style: AppTypography.headlineMedium.copyWith(
              color: Colors.white,
            ),
          ),
          const Spacer(),
          _buildHintLevelSelector(context, colors),
        ],
      ),
    );
  }

  /// Build hint level selector dropdown
  Widget _buildHintLevelSelector(BuildContext context, AppColorScheme colors) {
    return Semantics(
      label: 'Hint level selector',
      hint:
          'Select hint level for practice mode. Current: ${_getHintLevelName(_hintLevel)}',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: colors.onDarkText.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lightbulb_outline,
              color: colors.onDarkText,
              size: 18,
            ),
            const SizedBox(width: AppSpacing.sm),
            DropdownButton<int>(
              value: _hintLevel,
              dropdownColor: colors.background,
              underline: const SizedBox(),
              items: [
                DropdownMenuItem(
                  value: 0,
                  child: Text(
                    'No Hints',
                    style: AppTypography.bodySmall.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 1,
                  child: Text(
                    'Hint Level 1',
                    style: AppTypography.bodySmall.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 2,
                  child: Text(
                    'Hint Level 2',
                    style: AppTypography.bodySmall.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 3,
                  child: Text(
                    'Show Answer',
                    style: AppTypography.bodySmall.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
              style: AppTypography.bodySmall.copyWith(
                color: Colors.white,
              ),
              onChanged: (value) {
                setState(() {
                  _hintLevel = value ?? _defaultHintLevel;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Get hint level name for accessibility
  String _getHintLevelName(int level) {
    switch (level) {
      case 0:
        return 'No Hints';
      case 1:
        return 'Hint Level 1';
      case 2:
        return 'Hint Level 2';
      case 3:
        return 'Show Answer';
      default:
        return 'Unknown';
    }
  }

  /// Start practice game
  Future<void> _startPractice(
      BuildContext context, GameService gameService,) async {
    if (!mounted || _isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final buildContext = context;

    try {
      // Safely get TriviaGeneratorService with fallback
      TriviaGeneratorService generator;
      try {
        generator = Provider.of<TriviaGeneratorService>(
          buildContext,
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

      final analyticsService = ProviderHelper.safeGetOrThrow<AnalyticsService>(
        buildContext,
        listen: false,
      );

      // Use retry logic for better reliability
      final triviaPool = await _generateTriviaWithRetry(
        buildContext,
        generator,
        analyticsService,
        _practiceTheme,
      );

      if (!mounted || !buildContext.mounted) {
        return;
      }

      if (triviaPool.isNotEmpty) {
        gameService.startNewRound(
          triviaPool,
          mode: GameMode.practice,
        );
        unawaited(NavigationHelper.safeNavigate(
          buildContext,
          '/game',
          arguments: {
            'mode': GameMode.practice,
            'hintLevel': _hintLevel,
          },
        ),);
      } else {
        if (!mounted || !buildContext.mounted) return;
        setState(() {
          _isLoading = false;
        });
        FeedbackHelper.showError(
          buildContext,
          'No trivia content available after multiple attempts. Please try again or restart the app.',
          duration: _errorSnackbarDuration,
        );
      }
    } catch (e) {
      if (!mounted || !buildContext.mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      // Provide specific error message
      final localizations = AppLocalizations.of(context);
      String errorMessage = localizations?.triviaGenerationFailed ??
          'Failed to load trivia content. Please try again.';

      if (e.toString().contains('No templates available')) {
        errorMessage =
            '${localizations?.templateInitializationIssue ?? 'Template initialization issue detected. Please restart the app.'} ${localizations?.genericError ?? 'Please try again.'}';
      } else if (e.toString().contains('Unable to generate unique trivia')) {
        errorMessage =
            '${localizations?.allContentUsed ?? 'All available content has been used. Try clearing history or selecting a different theme.'} ${localizations?.genericError ?? 'Please try again.'}';
      } else {
        errorMessage += ' Please try again.';
      }

      setState(() {
        _errorMessage = errorMessage;
      });

      LoggerService.error(
        'PracticeModeScreen: Failed to start practice',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
    }
  }

  /// Generates trivia with retry logic and fallback themes.
  ///
  /// Attempts to generate trivia up to [_maxRetryAttempts] times.
  /// On failure, tries fallback themes (general, then random available themes).
  ///
  /// Parameters:
  /// - [context]: Build context for accessing services
  /// - [generator]: TriviaGeneratorService instance
  /// - [analyticsService]: AnalyticsService for logging
  /// - [mode]: Theme/mode for trivia generation (defaults to 'practice')
  ///
  /// Returns:
  /// - List of TriviaItem if successful, empty list if all retries fail
  ///
  /// Similar to game_screen.dart implementation for consistency.
  Future<List<TriviaItem>> _generateTriviaWithRetry(
    BuildContext context,
    TriviaGeneratorService generator,
    AnalyticsService analyticsService,
    String? mode,
  ) async {
    List<TriviaItem> triviaPool = [];
    String? currentTheme = mode;
    int attempts = 0;

    while (attempts < _maxRetryAttempts) {
      try {
        triviaPool =
            generator.generateBatch(_triviaBatchSize, theme: currentTheme);
        if (triviaPool.isNotEmpty) {
          await analyticsService.logTriviaGeneration(
            currentTheme ?? 'unknown',
            true,
          );
          return triviaPool;
        }
      } catch (e) {
        LoggerService.debug('Attempt ${attempts + 1} failed to generate trivia for theme "$currentTheme"', error: e);
        await analyticsService.logTriviaGeneration(
          currentTheme ?? 'unknown',
          false,
          error: e.toString(),
        );

        attempts++;
        if (attempts < _maxRetryAttempts) {
          // On failure, try a different theme or fallback to general
          if (currentTheme != null && currentTheme != 'general') {
            currentTheme = 'general'; // Fallback to general theme
            LoggerService.debug('Retrying with general theme...');
          } else {
            // If already on general theme or no specific theme, try a random theme
            final availableThemes = generator.getAvailableThemes();
            if (availableThemes.isNotEmpty) {
              currentTheme =
                  availableThemes[Random().nextInt(availableThemes.length)];
              LoggerService.debug('Retrying with random theme: $currentTheme...');
            } else {
              LoggerService.debug('No available themes for retry.');
              break; // No more themes to try
            }
          }
          await Future.delayed(_retryDelay);
        }
      }
    }
    return triviaPool; // Will be empty if all retries fail
  }
}