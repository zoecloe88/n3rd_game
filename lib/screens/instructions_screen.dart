import 'package:flutter/material.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/widgets/unified_background_widget.dart';
import 'package:n3rd_game/config/screen_animations_config.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';

class InstructionsScreen extends StatefulWidget {
  const InstructionsScreen({super.key});

  @override
  State<InstructionsScreen> createState() => _InstructionsScreenState();
}

class _InstructionsScreenState extends State<InstructionsScreen> {
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final route = ModalRoute.of(context)?.settings.name;
    final animationPath = ScreenAnimationsConfig.getAnimationForRoute(route);

    return Scaffold(
      backgroundColor: colors.background,
      body: UnifiedBackgroundWidget(
        animationPath: animationPath,
        animationAlignment: Alignment.bottomCenter,
        animationPadding: const EdgeInsets.only(bottom: 20),
        child: SafeArea(
          child: Column(
            children: [
              // Top app bar
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Semantics(
                      label: AppLocalizations.of(context)?.backButton ?? 'Back',
                      button: true,
                      child: IconButton(
                        onPressed: () => NavigationHelper.safePop(context),
                        icon: Icon(Icons.arrow_back, color: colors.onDarkText),
                        tooltip:
                            AppLocalizations.of(context)?.backButton ?? 'Back',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      AppLocalizations.of(context)?.howToPlay ?? 'How to Play',
                      style: AppTypography.headlineLarge.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: colors.onDarkText,
                      ),
                    ),
                  ],
                ),
              ),

              // Instructions content - with bottom padding to not block animation
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    120,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Step 1
                        _buildInstructionStep(
                          context: context,
                          number: '1',
                          title:
                              AppLocalizations.of(context)?.memorizeTheWords ??
                              'Memorize the Words',
                          description:
                              AppLocalizations.of(
                                context,
                              )?.memorizeTheWordsDescription ??
                              'Study the words shown to you during the memorization phase. Pay attention to the correct answers!',
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Step 2
                        _buildInstructionStep(
                          context: context,
                          number: '2',
                          title:
                              AppLocalizations.of(
                                context,
                              )?.select3CorrectAnswers ??
                              'Select 3 Correct Answers',
                          description:
                              AppLocalizations.of(
                                context,
                              )?.select3CorrectAnswersDescription ??
                              'From the shuffled list, choose exactly 3 words that match the correct answers you memorized.',
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Step 3
                        _buildInstructionStep(
                          context: context,
                          number: '3',
                          title:
                              AppLocalizations.of(context)?.scorePoints ??
                              'Score Points',
                          description:
                              AppLocalizations.of(
                                context,
                              )?.scorePointsDescription ??
                              'Earn points based on how many correct answers you select:\n• 1 correct = 10 points\n• 2 correct = 20 points\n• 3 correct = 30 points',
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Step 4
                        _buildInstructionStep(
                          context: context,
                          number: '4',
                          title:
                              AppLocalizations.of(context)?.tryDifferentModes ??
                              'Try Different Modes',
                          description:
                              AppLocalizations.of(
                                context,
                              )?.tryDifferentModesDescription ??
                              'Explore various game modes:\n• Classic: Standard timing\n• Speed: Fast-paced challenges\n• Shuffle: Tiles move during play\n• Time Attack: Score as much as possible in 60 seconds',
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Mode-specific instructions
                        _buildModeInstructionsSection(context, colors),
                        const SizedBox(height: AppSpacing.lg),

                        // Tips section
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: colors.onDarkText.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colors.onDarkText.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.lightbulb_outline,
                                    color: colors.onDarkText,
                                    size: 24,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(
                                    AppLocalizations.of(context)?.proTips ??
                                        'Pro Tips',
                                    style: AppTypography.headlineLarge.copyWith(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: colors.onDarkText,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm + 4),
                              _buildTip(
                                context,
                                AppLocalizations.of(
                                      context,
                                    )?.tipFocusCategory ??
                                    'Focus on the category to understand context',
                              ),
                              _buildTip(
                                context,
                                AppLocalizations.of(
                                      context,
                                    )?.tipTimeManagement ??
                                    'Time management is key in speed modes',
                              ),
                              _buildTip(
                                context,
                                AppLocalizations.of(
                                      context,
                                    )?.tipPracticeClassic ??
                                    'Practice with Classic mode first',
                              ),
                              _buildTip(
                                context,
                                AppLocalizations.of(context)?.tipWatchLives ??
                                    'Watch your lives - you lose one for zero correct answers',
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
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionStep({
    required BuildContext context,
    required String number,
    required String title,
    required String description,
  }) {
    final colors = AppColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.primaryButton,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              number,
              style: AppTypography.headlineLarge.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colors.buttonText,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.headlineLarge.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colors.onDarkText,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                description,
                style: AppTypography.lora(
                  fontSize: 15,
                  color: colors.onDarkText.withValues(alpha: 0.9),
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTip(BuildContext context, String tip) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, size: 18, color: colors.onDarkText),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              tip,
              style: AppTypography.bodyMedium.copyWith(
                fontSize: 14,
                color: colors.onDarkText.withValues(alpha: 0.9),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeInstructionsSection(
    BuildContext context,
    AppColorScheme colors,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.onDarkText.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.onDarkText.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gamepad_outlined, color: colors.onDarkText, size: 24),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Game Mode Details',
                style: AppTypography.headlineLarge.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: colors.onDarkText,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildModeDetail(
            context,
            'Classic',
            '10s memorize, 20s play. Perfect for beginners!',
          ),
          _buildModeDetail(
            context,
            'Classic II',
            '5s memorize, 10s play. Faster paced version.',
          ),
          _buildModeDetail(
            context,
            'Speed',
            '0s memorize (words shown with question), 7s play. Ultra-fast!',
          ),
          _buildModeDetail(
            context,
            'Regular',
            '0s memorize (words shown with question), 15s play.',
          ),
          _buildModeDetail(
            context,
            'Shuffle',
            '10s memorize, then tiles continuously shuffle during 20s play. Memory challenge!',
          ),
          _buildModeDetail(
            context,
            'Flip Mode',
            '10s study (4s visible, 6s tiles flip), 20s play face-down. Remember the order!',
          ),
          _buildModeDetail(
            context,
            'Time Attack',
            '60 seconds to score as much as possible. Continuous rounds!',
          ),
          _buildModeDetail(
            context,
            'Blitz',
            '3s memorize, 5s play. Extreme speed challenge!',
          ),
          _buildModeDetail(
            context,
            'Perfect',
            'Must get all 3 correct. One wrong = game over!',
          ),
          _buildModeDetail(
            context,
            'Survival',
            'Start with 1 life. Gain a life every 3 perfect rounds.',
          ),
          _buildModeDetail(
            context,
            'Precision',
            'Wrong selection = lose life immediately. High stakes!',
          ),
          _buildModeDetail(
            context,
            'Challenge',
            'Progressive difficulty - gets harder each round.',
          ),
          _buildModeDetail(
            context,
            'Streak',
            'Score multiplier increases with perfect rounds.',
          ),
          _buildModeDetail(
            context,
            'Marathon',
            'Infinite rounds with progressive difficulty.',
          ),
          _buildModeDetail(
            context,
            'AI Mode',
            'Adaptive difficulty that learns from your performance. Premium only.',
            isPremium: true,
          ),
        ],
      ),
    );
  }

  Widget _buildModeDetail(
    BuildContext context,
    String modeName,
    String description, {
    bool isPremium = false,
  }) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: colors.onDarkText.withValues(alpha: 0.7),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppTypography.bodyMedium.copyWith(
                  fontSize: 14,
                  color: colors.onDarkText.withValues(alpha: 0.9),
                  height: 1.5,
                ),
                children: [
                  TextSpan(
                    text: '$modeName: ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: description),
                  if (isPremium)
                    TextSpan(
                      text: ' (Premium)',
                      style: TextStyle(
                        color: colors.primaryButton,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
