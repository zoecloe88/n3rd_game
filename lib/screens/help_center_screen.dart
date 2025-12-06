import 'package:flutter/material.dart';
import 'package:n3rd_game/services/quick_tips_service.dart';
import 'package:n3rd_game/services/knowledge_base_service.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/widgets/unified_background_widget.dart';
import 'package:n3rd_game/config/screen_animations_config.dart';
import 'package:n3rd_game/screens/feedback_screen.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final _searchController = TextEditingController();
  String _selectedTab = 'quick_tips';
  List<KnowledgeArticle> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _isSearching = query.isNotEmpty;
      if (query.isNotEmpty) {
        _searchResults = KnowledgeBaseService.searchArticles(query);
      } else {
        _searchResults = [];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final route = ModalRoute.of(context)?.settings.name;
    final animationPath = ScreenAnimationsConfig.getAnimationForRoute(route);

    return Scaffold(
      backgroundColor: colors.background,
      body: UnifiedBackgroundWidget(
        animationPath: animationPath,
        animationAlignment: Alignment.bottomCenter,
        animationPadding: const EdgeInsets.only(bottom: 20),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Semantics(
                      label: AppLocalizations.of(context)?.backButton ?? 'Back',
                      button: true,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        tooltip:
                            AppLocalizations.of(context)?.backButton ?? 'Back',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Help Center',
                      style: AppTypography.headlineLarge.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Semantics(
                      label: 'Submit Feedback',
                      button: true,
                      child: IconButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => const FeedbackScreen(),
                          );
                        },
                        icon: const Icon(
                          Icons.feedback_outlined,
                          color: Colors.white,
                        ),
                        tooltip: 'Submit Feedback',
                      ),
                    ),
                  ],
                ),
              ),

              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: AppTypography.bodyMedium.copyWith(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search help articles...',
                    hintStyle: AppTypography.bodyMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    prefixIcon: const Icon(Icons.search, color: Colors.white),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? Semantics(
                            label: 'Clear search',
                            button: true,
                            child: IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                              tooltip: 'Clear search',
                            ),
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Tabs
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _buildTab('Quick Tips', 'quick_tips'),
                    _buildTab('FAQ', 'faq'),
                    _buildTab('Articles', 'articles'),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Content
              Expanded(
                child: _isSearching
                    ? _buildSearchResults()
                    : _buildTabContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(String label, String value) {
    final isSelected = _selectedTab == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.labelLarge.copyWith(
              color: Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 'quick_tips':
        return _buildQuickTips();
      case 'faq':
        return _buildFAQ();
      case 'articles':
        return _buildArticles();
      default:
        return _buildQuickTips();
    }
  }

  Widget _buildQuickTips() {
    final gems = QuickTipsService.getAllGems();
    final categories = gems.map((g) => g.category).toSet().toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Game Gems & Tips',
          style: AppTypography.headlineLarge.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          'Discover all the secrets to maximize your score and master the game!',
          style: AppTypography.bodyMedium.copyWith(
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 24),

        ...categories.map((category) {
          final categoryGems = gems
              .where((g) => g.category == category)
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.toUpperCase(),
                style: AppTypography.labelLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...categoryGems.map((gem) => _buildGemCard(gem)),
              const SizedBox(height: 24),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildGemCard(GameGem gem) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  gem.title,
                  style: AppTypography.titleLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  gem.points,
                  style: AppTypography.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            gem.description,
            style: AppTypography.bodyMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQ() {
    final faqArticles = KnowledgeBaseService.getAllArticles()
        .where((a) => a.category == 'Support' || a.id == 'troubleshooting')
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Frequently Asked Questions',
          style: AppTypography.headlineLarge.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 24),
        ...faqArticles.map((article) => _buildArticleCard(article)),
      ],
    );
  }

  Widget _buildArticles() {
    final articles = KnowledgeBaseService.getAllArticles();
    final categories = articles.map((a) => a.category).toSet().toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Knowledge Base',
          style: AppTypography.headlineLarge.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 24),
        ...categories.map((category) {
          final categoryArticles = articles
              .where((a) => a.category == category)
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category,
                style: AppTypography.titleLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...categoryArticles.map((article) => _buildArticleCard(article)),
              const SizedBox(height: 24),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildArticleCard(KnowledgeArticle article) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: Colors.white.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () => _showArticleDetail(article),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article.title,
                  style: AppTypography.titleLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${article.content.substring(0, article.content.length > 150 ? 150 : article.content.length)}...',
                  style: AppTypography.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: article.tags.take(3).map((tag) {
                    final chipColors = AppColors.of(context);
                    return Chip(
                      label: Text(tag, style: AppTypography.labelSmall),
                      backgroundColor: chipColors.cardBackground.withValues(
                        alpha: 0.2,
                      ),
                      labelStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: AppTypography.headlineLarge.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Try different keywords',
              style: AppTypography.bodyMedium.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Search Results (${_searchResults.length.toString()})',
          style: AppTypography.headlineLarge.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 16),
        ..._searchResults.map((article) => _buildArticleCard(article)),
      ],
    );
  }

  void _showArticleDetail(KnowledgeArticle article) {
    final dialogColors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: dialogColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: dialogColors.borderLight),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        article.title,
                        style: AppTypography.headlineLarge,
                      ),
                    ),
                    Semantics(
                      label:
                          AppLocalizations.of(context)?.closeButton ?? 'Close',
                      button: true,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                        tooltip:
                            AppLocalizations.of(context)?.closeButton ??
                            'Close',
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Text(article.content, style: AppTypography.bodyLarge),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
