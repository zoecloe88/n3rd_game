import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/theme/app_radius.dart';
import 'package:n3rd_game/services/trivia_creator_service.dart';
import 'package:n3rd_game/services/friends_service.dart';
import 'package:n3rd_game/services/ai_edition_service.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/widgets/video_background_widget.dart';
import 'package:n3rd_game/widgets/app_button.dart';
import 'package:n3rd_game/utils/feedback_helper.dart';
import 'package:n3rd_game/screens/trivia_creator_view_model.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';

class TriviaCreatorScreen extends StatefulWidget {
  const TriviaCreatorScreen({super.key});

  @override
  State<TriviaCreatorScreen> createState() => _TriviaCreatorScreenState();
}

class _TriviaCreatorScreenState extends State<TriviaCreatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _categoryController = TextEditingController();
  final _questionController = TextEditingController();
  final List<TextEditingController> _wordControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  final List<TextEditingController> _correctAnswerControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  late final TriviaCreatorViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = TriviaCreatorViewModel();
    _setupViewModelListeners();
  }

  void _setupViewModelListeners() {
    _viewModel.addListener(_onViewModelChanged);
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {
        // Update controllers from view model
        _categoryController.text = _viewModel.category;
        _questionController.text = _viewModel.question;
        for (int i = 0;
            i < _wordControllers.length && i < _viewModel.words.length;
            i++) {
          _wordControllers[i].text = _viewModel.words[i];
        }
        for (int i = 0;
            i < _correctAnswerControllers.length &&
                i < _viewModel.correctAnswers.length;
            i++) {
          _correctAnswerControllers[i].text = _viewModel.correctAnswers[i];
        }
      });
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _categoryController.dispose();
    _questionController.dispose();
    for (final controller in _wordControllers) {
      controller.dispose();
    }
    for (final controller in _correctAnswerControllers) {
      controller.dispose();
    }
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      body: VideoBackgroundWidget(
        videoPath: 'assets/settingscreen.mp4',
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        loop: true,
        autoplay: true,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.md,
                  AppSpacing.xl * 2,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Row(
                  children: [
                    AppButton(
                      icon: Icons.arrow_back,
                      onPressed: () => NavigationHelper.safePop(context),
                      variant: AppButtonVariant.icon,
                      backgroundColor: Colors.transparent,
                      foregroundColor: colors.onDarkText,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Create Trivia',
                      style: AppTypography.headlineLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.onDarkText,
                      ),
                    ),
                  ],
                ),
              ),

              // Form
              Expanded(
                child: Consumer<TriviaCreatorService>(
                  builder: (context, service, _) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Category
                            _buildFormField(
                              context,
                              controller: _categoryController,
                              label: 'Category',
                              leadingIcon: Icons.category,
                              errorText: _viewModel.fieldErrors['category'],
                              onChanged: (value) {
                                _viewModel.updateCategory(value);
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a category';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.md),

                            // Question/Statement
                            _buildFormField(
                              context,
                              controller: _questionController,
                              label: 'Question/Statement',
                              leadingIcon: Icons.help_outline,
                              maxLines: 3,
                              errorText: _viewModel.fieldErrors['question'],
                              onChanged: (value) {
                                _viewModel.updateQuestion(value);
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a question';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.lg),

                            // Words (6 tiles)
                            Text(
                              'Words (6 total)',
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colors.onDarkText,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            ...List.generate(6, (index) {
                              return Padding(
                                padding: const EdgeInsets.only(
                                    bottom: AppSpacing.md,),
                                child: _buildFormField(
                                  context,
                                  controller: _wordControllers[index],
                                  label: 'Word ${index + 1}',
                                  leadingIcon: Icons.text_fields,
                                  errorText:
                                      _viewModel.fieldErrors['word_$index'],
                                  onChanged: (value) {
                                    _viewModel.updateWord(index, value);
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a word';
                                    }
                                    return null;
                                  },
                                ),
                              );
                            }),
                            const SizedBox(height: AppSpacing.lg),

                            // Correct Answers (3)
                            Text(
                              'Correct Answers (3)',
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colors.onDarkText,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            ...List.generate(3, (index) {
                              return Padding(
                                padding: const EdgeInsets.only(
                                    bottom: AppSpacing.md,),
                                child: _buildFormField(
                                  context,
                                  controller: _correctAnswerControllers[index],
                                  label: 'Correct Answer ${index + 1}',
                                  leadingIcon: Icons.check_circle_outline,
                                  errorText: _viewModel
                                      .fieldErrors['correctAnswer_$index'],
                                  isCorrectAnswer: true,
                                  onChanged: (value) {
                                    _viewModel.updateCorrectAnswer(
                                        index, value,);
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a correct answer';
                                    }
                                    // Verify this word is in the words list
                                    final allWords = _wordControllers
                                        .map((c) => c.text.trim().toLowerCase())
                                        .toList();
                                    if (!allWords
                                        .contains(value.trim().toLowerCase())) {
                                      return 'This word must be in the words list';
                                    }
                                    return null;
                                  },
                                ),
                              );
                            }),
                            const SizedBox(height: AppSpacing.lg),

                            // Action buttons row
                            Row(
                              children: [
                                Expanded(
                                  child: AppButton(
                                    variant: AppButtonVariant.primary,
                                    icon: Icons.save_outlined,
                                    label: 'Save Locally',
                                    onPressed: service.isSaving
                                        ? null
                                        : () async {
                                            if (_formKey.currentState!
                                                .validate()) {
                                              await _saveTriviaLocally(service);
                                            }
                                          },
                                    isLoading: service.isSaving,
                                    backgroundColor: colors.success,
                                    foregroundColor: colors.onDarkText,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: AppButton(
                                    variant: AppButtonVariant.primary,
                                    icon: Icons.cloud_upload_outlined,
                                    label: 'Save to Cloud',
                                    onPressed: service.isSaving
                                        ? null
                                        : () async {
                                            if (_formKey.currentState!
                                                .validate()) {
                                              await _saveTrivia(service);
                                            }
                                          },
                                    isLoading: service.isSaving,
                                    backgroundColor: colors.accent,
                                    foregroundColor: colors.onDarkText,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              children: [
                                Expanded(
                                  child: AppButton(
                                    variant: AppButtonVariant.primary,
                                    icon: Icons.send_outlined,
                                    label: 'Send to Friend',
                                    onPressed: service.isSharing
                                        ? null
                                        : () async {
                                            if (_formKey.currentState!
                                                .validate()) {
                                              await _sendToFriend(service);
                                            }
                                          },
                                    isLoading: service.isSharing,
                                    backgroundColor: colors.info,
                                    foregroundColor: colors.onDarkText,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: AppButton(
                                    variant: AppButtonVariant.primary,
                                    icon: Icons.auto_awesome_outlined,
                                    label: 'AI Assist',
                                    onPressed: _viewModel.isGeneratingAI
                                        ? null
                                        : () {
                                            _showAIAssistDialog(service);
                                          },
                                    isLoading: _viewModel.isGeneratingAI,
                                    backgroundColor: Colors.purple,
                                    foregroundColor: colors.onDarkText,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveTrivia(TriviaCreatorService service) async {
    try {
      final formData = _viewModel.getFormData();
      await service.saveTriviaToCloud(
        category: formData['category'] as String,
        question: formData['question'] as String,
        words: formData['words'] as List<String>,
        correctAnswers: formData['correctAnswers'] as List<String>,
      );

      if (!mounted) return;
      FeedbackHelper.showSuccess(context, 'Trivia saved successfully!');

      _viewModel.clearForm();
      _clearControllers();
    } on ValidationException catch (e) {
      if (!mounted) return;
      _showError(e.message, e.recovery);
    } on AuthenticationException catch (e) {
      if (!mounted) return;
      _showError(e.message, e.recovery);
    } on NetworkException catch (e) {
      if (!mounted) return;
      _showError(e.message, e.recovery);
    } on StorageException catch (e) {
      if (!mounted) return;
      _showError(e.message, e.recovery);
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to save trivia: $e', 'Please try again later.');
    }
  }

  Future<void> _saveTriviaLocally(TriviaCreatorService service) async {
    try {
      final formData = _viewModel.getFormData();
      await service.saveTriviaLocally(
        category: formData['category'] as String,
        question: formData['question'] as String,
        words: formData['words'] as List<String>,
        correctAnswers: formData['correctAnswers'] as List<String>,
      );

      if (!mounted) return;
      FeedbackHelper.showSuccess(context, 'Trivia saved locally!');

      _viewModel.clearForm();
      _clearControllers();
    } on ValidationException catch (e) {
      if (!mounted) return;
      _showError(e.message, e.recovery);
    } on StorageException catch (e) {
      if (!mounted) return;
      _showError(e.message, e.recovery);
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to save locally: $e', 'Please try again later.');
    }
  }

  Future<void> _sendToFriend(TriviaCreatorService service) async {
    try {
      final friendsService =
          Provider.of<FriendsService>(context, listen: false);
      await friendsService.init();
      final friends = friendsService.friends;

      if (friends.isEmpty) {
        if (!mounted) return;
        FeedbackHelper.showWarning(
          context,
          'You have no friends. Add friends first!',
        );
        return;
      }

      if (!mounted) return;
      final colors = AppColors.of(context);
      final selectedFriend = await FeedbackHelper.showBottomSheet<String>(
        context,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Friend',
                style: AppTypography.headlineLarge
                    .copyWith(color: colors.onDarkText),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final friend = friends[index];
                    return ListTile(
                      title: Text(
                        friend.displayName ?? friend.email ?? 'Unknown',
                        style: AppTypography.bodyMedium
                            .copyWith(color: colors.onDarkText),
                      ),
                      onTap: () =>
                          NavigationHelper.safePop(context, friend.userId),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );

      if (selectedFriend != null) {
        final formData = _viewModel.getFormData();
        await service.shareTriviaWithFriend(
          friendUserId: selectedFriend,
          category: formData['category'] as String,
          question: formData['question'] as String,
          words: formData['words'] as List<String>,
          correctAnswers: formData['correctAnswers'] as List<String>,
        );

        if (!mounted) return;
        FeedbackHelper.showSuccess(context, 'Trivia sent to friend!');
      }
    } on ValidationException catch (e) {
      if (!mounted) return;
      _showError(e.message, e.recovery);
    } on AuthenticationException catch (e) {
      if (!mounted) return;
      _showError(e.message, e.recovery);
    } on NetworkException catch (e) {
      if (!mounted) return;
      _showError(e.message, e.recovery);
    } on StorageException catch (e) {
      if (!mounted) return;
      _showError(e.message, e.recovery);
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to send trivia: $e', 'Please try again later.');
    }
  }

  void _showAIAssistDialog(TriviaCreatorService service) {
    final aiService = Provider.of<AIEditionService>(context, listen: false);
    final colors = AppColors.of(context);

    FeedbackHelper.showBottomSheet(
      context,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'AI Assistance',
              style: AppTypography.headlineLarge
                  .copyWith(color: colors.onDarkText),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Get AI suggestions for:',
              style:
                  AppTypography.bodyMedium.copyWith(color: colors.onDarkText),
            ),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              leading: Icon(Icons.lightbulb_outline, color: colors.onDarkText),
              title: Text(
                'Suggest Question',
                style:
                    AppTypography.bodyMedium.copyWith(color: colors.onDarkText),
              ),
              onTap: () {
                NavigationHelper.safePop(context);
                _getAISuggestion(aiService, 'question');
              },
            ),
            ListTile(
              leading: Icon(Icons.text_fields, color: colors.onDarkText),
              title: Text(
                'Suggest Words',
                style:
                    AppTypography.bodyMedium.copyWith(color: colors.onDarkText),
              ),
              onTap: () {
                NavigationHelper.safePop(context);
                _getAISuggestion(aiService, 'words');
              },
            ),
            ListTile(
              leading:
                  Icon(Icons.check_circle_outline, color: colors.onDarkText),
              title: Text(
                'Suggest Answers',
                style:
                    AppTypography.bodyMedium.copyWith(color: colors.onDarkText),
              ),
              onTap: () {
                NavigationHelper.safePop(context);
                _getAISuggestion(aiService, 'answers');
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton.text(
                  label: 'Cancel',
                  onPressed: () => NavigationHelper.safePop(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _getAISuggestion(AIEditionService aiService, String type) {
    _viewModel.getAISuggestion(
      aiService: aiService,
      type: type,
      onSuccess: (item) {
        if (!mounted) return;
        FeedbackHelper.showSuccess(context, 'AI suggestions applied!');
      },
      onError: (error) {
        if (!mounted) return;
        _showError(
            'Failed to get AI suggestions: $error', 'Please try again later.',);
      },
    );
  }

  void _showError(String message, String? recovery) {
    final fullMessage = recovery != null ? '$message\n$recovery' : message;
    FeedbackHelper.showError(context, fullMessage);
  }

  void _clearControllers() {
    _categoryController.clear();
    _questionController.clear();
    for (final controller in _wordControllers) {
      controller.clear();
    }
    for (final controller in _correctAnswerControllers) {
      controller.clear();
    }
  }

  Widget _buildFormField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    IconData? leadingIcon,
    String? errorText,
    int maxLines = 1,
    bool isCorrectAnswer = false,
    ValueChanged<String>? onChanged,
    String? Function(String?)? validator,
  }) {
    final colors = AppColors.of(context);
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      validator: validator,
      style: AppTypography.bodyMedium.copyWith(
        color: colors.onDarkText,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: leadingIcon != null
            ? Icon(leadingIcon, color: colors.secondaryText)
            : null,
        filled: true,
        fillColor: isCorrectAnswer
            ? colors.success.withValues(alpha: 0.1)
            : colors.onDarkText.withValues(alpha: 0.1),
        errorText: errorText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: BorderSide(
            color: isCorrectAnswer
                ? colors.success.withValues(alpha: 0.3)
                : colors.onDarkText.withValues(alpha: 0.2),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: BorderSide(
            color: isCorrectAnswer
                ? colors.success.withValues(alpha: 0.3)
                : colors.onDarkText.withValues(alpha: 0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: BorderSide(
            color: isCorrectAnswer ? colors.success : colors.accent,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: BorderSide(
            color: colors.error,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: BorderSide(
            color: colors.error,
            width: 2,
          ),
        ),
        labelStyle: AppTypography.bodyMedium.copyWith(
          color: colors.onDarkText.withValues(alpha: 0.7),
        ),
        errorStyle: AppTypography.bodySmall.copyWith(
          color: colors.error,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
    );
  }
}
