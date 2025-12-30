import 'package:flutter/material.dart';
import 'package:n3rd_game/utils/unawaited_helper.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:n3rd_game/services/newsfeed_service.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/services/haptic_service.dart';
import 'package:n3rd_game/widgets/background_image_widget.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/services/logger_service.dart';

class NewsfeedScreen extends StatefulWidget {
  const NewsfeedScreen({super.key});

  @override
  State<NewsfeedScreen> createState() => _NewsfeedScreenState();
}

class _NewsfeedScreenState extends State<NewsfeedScreen> {
  final NewsfeedService _newsfeedService = NewsfeedService();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initializeNewsfeed();
  }

  void _onScroll() {
    // Load more when user scrolls to 80% of the list
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_newsfeedService.isLoadingMore &&
        _newsfeedService.hasMore &&
        !_newsfeedService.isLoading) {
      _newsfeedService.loadMore();
    }
  }

  Future<void> _initializeNewsfeed() async {
    try {
      await _newsfeedService.init();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        LoggerService.error('NewsfeedService init error', error: e);
      }
    }
  }

  Future<void> _refreshNewsfeed() async {
    unawaited(HapticService().lightImpact());
    try {
      await _newsfeedService.refresh();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations?.refreshError ??
                'Unable to refresh. Please try again.',),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _newsfeedService.dispose();
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
                        AppLocalizations.of(context)?.newsfeed ?? 'Newsfeed',
                        style: AppTypography.headlineLarge.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    // Unread badge
                    Consumer<NewsfeedService>(
                      builder: (context, service, _) {
                        final unread = service.unreadCount;
                        if (unread > 0) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00D9FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$unread',
                              style: AppTypography.labelSmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    const SizedBox(width: 8),
                    Semantics(
                      label: AppLocalizations.of(context)?.retryButton ?? 'Refresh',
                      button: true,
                      child: IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: _refreshNewsfeed,
                        tooltip: AppLocalizations.of(context)?.retryButton ?? 'Refresh',
                      ),
                    ),
                  ],
                ),
              ),

              // Newsfeed content
              Expanded(
                child: Consumer<NewsfeedService>(
                  builder: (context, service, _) {
                    if (service.isLoading && service.activities.isEmpty) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF00D9FF),
                        ),
                      );
                    }

                    if (service.activities.isEmpty) {
                      final localizations = AppLocalizations.of(context);
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.rss_feed,
                              size: 64,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              localizations?.noActivities ??
                                  'No activities yet',
                              style: AppTypography.bodyLarge.copyWith(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              localizations?.noFriendsDescription ??
                                  'Add friends to see their activities here',
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
                      onRefresh: _refreshNewsfeed,
                      color: const Color(0xFF00D9FF),
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: service.activities.length +
                            (service.hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          // Show Load More button at the end
                          if (index == service.activities.length) {
                            return _buildLoadMoreButton(service);
                          }

                          final activity = service.activities[index];
                          return _buildActivityCard(activity, service);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityCard(
    NewsfeedActivity activity,
    NewsfeedService service,
  ) {
    return InkWell(
      onTap: () {
        if (!activity.isRead) {
          service.markAsRead(activity.id);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: activity.isRead
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: activity.isRead
                ? Colors.white.withValues(alpha: 0.1)
                : const Color(0xFF00D9FF).withValues(alpha: 0.3),
            width: activity.isRead ? 1 : 2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF00D9FF),
              child: Text(
                (activity.userDisplayName?.isNotEmpty == true
                        ? activity.userDisplayName[0]
                        : activity.userEmail?[0] ?? '?')
                    .toUpperCase(),
                style: AppTypography.labelLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Activity description
                  _buildActivityText(activity),
                  const SizedBox(height: 4),

                  // Timestamp
                  Text(
                    _formatTimestamp(activity.timestamp),
                    style: AppTypography.bodyMedium.copyWith(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),

            // Activity icon
            _buildActivityIcon(activity),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityText(NewsfeedActivity activity) {
    final displayName = activity.userDisplayName ??
        activity.userEmail?.split('@')[0] ??
        'Someone';

    switch (activity.type) {
      case NewsfeedActivityType.achievement:
        final achievementName =
            activity.metadata?['achievementName'] as String? ?? 'Achievement';
        return RichText(
          text: TextSpan(
            style: AppTypography.bodyMedium.copyWith(
              color: Colors.white,
            ),
            children: [
              TextSpan(
                text: displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00D9FF),
                ),
              ),
              const TextSpan(text: ' unlocked '),
              TextSpan(
                text: achievementName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );

      case NewsfeedActivityType.challengeCompleted:
        final challengeName =
            activity.metadata?['challengeName'] as String? ?? 'Challenge';
        final score = activity.metadata?['score'] as int? ?? 0;
        return RichText(
          text: TextSpan(
            style: AppTypography.bodyMedium.copyWith(
              color: Colors.white,
            ),
            children: [
              TextSpan(
                text: displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00D9FF),
                ),
              ),
              const TextSpan(text: ' completed '),
              TextSpan(
                text: challengeName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(text: ' with $score points'),
            ],
          ),
        );

      case NewsfeedActivityType.highScore:
        final score = activity.metadata?['score'] as int? ?? 0;
        final mode = activity.metadata?['mode'] as String? ?? '';
        return RichText(
          text: TextSpan(
            style: AppTypography.bodyMedium.copyWith(
              color: Colors.white,
            ),
            children: [
              TextSpan(
                text: displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00D9FF),
                ),
              ),
              TextSpan(
                  text:
                      ' achieved a high score of $score${mode.isNotEmpty ? ' in $mode' : ''}',),
            ],
          ),
        );

      case NewsfeedActivityType.friendRequest:
        return RichText(
          text: TextSpan(
            style: AppTypography.bodyMedium.copyWith(
              color: Colors.white,
            ),
            children: [
              TextSpan(
                text: displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00D9FF),
                ),
              ),
              const TextSpan(text: ' sent you a friend request'),
            ],
          ),
        );

      case NewsfeedActivityType.friendAccepted:
        return RichText(
          text: TextSpan(
            style: AppTypography.bodyMedium.copyWith(
              color: Colors.white,
            ),
            children: [
              TextSpan(
                text: displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00D9FF),
                ),
              ),
              const TextSpan(text: ' accepted your friend request'),
            ],
          ),
        );

      case NewsfeedActivityType.gameCompleted:
        return RichText(
          text: TextSpan(
            style: AppTypography.bodyMedium.copyWith(
              color: Colors.white,
            ),
            children: [
              TextSpan(
                text: displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00D9FF),
                ),
              ),
              const TextSpan(text: ' completed a game'),
            ],
          ),
        );

      case NewsfeedActivityType.multiplayerGameStarted:
        final roomName = activity.metadata?['roomName'] as String? ?? 'a game';
        return RichText(
          text: TextSpan(
            style: AppTypography.bodyMedium.copyWith(
              color: Colors.white,
            ),
            children: [
              TextSpan(
                text: displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00D9FF),
                ),
              ),
              TextSpan(text: ' started $roomName'),
            ],
          ),
        );

      case NewsfeedActivityType.multiplayerGameCompleted:
        final roomName = activity.metadata?['roomName'] as String? ?? 'a game';
        return RichText(
          text: TextSpan(
            style: AppTypography.bodyMedium.copyWith(
              color: Colors.white,
            ),
            children: [
              TextSpan(
                text: displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00D9FF),
                ),
              ),
              TextSpan(text: ' completed $roomName'),
            ],
          ),
        );

      case NewsfeedActivityType.roomCreated:
        final roomName = activity.metadata?['roomName'] as String? ?? 'a room';
        return RichText(
          text: TextSpan(
            style: AppTypography.bodyMedium.copyWith(
              color: Colors.white,
            ),
            children: [
              TextSpan(
                text: displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00D9FF),
                ),
              ),
              TextSpan(text: ' created $roomName'),
            ],
          ),
        );

      case NewsfeedActivityType.friendInvitedToGame:
        final roomName = activity.metadata?['roomName'] as String? ?? 'a game';
        return RichText(
          text: TextSpan(
            style: AppTypography.bodyMedium.copyWith(
              color: Colors.white,
            ),
            children: [
              TextSpan(
                text: displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00D9FF),
                ),
              ),
              TextSpan(text: ' invited you to $roomName'),
            ],
          ),
        );
    }
  }

  Widget _buildActivityIcon(NewsfeedActivity activity) {
    IconData icon;
    Color iconColor;

    switch (activity.type) {
      case NewsfeedActivityType.achievement:
        icon = Icons.emoji_events;
        iconColor = Colors.amber;
        break;
      case NewsfeedActivityType.challengeCompleted:
        icon = Icons.check_circle;
        iconColor = Colors.green;
        break;
      case NewsfeedActivityType.highScore:
        icon = Icons.trending_up;
        iconColor = const Color(0xFF00D9FF);
        break;
      case NewsfeedActivityType.friendRequest:
        icon = Icons.person_add;
        iconColor = Colors.blue;
        break;
      case NewsfeedActivityType.friendAccepted:
        icon = Icons.how_to_reg;
        iconColor = Colors.green;
        break;
      case NewsfeedActivityType.gameCompleted:
        icon = Icons.play_circle;
        iconColor = Colors.purple;
        break;
      case NewsfeedActivityType.multiplayerGameStarted:
        icon = Icons.group;
        iconColor = Colors.blue;
        break;
      case NewsfeedActivityType.multiplayerGameCompleted:
        icon = Icons.group_work;
        iconColor = Colors.green;
        break;
      case NewsfeedActivityType.roomCreated:
        icon = Icons.add_circle;
        iconColor = Colors.orange;
        break;
      case NewsfeedActivityType.friendInvitedToGame:
        icon = Icons.person_add_alt_1;
        iconColor = Colors.pink;
        break;
    }

    return Icon(
      icon,
      color: iconColor,
      size: 24,
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return DateFormat('MMM d').format(timestamp);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildLoadMoreButton(NewsfeedService service) {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: service.isLoadingMore
          ? const CircularProgressIndicator(color: Color(0xFF00D9FF))
          : ElevatedButton(
              onPressed: service.hasMore
                  ? () {
                      HapticService().lightImpact();
                      service.loadMore();
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
}