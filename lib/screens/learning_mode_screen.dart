import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/services/learning_service.dart';
import 'package:n3rd_game/models/reviewed_question.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';

class LearningModeScreen extends StatefulWidget {
  const LearningModeScreen({super.key});

  @override
  State<LearningModeScreen> createState() => _LearningModeScreenState();
}

class _LearningModeScreenState extends State<LearningModeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    return Scaffold(
      backgroundColor: AppColors.of(context).background,
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Container(
              color: AppColors.of(context).background,
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => NavigationHelper.safePop(context),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Learning Mode',
                        style: AppTypography.headlineLarge.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // Tabs
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
                  indicatorColor: const Color(0xFF00D9FF),
                  tabs: const [
                    Tab(text: 'Wrong Answers'),
                    Tab(text: 'Bookmarked'),
                    Tab(text: 'All Questions'),
                  ],
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
        ],
      ),
    );
  }

  Widget _buildWrongAnswersTab() {
    return Consumer<LearningService>(
      builder: (context, learningService, _) {
        final wrongAnswers = learningService.wrongAnswers;

        if (wrongAnswers.isEmpty) {
          return Center(
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
                    Icons.check_circle_outline,
                    size: 64,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No wrong answers yet!',
                    style: AppTypography.headlineLarge.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Keep playing to review questions you got wrong.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: wrongAnswers.length,
          itemBuilder: (context, index) {
            final question = wrongAnswers[index];
            return _buildQuestionCard(question, learningService);
          },
        );
      },
    );
  }

  Widget _buildBookmarkedTab() {
    return Consumer<LearningService>(
      builder: (context, learningService, _) {
        final bookmarked = learningService.bookmarkedQuestions;

        if (bookmarked.isEmpty) {
          return Center(
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
                    Icons.bookmark_border,
                    size: 64,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No bookmarks yet',
                    style: AppTypography.headlineLarge.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bookmark questions to review them later.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bookmarked.length,
          itemBuilder: (context, index) {
            final question = bookmarked[index];
            return _buildQuestionCard(question, learningService);
          },
        );
      },
    );
  }

  Widget _buildAllQuestionsTab() {
    return Consumer<LearningService>(
      builder: (context, learningService, _) {
        final allQuestions = learningService.reviewedQuestions;

        if (allQuestions.isEmpty) {
          return Center(
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
                    Icons.history,
                    size: 64,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No questions reviewed yet',
                    style: AppTypography.headlineLarge.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Play games to build your question history.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: allQuestions.length,
          itemBuilder: (context, index) {
            final question = allQuestions[index];
            return _buildQuestionCard(question, learningService);
          },
        );
      },
    );
  }

  Widget _buildQuestionCard(
    ReviewedQuestion question,
    LearningService learningService,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: question.wasCorrect
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: question.wasCorrect
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.category,
                      style: AppTypography.headlineLarge.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${question.gameMode} • Round ${question.roundNumber}',
                      style: AppTypography.bodyMedium.copyWith(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  question.isBookmarked
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  color: question.isBookmarked
                      ? Colors.amber
                      : Colors.white.withValues(alpha: 0.7),
                ),
                onPressed: () {
                  learningService.toggleBookmark(question.questionId);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Words:',
            style: AppTypography.bodyMedium.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: question.words.map((word) {
              final isCorrect = question.correctAnswers.contains(word);
              final wasSelected = question.userAnswers.contains(word);

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isCorrect
                      ? Colors.green.withValues(alpha: 0.3)
                      : wasSelected
                          ? Colors.red.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCorrect
                        ? Colors.green
                        : wasSelected
                            ? Colors.red
                            : Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      word,
                      style: AppTypography.bodyMedium.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    if (isCorrect) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.check, size: 16, color: Colors.green),
                    ],
                    if (wasSelected && !isCorrect) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.close, size: 16, color: Colors.red),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            'Your answers: ${question.userAnswers.join(", ")}',
            style: AppTypography.bodyMedium.copyWith(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
