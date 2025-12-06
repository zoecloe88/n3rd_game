import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/services/word_service.dart';
import 'package:n3rd_game/services/auth_service.dart';
import 'package:n3rd_game/services/onboarding_service.dart';
import 'package:n3rd_game/widgets/unified_background_widget.dart';
import 'package:n3rd_game/config/screen_animations_config.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/utils/responsive_helper.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';

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
      final hasCompletedOnboarding = await _onboardingService
          .hasCompletedOnboarding();
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
      // but handle gracefully
      if (mounted && context.mounted) {
        NavigationHelper.safeNavigate(context, '/login', replace: true);
      }
      return;
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
    final route = ModalRoute.of(context)?.settings.name;
    final animationPath = ScreenAnimationsConfig.getAnimationForRoute(route);

    return Scaffold(
      backgroundColor: AppColors.of(context).background,
      body: UnifiedBackgroundWidget(
        animationPath: animationPath,
        animationAlignment: Alignment.bottomCenter,
        animationPadding: const EdgeInsets.only(bottom: 20),
        child: SafeArea(
          child: _checkingAuth
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
                )
              : _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
                )
              : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    // Safety check - if word is still null, show error message
    if (_word == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 48),
            const SizedBox(height: 16),
            Text(
              'Unable to load word',
              style: AppTypography.bodyLarge.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => NavigationHelper.safeNavigate(context, '/title'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.of(context).background,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Continue',
                style: AppTypography.labelLarge.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    final mediaQuery = MediaQuery.of(context);
    final isTablet = ResponsiveHelper.isTablet(context);
    final maxContentWidth = isTablet ? 600.0 : 360.0;
    final horizontalPadding = isTablet ? mediaQuery.size.width * 0.15 : 24.0;
    final verticalPadding = isTablet ? 100.0 : 48.0;

    return Stack(
      children: [
        Positioned(
          top: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () => NavigationHelper.safeNavigate(context, '/title'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.of(context).background,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Continue',
                style: AppTypography.labelLarge.copyWith(color: Colors.white),
              ),
            ),
          ),
        ),
        Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              verticalPadding,
              horizontalPadding,
              verticalPadding + 100,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Word of the Day',
                    style: AppTypography.displayMedium.copyWith(
                      fontSize: isTablet ? 30 : 24,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _word!.word.toUpperCase(),
                        maxLines: 1,
                        style: AppTypography.displayLarge.copyWith(
                          fontSize: isTablet ? 56 : 40,
                          color: Colors.white,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Definition',
                    style: AppTypography.labelSmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _word!.definition,
                    style: AppTypography.bodyLarge.copyWith(
                      fontSize: isTablet ? 18 : 16,
                      color: Colors.white,
                    ),
                  ),
                  if (_word!.example.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Example',
                      style: AppTypography.labelSmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '"${_word!.example}"',
                      style: AppTypography.bodyLarge.copyWith(
                        fontSize: isTablet ? 17 : 15,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
