import 'dart:async';
import 'package:n3rd_game/utils/unawaited_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:n3rd_game/services/word_service.dart';
import 'package:n3rd_game/services/auth_service.dart';
import 'package:n3rd_game/services/onboarding_service.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/widgets/video_background_widget.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/utils/responsive_helper.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/utils/error_handler.dart';
import 'package:n3rd_game/widgets/standardized_loading_widget.dart';
import 'package:n3rd_game/widgets/error_recovery_widget.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/services/logger_service.dart';

class WordOfDayScreen extends StatefulWidget {
  const WordOfDayScreen({super.key});

  @override
  State<WordOfDayScreen> createState() => _WordOfDayScreenState();
}

class _WordOfDayScreenState extends State<WordOfDayScreen> {
  final WordService _wordService = WordService();
  final OnboardingService _onboardingService = OnboardingService();
  WordOfTheDay? _word;
  bool _loading = true;
  bool _checkingAuth = true;

  @override
  void initState() {
    super.initState();
    // Wait for first frame to ensure Provider context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkAuthAndOnboarding();
        // Track screen view
        _trackScreenView();
      }
    });
    _loadWord();
  }

  /// Track screen view analytics (non-blocking)
  void _trackScreenView() {
    try {
      final analytics = Provider.of<AnalyticsService>(context, listen: false);
      analytics.logScreenView('word_of_day').catchError((e) {
        // Non-critical - analytics failure shouldn't block app
        LoggerService.error('Failed to track screen view', error: e);
      });
    } catch (e) {
      // Analytics not available - non-critical
      LoggerService.debug('Analytics not available for screen view', error: e);
    }
  }

  Future<void> _checkAuthAndOnboarding() async {
    if (!mounted) return;

    // Small delay to ensure auth state is updated after login
    // This prevents race condition where auth check happens before state is updated
    await Future.delayed(const Duration(milliseconds: 200));

    if (!mounted) return;

    // Check onboarding first - must be completed before accessing word of day
    try {
      final hasCompletedOnboarding =
          await _onboardingService.hasCompletedOnboarding();
      if (!hasCompletedOnboarding) {
        if (mounted && context.mounted) {
          unawaited(NavigationHelper.safeNavigate(context, '/onboarding', replace: true));
        }
        return;
      }
    } catch (e) {
      // Onboarding check failed - log error but allow access (fail-open to prevent blocking users)
      LoggerService.error('⚠️ Onboarding check failed in WordOfDayScreen', error: e);
      // Continue - don't block access if check fails (fail-open approach)
    }

    // Then check auth - use Consumer/Provider after first frame
    if (!mounted || !context.mounted) return;

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (!authService.isAuthenticated) {
        if (mounted && context.mounted) {
          unawaited(NavigationHelper.safeNavigate(context, '/login', replace: true));
        }
        return;
      }
    } catch (e) {
      // Provider not available yet - this shouldn't happen after addPostFrameCallback
      // but handle gracefully - allow access to show content (fail-open)
      LoggerService.error('⚠️ Auth check failed in WordOfDayScreen', error: e);
      // Continue to show content instead of redirecting
    }

    if (mounted) {
      setState(() {
        _checkingAuth = false;
      });
    }
  }

  Future<void> _loadWord() async {
    try {
      final word = await _wordService.getWordOfTheDay();
      if (mounted) {
        setState(() {
          _word = word;
          _loading = false;
        });
        // Track successful word load
        _trackWordLoadSuccess();
      }
    } catch (e) {
      // Log error for debugging
      LoggerService.error(
        'Failed to load word of the day',
        error: e,
        fatal: false,
      );

      // Track word load failure
      _trackWordLoadFailure(e.toString());

      // Show user-friendly error message
      if (mounted && context.mounted) {
        ErrorHandler.showSnackBar(context, null, error: e);
      }

      // Still set fallback word for graceful degradation
      if (mounted) {
        setState(() {
          _word = _createDateBasedFallbackWord();
          _loading = false;
        });
      }
    }
  }

  /// Track word load success (non-blocking)
  void _trackWordLoadSuccess() {
    try {
      final analytics = Provider.of<AnalyticsService>(context, listen: false);
      analytics.logCustomEvent('word_of_day_load_success').catchError((e) {
        // Non-critical
        LoggerService.error('Failed to track word load success', error: e);
      });
    } catch (e) {
      // Analytics not available - non-critical
    }
  }

  /// Track word load failure (non-blocking)
  void _trackWordLoadFailure(String error) {
    try {
      final analytics = Provider.of<AnalyticsService>(context, listen: false);
      analytics.logCustomEvent(
        'word_of_day_load_failure',
        parameters: {'error': error},
      ).catchError((e) {
        // Non-critical
        LoggerService.error('Failed to track word load failure', error: e);
      });
    } catch (e) {
      // Analytics not available - non-critical
    }
  }

  /// Track continue button click (non-blocking)
  void _trackContinueClick() {
    try {
      final analytics = Provider.of<AnalyticsService>(context, listen: false);
      analytics.logCustomEvent('word_of_day_continue_clicked').catchError((e) {
        // Non-critical
        LoggerService.error('Failed to track continue click', error: e);
      });
    } catch (e) {
      // Analytics not available - non-critical
    }
  }

  /// Track retry attempt (non-blocking)
  void _trackRetryAttempt() {
    try {
      final analytics = Provider.of<AnalyticsService>(context, listen: false);
      analytics.logCustomEvent('word_of_day_retry').catchError((e) {
        // Non-critical
        LoggerService.error('Failed to track retry', error: e);
      });
    } catch (e) {
      // Analytics not available - non-critical
    }
  }

  /// Retry loading word of the day
  Future<void> _retryLoadWord() async {
    _trackRetryAttempt();
    setState(() {
      _loading = true;
      _word = null;
    });
    await _loadWord();
  }

  /// Create date-based fallback word using WordService logic
  WordOfTheDay _createDateBasedFallbackWord() {
    final today = DateTime.now().toUtc();
    // Use same logic as WordService: today.day % wordList.length
    // WordService has 30 words in _wordList
    final wordIndex = today.day % 30;
    final wordList = [
      'serendipity',
      'ephemeral',
      'eloquent',
      'resilient',
      'pragmatic',
      'ambiguous',
      'benevolent',
      'cognitive',
      'diligent',
      'euphoria',
      'facetious',
      'gregarious',
      'harmonious',
      'ingenious',
      'jubilant',
      'kinetic',
      'luminous',
      'meticulous',
      'nostalgic',
      'optimistic',
      'paradox',
      'quintessential',
      'robust',
      'subtle',
      'tenacious',
      'ubiquitous',
      'vivid',
      'whimsical',
      'zealous',
      'aesthetic',
    ];
    final word = wordList[wordIndex];

    // Create fallback word with proper definition
    final fallbackData = _getFallbackWordData(word);
    return WordOfTheDay(
      word: word,
      definition:
          fallbackData['definition'] ?? 'A fascinating word to explore today.',
      example: fallbackData['example'] ??
          'This word can be used in various contexts to express meaning.',
      date: today,
    );
  }

  /// Get fallback data for common words (matches WordService logic)
  Map<String, String> _getFallbackWordData(String word) {
    final wordLower = word.toLowerCase();
    final fallbackMap = {
      'serendipity': {
        'definition':
            'The occurrence and development of events by chance in a happy or beneficial way.',
        'example':
            'Finding that rare book in the library was pure serendipity.',
      },
      'ephemeral': {
        'definition': 'Lasting for a very short time; transient.',
        'example':
            'The beauty of cherry blossoms is ephemeral, lasting only a few weeks.',
      },
      'eloquent': {
        'definition': 'Fluent or persuasive in speaking or writing.',
        'example': 'Her eloquent speech moved the entire audience to tears.',
      },
      'resilient': {
        'definition':
            'Able to withstand or recover quickly from difficult conditions.',
        'example':
            'Despite the setbacks, she remained resilient and continued pursuing her goals.',
      },
      'pragmatic': {
        'definition': 'Dealing with things in a practical and realistic way.',
        'example':
            'His pragmatic approach to problem-solving helped the team succeed.',
      },
    };
    return fallbackMap[wordLower] ??
        {
          'definition': 'A fascinating word to explore today.',
          'example':
              'This word can be used in various contexts to express meaning.',
        };
  }

  @override
  void dispose() {
    // Dispose service instances if they have cleanup methods
    // WordService and OnboardingService are ChangeNotifiers but don't have
    // subscriptions or timers that need cleanup in this context
    // They're accessed via Provider in other parts of the app
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: VideoBackgroundWidget(
        videoPath: 'assets/wordoftheday.mp4',
        fit: BoxFit.cover, // CSS object-fit: cover equivalent
        alignment: Alignment.topCenter, // Characters/logos in upper portion
        loop: true,
        autoplay: true,
        child: SafeArea(
          child: Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return _checkingAuth
                  ? StandardizedLoadingWidget(
                      message: localizations?.checkingAuthentication ??
                          'Checking authentication...',
                      color: const Color(0xFF00D9FF),
                    )
                  : _loading
                      ? StandardizedLoadingWidget(
                          message: localizations?.loadingWordOfTheDay ??
                              'Loading word of the day...',
                          color: const Color(0xFF00D9FF),
                        )
                      : _buildContent();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    // Safety check - if word is still null, show error message
    if (_word == null) {
      final localizations = AppLocalizations.of(context);
      return ErrorRecoveryWidget(
        title: localizations?.unableToLoadWord ?? 'Unable to Load Word',
        message: localizations?.wordOfTheDayLoadError ??
            'There was an error loading the word of the day. Please try again later.',
        onRetry: _retryLoadWord,
        icon: Icons.error_outline,
        showRetryButton: true,
      );
    }

    final mediaQuery = MediaQuery.of(context);
    final isTablet = ResponsiveHelper.isTablet(context);
    final maxContentWidth = isTablet ? 600.0 : 360.0;
    final horizontalPadding = isTablet ? mediaQuery.size.width * 0.15 : 24.0;
    final verticalPadding = isTablet ? 100.0 : 48.0;

    return Stack(
      children: [
        // Continue button - bottom right
        Positioned(
          bottom: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                _trackContinueClick();
                NavigationHelper.safeNavigate(context, '/title');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black, // Black button with white text
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Continue',
                style: AppTypography.labelLarge.copyWith(color: Colors.white),
              ),
            ),
          ),
        ),
        // Content positioned higher up and centered
        Center(
          child: SingleChildScrollView(
            padding: EdgeInsetsDirectional.fromSTEB(
              horizontalPadding,
              ResponsiveHelper.responsiveHeight(context, 0.15).clamp(60.0,
                  120.0,), // Reduced top padding to move content up ~1 inch
              horizontalPadding,
              verticalPadding + 80, // Space for continue button
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Word of the Day',
                      textAlign: TextAlign.center,
                      style: AppTypography.displayMedium.copyWith(
                        fontSize: isTablet ? 30 : 24,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _word!.word.toUpperCase(),
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: AppTypography.displayLarge.copyWith(
                          fontSize: isTablet ? 56 : 40,
                          color: Colors.white,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Definition',
                      textAlign: TextAlign.center,
                      style: AppTypography.labelSmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _word!.definition,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyLarge.copyWith(
                        fontSize: isTablet ? 18 : 16,
                        color: Colors.white,
                      ),
                    ),
                    if (_word!.example.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Example',
                        textAlign: TextAlign.center,
                        style: AppTypography.labelSmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '"${_word!.example}"',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyLarge.copyWith(
                          fontSize: isTablet ? 17 : 15,
                          color: Colors.white.withValues(alpha: 0.9),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    // Date display with same styling as Youth Edition header
                    const SizedBox(height: 24),
                    Text(
                      DateFormat('EEEE, MMMM d yyyy').format(_word!.date),
                      textAlign: TextAlign.center,
                      style: AppTypography.orbitron(
                        fontSize: isTablet ? 20 : 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ).copyWith(
                        letterSpacing: 2,
                        shadows: const [
                          Shadow(
                            color: Color(0xFF70F3FF),
                            offset: Offset(-1, 0),
                          ),
                          Shadow(
                            color: Color(0xFFB000E8),
                            offset: Offset(1, 0),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}