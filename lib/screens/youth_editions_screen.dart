import 'package:flutter/material.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/widgets/video_background_widget.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/screens/ai_edition_input_screen.dart';
import 'package:n3rd_game/screens/youth_transition_screen.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/theme/app_shadows.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/utils/responsive_helper.dart';

class YouthEditionsScreen extends StatefulWidget {
  const YouthEditionsScreen({super.key});

  @override
  State<YouthEditionsScreen> createState() => _YouthEditionsScreenState();
}

class _YouthEditionsScreenState extends State<YouthEditionsScreen> {
  int _currentPage = 0;
  final PageController _pageController = PageController();
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

  /// Get number of cards to show per page based on device type
  /// Tablets show 6 cards (2 columns x 3 rows), phones show 3 cards (1 column)
  int _cardsPerPage(BuildContext context) {
    return ResponsiveHelper.isTablet(context) ? 6 : 3;
  }

  int _totalPages(BuildContext context) {
    final cardsPerPage = _cardsPerPage(context);
    return (_editions.length / cardsPerPage).ceil();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // RouteGuard handles subscription checking at route level

    return Scaffold(
      body: VideoBackgroundWidget(
        videoPath: 'assets/youthscreen.mp4',
        fit: BoxFit.cover,
        alignment: Alignment.topCenter, // Characters/logos in upper portion
        loop: true,
        autoplay: true,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              // Back button header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => NavigationHelper.safePop(context),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              // Edition cards with responsive pagination (3 per page on phones, 6 on tablets)
              // Content positioned in lower portion to avoid overlapping animated logos in upper portion
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    // Spacer to position tiles below animations (moved down ~0.1 cm = ~4-8 pixels)
                    SizedBox(
                      height: ResponsiveHelper.responsiveHeight(context, 0.15)
                          .clamp(104.0, 158.0), // Increased by ~4-8 pixels
                    ),

                    // Page view with responsive cards per page
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() {
                            _currentPage = index;
                          });
                        },
                        itemCount: _totalPages(context),
                        itemBuilder: (context, pageIndex) {
                          final cardsPerPage = _cardsPerPage(context);
                          final startIndex = pageIndex * cardsPerPage;
                          final endIndex = (startIndex + cardsPerPage).clamp(
                            0,
                            _editions.length,
                          );
                          final pageEditions = _editions.sublist(
                            startIndex,
                            endIndex,
                          );

                          // On tablets, use GridView for 2 columns; on phones, use Column
                          final isTablet = ResponsiveHelper.isTablet(context);

                          return SingleChildScrollView(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 32 : 16,
                                vertical: isTablet ? 16 : 0,
                              ),
                              child: isTablet
                                  ? GridView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        childAspectRatio: 1.2,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                      ),
                                      itemCount: pageEditions.length,
                                      itemBuilder: (context, index) {
                                        final edition = pageEditions[index];
                                        return _buildEditionCard(context, edition);
                                      },
                                    )
                                  : Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        ...pageEditions.map(
                                          (edition) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 16,
                                            ),
                                            child: _buildEditionCard(context, edition),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Navigation arrows and page indicators
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Back arrow
                          Semantics(
                            label: 'Previous page',
                            button: true,
                            enabled: _currentPage > 0,
                            child: IconButton(
                              icon: Icon(
                                Icons.arrow_back_ios,
                                color: _currentPage > 0
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.3),
                              ),
                              onPressed: _currentPage > 0
                                  ? () {
                                      if (_pageController.hasClients) {
                                        _pageController.previousPage(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          curve: Curves.easeInOut,
                                        );
                                      }
                                    }
                                  : null,
                            ),
                          ),
                          // Page indicators
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                              _totalPages(context),
                              (index) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: index == _currentPage
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Next arrow
                          Semantics(
                            label: 'Next page',
                            button: true,
                            enabled: _currentPage < _totalPages(context) - 1,
                            child: IconButton(
                              icon: Icon(
                                Icons.arrow_forward_ios,
                                color: _currentPage < _totalPages(context) - 1
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.3),
                              ),
                              onPressed: _currentPage < _totalPages(context) - 1
                                  ? () {
                                      if (_pageController.hasClients) {
                                        _pageController.nextPage(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          curve: Curves.easeInOut,
                                        );
                                      }
                                    }
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Header at bottom replacing star animation
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: Column(
                        children: [
                          Text(
                            'YOUTH',
                            style: AppTypography.orbitron(
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
                            style: AppTypography.ibmPlexMono(
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
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onAIEditionTapped() {
    if (!mounted || !context.mounted) return;
    try {
      NavigationHelper.safePush(
        context,
        MaterialPageRoute(
          builder: (_) => const AIEditionInputScreen(isYouthEdition: true),
        ),
      );
    } catch (e) {
      // Handle navigation error gracefully
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Widget _buildEditionCard(BuildContext context, YouthEdition edition) {
    return GestureDetector(
      onTap: edition.isAI
          ? () => _onAIEditionTapped()
          : () => _onEditionTapped(edition),
      child: Container(
        constraints: BoxConstraints(
          minHeight: ResponsiveHelper.isTablet(context) ? 160.0 : 130.0,
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: edition.isAI
              ? const Color(0xFF6366F1).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppShadows.medium,
          border: Border.all(
            color: edition.isAI
                ? const Color(0xFF6366F1)
                : const Color(0xFF6B4FC9),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
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
                      fontSize: ResponsiveHelper.isTablet(context) ? 24 : 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.of(context).primaryText,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              edition.tagline,
              style: AppTypography.bodyMedium.copyWith(
                fontSize: ResponsiveHelper.isTablet(context) ? 16 : 14,
                color: AppColors.of(context).secondaryText,
              ),
              maxLines: null,
              overflow: TextOverflow.visible,
              softWrap: true,
            ),
          ],
        ),
      ),
    );
  }

  void _onEditionTapped(YouthEdition edition) {
    if (!mounted || !context.mounted) return;
    try {
      // Navigate to transition screen first, then to game
      NavigationHelper.safePush(
        context,
        MaterialPageRoute(
          builder: (_) => YouthTransitionScreen(
            onFinished: () {
              if (!context.mounted) return;
              NavigationHelper.safePop(context); // Pop transition screen
              // Navigate to game screen with edition info
              if (!context.mounted) return;
              NavigationHelper.safeNavigate(
                context,
                '/game',
                arguments: {
                  'mode': null,
                  'edition': edition.title.toLowerCase().replaceAll(' ', '_'),
                  'editionName': edition.title,
                },
              );
            },
          ),
        ),
      );
    } catch (e) {
      // Handle navigation error gracefully
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error navigating to game: ${e.toString()}')),
        );
      }
    }
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
