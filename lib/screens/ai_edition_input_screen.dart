import 'package:flutter/material.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/services/ai_edition_service.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/theme/app_radius.dart';
import 'package:n3rd_game/theme/app_shadows.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';

/// Screen for users to input their desired topic/theme for AI Edition
class AIEditionInputScreen extends StatefulWidget {
  final bool isYouthEdition;

  const AIEditionInputScreen({super.key, required this.isYouthEdition});

  @override
  State<AIEditionInputScreen> createState() => _AIEditionInputScreenState();
}

class _AIEditionInputScreenState extends State<AIEditionInputScreen> {
  final TextEditingController _topicController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isGenerating = false;
  String? _errorMessage;
  List<String> _suggestedTopics = [];

  @override
  void initState() {
    super.initState();
    _loadSuggestedTopics();

    // Pre-fill topic if provided via route arguments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !context.mounted) return;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        final topic = args['topic'] as String?;
        if (topic != null && topic.isNotEmpty) {
          _topicController.text = topic;
        }
      }
    });
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  void _loadSuggestedTopics() {
    if (widget.isYouthEdition) {
      _suggestedTopics = [
        'Animals',
        'Space',
        'Dinosaurs',
        'Ocean',
        'Nature',
        'Science',
        'Art',
        'Music',
        'Sports',
        'Food',
      ];
    } else {
      _suggestedTopics = [
        'History',
        'Science',
        'Literature',
        'Art',
        'Music',
        'Geography',
        'Technology',
        'Philosophy',
        'Business',
        'Sports',
      ];
    }
  }

  Future<void> _generateTrivia() async {
    if (!_formKey.currentState!.validate()) return;

    // RouteGuard handles subscription checking at route level
    // Double-check subscription before expensive AI operation
    final subscriptionService = Provider.of<SubscriptionService>(
      context,
      listen: false,
    );
    if (!subscriptionService.hasEditionsAccess) {
      if (!mounted) return;
      _showUpgradeDialog();
      return;
    }

    final topic = _topicController.text.trim();
    if (topic.isEmpty) return;

    if (!mounted) return;
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    final aiService = Provider.of<AIEditionService>(context, listen: false);

    try {
      final triviaItems = await aiService.generateTriviaForTopic(
        topic: topic,
        isYouthEdition: widget.isYouthEdition,
        count: 50,
      );

      if (!mounted) return;

      setState(() {
        _isGenerating = false;
      });

      if (triviaItems.isEmpty) {
        if (!mounted) return;
        setState(() {
          _errorMessage = aiService.lastError ??
              'Failed to generate trivia. Please try a different topic.';
        });
        return;
      }

      // Navigate to game with generated trivia
      if (!mounted || !context.mounted) return;
      NavigationHelper.safeNavigate(
        context,
        '/game',
        arguments: {
          'mode': null,
          'edition': 'ai_edition',
          'editionName': 'AI Edition: $topic',
          'triviaPool': triviaItems,
          'isAIEdition': true,
        },
      );
    } on AIEditionException catch (e) {
      if (!mounted) return;

      setState(() {
        _isGenerating = false;
        _errorMessage = e.message;
      });

      // Show specific error message based on error type
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: e.type == AIEditionErrorType.rateLimitExceeded
              ? Colors.orange
              : Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isGenerating = false;
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    }
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Premium Required'),
        content: const Text(
          'AI Edition is a Premium feature. Upgrade to Premium to create unlimited custom trivia topics!',
        ),
        actions: [
          TextButton(
            onPressed: () => NavigationHelper.safePop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              NavigationHelper.safePop(context);
              NavigationHelper.safeNavigate(
                context,
                '/subscription-management',
              );
            },
            child: const Text('Upgrade to Premium'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => NavigationHelper.safePop(context),
        ),
        title: Text(
          widget.isYouthEdition ? 'AI Edition - Youth' : 'AI Edition',
          style: AppTypography.headlineLarge.copyWith(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.large),
                    boxShadow: AppShadows.large,
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 48,
                        color: Colors.white,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Create Your Own Trivia',
                        style: AppTypography.headlineLarge.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        widget.isYouthEdition
                            ? 'Enter any age-appropriate topic and we\'ll generate trivia for you!'
                            : 'Enter any topic or theme and we\'ll generate trivia for you!',
                        style: AppTypography.bodyMedium.copyWith(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Topic Input
                Text(
                  'Enter Your Topic',
                  style: AppTypography.bodyMedium.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _topicController,
                  style: AppTypography.bodyMedium.copyWith(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: widget.isYouthEdition
                        ? 'e.g., Dinosaurs, Space, Animals...'
                        : 'e.g., Ancient History, Quantum Physics, Jazz Music...',
                    hintStyle: AppTypography.bodyMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      borderSide: const BorderSide(
                        color: Color(0xFF6366F1),
                        width: 2,
                      ),
                    ),
                    prefixIcon: const Icon(
                      Icons.lightbulb_outline,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a topic';
                    }
                    if (value.trim().length < 2) {
                      return 'Topic must be at least 2 characters';
                    }
                    if (value.trim().length > 50) {
                      return 'Topic must be less than 50 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // Error message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: AppTypography.bodyMedium.copyWith(
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (_errorMessage != null)
                  const SizedBox(height: AppSpacing.md),

                // Suggested Topics
                Text(
                  'Suggested Topics',
                  style: AppTypography.bodyMedium.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: _suggestedTopics.map((topic) {
                    return ActionChip(
                      label: Text(topic),
                      onPressed: () {
                        _topicController.text = topic;
                      },
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      labelStyle: AppTypography.bodyMedium.copyWith(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Rate limit info
                Consumer<AIEditionService>(
                  builder: (context, aiService, _) {
                    return FutureBuilder<(bool, int)>(
                      future: aiService.checkRateLimit(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          final (canGenerate, remaining) = snapshot.data!;
                          if (remaining < 5) {
                            return Container(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              margin: const EdgeInsets.only(
                                bottom: AppSpacing.md,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.medium,
                                ),
                                border: Border.all(
                                  color: Colors.orange.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    color: Colors.orange,
                                    size: 20,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      '$remaining generations remaining today',
                                      style: AppTypography.bodyMedium.copyWith(
                                        fontSize: 12,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                        }
                        return const SizedBox.shrink();
                      },
                    );
                  },
                ),

                // Generate Button
                Consumer<SubscriptionService>(
                  builder: (context, subscriptionService, _) {
                    final isPremium = subscriptionService.isPremium;
                    return ElevatedButton(
                      onPressed: _isGenerating ? null : _generateTrivia,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isPremium ? const Color(0xFF6366F1) : Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                        ),
                      ),
                      child: _isGenerating
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  'Generating...',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.auto_awesome),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  'Generate Trivia',
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    );
                  },
                ),

                if (!Provider.of<SubscriptionService>(context).isPremium) ...[
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pushNamed('/subscription-management');
                    },
                    child: Text(
                      'Upgrade to Premium to unlock AI Edition',
                      style: AppTypography.bodyMedium.copyWith(
                        color: const Color(0xFF6366F1),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],

                // History button
                const SizedBox(height: AppSpacing.md),
                TextButton.icon(
                  onPressed: () {
                    NavigationHelper.safeNavigate(
                      context,
                      '/ai-edition-history',
                    );
                  },
                  icon: const Icon(Icons.history, size: 18),
                  label: Text(
                    'View Generation History',
                    style: AppTypography.bodyMedium.copyWith(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ),

                // Safety notice for youth
                if (widget.isYouthEdition) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          color: Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Safety Guardrails: All topics are filtered to ensure age-appropriate content for youth editions.',
                            style: AppTypography.bodyMedium.copyWith(
                              fontSize: 12,
                              color: Colors.blue.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
