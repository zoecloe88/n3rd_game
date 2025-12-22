import 'package:flutter/material.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/widgets/unified_background_widget.dart';
import 'package:n3rd_game/config/screen_animations_config.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/screens/ai_edition_input_screen.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/theme/app_radius.dart';
import 'package:n3rd_game/theme/app_shadows.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';

class YouthEditionsScreen extends StatefulWidget {
  const YouthEditionsScreen({super.key});

  @override
  State<YouthEditionsScreen> createState() => _YouthEditionsScreenState();
}

class _YouthEditionsScreenState extends State<YouthEditionsScreen> {
  final List<YouthEdition> _editions = const [
    YouthEdition(
      title: 'AI Edition',
      tagline: 'Create your own topic • Premium only',
      isAI: true,
    ),
    YouthEdition(
      title: 'Little N3RD Edition',
      tagline: 'Ages 4-6 • colors, animals, sight words',
    ),
    YouthEdition(
      title: 'Junior N3RD Edition',
      tagline: 'Ages 7-8 • early readers, numbers, geography',
    ),
    YouthEdition(
      title: 'Elementary N3RD Edition',
      tagline: 'Grades 3-5 • science, civics, vocab missions',
    ),
    YouthEdition(
      title: 'Middle School N3RD Edition',
      tagline: 'Grades 6-8 • STEM labs & world cultures',
    ),
    YouthEdition(
      title: 'High School N3RD Edition',
      tagline: 'Grades 9-12 • advanced trivia & electives',
    ),
    YouthEdition(
      title: 'College Prep N3RD Edition',
      tagline: 'SAT/ACT style drills • study hacks • confidence',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // RouteGuard handles subscription checking at route level
    final route = ModalRoute.of(context)?.settings.name;
    final animationPath = ScreenAnimationsConfig.getAnimationForRoute(route);

    return Scaffold(
      backgroundColor: AppColors.of(context).background,
      body: UnifiedBackgroundWidget(
        animationPath: animationPath,
        animationAlignment: Alignment.bottomCenter,
        animationPadding: const EdgeInsets.only(bottom: 20),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => NavigationHelper.safePop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(
                    'YOUTH',
                    style:
                        AppTypography.orbitron(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ).copyWith(
                          letterSpacing: 6,
                          shadows: const [
                            Shadow(
                              color: Color(0xFF70F3FF),
                              offset: Offset(-2, 0),
                            ),
                            Shadow(
                              color: Color(0xFFB000E8),
                              offset: Offset(2, 0),
                            ),
                          ],
                        ),
                  ),
                  Text(
                    'EDITIONS',
                    style:
                        AppTypography.ibmPlexMono(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ).copyWith(
                          letterSpacing: 4,
                          shadows: const [
                            Shadow(
                              color: Color(0xFF70F3FF),
                              offset: Offset(-2, 0),
                            ),
                            Shadow(
                              color: Color(0xFFB000E8),
                              offset: Offset(2, 0),
                            ),
                          ],
                        ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  itemBuilder: (context, index) {
                    final edition = _editions[index];
                    return GestureDetector(
                      onTap: edition.isAI
                          ? () => _onAIEditionTapped()
                          : () => _onEditionTapped(edition),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: edition.isAI
                              ? const Color(0xFF6366F1).withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(AppRadius.large),
                          boxShadow: AppShadows.medium,
                          border: Border.all(
                            color: edition.isAI
                                ? const Color(0xFF6366F1)
                                : const Color(0xFF6B4FC9),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (edition.isAI)
                                  const Icon(
                                    Icons.auto_awesome,
                                    color: Color(0xFF6366F1),
                                    size: 20,
                                  ),
                                if (edition.isAI)
                                  const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    edition.title,
                                    style: AppTypography.headlineLarge.copyWith(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.of(context).primaryText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              edition.tagline,
                              style: AppTypography.bodyMedium.copyWith(
                                fontSize: 13,
                                color: AppColors.of(context).secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (_, index) =>
                      const SizedBox(height: AppSpacing.md),
                  itemCount: _editions.length,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.lg),
                child: YouthMascot(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onAIEditionTapped() {
    NavigationHelper.safePush(
      context,
      MaterialPageRoute(
        builder: (_) => const AIEditionInputScreen(isYouthEdition: true),
      ),
    );
  }

  void _onEditionTapped(YouthEdition edition) {
    // Handle regular edition tap
    // Navigate to game with edition info
    NavigationHelper.safeNavigate(
      context,
      '/game',
      arguments: {
        'mode': null,
        'edition': edition.title.toLowerCase().replaceAll(' ', '_'),
        'editionName': edition.title,
      },
    );
  }
}

class YouthMascot extends StatefulWidget {
  const YouthMascot({super.key});

  @override
  State<YouthMascot> createState() => _YouthMascotState();
}

class _YouthMascotState extends State<YouthMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _controller.value * 12),
          child: child,
        );
      },
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFF8C42),
            ),
            child: Center(
              child: Text(
                '☆',
                style: AppTypography.spaceGrotesk(
                  fontSize: 28,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Stay Curious!',
            style: AppTypography.bodyMedium.copyWith(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class YouthEdition {
  final String title;
  final String tagline;
  final bool isAI;

  const YouthEdition({
    required this.title,
    required this.tagline,
    this.isAI = false,
  });
}
