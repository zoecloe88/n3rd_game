import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:n3rd_game/services/content_moderation_service.dart';
import 'package:n3rd_game/services/friends_service.dart';
import 'package:n3rd_game/services/ai_edition_service.dart';
import 'package:n3rd_game/utils/input_sanitizer.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/widgets/video_background_widget.dart';

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
      body: VideoBackgroundWidget(
        videoPath: 'assets/settingscreen.mp4', // Use settings video as fallback
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        loop: true,
        autoplay: true,
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
                        const SizedBox(height: 24),

                        // Action buttons row
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  if (_formKey.currentState!.validate()) {
                                    _saveTriviaLocally();
                                  }
                                },
                                icon: const Icon(Icons.save_outlined),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
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
                                onPressed: () {
                                  if (_formKey.currentState!.validate()) {
                                    _saveTrivia();
                                  }
                                },
                                icon: const Icon(Icons.cloud_upload_outlined),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00D9FF),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
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
                                onPressed: () {
                                  if (_formKey.currentState!.validate()) {
                                    _sendToFriend();
                                  }
                                },
                                icon: const Icon(Icons.send_outlined),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
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
                                onPressed: () {
                                  _showAIAssistDialog();
                                },
                                icon: const Icon(Icons.auto_awesome_outlined),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
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

  // Save trivia locally using SharedPreferences
  Future<void> _saveTriviaLocally() async {
    try {
      final allWords = _wordControllers
          .map((c) => c.text.trim())
          .where((w) => w.isNotEmpty)
          .toList();
      final correctAnswers = _correctAnswerControllers
          .map((c) => c.text.trim())
          .where((w) => w.isNotEmpty)
          .toList();

      final triviaData = {
        'category': _categoryController.text.trim(),
        'question': _questionController.text.trim(),
        'words': allWords,
        'correctAnswers': correctAnswers,
        'savedAt': DateTime.now().toIso8601String(),
      };

      final prefs = await SharedPreferences.getInstance();
      final savedTriviaList = prefs.getStringList('saved_trivia') ?? [];
      savedTriviaList.add(jsonEncode(triviaData));
      await prefs.setStringList('saved_trivia', savedTriviaList);

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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to save locally: $e',
            style: AppTypography.bodyMedium.copyWith(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Send trivia to a friend
  Future<void> _sendToFriend() async {
    try {
      final friendsService = Provider.of<FriendsService>(context, listen: false);
      final user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please sign in to send trivia to friends',
              style: AppTypography.bodyMedium.copyWith(),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Get friend list
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

      // Show friend selection dialog
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
                    style: AppTypography.bodyMedium.copyWith(color: Colors.white),
                  ),
                  onTap: () => Navigator.pop(context, friend.userId),
                );
              },
            ),
          ),
        ),
      );

      if (selectedFriend != null) {
        // Save trivia data to Firestore for friend
        final firestore = FirebaseFirestore.instance;
        final triviaData = {
          'category': _categoryController.text.trim(),
          'question': _questionController.text.trim(),
          'words': _wordControllers
              .map((c) => c.text.trim())
              .where((w) => w.isNotEmpty)
              .toList(),
          'correctAnswers': _correctAnswerControllers
              .map((c) => c.text.trim())
              .where((w) => w.isNotEmpty)
              .toList(),
          'fromUserId': user.uid,
          'fromUserName': user.displayName ?? user.email,
          'toUserId': selectedFriend,
          'sentAt': FieldValue.serverTimestamp(),
        };

        await firestore.collection('shared_trivia').add(triviaData);

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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to send trivia: $e',
            style: AppTypography.bodyMedium.copyWith(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show AI assistance dialog
  void _showAIAssistDialog() {
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
                Navigator.pop(context);
                _getAISuggestion('question');
              },
            ),
            ListTile(
              leading: const Icon(Icons.text_fields, color: Colors.white),
              title: Text(
                'Suggest Words',
                style: AppTypography.bodyMedium.copyWith(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _getAISuggestion('words');
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline, color: Colors.white),
              title: Text(
                'Suggest Answers',
                style: AppTypography.bodyMedium.copyWith(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _getAISuggestion('answers');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTypography.labelLarge.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // Get AI suggestion
  Future<void> _getAISuggestion(String type) async {
    try {
      final aiService = Provider.of<AIEditionService>(context, listen: false);
      final category = _categoryController.text.trim();
      
      if (category.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please enter a category first',
              style: AppTypography.bodyMedium.copyWith(),
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Generating AI suggestions...',
            style: AppTypography.bodyMedium.copyWith(),
          ),
        ),
      );

      // Generate trivia for the category
      final triviaItems = await aiService.generateTriviaForTopic(
        topic: category,
        isYouthEdition: false,
        count: 1,
      );

      if (triviaItems.isNotEmpty && mounted) {
        final item = triviaItems.first;
        setState(() {
          if (type == 'question') {
            _questionController.text = item.category;
          } else if (type == 'words') {
            // Fill word controllers with AI suggestions
            for (int i = 0; i < _wordControllers.length && i < item.words.length; i++) {
              _wordControllers[i].text = item.words[i];
            }
          } else if (type == 'answers') {
            // Fill answer controllers with AI suggestions
            for (int i = 0; i < _correctAnswerControllers.length && i < item.correctAnswers.length; i++) {
              _correctAnswerControllers[i].text = item.correctAnswers[i];
            }
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'AI suggestions applied!',
              style: AppTypography.bodyMedium.copyWith(),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to get AI suggestions: $e',
            style: AppTypography.bodyMedium.copyWith(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
