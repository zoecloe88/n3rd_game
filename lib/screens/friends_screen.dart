import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/services/friends_service.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/services/haptic_service.dart';
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

  @override
  void initState() {
    super.initState();
    _initializeFriends();
  }

  Future<void> _initializeFriends() async {
    try {
      await _friendsService.init();
    } catch (e) {
      if (mounted) {
        // Log error but don't show error screen immediately
        debugPrint('FriendsService init error: $e');
        // Show user-friendly message
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Unable to load friends. Please check your connection.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
        });
      }
    }
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
      // Try to search contacts and users first
      List<Map<String, dynamic>> results;
      try {
        results = await _friendsService.searchContactsAndUsers(query);
      } catch (e) {
        // Fallback to regular user search if contact access fails
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Contact access unavailable, searching users only: ${e.toString()}'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        results = await _friendsService.searchUsers(query);
      }
      
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

  Future<void> _blockFriend(String friendUserId) async {
    HapticService().lightImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block Friend'),
        content: const Text(
          'Are you sure you want to block this friend? They will be removed from your friends list and won\'t be able to message you.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Block',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _friendsService.blockUser(friendUserId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Friend blocked'),
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

  void _showFriendProfile(BuildContext context, dynamic friend) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: AppColors.of(context).cardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.of(context).tertiaryText,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Profile content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppColors.of(context).primaryButton,
                      child: Text(
                        (friend.displayName ??
                                friend.email?.split('@').first ??
                                'U')
                            .substring(0, 1)
                            .toUpperCase(),
                        style: AppTypography.displayLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      friend.displayName ??
                          friend.email?.split('@').first ??
                          'Unknown',
                      style: AppTypography.headlineLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.of(context).primaryText,
                      ),
                    ),
                    if (friend.email != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        friend.email!,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.of(context).secondaryText,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    // Online status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: friend.isOnline
                                ? AppColors.success
                                : AppColors.of(context).tertiaryText,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          friend.isOnline ? 'Online' : 'Offline',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.of(context).secondaryText,
                          ),
                        ),
                      ],
                    ),
                    if (friend.addedAt != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Friends since ${_formatDate(friend.addedAt!)}',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.of(context).tertiaryText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays < 1) {
      return 'Today';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    // FriendsScreen is used inside FriendsAndMessagesScreen which already has tabs
    // So we only show the Friends list and action buttons here
    return Container(
      color: Colors.black, // Black background
      child: Column(
        children: [
          // Action buttons at top
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Semantics(
                  label: 'Friend Suggestions',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.people_outline, color: Colors.white),
                    tooltip: 'Friend Suggestions',
                    onPressed: () {
                      HapticService().lightImpact();
                      _showFriendSuggestions();
                    },
                  ),
                ),
                Semantics(
                  label: AppLocalizations.of(context)?.addFriend ?? 'Add Friend',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.person_add, color: Colors.white),
                    tooltip: AppLocalizations.of(context)?.addFriend ?? 'Add Friend',
                    onPressed: () {
                      HapticService().lightImpact();
                      _showAddFriendDialog();
                    },
                  ),
                ),
              ],
            ),
          ),
          // Content - Friends list only (no tabs, as parent handles Friends/Messages tabs)
          Expanded(
            child: Container(
              color: Colors.black, // Black content area
              child: _buildFriendsList(),
            ),
          ),
        ],
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
                child: Center(
                  child: EmptyStateWidget(
                    icon: Icons.people_outline,
                    title: AppLocalizations.of(context)!.noFriends,
                    description:
                        AppLocalizations.of(context)!.noFriendsDescription,
                    actionLabel: AppLocalizations.of(context)!.addFriend,
                    onAction: () => _showAddFriendDialog(),
                  ),
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
              return PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: itemColors.primaryText,
                ),
                onSelected: (value) async {
                  HapticService().lightImpact();
                  switch (value) {
                    case 'message':
                      if (hasPremium) {
                        NavigationHelper.safeNavigate(
                          context,
                          '/direct-message',
                          arguments: friend.userId,
                        );
                      }
                      break;
                    case 'profile':
                      _showFriendProfile(context, friend);
                      break;
                    case 'block':
                      await _blockFriend(friend.userId);
                      break;
                    case 'remove':
                      await _removeFriend(friend.userId);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (hasPremium)
                    PopupMenuItem(
                      value: 'message',
                      child: Row(
                        children: [
                          Icon(Icons.message,
                              size: 20, color: itemColors.primaryText,),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            AppLocalizations.of(context)?.chat ?? 'Message',
                            style: AppTypography.labelLarge,
                          ),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 20, color: itemColors.primaryText,),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'View Profile',
                          style: AppTypography.labelLarge,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'block',
                    child: Row(
                      children: [
                        const Icon(Icons.block,
                            size: 20, color: AppColors.error,),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Block',
                          style: AppTypography.labelLarge.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline,
                            size: 20, color: AppColors.error,),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          AppLocalizations.of(context)?.deleteButton ??
                              'Remove',
                          style: AppTypography.labelLarge.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
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
                          label: AppLocalizations.of(context)?.addFriend ??
                              'Add Friend',
                          button: true,
                          child: IconButton(
                            icon: const Icon(Icons.person_add),
                            onPressed: () => _sendFriendRequest(
                              user['userId'],
                              user['email'],
                              user['displayName'],
                            ),
                            tooltip: AppLocalizations.of(context)?.addFriend ??
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

  Future<void> _showFriendSuggestions() async {
    HapticService().lightImpact();
    try {
      final suggestions = await _friendsService.getFriendSuggestions();
      if (!mounted) return;

      if (suggestions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No friend suggestions available'),
            backgroundColor: AppColors.success,
          ),
        );
        return;
      }

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
              'Friend Suggestions',
              style: AppTypography.headlineLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: dialogColors.primaryText,
              ),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  final user = suggestions[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: dialogColors.primaryButton,
                      child: Text(
                        (user['displayName'] ??
                                user['email']?.split('@').first ??
                                'U')
                            .substring(0, 1)
                            .toUpperCase(),
                        style: AppTypography.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    title: Text(
                      user['displayName'] ??
                          user['email']?.split('@').first ??
                          'Unknown',
                      style: AppTypography.labelLarge,
                    ),
                    subtitle: Text(
                      user['email'] ?? '',
                      style: AppTypography.labelSmall,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.person_add),
                      onPressed: () {
                        Navigator.pop(context);
                        _sendFriendRequest(
                          user['userId'],
                          user['email'],
                          user['displayName'],
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: AppTypography.labelLarge.copyWith(
                    color: dialogColors.secondaryText,
                  ),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading suggestions: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
