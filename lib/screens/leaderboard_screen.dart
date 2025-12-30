import 'package:flutter/material.dart';
import 'package:n3rd_game/utils/unawaited_helper.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:n3rd_game/services/leaderboard_service.dart';
import 'package:n3rd_game/services/auth_service.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/widgets/empty_state_widget.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/services/haptic_service.dart';
import 'package:n3rd_game/widgets/background_image_widget.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/widgets/view_toggle_widget.dart';
import 'package:n3rd_game/widgets/personal_stats_view.dart';
import 'package:n3rd_game/utils/stats_preferences.dart';
import 'package:n3rd_game/services/analytics_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  final LeaderboardService _leaderboardService = LeaderboardService();
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _entries = [];
  int _userRank = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String _error = '';

  // Pagination state
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  static const int _pageSize = 20;

  // Filters
  String _selectedCategory = 'All';
  String _selectedTimePeriod = 'All Time';
  String _selectedRegion = 'Global';
  bool _friendsOnly = false;

  // View toggle state
  bool _showPersonalStats = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController.addListener(_onScroll);
    _loadPreferences();
    _loadLeaderboard(reset: true);
  }

  Future<void> _loadPreferences() async {
    final viewType = await StatsPreferences.getViewType();
    if (mounted) {
      setState(() {
        _showPersonalStats = viewType == 'personal_stats';
      });
    }
  }

  Future<void> _onViewToggleChanged(bool showPersonalStats) async {
    final viewType = showPersonalStats ? 'personal_stats' : 'leaderboard';
    await StatsPreferences.setViewType(viewType);

    // Track analytics - capture context before async
    if (!mounted) return;
    final analyticsService =
        Provider.of<AnalyticsService>(context, listen: false);
    await analyticsService.logCustomEvent(
      'leaderboard_view_toggled',
      parameters: {
        'view_type': viewType,
      },
    );

    if (mounted) {
      setState(() {
        _showPersonalStats = showPersonalStats;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Load more when user scrolls to 80% of the list
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_loadingMore &&
        _hasMore &&
        !_loading) {
      _loadMore();
    }
  }

  Future<void> _loadLeaderboard({bool reset = false}) async {
    if (!mounted) return;

    if (reset) {
      setState(() {
        _loading = true;
        _error = '';
        _entries = [];
        _lastDocument = null;
        _hasMore = true;
      });
    }

    try {
      // CRITICAL: Capture context before async operations to avoid BuildContext async gap
      if (!mounted) return;
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.uid;

      // Use pagination method
      final result =
          await _leaderboardService.getGlobalLeaderboardWithPagination(
        limit: _pageSize,
        startAfter: reset ? null : _lastDocument,
        category: _selectedCategory == 'All' ? null : _selectedCategory,
        timePeriod:
            _selectedTimePeriod == 'All Time' ? null : _selectedTimePeriod,
        region: _selectedRegion == 'Global' ? null : _selectedRegion,
        friendsOnly: _friendsOnly,
      );

      final entries = result['entries'] as List<LeaderboardEntry>;
      _lastDocument = result['lastDocument'] as DocumentSnapshot?;
      final hasMore = result['hasMore'] as bool;

      // Convert LeaderboardEntry to Map for compatibility
      // Calculate correct global rank based on pagination offset
      final baseRank = reset ? 0 : _entries.length;
      final entriesList = entries
          .map(
            (e) => {
              'userId': e.userId,
              'displayName': e.displayName,
              'email': e.email,
              'score': e.score,
              'rank': baseRank + e.rank, // Adjust rank for pagination
            },
          )
          .toList();

      if (userId != null && mounted && reset) {
        final rank = await _leaderboardService.getUserRank(userId);
        if (mounted) {
          setState(() {
            _userRank = rank;
          });
        }
      }

      if (mounted) {
        setState(() {
          if (reset) {
            _entries = entriesList;
          } else {
            _entries.addAll(entriesList);
          }
          _hasMore = hasMore;
          _loading = false;
          _loadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppLocalizations.of(context)?.leaderboardLoadError ??
              'Failed to load leaderboard';
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;

    setState(() {
      _loadingMore = true;
    });

    await _loadLeaderboard(reset: false);
  }

  Future<void> _refreshLeaderboard() async {
    unawaited(HapticService().lightImpact());
    await _loadLeaderboard(reset: true);
  }

  Widget _buildLoadMoreButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: _loadingMore
          ? const CircularProgressIndicator(color: Colors.white)
          : ElevatedButton(
              onPressed: _hasMore
                  ? () {
                      HapticService().lightImpact();
                      _loadMore();
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D9FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              child: Text(
                AppLocalizations.of(context)?.loadMore ?? 'Load More',
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.black, // Black fallback - static background will cover
      body: BackgroundImageWidget(
        imagePath: 'assets/background n3rd.png',
        child: SafeArea(
          child: Column(
            children: [
              // Header with filters
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Semantics(
                      label: AppLocalizations.of(context)?.backButton ?? 'Back',
                      button: true,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => NavigationHelper.safePop(context),
                        tooltip:
                            AppLocalizations.of(context)?.backButton ?? 'Back',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Leaderboard',
                        style: AppTypography.headlineLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                    ViewToggleWidget(
                      showPersonalStats: _showPersonalStats,
                      onChanged: _onViewToggleChanged,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.filter_list, color: Colors.white),
                      onPressed: () => _showFilterDialog(),
                      tooltip: 'Filters',
                    ),
                  ],
                ),
              ),

              // Tabs for time period (only show for leaderboard view)
              if (!_showPersonalStats)
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
                  indicatorColor: const Color(0xFF00D9FF),
                  onTap: (index) {
                    setState(() {
                      _selectedTimePeriod = [
                        'All Time',
                        'Weekly',
                        'Monthly',
                      ][index];
                      _loadLeaderboard(reset: true);
                    });
                  },
                  tabs: const [
                    Tab(text: 'All Time'),
                    Tab(text: 'Weekly'),
                    Tab(text: 'Monthly'),
                  ],
                ),

              // User rank card (only show for leaderboard view)
              if (_userRank > 0 && !_loading && !_showPersonalStats)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF00D9FF).withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.emoji_events,
                        color: Colors.amber,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Your Rank: #$_userRank',
                        style: AppTypography.playfairDisplay(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

              // Content: Leaderboard or Personal Stats
              Expanded(
                child: _showPersonalStats
                    ? const PersonalStatsView()
                    : _loading
                        ? const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white),
                          )
                        : _error.isNotEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _error,
                                      style: AppTypography.inter(
                                          color: Colors.white,),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: () {
                                        HapticService().lightImpact();
                                        _loadLeaderboard();
                                      },
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              )
                            : _entries.isEmpty
                                ? RefreshIndicator(
                                    onRefresh: _refreshLeaderboard,
                                    child: SingleChildScrollView(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      child: SizedBox(
                                        height:
                                            MediaQuery.of(context).size.height *
                                                0.6,
                                        child: EmptyStateWidget(
                                          icon: Icons.emoji_events_outlined,
                                          title: AppLocalizations.of(context)
                                                  ?.noLeaderboard ??
                                              'No leaderboard data',
                                          description: AppLocalizations.of(
                                                context,
                                              )?.noLeaderboardDescription ??
                                              'Be the first to play and set a record!',
                                        ),
                                      ),
                                    ),
                                  )
                                : RefreshIndicator(
                                    onRefresh: _refreshLeaderboard,
                                    child: ListView.builder(
                                      controller: _scrollController,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      // Performance optimization: Use lazy loading
                                      itemCount:
                                          _entries.length + (_hasMore ? 1 : 0),
                                      // Cache extent for better scroll performance
                                      cacheExtent: 500.0,
                                      itemBuilder: (context, index) {
                                        // Show Load More button at the end
                                        if (index == _entries.length) {
                                          return _buildLoadMoreButton();
                                        }

                                        final entry =
                                            _entries[index] as dynamic;
                                        final isCurrentUser = entry.userId ==
                                            Provider.of<AuthService>(
                                              context,
                                              listen: false,
                                            ).currentUser?.uid;

                                        return _buildLeaderboardItem(
                                          context,
                                          entry,
                                          isCurrentUser,
                                        );
                                      },
                                    ),
                                  ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardItem(
    BuildContext context,
    dynamic entry,
    bool isCurrentUser,
  ) {
    final displayName =
        entry.displayName ?? entry.email?.split('@').first ?? 'Anonymous';
    final itemColors = AppColors.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 4,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? itemColors.primaryButton.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        border: isCurrentUser
            ? Border.all(color: itemColors.primaryButton, width: 2)
            : null,
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 40,
            alignment: Alignment.center,
            child: Text(
              '#${entry.rank}',
              style: AppTypography.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: entry.rank <= 3
                    ? AppColors.of(context).primaryButton
                    : AppColors.of(context).secondaryText,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.of(context).primaryButton,
            child: Text(
              displayName.substring(0, 1).toUpperCase(),
              style: AppTypography.playfairDisplay(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Name
          Expanded(
            child: Text(
              displayName,
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: isCurrentUser ? FontWeight.w600 : FontWeight.normal,
                color: AppColors.of(context).primaryText,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Score
          Text(
            '${entry.score}',
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.of(context).primaryButton,
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final dialogColors = AppColors.of(context);
          return AlertDialog(
            backgroundColor: dialogColors.cardBackground,
            title: Text(
              'Leaderboard Filters',
              style: AppTypography.headlineLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Category filter
                  ListTile(
                    title: Text(
                      'Category',
                      style: AppTypography.labelLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 150),
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        isExpanded: true, // Allow dropdown to expand
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All')),
                          DropdownMenuItem(
                            value: 'History',
                            child: Text('History',
                                overflow: TextOverflow.visible, softWrap: true,),
                          ),
                          DropdownMenuItem(
                            value: 'Science',
                            child: Text('Science',
                                overflow: TextOverflow.visible, softWrap: true,),
                          ),
                          DropdownMenuItem(
                            value: 'Geography',
                            child: Text('Geography',
                                overflow: TextOverflow.visible, softWrap: true,),
                          ),
                          DropdownMenuItem(
                            value: 'Sports',
                            child: Text('Sports',
                                overflow: TextOverflow.visible, softWrap: true,),
                          ),
                          DropdownMenuItem(
                            value: 'Entertainment',
                            child: Text('Entertainment',
                                overflow: TextOverflow.visible, softWrap: true,),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value ?? 'All';
                          });
                        },
                      ),
                    ),
                  ),

                  // Region filter
                  ListTile(
                    title: Text(
                      'Region',
                      style: AppTypography.labelLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 150),
                      child: DropdownButton<String>(
                        value: _selectedRegion,
                        isExpanded: true, // Allow dropdown to expand
                        items: const [
                          DropdownMenuItem(
                            value: 'Global',
                            child: Text('Global',
                                overflow: TextOverflow.visible, softWrap: true,),
                          ),
                          DropdownMenuItem(
                            value: 'North America',
                            child: Text('North America',
                                overflow: TextOverflow.visible, softWrap: true,),
                          ),
                          DropdownMenuItem(
                            value: 'Europe',
                            child: Text('Europe',
                                overflow: TextOverflow.visible, softWrap: true,),
                          ),
                          DropdownMenuItem(
                            value: 'Asia',
                            child: Text('Asia',
                                overflow: TextOverflow.visible, softWrap: true,),
                          ),
                          DropdownMenuItem(
                            value: 'Other',
                            child: Text('Other',
                                overflow: TextOverflow.visible, softWrap: true,),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedRegion = value ?? 'Global';
                          });
                        },
                      ),
                    ),
                  ),

                  // Friends only
                  SwitchListTile(
                    title:
                        Text('Friends Only', style: AppTypography.bodyMedium),
                    value: _friendsOnly,
                    onChanged: (value) {
                      setState(() {
                        _friendsOnly = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => NavigationHelper.safePop(context),
                child: Text('Cancel', style: AppTypography.bodyMedium),
              ),
              TextButton(
                onPressed: () {
                  NavigationHelper.safePop(context);
                  _loadLeaderboard();
                },
                child: Text(
                  'Apply',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}