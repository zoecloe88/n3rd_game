import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/services/learning_service.dart';
import 'package:n3rd_game/models/reviewed_question.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/widgets/background_image_widget.dart';
import 'package:n3rd_game/widgets/app_button.dart';
import 'package:n3rd_game/widgets/app_card.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/widgets/empty_state_widget.dart';
import 'package:n3rd_game/utils/feedback_helper.dart';
import 'package:n3rd_game/widgets/error_recovery_widget.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Learning Mode screen for reviewing previously answered questions
///
/// Features:
/// - Review wrong answers
/// - Manage bookmarked questions
/// - View all reviewed questions
/// - Bookmark/unbookmark questions for later review
/// - Requires Premium subscription (enforced by RouteGuard)
///
/// Usage:
/// ```dart
/// Navigator.pushNamed(context, '/learning');
/// ```
class LearningModeScreen extends StatefulWidget {
  const LearningModeScreen({super.key});

  @override
  State<LearningModeScreen> createState() => _LearningModeScreenState();
}

class _LearningModeScreenState extends State<LearningModeScreen>
    with SingleTickerProviderStateMixin {
  // Constants
  static const double _wordChipIconSize = 16.0;
  static const int _tabCount = 3;
  static const String _tabWrongAnswers = 'Wrong Answers';
  static const String _tabBookmarked = 'Bookmarked';
  static const String _tabAllQuestions = 'All Questions';
  static const int _pageSize = 20; // Questions per page

  late TabController _tabController;
  final bool _isLoading = false;
  String? _errorMessage;

  // Memoization cache
  List<ReviewedQuestion>? _cachedWrongAnswers;
  List<ReviewedQuestion>? _cachedBookmarked;
  List<ReviewedQuestion>? _cachedAllQuestions;

  // Pagination state
  int _wrongAnswersPage = 0;
  int _bookmarkedPage = 0;
  int _allQuestionsPage = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // NOTE: Subscription access is enforced by RouteGuard in main.dart
    // No need for redundant check here
    final colors = AppColors.of(context);

    // Show error state if data loading failed
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
      body: BackgroundImageWidget(
        imagePath: 'assets/background n3rd.png',
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    AppButton(
                      icon: Icons.arrow_back,
                      onPressed: () => NavigationHelper.safePop(context),
                      variant: AppButtonVariant.icon,
                      backgroundColor: Colors.transparent,
                      foregroundColor: colors.onDarkText,
                      semanticsLabel:
                          'Go back. Double tap to return to previous screen',
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Learning Mode',
                      style: AppTypography.headlineLarge.copyWith(
                        color: colors.onDarkText,
                      ),
                    ),
                  ],
                ),
              ),

              // Tabs
              Semantics(
                label:
                    'Learning mode tabs. Use swipe or tap to switch between Wrong Answers, Bookmarked, and All Questions',
                child: TabBar(
                  controller: _tabController,
                  labelColor: colors.onDarkText,
                  unselectedLabelColor:
                      colors.onDarkText.withValues(alpha: 0.6),
                  indicatorColor: colors.accent,
                  labelStyle: AppTypography.labelLarge,
                  unselectedLabelStyle: AppTypography.labelLarge.copyWith(
                    color: colors.onDarkText.withValues(alpha: 0.6),
                  ),
                  tabs: [
                    Semantics(
                      label:
                          'Wrong Answers tab. Shows questions you answered incorrectly',
                      child: const Tab(text: _tabWrongAnswers),
                    ),
                    Semantics(
                      label:
                          'Bookmarked tab. Shows questions you bookmarked for review',
                      child: const Tab(text: _tabBookmarked),
                    ),
                    Semantics(
                      label: 'All Questions tab. Shows all reviewed questions',
                      child: const Tab(text: _tabAllQuestions),
                    ),
                  ],
                ),
              ),

              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildWrongAnswersTab(),
                    _buildBookmarkedTab(),
                    _buildAllQuestionsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build wrong answers tab
  ///
  /// Displays all questions that were answered incorrectly.
  /// Shows empty state if no wrong answers exist.
  Widget _buildWrongAnswersTab() {
    return Consumer<LearningService>(
      builder: (context, learningService, _) {
        try {
          // Memoize wrong answers
          final wrongAnswers =
              _cachedWrongAnswers ?? learningService.wrongAnswers;
          if (_cachedWrongAnswers != wrongAnswers) {
            _cachedWrongAnswers = wrongAnswers;
          }

          if (wrongAnswers.isEmpty) {
            return _buildEmptyState(
              icon: Icons.check_circle_outline,
              title: 'No wrong answers yet!',
              description: 'Keep playing to review questions you got wrong.',
            );
          }

          // Pagination: show only current page
          final startIndex = _wrongAnswersPage * _pageSize;
          final endIndex =
              (startIndex + _pageSize).clamp(0, wrongAnswers.length);
          final paginatedQuestions = wrongAnswers.sublist(0, endIndex);
          final hasMore = endIndex < wrongAnswers.length;

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: paginatedQuestions.length + (hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == paginatedQuestions.length) {
                // Load more button
                return _buildLoadMoreButton(
                  onPressed: () {
                    setState(() {
                      _wrongAnswersPage++;
                    });
                  },
                );
              }
              final question = paginatedQuestions[index];
              return _buildQuestionCard(question, learningService);
            },
          );
        } catch (e) {
          LoggerService.error(
            'LearningModeScreen: Error loading wrong answers',
            error: e,
            stack: StackTrace.current,
            fatal: false,
          );
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _errorMessage =
                      'Failed to load wrong answers. Please try again.';
                });
              }
            });
          }
          return const SizedBox.shrink();
        }
      },
    );
  }

  /// Build bookmarked tab
  ///
  /// Displays all questions that have been bookmarked for review.
  /// Shows empty state if no bookmarks exist.
  Widget _buildBookmarkedTab() {
    return Consumer<LearningService>(
      builder: (context, learningService, _) {
        try {
          // Memoize bookmarked questions
          final bookmarked =
              _cachedBookmarked ?? learningService.bookmarkedQuestions;
          if (_cachedBookmarked != bookmarked) {
            _cachedBookmarked = bookmarked;
          }

          if (bookmarked.isEmpty) {
            return _buildEmptyState(
              icon: Icons.bookmark_border,
              title: 'No bookmarks yet',
              description: 'Bookmark questions to review them later.',
            );
          }

          // Pagination: show only current page
          final startIndex = _bookmarkedPage * _pageSize;
          final endIndex = (startIndex + _pageSize).clamp(0, bookmarked.length);
          final paginatedQuestions = bookmarked.sublist(0, endIndex);
          final hasMore = endIndex < bookmarked.length;

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: paginatedQuestions.length + (hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == paginatedQuestions.length) {
                // Load more button
                return _buildLoadMoreButton(
                  onPressed: () {
                    setState(() {
                      _bookmarkedPage++;
                    });
                  },
                );
              }
              final question = paginatedQuestions[index];
              return _buildQuestionCard(question, learningService);
            },
          );
        } catch (e) {
          LoggerService.error(
            'LearningModeScreen: Error loading bookmarked questions',
            error: e,
            stack: StackTrace.current,
            fatal: false,
          );
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _errorMessage =
                      'Failed to load bookmarked questions. Please try again.';
                });
              }
            });
          }
          return const SizedBox.shrink();
        }
      },
    );
  }

  /// Build all questions tab
  ///
  /// Displays all reviewed questions regardless of correctness or bookmark status.
  /// Shows empty state if no questions have been reviewed.
  Widget _buildAllQuestionsTab() {
    return Consumer<LearningService>(
      builder: (context, learningService, _) {
        try {
          // Memoize all questions
          final allQuestions =
              _cachedAllQuestions ?? learningService.reviewedQuestions;
          if (_cachedAllQuestions != allQuestions) {
            _cachedAllQuestions = allQuestions;
          }

          if (allQuestions.isEmpty) {
            return _buildEmptyState(
              icon: Icons.history,
              title: 'No questions reviewed yet',
              description: 'Play games to build your question history.',
            );
          }

          // Pagination: show only current page
          final startIndex = _allQuestionsPage * _pageSize;
          final endIndex =
              (startIndex + _pageSize).clamp(0, allQuestions.length);
          final paginatedQuestions = allQuestions.sublist(0, endIndex);
          final hasMore = endIndex < allQuestions.length;

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: paginatedQuestions.length + (hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == paginatedQuestions.length) {
                // Load more button
                return _buildLoadMoreButton(
                  onPressed: () {
                    setState(() {
                      _allQuestionsPage++;
                    });
                  },
                );
              }
              final question = paginatedQuestions[index];
              return _buildQuestionCard(question, learningService);
            },
          );
        } catch (e) {
          LoggerService.error(
            'LearningModeScreen: Error loading all questions',
            error: e,
            stack: StackTrace.current,
            fatal: false,
          );
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _errorMessage = 'Failed to load questions. Please try again.';
                });
              }
            });
          }
          return const SizedBox.shrink();
        }
      },
    );
  }

  /// Build empty state widget
  ///
  /// Parameters:
  /// - [icon]: Icon to display
  /// - [title]: Empty state title
  /// - [description]: Empty state description
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return EmptyStateWidget(
      icon: icon,
      title: title,
      description: description,
    );
  }

  /// Build load more button for pagination
  ///
  /// Parameters:
  /// - [onPressed]: Callback when button is pressed
  Widget _buildLoadMoreButton({required VoidCallback onPressed}) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Semantics(
        label: 'Load more questions. Double tap to load additional questions',
        button: true,
        child: AppButton.primary(
          label: 'Load More',
          onPressed: onPressed,
          size: AppButtonSize.medium,
        ),
      ),
    );
  }

  /// Build question card widget
  ///
  /// Displays a reviewed question with its category, game mode, words,
  /// correct/incorrect indicators, and bookmark functionality.
  ///
  /// Parameters:
  /// - [question]: The reviewed question to display
  /// - [learningService]: The learning service for bookmark operations
  Widget _buildQuestionCard(
    ReviewedQuestion question,
    LearningService learningService,
  ) {
    final colors = AppColors.of(context);
    final cardColor = question.wasCorrect
        ? colors.success.withValues(alpha: 0.1)
        : colors.error.withValues(alpha: 0.1);

    return Semantics(
      label:
          'Question card: ${question.category}. ${question.wasCorrect ? "Correct" : "Incorrect"}. ${question.isBookmarked ? "Bookmarked" : "Not bookmarked"}',
      child: AppCard.filled(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.lg),
        backgroundColor: cardColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildQuestionHeader(question, learningService, colors),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Words:',
              style: AppTypography.labelSmall.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.onDarkText.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: question.words.map((word) {
                return _buildWordChip(
                  word: word,
                  isCorrect: question.correctAnswers.contains(word),
                  wasSelected: question.userAnswers.contains(word),
                  colors: colors,
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your answers: ${question.userAnswers.join(", ")}',
              style: AppTypography.bodySmall.copyWith(
                color: colors.onDarkText.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build question header with category, game mode, and bookmark button
  ///
  /// Parameters:
  /// - [question]: The reviewed question
  /// - [learningService]: The learning service for bookmark operations
  /// - [colors]: App colors for theming
  Widget _buildQuestionHeader(
    ReviewedQuestion question,
    LearningService learningService,
    AppColorScheme colors,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                question.category,
                style: AppTypography.headlineMedium.copyWith(
                  color: colors.onDarkText,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${question.gameMode} • Round ${question.roundNumber}',
                style: AppTypography.bodySmall.copyWith(
                  color: colors.onDarkText.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        Semantics(
          label: question.isBookmarked
              ? 'Remove bookmark. Double tap to unbookmark this question'
              : 'Add bookmark. Double tap to bookmark this question for later review',
          button: true,
          child: AppButton(
            icon:
                question.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            onPressed: () async {
              try {
                await learningService.toggleBookmark(question.questionId);
                if (mounted) {
                  FeedbackHelper.showInfo(
                    context,
                    question.isBookmarked
                        ? 'Bookmark removed'
                        : 'Question bookmarked',
                  );
                }
              } catch (e) {
                LoggerService.error(
                  'LearningModeScreen: Failed to toggle bookmark',
                  error: e,
                  stack: StackTrace.current,
                  fatal: false,
                );
                if (mounted) {
                  FeedbackHelper.showError(
                    context,
                    'Failed to update bookmark. Please try again.',
                  );
                }
              }
            },
            variant: AppButtonVariant.icon,
            backgroundColor: Colors.transparent,
            foregroundColor: question.isBookmarked
                ? colors.warning
                : colors.onDarkText.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  /// Build word chip with correct/incorrect indicators
  ///
  /// Parameters:
  /// - [word]: The word to display
  /// - [isCorrect]: Whether this word is a correct answer
  /// - [wasSelected]: Whether this word was selected by the user
  /// - [colors]: App colors for theming
  Widget _buildWordChip({
    required String word,
    required bool isCorrect,
    required bool wasSelected,
    required AppColorScheme colors,
  }) {
    final chipColor = isCorrect
        ? colors.success.withValues(alpha: 0.3)
        : wasSelected
            ? colors.error.withValues(alpha: 0.3)
            : colors.onDarkText.withValues(alpha: 0.1);

    return Semantics(
      label:
          '$word. ${isCorrect ? "Correct answer" : wasSelected ? "Incorrect answer" : "Not selected"}',
      child: AppCard.filled(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        backgroundColor: chipColor,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              word,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.onDarkText,
              ),
            ),
            if (isCorrect) ...[
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.check,
                size: _wordChipIconSize,
                color: colors.success,
              ),
            ],
            if (wasSelected && !isCorrect) ...[
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.close,
                size: _wordChipIconSize,
                color: colors.error,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
