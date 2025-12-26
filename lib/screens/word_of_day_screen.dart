import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:n3rd_game/services/word_service.dart';
import 'package:n3rd_game/services/auth_service.dart';
import 'package:n3rd_game/services/onboarding_service.dart';
import 'package:n3rd_game/widgets/video_background_widget.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/utils/responsive_helper.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/widgets/standardized_loading_widget.dart';
import 'package:n3rd_game/widgets/error_recovery_widget.dart';

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
      }
    });
    _loadWord();
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
          NavigationHelper.safeNavigate(context, '/onboarding', replace: true);
        }
        return;
      }
    } catch (e) {
      // Onboarding check failed - log error but allow access (fail-open to prevent blocking users)
      if (kDebugMode) {
        debugPrint('⚠️ Onboarding check failed in WordOfDayScreen: $e');
      }
      // Continue - don't block access if check fails (fail-open approach)
    }

    // Then check auth - use Consumer/Provider after first frame
    if (!mounted || !context.mounted) return;

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (!authService.isAuthenticated) {
        if (mounted && context.mounted) {
          NavigationHelper.safeNavigate(context, '/login', replace: true);
        }
        return;
      }
    } catch (e) {
      // Provider not available yet - this shouldn't happen after addPostFrameCallback
      // but handle gracefully - allow access to show content (fail-open)
      if (kDebugMode) {
        debugPrint('⚠️ Auth check failed in WordOfDayScreen: $e');
      }
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
      }
    } catch (e) {
      // If loading fails, create a fallback word
      if (mounted) {
        setState(() {
          _word = WordOfTheDay(
            word: 'Serendipity',
            definition:
                'The occurrence and development of events by chance in a happy or beneficial way.',
            example:
                'A fortunate stroke of serendipity brought the two old friends together.',
            date: DateTime.now(),
          );
          _loading = false;
        });
      }
    }
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
          child: _checkingAuth
              ? const StandardizedLoadingWidget(
                  message: 'Checking authentication...',
                  color: Color(0xFF00D9FF),
                )
              : _loading
                  ? const StandardizedLoadingWidget(
                      message: 'Loading word of the day...',
                      color: Color(0xFF00D9FF),
                    )
                  : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    // Safety check - if word is still null, show error message
    if (_word == null) {
      return ErrorRecoveryWidget(
        title: 'Unable to Load Word',
        message:
            'There was an error loading the word of the day. Please try again later.',
        onRetry: () => NavigationHelper.safeNavigate(context, '/title'),
        icon: Icons.error_outline,
        showRetryButton: false,
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
              onPressed: () => NavigationHelper.safeNavigate(context, '/title'),
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
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              ResponsiveHelper.responsiveHeight(context, 0.15)
                  .clamp(60.0, 120.0), // Reduced top padding to move content up ~1 inch
              horizontalPadding,
              verticalPadding + 80, // Space for continue button
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center, // Center text
                  children: [
                  Text(
                    'Word of the Day',
                    textAlign: TextAlign.center, // Center text
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
                      textAlign: TextAlign.center, // Center text
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
                    textAlign: TextAlign.center, // Center text
                    style: AppTypography.labelSmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _word!.definition,
                    textAlign: TextAlign.center, // Center text
                    style: AppTypography.bodyLarge.copyWith(
                      fontSize: isTablet ? 18 : 16,
                      color: Colors.white,
                    ),
                  ),
                  if (_word!.example.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Example',
                      textAlign: TextAlign.center, // Center text
                      style: AppTypography.labelSmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '"${_word!.example}"',
                      textAlign: TextAlign.center, // Center text
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
      ],
    );
  }
}
