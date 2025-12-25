import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/services/direct_message_service.dart';
import 'package:n3rd_game/services/auth_service.dart';
import 'package:n3rd_game/models/direct_message.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/services/haptic_service.dart';
import 'package:n3rd_game/widgets/empty_state_widget.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final DirectMessageService _messageService = DirectMessageService();
  bool _hasPremium = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final hasPremium = await _messageService.hasPremiumAccess();
    if (mounted) {
      setState(() {
        _hasPremium = hasPremium;
        _loading = false;
      });
    }

    if (hasPremium) {
      await _messageService.loadConversations();
    }
  }

  Future<void> _refreshConversations() async {
    HapticService().lightImpact();
    if (!_hasPremium) return;
    try {
      await _messageService.loadConversations();
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
    _messageService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    if (_loading) {
      return Scaffold(
        backgroundColor: colors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasPremium) {
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
            'Direct Messages',
            style: AppTypography.headlineLarge.copyWith(
              color: colors.primaryText,
            ),
          ),
        ),
        body: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 64,
                    color: colors.tertiaryText,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Premium Required',
                    style: AppTypography.headlineLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.primaryText,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Direct messaging is available for premium users only.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyLarge.copyWith(
                      color: colors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    }

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
          'Messages',
          style: AppTypography.headlineLarge.copyWith(
            color: colors.primaryText,
          ),
        ),
      ),
      body: SafeArea(
          child: Consumer<DirectMessageService>(
            builder: (context, messageService, _) {
              final conversations = messageService.conversations;

              if (conversations.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _refreshConversations,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: EmptyStateWidget(
                        icon: Icons.message_outlined,
                        title: AppLocalizations.of(context)?.noChatMessages ??
                            'No messages yet',
                        description: AppLocalizations.of(context)
                                ?.noChatMessagesDescription ??
                            'Start a conversation!',
                      ),
                    ),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _refreshConversations,
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: conversations.length,
                  itemBuilder: (context, index) {
                    final conversation = conversations[index];
                    final authService = Provider.of<AuthService>(
                      context,
                      listen: false,
                    );
                    final currentUserId = authService.currentUser?.uid ?? '';
                    final otherUserId = conversation.getOtherUserId(
                      currentUserId,
                    );
                    final otherDisplayName =
                        conversation.getOtherDisplayName(currentUserId) ??
                            'User';

                    return _buildConversationItem(
                      context,
                      conversation,
                      otherUserId,
                      otherDisplayName,
                      messageService,
                    );
                  },
                ),
              );
            },
          ),
        ),
      );
  }

  Widget _buildConversationItem(
    BuildContext context,
    Conversation conversation,
    String otherUserId,
    String otherDisplayName,
    DirectMessageService messageService,
  ) {
    final hasUnread = conversation.unreadCount > 0;
    final itemColors = AppColors.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: () {
          HapticService().lightImpact();
          NavigationHelper.safeNavigate(
            context,
            '/direct-message',
            arguments: otherUserId,
          );
        },
        onLongPress: () =>
            _showConversationOptions(context, conversation, messageService),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: hasUnread
                ? itemColors.primaryButton.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(8),
            border: hasUnread
                ? Border.all(color: itemColors.primaryButton, width: 2)
                : null,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: itemColors.primaryButton,
                child: Text(
                  otherDisplayName.substring(0, 1).toUpperCase(),
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            otherDisplayName,
                            style: AppTypography.labelLarge.copyWith(
                              fontWeight: hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: itemColors.primaryText,
                            ),
                          ),
                        ),
                        if (conversation.lastMessage != null)
                          Text(
                            _formatTime(conversation.lastMessage!.timestamp),
                            style: AppTypography.labelSmall.copyWith(
                              color: itemColors.secondaryText,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (conversation.lastMessage != null)
                      Text(
                        conversation.lastMessage!.message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium.copyWith(
                          color: itemColors.secondaryText,
                        ),
                      ),
                  ],
                ),
              ),
              if (hasUnread)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: itemColors.primaryButton,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    conversation.unreadCount > 9
                        ? '9+'
                        : '${conversation.unreadCount}',
                    style: AppTypography.labelSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else {
      return '${dateTime.month}/${dateTime.day}';
    }
  }

  void _showConversationOptions(
    BuildContext context,
    Conversation conversation,
    DirectMessageService messageService,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.of(context).cardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: Text(
                'Delete Conversation',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.error,
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Conversation'),
                    content: const Text(
                      'Are you sure you want to delete this conversation? All messages will be permanently deleted.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  if (!context.mounted) return;
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await messageService.deleteConversation(conversation.id);
                    if (!mounted) return;
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Conversation deleted'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              ),
            ],
          ),
        ),
      );
  }
}
