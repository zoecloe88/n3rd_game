import 'package:flutter/material.dart';
import 'package:n3rd_game/utils/unawaited_helper.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/services/social_discovery_service.dart';
import 'package:n3rd_game/services/friends_service.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/services/haptic_service.dart';
import 'package:n3rd_game/widgets/background_image_widget.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/services/logger_service.dart';

class SocialDiscoveryScreen extends StatefulWidget {
  const SocialDiscoveryScreen({super.key});

  @override
  State<SocialDiscoveryScreen> createState() => _SocialDiscoveryScreenState();
}

class _SocialDiscoveryScreenState extends State<SocialDiscoveryScreen>
    with SingleTickerProviderStateMixin {
  final SocialDiscoveryService _discoveryService = SocialDiscoveryService();
  final FriendsService _friendsService = FriendsService();
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  List<RecommendedPlayer> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeDiscovery();
  }

  Future<void> _initializeDiscovery() async {
    try {
      await _discoveryService.init();
      await _friendsService.init();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        LoggerService.error('SocialDiscoveryService init error', error: e);
      }
    }
  }

  Future<void> _searchPlayers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults.clear();
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await _discoveryService.searchPlayers(query.trim());
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations?.searchError ??
                'Search failed. Please try again.',),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _sendFriendRequest(String friendUserId) async {
    unawaited(HapticService().lightImpact());
    try {
      await _friendsService.sendFriendRequest(friendUserId);
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                localizations?.friendRequestSent ?? 'Friend request sent!',),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh recommended players
        await _discoveryService.refresh();
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations?.sendRequestError ??
                'Failed to send friend request. Please try again.',),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _discoveryService.dispose();
    _friendsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BackgroundImageWidget(
        imagePath: 'assets/background n3rd.png',
        child: SafeArea(
          child: Column(
            children: [
              // Header
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
                        tooltip: AppLocalizations.of(context)?.backButton ?? 'Back',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)?.discover ?? 'Discover',
                        style: AppTypography.headlineLarge.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Semantics(
                      label: AppLocalizations.of(context)?.retryButton ?? 'Refresh',
                      button: true,
                      child: IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: () async {
                          unawaited(HapticService().lightImpact());
                          await _discoveryService.refresh();
                        },
                        tooltip: AppLocalizations.of(context)?.retryButton ?? 'Refresh',
                      ),
                    ),
                  ],
                ),
              ),

              // Tabs
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return TabBar(
                    controller: _tabController,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
                    indicatorColor: const Color(0xFF00D9FF),
                    tabs: [
                      Tab(text: localizations?.findPlayers ?? 'Find Players'),
                      Tab(text: localizations?.trending ?? 'Trending'),
                      Tab(text: localizations?.recommended ?? 'Recommended'),
                    ],
                  );
                },
              ),

              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildFindPlayersTab(),
                    _buildTrendingTab(),
                    _buildRecommendedTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFindPlayersTab() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)?.searchPlayersHint ??
                  'Search by name or email...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              prefixIcon: const Icon(Icons.search, color: Colors.white70),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white70),
                      onPressed: () {
                        _searchController.clear();
                        _searchPlayers('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF00D9FF)),
              ),
            ),
            style: const TextStyle(color: Colors.white),
            onSubmitted: _searchPlayers,
            onChanged: (value) {
              if (value.isEmpty) {
                _searchPlayers('');
              }
            },
          ),
        ),

        // Search results
        Expanded(
          child: _isSearching
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF00D9FF),
                  ),
                )
              : _searchResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search,
                            size: 64,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isEmpty
                                ? (AppLocalizations.of(context)
                                        ?.searchPlayersHint ??
                                    'Search for players by name or email')
                                : (AppLocalizations.of(context)
                                        ?.noPlayersFound ??
                                    'No players found'),
                            style: AppTypography.bodyMedium.copyWith(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final player = _searchResults[index];
                        return _buildPlayerCard(player, showAddButton: true);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildTrendingTab() {
    return Consumer<SocialDiscoveryService>(
      builder: (context, service, _) {
        if (service.isLoading && service.trendingChallenges.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF00D9FF),
            ),
          );
        }

        if (service.trendingChallenges.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.trending_up,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)?.noChallenges ??
                      'No trending challenges',
                  style: AppTypography.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => service.refresh(),
          color: const Color(0xFF00D9FF),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: service.trendingChallenges.length,
            itemBuilder: (context, index) {
              final challenge = service.trendingChallenges[index];
              return _buildTrendingChallengeCard(challenge);
            },
          ),
        );
      },
    );
  }

  Widget _buildRecommendedTab() {
    return Consumer<SocialDiscoveryService>(
      builder: (context, service, _) {
        if (service.isLoading && service.recommendedPlayers.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF00D9FF),
            ),
          );
        }

        if (service.recommendedPlayers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)?.noPlayersFound ??
                      'No recommendations yet',
                  style: AppTypography.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)?.noFriendsDescription ??
                      'Add more friends to get better recommendations',
                  style: AppTypography.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => service.refresh(),
          color: const Color(0xFF00D9FF),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: service.recommendedPlayers.length,
            itemBuilder: (context, index) {
              final player = service.recommendedPlayers[index];
              return _buildPlayerCard(player, showAddButton: true);
            },
          ),
        );
      },
    );
  }

  Widget _buildPlayerCard(RecommendedPlayer player,
      {bool showAddButton = false,}) {
    final displayName =
        player.displayName ?? player.email?.split('@')[0] ?? 'Anonymous';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFF00D9FF),
            child: Text(
              displayName[0].toUpperCase(),
              style: AppTypography.labelLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Player info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: AppTypography.bodyLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  softWrap: true,
                ),
                if (player.highestScore != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'High Score: ${player.highestScore}',
                    style: AppTypography.bodyMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
                if (player.mutualFriends != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.people,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${player.mutualFriends} mutual friend${player.mutualFriends! > 1 ? 's' : ''}',
                        style: AppTypography.bodyMedium.copyWith(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
                if (player.commonInterest != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Interest: ${player.commonInterest}',
                    style: AppTypography.bodyMedium.copyWith(
                      color: const Color(0xFF00D9FF),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Add friend button
          if (showAddButton)
            IconButton(
              icon: const Icon(Icons.person_add, color: Color(0xFF00D9FF)),
              onPressed: () => _sendFriendRequest(player.userId),
              tooltip: 'Send friend request',
            ),
        ],
      ),
    );
  }

  Widget _buildTrendingChallengeCard(TrendingChallenge challenge) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.trending_up,
                color: Color(0xFFFFD700),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  challenge.name,
                  style: AppTypography.bodyLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  softWrap: true,
                ),
              ),
            ],
          ),
          if (challenge.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              challenge.description,
              style: AppTypography.bodyMedium.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.people,
                size: 16,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 4),
              Text(
                '${challenge.participantCount} participants',
                style: AppTypography.bodyMedium.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              if (challenge.category != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D9FF).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    challenge.category!,
                    style: AppTypography.labelSmall.copyWith(
                      color: const Color(0xFF00D9FF),
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}