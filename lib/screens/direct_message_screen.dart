import 'dart:async';
import 'package:flutter/material.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/services/direct_message_service.dart';
import 'package:n3rd_game/services/auth_service.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/models/direct_message.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/services/haptic_service.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/utils/responsive_helper.dart';
import 'package:n3rd_game/widgets/standardized_loading_widget.dart';

class DirectMessageScreen extends StatefulWidget {
  const DirectMessageScreen({super.key});

  @override
  State<DirectMessageScreen> createState() => _DirectMessageScreenState();
}

class _DirectMessageScreenState extends State<DirectMessageScreen> {
  final DirectMessageService _messageService = DirectMessageService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _otherUserId;
  String? _otherDisplayName;
  bool _hasPremium = false;
  bool _loading = true;
  bool _initialized = false;
  bool _isTyping = false;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize after context is fully ready
    if (!_initialized) {
      _initialized = true;
      _initialize();
    }
  }

  Future<void> _initialize() async {
    if (!mounted) return;
    
    // CRITICAL: Check subscription access first using SubscriptionService
    final subscriptionService = Provider.of<SubscriptionService>(
      context,
      listen: false,
    );
    
    if (!subscriptionService.hasOnlineAccess) {
      if (!mounted) return;
      setState(() {
        _hasPremium = false;
        _loading = false;
      });
      return;
    }

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) {
      _otherUserId = args;
    }

    if (_otherUserId == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    // Get current user ID before any async operations
    final currentUserId =
        Provider.of<AuthService>(context, listen: false).currentUser?.uid ?? '';

    // Double-check premium access via message service
    final hasPremium = await _messageService.hasPremiumAccess();
    if (!hasPremium) {
      if (!mounted) return;
      setState(() {
        _hasPremium = false;
        _loading = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _hasPremium = true;
    });

    // Load conversations first to get display name
    await _messageService.loadConversations();

    // Find conversation
    final conversations = _messageService.conversations;
    final conversation = conversations.firstWhere(
      (c) => c.userId1 == _otherUserId || c.userId2 == _otherUserId,
      orElse: () => Conversation(id: '', userId1: '', userId2: _otherUserId!),
    );

    _otherDisplayName =
        conversation.getOtherDisplayName(currentUserId) ??
        _otherUserId?.split('@').first ??
        'User';

    // Load messages
    await _messageService.loadMessages(_otherUserId!);

    if (!mounted) return;
    setState(() => _loading = false);

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _messageService.stopListening();
    super.dispose();
  }

  void _onTextChanged(String text) {
    if (!_hasPremium || _otherUserId == null) return;

    // Set typing indicator
    if (text.trim().isNotEmpty && !_isTyping) {
      _isTyping = true;
      _messageService.setTypingIndicator(_otherUserId!, true);
    }

    // Cancel previous timer
    _typingTimer?.cancel();

    // Clear typing indicator after 2 seconds of no typing
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        _isTyping = false;
        _messageService.setTypingIndicator(_otherUserId!, false);
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _otherUserId == null) return;

    // Clear typing indicator
    _typingTimer?.cancel();
    if (_isTyping) {
      _isTyping = false;
      _messageService.setTypingIndicator(_otherUserId!, false);
    }

    HapticService().lightImpact();
    final message = _messageController.text.trim();
    _messageController.clear();

    try {
      await _messageService.sendMessage(_otherUserId!, message);
      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.of(context).background,
        body: const StandardizedLoadingWidget(
          message: 'Loading messages...',
        ),
      );
    }

    final colors = AppColors.of(context);
    if (!_hasPremium) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Semantics(
            label: AppLocalizations.of(context)?.backButton ?? 'Back',
            button: true,
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: colors.primaryText),
              onPressed: () {
                HapticService().lightImpact();
                NavigationHelper.safePop(context);
              },
              tooltip: AppLocalizations.of(context)?.backButton ?? 'Back',
            ),
          ),
          title: Text(
            'Direct Messages',
            style: AppTypography.headlineLarge.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w600,
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
                Icon(Icons.lock_outline, size: 64, color: colors.tertiaryText),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Premium Required',
                  style: AppTypography.headlineLarge.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: colors.primaryText,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Direct messaging is available for premium users only.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    fontSize: 16,
                    color: colors.secondaryText,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                ElevatedButton(
                  onPressed: () {
                    HapticService().lightImpact();
                    NavigationHelper.safePop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primaryButton,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.md,
                    ),
                  ),
                  child: Text(
                    'Upgrade to Premium',
                    style: AppTypography.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
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
        leading: Semantics(
          label: AppLocalizations.of(context)?.backButton ?? 'Back',
          button: true,
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: colors.primaryText),
            onPressed: () {
              HapticService().lightImpact();
              NavigationHelper.safePop(context);
            },
            tooltip: AppLocalizations.of(context)?.backButton ?? 'Back',
          ),
        ),
        title: Text(
          _otherDisplayName ?? 'Direct Message',
          style: AppTypography.headlineLarge.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: colors.primaryText,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: colors.primaryText),
            onSelected: (value) async {
              HapticService().lightImpact();
              if (value == 'delete' && _otherUserId != null) {
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
                if (confirmed == true && _otherUserId != null) {
                  if (!context.mounted) return;
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    final conversationId = _messageService.currentConversationId;
                    if (conversationId != null) {
                      await _messageService.deleteConversation(conversationId);
                      if (!mounted) return;
                      navigator.pop();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Conversation deleted'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
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
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Delete Conversation',
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Messages list
            Expanded(
              child: Consumer<DirectMessageService>(
                builder: (context, messageService, _) {
                  final messages = messageService.messages;

                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.message_outlined,
                            size: 64,
                            color: colors.tertiaryText,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'No messages yet',
                            style: AppTypography.bodyMedium.copyWith(
                              color: colors.secondaryText,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Start the conversation!',
                            style: AppTypography.labelSmall.copyWith(
                              color: colors.tertiaryText,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: messages.length + 1, // +1 for typing indicator
                    itemBuilder: (context, index) {
                      if (index == messages.length) {
                        // Typing indicator
                        return _buildTypingIndicator();
                      }
                      final message = messages[index];
                      final authService = Provider.of<AuthService>(
                        context,
                        listen: false,
                      );
                      final isMe =
                          message.fromUserId == authService.currentUser?.uid;

                      return _buildMessageBubble(message, isMe);
                    },
                  );
                },
              ),
            ),

            // Message input
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: colors.tertiaryText),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: _onTextChanged,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Semantics(
                    label:
                        AppLocalizations.of(context)?.sendMessage ??
                        'Send Message',
                    button: true,
                    enabled: _messageController.text.trim().isNotEmpty,
                    child: IconButton(
                      icon: Icon(Icons.send, color: colors.primaryButton),
                      onPressed: _messageController.text.trim().isNotEmpty
                          ? _sendMessage
                          : null,
                      tooltip:
                          AppLocalizations.of(context)?.sendMessage ??
                          'Send Message',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(DirectMessage message, bool isMe) {
    final bubbleColors = AppColors.of(context);
    final authService = Provider.of<AuthService>(context, listen: false);
    final isMyMessage = message.fromUserId == authService.currentUser?.uid;
    
    return GestureDetector(
      onLongPress: isMyMessage
          ? () => _showMessageOptions(message)
          : null,
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          constraints: BoxConstraints(
            maxWidth: ResponsiveHelper.responsiveWidth(context, 0.75),
          ),
          decoration: BoxDecoration(
            color: isMe
                ? bubbleColors.primaryButton
                : Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.message,
                style: AppTypography.bodyMedium.copyWith(
                  fontSize: 14,
                  color: isMe ? Colors.white : bubbleColors.primaryText,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(message.timestamp),
                    style: AppTypography.bodyMedium.copyWith(
                      fontSize: 10,
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.7)
                          : bubbleColors.secondaryText,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.isRead ?? false
                          ? Icons.done_all
                          : Icons.done,
                      size: 12,
                      color: message.isRead ?? false
                          ? Colors.white.withValues(alpha: 0.9)
                          : Colors.white.withValues(alpha: 0.6),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.of(context).primaryButton,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Typing...',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.of(context).secondaryText,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageOptions(DirectMessage message) {
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
                'Delete Message',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.error,
                ),
              ),
              onTap: () async {
                if (!mounted) return;
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                try {
                  await _messageService.deleteMessage(message.id);
                  if (!mounted) return;
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Message deleted'),
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
              },
            ),
          ],
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
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${dateTime.month}/${dateTime.day}';
    }
  }
}
