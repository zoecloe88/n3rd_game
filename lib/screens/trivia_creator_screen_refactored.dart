import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/services/trivia_creator_service.dart';
import 'package:n3rd_game/services/friends_service.dart';
import 'package:n3rd_game/services/ai_edition_service.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/widgets/video_background_widget.dart';
import 'package:n3rd_game/screens/trivia_creator_view_model.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';

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
                    16.0, 52.0, 16.0, 16.0,),
                child: Row(
                  children: [
                    Semantics(
                      label: AppLocalizations.of(context)?.backButton ?? 'Back',
                      button: true,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => NavigationHelper.safePop(context),
                        tooltip: AppLocalizations.of(context)?.backButton ?? 'Back',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Create Trivia',
                      style: AppTypography.headlineLarge.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Category
                            TextFormField(
                              controller: _categoryController,
                              decoration: InputDecoration(
                                labelText: 'Category',
                                labelStyle: AppTypography.bodyMedium.copyWith(
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.1),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF00D9FF),
                                  ),
                                ),
                                errorText: _viewModel.fieldErrors['category'],
                              ),
                              style: AppTypography.bodyMedium.copyWith(
                                color: Colors.white,
                              ),
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
                            const SizedBox(height: 16),

                            // Question/Statement
                            TextFormField(
                              controller: _questionController,
                              decoration: InputDecoration(
                                labelText: 'Question/Statement',
                                labelStyle: AppTypography.bodyMedium.copyWith(
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.1),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF00D9FF),
                                  ),
                                ),
                                errorText: _viewModel.fieldErrors['question'],
                              ),
                              style: AppTypography.bodyMedium.copyWith(
                                color: Colors.white,
                              ),
                              maxLines: 3,
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
                            const SizedBox(height: 24),

                            // Words (6 tiles)
                            Text(
                              'Words (6 total)',
                              style: AppTypography.bodyMedium.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...List.generate(6, (index) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: TextFormField(
                                  controller: _wordControllers[index],
                                  decoration: InputDecoration(
                                    labelText: 'Word ${index + 1}',
                                    labelStyle:
                                        AppTypography.bodyMedium.copyWith(
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
                                    ),
                                    filled: true,
                                    fillColor:
                                        Colors.white.withValues(alpha: 0.1),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color:
                                            Colors.white.withValues(alpha: 0.2),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color:
                                            Colors.white.withValues(alpha: 0.2),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF00D9FF),
                                      ),
                                    ),
                                    errorText:
                                        _viewModel.fieldErrors['word_$index'],
                                  ),
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: Colors.white,
                                  ),
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
                            const SizedBox(height: 24),

                            // Correct Answers (3)
                            Text(
                              'Correct Answers (3)',
                              style: AppTypography.bodyMedium.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...List.generate(3, (index) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: TextFormField(
                                  controller: _correctAnswerControllers[index],
                                  decoration: InputDecoration(
                                    labelText: 'Correct Answer ${index + 1}',
                                    labelStyle:
                                        AppTypography.bodyMedium.copyWith(
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
                                    ),
                                    filled: true,
                                    fillColor:
                                        Colors.green.withValues(alpha: 0.1),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color:
                                            Colors.green.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color:
                                            Colors.green.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: Colors.green,
                                      ),
                                    ),
                                    errorText: _viewModel
                                        .fieldErrors['correctAnswer_$index'],
                                  ),
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: Colors.white,
                                  ),
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
                            const SizedBox(height: 24),

                            // Action buttons row
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: service.isSaving
                                        ? null
                                        : () async {
                                            if (_formKey.currentState!
                                                .validate()) {
                                              await _saveTriviaLocally(service);
                                            }
                                          },
                                    icon: service.isSaving
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white,),
                                            ),
                                          )
                                        : const Icon(Icons.save_outlined),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16,),
                                      disabledBackgroundColor:
                                          Colors.green.withValues(alpha: 0.5),
                                    ),
                                    label: Text(
                                      'Save Locally',
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: service.isSaving
                                        ? null
                                        : () async {
                                            if (_formKey.currentState!
                                                .validate()) {
                                              await _saveTrivia(service);
                                            }
                                          },
                                    icon: service.isSaving
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white,),
                                            ),
                                          )
                                        : const Icon(
                                            Icons.cloud_upload_outlined,),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00D9FF),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16,),
                                      disabledBackgroundColor:
                                          const Color(0xFF00D9FF)
                                              .withValues(alpha: 0.5),
                                    ),
                                    label: Text(
                                      'Save to Cloud',
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: service.isSharing
                                        ? null
                                        : () async {
                                            if (_formKey.currentState!
                                                .validate()) {
                                              await _sendToFriend(service);
                                            }
                                          },
                                    icon: service.isSharing
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white,),
                                            ),
                                          )
                                        : const Icon(Icons.send_outlined),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16,),
                                      disabledBackgroundColor:
                                          Colors.blue.withValues(alpha: 0.5),
                                    ),
                                    label: Text(
                                      'Send to Friend',
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _viewModel.isGeneratingAI
                                        ? null
                                        : () {
                                            _showAIAssistDialog(service);
                                          },
                                    icon: _viewModel.isGeneratingAI
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white,),
                                            ),
                                          )
                                        : const Icon(
                                            Icons.auto_awesome_outlined,),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.purple,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16,),
                                      disabledBackgroundColor:
                                          Colors.purple.withValues(alpha: 0.5),
                                    ),
                                    label: Text(
                                      'AI Assist',
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Trivia saved successfully!',
            style: AppTypography.bodyMedium.copyWith(),
          ),
          backgroundColor: Colors.green,
        ),
      );

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Trivia saved locally!',
            style: AppTypography.bodyMedium.copyWith(),
          ),
          backgroundColor: Colors.green,
        ),
      );

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You have no friends. Add friends first!',
              style: AppTypography.bodyMedium.copyWith(),
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (!mounted) return;
      final selectedFriend = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.black.withValues(alpha: 0.95),
          title: Text(
            'Select Friend',
            style: AppTypography.headlineLarge.copyWith(color: Colors.white),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: friends.length,
              itemBuilder: (context, index) {
                final friend = friends[index];
                return ListTile(
                  title: Text(
                    friend.displayName ?? friend.email ?? 'Unknown',
                    style:
                        AppTypography.bodyMedium.copyWith(color: Colors.white),
                  ),
                  onTap: () => NavigationHelper.safePop(context, friend.userId),
                );
              },
            ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Trivia sent to friend!',
              style: AppTypography.bodyMedium.copyWith(),
            ),
            backgroundColor: Colors.green,
          ),
        );
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withValues(alpha: 0.95),
        title: Text(
          'AI Assistance',
          style: AppTypography.headlineLarge.copyWith(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Get AI suggestions for:',
              style: AppTypography.bodyMedium.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.lightbulb_outline, color: Colors.white),
              title: Text(
                'Suggest Question',
                style: AppTypography.bodyMedium.copyWith(color: Colors.white),
              ),
              onTap: () {
                NavigationHelper.safePop(context);
                _getAISuggestion(aiService, 'question');
              },
            ),
            ListTile(
              leading: const Icon(Icons.text_fields, color: Colors.white),
              title: Text(
                'Suggest Words',
                style: AppTypography.bodyMedium.copyWith(color: Colors.white),
              ),
              onTap: () {
                NavigationHelper.safePop(context);
                _getAISuggestion(aiService, 'words');
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.check_circle_outline, color: Colors.white),
              title: Text(
                'Suggest Answers',
                style: AppTypography.bodyMedium.copyWith(color: Colors.white),
              ),
              onTap: () {
                NavigationHelper.safePop(context);
                _getAISuggestion(aiService, 'answers');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => NavigationHelper.safePop(context),
            child: Text(
              'Cancel',
              style: AppTypography.labelLarge.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _getAISuggestion(AIEditionService aiService, String type) {
    _viewModel.getAISuggestion(
      aiService: aiService,
      type: type,
      onSuccess: (item) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'AI suggestions applied!',
              style: AppTypography.bodyMedium.copyWith(),
            ),
            backgroundColor: Colors.green,
          ),
        );
      },
      onError: (error) {
        if (!mounted) return;
        _showError(
            'Failed to get AI suggestions: $error', 'Please try again later.',);
      },
    );
  }

  void _showError(String message, String? recovery) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: AppTypography.bodyMedium.copyWith(),
            ),
            if (recovery != null) ...[
              const SizedBox(height: 4),
              Text(
                recovery,
                style: AppTypography.bodySmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
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
}



