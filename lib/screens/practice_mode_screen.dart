import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/services/game_service.dart';
import 'package:n3rd_game/services/trivia_generator_service.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/widgets/video_player_widget.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/models/trivia_item.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';

class PracticeModeScreen extends StatefulWidget {
  const PracticeModeScreen({super.key});

  @override
  State<PracticeModeScreen> createState() => _PracticeModeScreenState();
}

class _PracticeModeScreenState extends State<PracticeModeScreen> {
  int _hintLevel =
      0; // 0 = no hint, 1 = eliminate 1 wrong, 2 = eliminate 2 wrong, 3 = show answer

  @override
  Widget build(BuildContext context) {
    // NOTE: Subscription access is enforced by RouteGuard in main.dart
    // No need for redundant check here
    return Scaffold(
      backgroundColor: AppColors.of(context).background,
      body: Stack(
        children: [
          // Video background
          const Positioned.fill(
            child: VideoPlayerWidget(
              videoPath: 'assets/videos/settings_video.mp4',
              loop: true,
              autoplay: true,
            ),
          ),

          // Content
          SafeArea(
            child: Consumer<GameService>(
              builder: (context, gameService, _) {
                return Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            onPressed: () => NavigationHelper.safePop(context),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Practice Mode',
                            style: AppTypography.headlineLarge.copyWith(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          // Hint level selector
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.lightbulb_outline,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                DropdownButton<int>(
                                  value: _hintLevel,
                                  dropdownColor: Colors.black,
                                  underline: const SizedBox(),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 0,
                                      child: Text(
                                        'No Hints',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 1,
                                      child: Text(
                                        'Hint Level 1',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 2,
                                      child: Text(
                                        'Hint Level 2',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 3,
                                      child: Text(
                                        'Show Answer',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _hintLevel = value ?? 0;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Practice game area
                    Expanded(
                      child: Center(
                        child: Container(
                          margin: const EdgeInsets.all(24),
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.school,
                                size: 64,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Practice Mode',
                                style: AppTypography.headlineLarge.copyWith(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Unlimited practice rounds with progressive hints.\nNo score penalties - focus on learning!',
                                textAlign: TextAlign.center,
                                style: AppTypography.bodyMedium.copyWith(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: () async {
                                  if (!mounted) return;
                                  final buildContext = context;
                                  // Start practice game with retry logic
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
                                    final triviaPool =
                                        await _generateTriviaWithRetry(
                                      buildContext,
                                      generator,
                                      analyticsService,
                                      'practice',
                                    );

                                    if (!mounted || !buildContext.mounted) {
                                      return;
                                    }
                                    if (triviaPool.isNotEmpty) {
                                      gameService.startNewRound(
                                        triviaPool,
                                        mode: GameMode.classic,
                                      );
                                      Navigator.of(buildContext).pushNamed(
                                        '/game',
                                        arguments: GameMode.classic,
                                      );
                                    } else {
                                      ScaffoldMessenger.of(
                                        buildContext,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'No trivia content available after multiple attempts. Please try again or restart the app.',
                                          ),
                                          duration: Duration(seconds: 4),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (!mounted || !buildContext.mounted) {
                                      return;
                                    }
                                    // Provide specific error message
                                    String errorMessage =
                                        'Failed to load trivia content. ';
                                    if (e.toString().contains(
                                          'No templates available',
                                        )) {
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
                                    ScaffoldMessenger.of(
                                      buildContext,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text(errorMessage),
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00D9FF),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 16,
                                  ),
                                ),
                                child: Text(
                                  'Start Practice',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Hint Levels:\n• Level 1: Eliminate 1 wrong answer\n• Level 2: Eliminate 2 wrong answers\n• Show Answer: Reveal correct answers',
                                textAlign: TextAlign.center,
                                style: AppTypography.bodyMedium.copyWith(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
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

  /// Generates trivia with retry logic and fallback themes.
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
    const maxAttempts = 3;

    while (attempts < maxAttempts) {
      try {
        triviaPool = generator.generateBatch(50, theme: currentTheme);
        if (triviaPool.isNotEmpty) {
          await analyticsService.logTriviaGeneration(
            currentTheme ?? 'unknown',
            true,
          );
          return triviaPool;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            'Attempt ${attempts + 1} failed to generate trivia for theme "$currentTheme": $e',
          );
        }
        await analyticsService.logTriviaGeneration(
          currentTheme ?? 'unknown',
          false,
          error: e.toString(),
        );

        attempts++;
        if (attempts < maxAttempts) {
          // On failure, try a different theme or fallback to general
          if (currentTheme != null && currentTheme != 'general') {
            currentTheme = 'general'; // Fallback to general theme
            if (kDebugMode) {
              debugPrint('Retrying with general theme...');
            }
          } else {
            // If already on general theme or no specific theme, try a random theme
            final availableThemes = generator.getAvailableThemes();
            if (availableThemes.isNotEmpty) {
              currentTheme =
                  availableThemes[Random().nextInt(availableThemes.length)];
              if (kDebugMode) {
                debugPrint('Retrying with random theme: $currentTheme...');
              }
            } else {
              if (kDebugMode) {
                debugPrint('No available themes for retry.');
              }
              break; // No more themes to try
            }
          }
          await Future.delayed(
            const Duration(seconds: 1),
          ); // Small delay before retry
        }
      }
    }
    return triviaPool; // Will be empty if all retries fail
  }
}
