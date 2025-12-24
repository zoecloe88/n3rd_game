import 'package:flutter/material.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:n3rd_game/services/content_moderation_service.dart';
import 'package:n3rd_game/utils/input_sanitizer.dart';
import 'package:n3rd_game/widgets/unified_background_widget.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';

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

  @override
  void dispose() {
    _categoryController.dispose();
    _questionController.dispose();
    for (final controller in _wordControllers) {
      controller.dispose();
    }
    for (final controller in _correctAnswerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // NOTE: Subscription access is enforced by RouteGuard in main.dart
    // No need for redundant check here

    return Scaffold(
      backgroundColor: AppColors.of(context).background,
      body: UnifiedBackgroundWidget(
        child: SafeArea(
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
                child: SingleChildScrollView(
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
                          ),
                          style: AppTypography.bodyMedium.copyWith(
                            color: Colors.white,
                          ),
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
                          ),
                          style: AppTypography.bodyMedium.copyWith(
                            color: Colors.white,
                          ),
                          maxLines: 3,
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
                              ),
                              style: AppTypography.bodyMedium.copyWith(
                                color: Colors.white,
                              ),
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
                                labelStyle: AppTypography.bodyMedium.copyWith(
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                                filled: true,
                                fillColor: Colors.green.withValues(alpha: 0.1),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.green.withValues(alpha: 0.3),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.green.withValues(alpha: 0.3),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                              style: AppTypography.bodyMedium.copyWith(
                                color: Colors.white,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a correct answer';
                                }
                                // Verify this word is in the words list
                                final allWords = _wordControllers
                                    .map((c) => c.text.trim().toLowerCase())
                                    .toList();
                                if (!allWords.contains(
                                  value.trim().toLowerCase(),
                                )) {
                                  return 'This word must be in the words list';
                                }
                                return null;
                              },
                            ),
                          );
                        }),
                        const SizedBox(height: 32),

                        // Save button
                        ElevatedButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              _saveTrivia();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00D9FF),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            'Save Trivia',
                            style: AppTypography.bodyMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
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

  Future<void> _saveTrivia() async {
    try {
      // Import Firestore
      final firestore = FirebaseFirestore.instance;
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please sign in to save trivia',
              style: AppTypography.bodyMedium.copyWith(),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Import content moderation
      final contentModeration = ContentModerationService();

      // Create TriviaItem
      final allWords = _wordControllers
          .map((c) => c.text.trim())
          .where((w) => w.isNotEmpty)
          .toList();
      final correctAnswers = _correctAnswerControllers
          .map((c) => c.text.trim())
          .where((w) => w.isNotEmpty)
          .toList();

      // Validate content
      final validationError = contentModeration.validateTriviaContent(
        category: _categoryController.text.trim(),
        question: _questionController.text.trim(),
        words: allWords,
        correctAnswers: correctAnswers,
      );

      if (validationError != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              validationError,
              style: AppTypography.bodyMedium.copyWith(),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      // Sanitize inputs
      final sanitizedCategory = InputSanitizer.sanitizeText(
        _categoryController.text.trim(),
      );
      final sanitizedQuestion = InputSanitizer.sanitizeText(
        _questionController.text.trim(),
      );
      final sanitizedWords =
          allWords.map((w) => InputSanitizer.sanitizeText(w)).toList();
      final sanitizedAnswers =
          correctAnswers.map((a) => InputSanitizer.sanitizeText(a)).toList();

      final triviaItem = {
        'category': sanitizedCategory,
        'question': sanitizedQuestion,
        'words': sanitizedWords,
        'correctAnswers': sanitizedAnswers,
        'difficulty': 'medium', // Default difficulty
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'isCustom': true,
        'isPublic': false, // User can make public later
      };

      // Save to Firestore
      await firestore.collection('custom_trivia').add(triviaItem);

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

      // Clear form
      _categoryController.clear();
      _questionController.clear();
      for (final controller in _wordControllers) {
        controller.clear();
      }
      for (final controller in _correctAnswerControllers) {
        controller.clear();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to save trivia: $e',
            style: AppTypography.bodyMedium.copyWith(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
