import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/services/friends_service.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/services/haptic_service.dart';
import 'package:n3rd_game/widgets/unified_background_widget.dart';
import 'package:n3rd_game/widgets/empty_state_widget.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final FriendsService _friendsService = FriendsService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;
  int _selectedTab = 0; // 0 = Friends, 1 = Requests

  @override
  void initState() {
    super.initState();
    _friendsService.init();
  }

  Future<void> _refreshFriends() async {
    HapticService().lightImpact();
    try {
      await _friendsService.refreshFriends();
      if (mounted) {
        setState(() {
          // Trigger rebuild to show updated data
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _friendsService.dispose();
    super.dispose();
  }

  Future<void> _searchUsers() async {
    if (!mounted) return;
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _searching = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _searching = true);
    }
    HapticService().lightImpact();

    try {
      final results = await _friendsService.searchUsers(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _searching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _searching = false);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _sendFriendRequest(
    String userId,
    String? email,
    String? displayName,
  ) async {
    HapticService().lightImpact();
    try {
      await _friendsService.sendFriendRequest(
        userId,
        friendEmail: email,
        friendDisplayName: displayName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request sent!'),
            backgroundColor: AppColors.success,
          ),
        );
        _searchController.clear();
        if (mounted) {
          setState(() => _searchResults = []);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _acceptRequest(String requestId) async {
    HapticService().lightImpact();
    try {
      await _friendsService.acceptFriendRequest(requestId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request accepted!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    HapticService().lightImpact();
    try {
      await _friendsService.rejectFriendRequest(requestId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _removeFriend(String friendUserId) async {
    HapticService().lightImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend'),
        content: const Text('Are you sure you want to remove this friend?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _friendsService.removeFriend(friendUserId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Friend removed'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
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
          icon: Icon(Icons.arrow_back, color: colors.primaryText),
          onPressed: () {
            HapticService().lightImpact();
            NavigationHelper.safePop(context);
          },
          tooltip: 'Back',
        ),
        title: Text(
          'Friends',
          style: AppTypography.headlineLarge.copyWith(
            color: colors.primaryText,
          ),
        ),
        actions: [
          Semantics(
            label: AppLocalizations.of(context)?.addFriend ?? 'Add Friend',
            button: true,
            child: IconButton(
              icon: Icon(Icons.person_add, color: colors.primaryText),
              tooltip: AppLocalizations.of(context)?.addFriend ?? 'Add Friend',
              onPressed: () {
                HapticService().lightImpact();
                _showAddFriendDialog();
              },
            ),
          ),
        ],
      ),
      body: UnifiedBackgroundWidget(
        // Remove animation overlay - use icon-sized animations only
        child: SafeArea(
          child: Column(
            children: [
              // Tabs - in cyan section
              Container(
                color: const Color(0xFF00D9FF), // Cyan background for tabs
                child: Row(
                  children: [
                    Expanded(child: _buildTab(0, 'Friends')),
                    Expanded(child: _buildTab(1, 'Requests')),
                  ],
                ),
              ),

              // Content - black background
              Expanded(
                child: Container(
                  color: Colors.black, // Black content area
                  child: _selectedTab == 0
                      ? _buildFriendsList()
                      : _buildRequestsList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(int index, String label) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () {
        HapticService().lightImpact();
        if (mounted) {
          setState(() => _selectedTab = index);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.black : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.labelLarge.copyWith(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? Colors.black : Colors.black.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  Widget _buildFriendsList() {
    return Consumer<FriendsService>(
      builder: (context, friendsService, _) {
        final friends = friendsService.friends;

        if (friends.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refreshFriends,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: EmptyStateWidget(
                  icon: Icons.people_outline,
                  title: AppLocalizations.of(context)!.noFriends,
                  description: AppLocalizations.of(context)!.noFriendsDescription,
                  actionLabel: AppLocalizations.of(context)!.addFriend,
                  onAction: () => _showAddFriendDialog(),
                ),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refreshFriends,
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final friend = friends[index];
              return _buildFriendItem(context, friend);
            },
          ),
        );
      },
    );
  }

  Widget _buildFriendItem(BuildContext context, dynamic friend) {
    final itemColors = AppColors.of(context);
    final displayName =
        friend.displayName ?? friend.email?.split('@').first ?? 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: itemColors.cardBackground.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: itemColors.primaryButton,
                child: Text(
                  displayName.substring(0, 1).toUpperCase(),
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: itemColors.buttonText,
                  ),
                ),
              ),
              if (friend.isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: itemColors.cardBackground,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: itemColors.primaryText,
                  ),
                ),
                if (friend.email != null)
                  Text(
                    friend.email!,
                    style: AppTypography.labelSmall.copyWith(
                      color: itemColors.secondaryText,
                    ),
                  ),
              ],
            ),
          ),
          Consumer<SubscriptionService>(
            builder: (context, subscriptionService, _) {
              final hasPremium = subscriptionService.isPremium;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasPremium)
                    IconButton(
                      icon: Icon(
                        Icons.message,
                        color: AppColors.of(context).primaryButton,
                      ),
                      onPressed: () {
                        HapticService().lightImpact();
                        NavigationHelper.safeNavigate(
                          context,
                          '/direct-message',
                          arguments: friend.userId,
                        );
                      },
                      tooltip: AppLocalizations.of(context)?.chat ?? 'Message',
                    ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.error,
                    ),
                    onPressed: () => _removeFriend(friend.userId),
                    tooltip:
                        AppLocalizations.of(context)?.deleteButton ??
                        'Remove Friend',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList() {
    return Consumer<FriendsService>(
      builder: (context, friendsService, _) {
        final requests = friendsService.pendingRequests;

        if (requests.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refreshFriends,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: const EmptyStateWidget(
                  icon: Icons.mark_email_read_outlined,
                  title: 'No pending requests',
                  description: 'Friend requests will appear here',
                ),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refreshFriends,
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return _buildRequestItem(context, request);
            },
          ),
        );
      },
    );
  }

  Widget _buildRequestItem(BuildContext context, dynamic request) {
    final itemColors = AppColors.of(context);
    final displayName =
        request.fromDisplayName ??
        request.fromEmail?.split('@').first ??
        'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: itemColors.cardBackground.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: itemColors.primaryButton,
            child: Text(
              displayName.substring(0, 1).toUpperCase(),
              style: AppTypography.titleLarge.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: itemColors.buttonText,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: itemColors.primaryText,
                  ),
                ),
                if (request.fromEmail != null)
                  Text(
                    request.fromEmail!,
                    style: AppTypography.labelSmall.copyWith(
                      color: itemColors.secondaryText,
                    ),
                  ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.check, color: AppColors.success),
                onPressed: () => _acceptRequest(request.id),
                tooltip:
                    AppLocalizations.of(context)?.confirmButton ?? 'Accept',
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.error),
                onPressed: () => _rejectRequest(request.id),
                tooltip: AppLocalizations.of(context)?.cancelButton ?? 'Reject',
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddFriendDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final dialogColors = AppColors.of(context);
        return AlertDialog(
          backgroundColor: dialogColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Add Friend',
            style: AppTypography.headlineLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: dialogColors.primaryText,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search by email',
                  hintText: 'user@example.com',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: AppSpacing.md),
              if (_searching)
                const CircularProgressIndicator()
              else if (_searchResults.isNotEmpty)
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final user = _searchResults[index];
                      return ListTile(
                        title: Text(user['displayName'] ?? user['email']),
                        subtitle: Text(user['email']),
                        trailing: Semantics(
                          label:
                              AppLocalizations.of(context)?.addFriend ??
                              'Add Friend',
                          button: true,
                          child: IconButton(
                            icon: const Icon(Icons.person_add),
                            onPressed: () => _sendFriendRequest(
                              user['userId'],
                              user['email'],
                              user['displayName'],
                            ),
                            tooltip:
                                AppLocalizations.of(context)?.addFriend ??
                                'Add Friend',
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _searchController.clear();
                if (mounted) {
                  setState(() => _searchResults = []);
                }
              },
              child: Text(
                'Cancel',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.of(context).secondaryText,
                ),
              ),
            ),
            TextButton(
              onPressed: _searchUsers,
              child: Text(
                'Search',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.of(context).primaryButton,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
