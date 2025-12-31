import 'dart:async';
import 'package:flutter/material.dart';
import 'package:n3rd_game/services/quick_tips_service.dart';
import 'package:n3rd_game/services/knowledge_base_service.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/theme/app_radius.dart';
import 'package:n3rd_game/screens/feedback_screen.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/utils/feedback_helper.dart';
import 'package:n3rd_game/utils/accessibility_helper.dart';
import 'package:n3rd_game/widgets/background_image_widget.dart';
import 'package:n3rd_game/widgets/app_button.dart';
import 'package:n3rd_game/widgets/app_card.dart';
import 'package:n3rd_game/widgets/app_text_field.dart';
import 'package:n3rd_game/widgets/app_chip.dart';
import 'package:n3rd_game/widgets/standardized_loading_widget.dart';
import 'package:n3rd_game/widgets/error_recovery_widget.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/services/haptic_service.dart';

/// Help Center screen providing access to quick tips, FAQ, and knowledge base articles
///
/// Features:
/// - Search functionality with debouncing
/// - Three tabs: Quick Tips, FAQ, Articles
/// - Article detail view
/// - Error handling and recovery
/// - Full accessibility support
class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _selectedTab = 'quick_tips';
  List<KnowledgeArticle> _searchResults = [];
  bool _isSearching = false;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _searchDebounceTimer;

  static const String _tabQuickTips = 'quick_tips';
  static const String _tabFAQ = 'faq';
  static const String _tabArticles = 'articles';
  static const Duration _searchDebounceDelay = Duration(milliseconds: 300);

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Handle search input changes with debouncing
  ///
  /// Debounces search queries by 300ms to avoid excessive service calls
  /// Shows error recovery UI if search fails
  void _onSearchChanged(String query) {
    _searchDebounceTimer?.cancel();
    setState(() {
      _isSearching = query.isNotEmpty;
      _errorMessage = null;
    });

    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    _searchDebounceTimer = Timer(_searchDebounceDelay, () {
      if (!mounted) return;
      try {
        final results = KnowledgeBaseService.searchArticles(query);
        setState(() {
          _searchResults = results;
          _errorMessage = null;
        });
      } catch (e) {
        LoggerService.error(
          'HelpCenter: Failed to search articles',
          error: e,
          stack: StackTrace.current,
          fatal: false,
        );
        setState(() {
          _errorMessage = 'Failed to search articles. Please try again.';
          _searchResults = [];
        });
        FeedbackHelper.showError(context, _errorMessage!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).background,
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
                      semanticsLabel:
                          AppLocalizations.of(context)?.backButton ?? 'Back',
                      backgroundColor: Colors.transparent,
                      foregroundColor: AppColors.of(context).onDarkText,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Help Center',
                      style: AppTypography.headlineLarge.copyWith(
                        color: AppColors.of(context).onDarkText,
                      ),
                    ),
                    const Spacer(),
                    AppButton(
                      icon: Icons.feedback_outlined,
                      onPressed: () {
                        HapticService().lightImpact();
                        showDialog(
                          context: context,
                          builder: (context) => const FeedbackScreen(),
                        );
                      },
                      variant: AppButtonVariant.icon,
                      semanticsLabel: 'Submit Feedback',
                      backgroundColor: Colors.transparent,
                      foregroundColor: AppColors.of(context).onDarkText,
                    ),
                  ],
                ),
              ),

              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: AppTextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  hint: 'Search help articles...',
                  leadingIcon: Icons.search,
                  trailingIcon:
                      _searchController.text.isNotEmpty ? Icons.clear : null,
                  onTrailingIconTap: _searchController.text.isNotEmpty
                      ? () {
                          _searchController.clear();
                          _onSearchChanged('');
                        }
                      : null,
                  focusNode: _searchFocusNode,
                  textInputAction: TextInputAction.search,
                  semanticsLabel: 'Search help articles',
                  semanticsHint: 'Type to search for help articles',
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Tabs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: AppCard(
                  variant: AppCardVariant.filled,
                  padding: EdgeInsets.zero,
                  backgroundColor:
                      AppColors.of(context).onDarkText.withValues(alpha: 0.1),
                  child: Row(
                    children: [
                      _buildTab('Quick Tips', _tabQuickTips),
                      _buildTab('FAQ', _tabFAQ),
                      _buildTab('Articles', _tabArticles),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Content
              Expanded(
                child:
                    _isSearching ? _buildSearchResults() : _buildTabContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build a tab button with accessibility support
  ///
  /// [label] - Display text for the tab
  /// [value] - Tab identifier value
  Widget _buildTab(String label, String value) {
    final isSelected = _selectedTab == value;
    final colors = AppColors.of(context);
    return Expanded(
      child: AccessibilityHelper.buttonSemantics(
        label: '$label tab',
        hint: isSelected ? 'Selected' : 'Tap to select',
        selected: isSelected,
        onTap: () {
          HapticService().lightImpact();
          setState(() => _selectedTab = value);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.onDarkText.withValues(alpha: 0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.labelLarge.copyWith(
              color: colors.onDarkText,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  /// Build content for the currently selected tab
  ///
  /// Shows loading state, error recovery, or tab-specific content
  Widget _buildTabContent() {
    if (_isLoading) {
      return const StandardizedLoadingWidget(
        message: 'Loading help content...',
      );
    }

    if (_errorMessage != null && !_isSearching) {
      return ErrorRecoveryWidget(
        errorMessage: _errorMessage!,
        onRetry: () {
          setState(() {
            _errorMessage = null;
            _isLoading = true;
          });
          // Reload content
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          });
        },
      );
    }

    switch (_selectedTab) {
      case _tabQuickTips:
        return _buildQuickTips();
      case _tabFAQ:
        return _buildFAQ();
      case _tabArticles:
        return _buildArticles();
      default:
        return _buildQuickTips();
    }
  }

  /// Build the Quick Tips tab content
  ///
  /// Displays game gems organized by category with error handling
  Widget _buildQuickTips() {
    try {
      final gems = QuickTipsService.getAllGems();
      final categories = gems.map((g) => g.category).toSet().toList();
      final colors = AppColors.of(context);

      return ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            'Game Gems & Tips',
            style: AppTypography.headlineLarge.copyWith(
              color: colors.primaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Discover all the secrets to maximize your score and master the game!',
            style: AppTypography.bodyMedium.copyWith(
              color: colors.secondaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ...categories.map((category) {
            final categoryGems =
                gems.where((g) => g.category == category).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.toUpperCase(),
                  style: AppTypography.labelLarge.copyWith(
                    color: colors.primaryText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ...categoryGems.map((gem) => _buildGemCard(gem)),
                const SizedBox(height: AppSpacing.lg),
              ],
            );
          }),
        ],
      );
    } catch (e) {
      LoggerService.error(
        'HelpCenter: Failed to load quick tips',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
      return ErrorRecoveryWidget(
        errorMessage: 'Failed to load quick tips. Please try again.',
        onRetry: () {
          setState(() {});
        },
      );
    }
  }

  /// Build a card displaying a game gem (tip)
  ///
  /// [gem] - The game gem to display
  Widget _buildGemCard(GameGem gem) {
    final colors = AppColors.of(context);
    return AppCard(
      variant: AppCardVariant.outlined,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      backgroundColor: colors.cardBackground,
      semanticsLabel: '${gem.title}. ${gem.description}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  gem.title,
                  style: AppTypography.titleLarge.copyWith(
                    color: colors.primaryText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: Text(
                  gem.points,
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onDarkText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            gem.description,
            style: AppTypography.bodyMedium.copyWith(
              color: colors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  /// Build the FAQ tab content
  ///
  /// Displays frequently asked questions from the knowledge base
  Widget _buildFAQ() {
    try {
      final faqArticles = KnowledgeBaseService.getAllArticles()
          .where((a) => a.category == 'Support' || a.id == 'troubleshooting')
          .toList();
      final colors = AppColors.of(context);

      return ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            'Frequently Asked Questions',
            style: AppTypography.headlineLarge.copyWith(
              color: colors.primaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ...faqArticles.map((article) => _buildArticleCard(article)),
        ],
      );
    } catch (e) {
      LoggerService.error(
        'HelpCenter: Failed to load FAQ',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
      return ErrorRecoveryWidget(
        errorMessage: 'Failed to load FAQ. Please try again.',
        onRetry: () {
          setState(() {});
        },
      );
    }
  }

  /// Build the Articles tab content
  ///
  /// Displays all knowledge base articles organized by category
  Widget _buildArticles() {
    try {
      final articles = KnowledgeBaseService.getAllArticles();
      final categories = articles.map((a) => a.category).toSet().toList();
      final colors = AppColors.of(context);

      return ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            'Knowledge Base',
            style: AppTypography.headlineLarge.copyWith(
              color: colors.primaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ...categories.map((category) {
            final categoryArticles =
                articles.where((a) => a.category == category).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: AppTypography.titleLarge.copyWith(
                    color: colors.primaryText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ...categoryArticles
                    .map((article) => _buildArticleCard(article)),
                const SizedBox(height: AppSpacing.lg),
              ],
            );
          }),
        ],
      );
    } catch (e) {
      LoggerService.error(
        'HelpCenter: Failed to load articles',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
      return ErrorRecoveryWidget(
        errorMessage: 'Failed to load articles. Please try again.',
        onRetry: () {
          setState(() {});
        },
      );
    }
  }

  /// Build a card displaying a knowledge base article
  ///
  /// [article] - The article to display
  Widget _buildArticleCard(KnowledgeArticle article) {
    final colors = AppColors.of(context);
    final preview = article.content.length > 150
        ? '${article.content.substring(0, 150)}...'
        : article.content;

    return AppCard(
      variant: AppCardVariant.elevated,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => _showArticleDetail(article),
      semanticsLabel: '${article.title}. $preview',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            article.title,
            style: AppTypography.titleLarge.copyWith(
              color: colors.primaryText,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            preview,
            style: AppTypography.bodyMedium.copyWith(
              color: colors.secondaryText,
            ),
            maxLines: 3,
            overflow: TextOverflow.visible,
            softWrap: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: article.tags.take(3).map((tag) {
              return AppChip(
                label: tag,
                variant: AppChipVariant.filled,
                semanticsLabel: 'Tag: $tag',
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Build search results view
  ///
  /// Shows error state, empty state, or list of matching articles
  Widget _buildSearchResults() {
    if (_errorMessage != null) {
      return ErrorRecoveryWidget(
        errorMessage: _errorMessage!,
        onRetry: () {
          _onSearchChanged(_searchController.text);
        },
      );
    }

    if (_searchResults.isEmpty) {
      final colors = AppColors.of(context);
      return Semantics(
        label: 'No search results found. Try different keywords.',
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AccessibilityHelper.accessibleIcon(
                icon: Icons.search_off,
                label: 'No results',
                size: 64,
                color: colors.tertiaryText,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No results found',
                style: AppTypography.headlineLarge.copyWith(
                  color: colors.primaryText,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Try different keywords',
                style: AppTypography.bodyMedium.copyWith(
                  color: colors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final colors = AppColors.of(context);
    return Semantics(
      label: 'Search results: ${_searchResults.length} articles found',
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            'Search Results (${_searchResults.length})',
            style: AppTypography.headlineLarge.copyWith(
              color: colors.primaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ..._searchResults.map((article) => _buildArticleCard(article)),
        ],
      ),
    );
  }

  /// Show article detail in a dialog
  ///
  /// [article] - The article to display in detail
  void _showArticleDetail(KnowledgeArticle article) {
    final dialogColors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: dialogColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
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
                    AppButton(
                      icon: Icons.close,
                      onPressed: () => NavigationHelper.safePop(context),
                      variant: AppButtonVariant.icon,
                      semanticsLabel:
                          AppLocalizations.of(context)?.closeButton ?? 'Close',
                      backgroundColor: Colors.transparent,
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
