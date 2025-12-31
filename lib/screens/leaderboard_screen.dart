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
import 'package:n3rd_game/utils/provider_helper.dart';
import 'package:n3rd_game/widgets/chart_type_selector.dart';
import 'package:n3rd_game/utils/stats_preferences.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/widgets/stats_chart_widgets.dart';
import 'package:n3rd_game/services/stats_service.dart';
import 'package:n3rd_game/services/logger_service.dart';

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

  // Chart type for future chart visualization
  String _chartType = 'line';
  bool _showChart = true;
  List<DailyStats> _chartData = [];
  bool _loadingChartData = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController.addListener(_onScroll);
    _loadChartTypePreference();
    _loadLeaderboard(reset: true);
    _loadChartData();
  }

  Future<void> _loadChartTypePreference() async {
    final chartType = await StatsPreferences.getChartType();
    if (mounted) {
      setState(() {
        _chartType = chartType;
      });
    }
  }

  Future<void> _onChartTypeChanged(String chartType) async {
    await StatsPreferences.setChartType(chartType);
    if (mounted) {
      setState(() {
        _chartType = chartType;
      });
    }
    // Track analytics
    try {
      if (!mounted) return;
      final analyticsService = ProviderHelper.safeGetOrThrow<AnalyticsService>(context, listen: false);
      await analyticsService.logCustomEvent(
        'leaderboard_chart_type_changed',
        parameters: {
          'chart_type': chartType,
        },
      );
    } catch (e) {
      // Analytics not available - non-critical
    }
  }

  Future<void> _loadChartData() async {
    if (!mounted) return;
    setState(() => _loadingChartData = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.uid;
      if (userId == null) {
        if (mounted) {
          setState(() {
            _loadingChartData = false;
            _chartData = [];
          });
        }
        return;
      }

      // Get stats service to load daily stats
      final statsService = ProviderHelper.safeGetOrThrow<StatsService>(
        context,
        listen: false,
      );
      await statsService.init();
      final gameStats = statsService.stats;

      // Validate and convert to chart data (last 30 days)
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      
      final chartData = gameStats.dailyStats
          .where((stat) {
            // Validate date is not null and within range
            if (stat.date.isBefore(thirtyDaysAgo) || stat.date.isAfter(now.add(const Duration(days: 1)))) {
              return false;
            }
            // Validate score is non-negative
            if (stat.score < 0) {
              LoggerService.warning('Invalid negative score in daily stats: ${stat.score}');
              return false;
            }
            return true;
          })
          .toList()
        ..sort((a, b) {
          // Ensure chronological order
          return a.date.compareTo(b.date);
        });

      // Validate data completeness - check for gaps
      if (chartData.isNotEmpty) {
        final firstDate = chartData.first.date;
        final lastDate = chartData.last.date;
        final expectedDays = lastDate.difference(firstDate).inDays + 1;
        if (chartData.length < expectedDays * 0.5) {
          // Less than 50% data coverage - log warning
          LoggerService.warning(
            'Chart data has gaps: ${chartData.length} data points for $expectedDays expected days',
          );
        }
      }

      if (mounted) {
        setState(() {
          _chartData = chartData;
          _loadingChartData = false;
        });
      }
    } catch (e, stackTrace) {
      LoggerService.error(
        'Error loading chart data',
        error: e,
        stack: stackTrace,
      );
      if (mounted) {
        setState(() {
          _loadingChartData = false;
          _chartData = [];
        });
      }
    }
  }

  Widget _buildLeaderboardChart() {
    if (_loadingChartData) {
      return Container(
        height: 250,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // Validate chart data before rendering
    if (_chartData.isEmpty) {
      return const SizedBox.shrink();
    }

    // Additional validation: check for valid data points
    final validData = _chartData.where((stat) {
      return stat.date.isBefore(DateTime.now().add(const Duration(days: 1))) &&
          stat.date.isAfter(DateTime.now().subtract(const Duration(days: 31))) &&
          stat.score >= 0;
    }).toList();

    if (validData.isEmpty) {
      return Container(
        height: 200,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'No chart data available',
            style: AppTypography.bodyMedium.copyWith(color: Colors.white70),
          ),
        ),
      );
    }

    try {
      return Container(
        margin: const EdgeInsets.all(16),
        child: ScoreTrendChart(
          dailyStats: validData,
          daysToShow: 30,
          chartType: _chartType,
        ),
      );
    } catch (e, stackTrace) {
      LoggerService.error(
        'Error rendering leaderboard chart',
        error: e,
        stack: stackTrace,
      );
      return Container(
        height: 200,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'Unable to display chart',
            style: AppTypography.bodyMedium.copyWith(color: Colors.white70),
          ),
        ),
      );
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
                        overflow: TextOverflow.visible,
                        softWrap: true,
                        maxLines: 2,
                      ),
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

              // Chart type selector and toggle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Switch(
                          value: _showChart,
                          onChanged: (value) {
                            setState(() => _showChart = value);
                          },
                          activeColor: const Color(0xFF00D9FF),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Show Chart',
                          style: AppTypography.bodyMedium.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    if (_showChart)
                      ChartTypeSelector(
                        selectedChartType: _chartType,
                        onChanged: _onChartTypeChanged,
                      ),
                  ],
                ),
              ),

              // Chart visualization
              if (_showChart && !_loading && _chartData.isNotEmpty)
                _buildLeaderboardChart(),

              // Tabs for time period
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
                      _loadChartData(); // Reload chart data when time period changes
                    });
                  },
                  tabs: const [
                    Tab(text: 'All Time'),
                    Tab(text: 'Weekly'),
                    Tab(text: 'Monthly'),
                  ],
                ),

              // User rank card
              if (_userRank > 0 && !_loading)
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

              // Content: Leaderboard
              Expanded(
                child: _loading
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
                                            ProviderHelper.safeGetOrThrow<AuthService>(
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
              maxLines: 2,
              overflow: TextOverflow.visible,
              softWrap: true,
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