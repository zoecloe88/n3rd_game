import 'package:flutter/material.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/services/ai_edition_service.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/theme/app_radius.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/widgets/empty_state_widget.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';

/// Screen to view and replay past AI Edition generations
class AIEditionHistoryScreen extends StatefulWidget {
  const AIEditionHistoryScreen({super.key});

  @override
  State<AIEditionHistoryScreen> createState() => _AIEditionHistoryScreenState();
}

class _AIEditionHistoryScreenState extends State<AIEditionHistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final aiService = Provider.of<AIEditionService>(context, listen: false);
      final history = await aiService.getGenerationHistory(limit: 50);

      if (!mounted) return;

      setState(() {
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load history: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _replayGeneration(Map<String, dynamic> historyItem) async {
    final topic = historyItem['topic'] as String;
    final isYouth = historyItem['isYouth'] as bool? ?? false;

    // Try to get cached trivia
    final aiService = Provider.of<AIEditionService>(context, listen: false);
    final cachedTrivia = await aiService.getCachedTriviaForTopic(
      topic,
      isYouth,
    );

    if (cachedTrivia != null && cachedTrivia.isNotEmpty) {
      // Navigate to game with cached trivia
      if (!mounted) return;
      NavigationHelper.safeNavigate(
        context,
        '/game',
        arguments: {
          'mode': null,
          'edition': 'ai_edition',
          'editionName': 'AI Edition: $topic',
          'triviaPool': cachedTrivia,
          'isAIEdition': true,
        },
      );
    } else {
      // Navigate to input screen with topic pre-filled
      if (!mounted) return;
      NavigationHelper.safeNavigate(
        context,
        '/ai-edition-input',
        arguments: {'topic': topic, 'isYouthEdition': isYouth},
      );
    }
  }

  String _formatDate(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now().toUtc();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          if (difference.inMinutes == 0) {
            return 'Just now';
          }
          return '${difference.inMinutes}m ago';
        }
        return '${difference.inHours}h ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'Unknown';
    }
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
          tooltip: AppLocalizations.of(context)?.backButton ?? 'Back',
        ),
        title: Text(
          'Generation History',
          style: AppTypography.headlineLarge.copyWith(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadHistory,
            tooltip: AppLocalizations.of(context)?.retryButton ?? 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _error!,
                      style: AppTypography.bodyMedium.copyWith(
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton(
                      onPressed: _loadHistory,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : _history.isEmpty
            ? EmptyStateWidget(
                icon: Icons.history,
                title:
                    AppLocalizations.of(context)?.noTriviaHistory ??
                    'No trivia history',
                description:
                    AppLocalizations.of(context)?.noTriviaHistoryDescription ??
                    'Play some games to see your history!',
              )
            : RefreshIndicator(
                onRefresh: _loadHistory,
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    final topic = item['topic'] as String;
                    final isYouth = item['isYouth'] as bool? ?? false;
                    final itemCount = item['itemCount'] as int? ?? 0;
                    final timestamp = item['timestamp'] as String;

                    return Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(AppSpacing.md),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                            ),
                            borderRadius: BorderRadius.circular(
                              AppRadius.small,
                            ),
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          topic,
                          style: AppTypography.bodyMedium.copyWith(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (isYouth)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.small,
                                      ),
                                    ),
                                    child: Text(
                                      'Youth',
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: Colors.blue,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                if (isYouth) const SizedBox(width: 8),
                                Text(
                                  '$itemCount items',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '•',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatDate(timestamp),
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                          ),
                          onPressed: () => _replayGeneration(item),
                          tooltip:
                              AppLocalizations.of(context)?.playButton ??
                              'Play',
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
