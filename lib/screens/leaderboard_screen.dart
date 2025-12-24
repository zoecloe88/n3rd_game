import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/services/leaderboard_service.dart';
import 'package:n3rd_game/services/auth_service.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/widgets/unified_background_widget.dart';
import 'package:n3rd_game/widgets/empty_state_widget.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/services/haptic_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  final LeaderboardService _leaderboardService = LeaderboardService();
  List<dynamic> _entries = [];
  int _userRank = 0;
  bool _loading = true;
  String _error = '';

  // Filters
  String _selectedCategory = 'All';
  String _selectedTimePeriod = 'All Time';
  String _selectedRegion = 'Global';
  bool _friendsOnly = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadLeaderboard();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaderboard() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      // CRITICAL: Capture context before async operations to avoid BuildContext async gap
      if (!mounted) return;
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.uid;

      // Apply filters
      final entries = await _leaderboardService.getGlobalLeaderboard(
        limit: 100,
        category: _selectedCategory == 'All' ? null : _selectedCategory,
        timePeriod:
            _selectedTimePeriod == 'All Time' ? null : _selectedTimePeriod,
        region: _selectedRegion == 'Global' ? null : _selectedRegion,
        friendsOnly: _friendsOnly,
      );

      // Convert LeaderboardEntry to Map for compatibility
      final entriesList = entries
          .map(
            (e) => {
              'userId': e.userId,
              'displayName': e.displayName,
              'email': e.email,
              'score': e.score,
              'rank': e.rank,
            },
          )
          .toList();

      if (userId != null && mounted) {
        final rank = await _leaderboardService.getUserRank(userId);
        if (mounted) {
          setState(() {
            _userRank = rank;
          });
        }
      }

      if (mounted) {
        setState(() {
          _entries = entriesList;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load leaderboard';
          _loading = false;
        });
      }
    }
  }

  Future<void> _refreshLeaderboard() async {
    HapticService().lightImpact();
    await _loadLeaderboard();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: UnifiedBackgroundWidget(
        // Remove large animation overlay - leaderboard screen should be clean
        child: SafeArea(
          child: Column(
            children: [
              // Header with filters
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      // Back button removed - using bottom navigation instead
                      onPressed: null,
                      tooltip:
                          AppLocalizations.of(context)?.backButton ?? 'Back',
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
                    IconButton(
                      icon: const Icon(Icons.filter_list, color: Colors.white),
                      onPressed: () => _showFilterDialog(),
                      tooltip: 'Filters',
                    ),
                  ],
                ),
              ),

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
                    _loadLeaderboard();
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

              // Leaderboard content
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : _error.isNotEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _error,
                                  style:
                                      AppTypography.inter(color: Colors.white),
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
                                    height: MediaQuery.of(context).size.height *
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16,),
                                  itemCount: _entries.length,
                                  itemBuilder: (context, index) {
                                    final entry = _entries[index] as dynamic;
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
            content: Column(
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
                  trailing: DropdownButton<String>(
                    value: _selectedCategory,
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All')),
                      DropdownMenuItem(
                        value: 'History',
                        child: Text('History'),
                      ),
                      DropdownMenuItem(
                        value: 'Science',
                        child: Text('Science'),
                      ),
                      DropdownMenuItem(
                        value: 'Geography',
                        child: Text('Geography'),
                      ),
                      DropdownMenuItem(value: 'Sports', child: Text('Sports')),
                      DropdownMenuItem(
                        value: 'Entertainment',
                        child: Text('Entertainment'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value ?? 'All';
                      });
                    },
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
                  trailing: DropdownButton<String>(
                    value: _selectedRegion,
                    items: const [
                      DropdownMenuItem(value: 'Global', child: Text('Global')),
                      DropdownMenuItem(
                        value: 'North America',
                        child: Text('North America'),
                      ),
                      DropdownMenuItem(value: 'Europe', child: Text('Europe')),
                      DropdownMenuItem(value: 'Asia', child: Text('Asia')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedRegion = value ?? 'Global';
                      });
                    },
                  ),
                ),

                // Friends only
                SwitchListTile(
                  title: Text('Friends Only', style: AppTypography.bodyMedium),
                  value: _friendsOnly,
                  onChanged: (value) {
                    setState(() {
                      _friendsOnly = value;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: AppTypography.bodyMedium),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
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
