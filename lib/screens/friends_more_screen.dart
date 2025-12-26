import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:n3rd_game/services/friends_service.dart';
import 'package:n3rd_game/services/haptic_service.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/widgets/background_image_widget.dart';

/// More tab screen for Friends section
/// Provides additional friend management features: Add Friend, Suggestions, Invite, Block, Report
class FriendsMoreScreen extends StatefulWidget {
  const FriendsMoreScreen({super.key});

  @override
  State<FriendsMoreScreen> createState() => _FriendsMoreScreenState();
}

class _FriendsMoreScreenState extends State<FriendsMoreScreen> {
  final FriendsService _friendsService = FriendsService();
  final TextEditingController _emailController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _friendsService.init();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// Show dialog to add friend by email
  Future<void> _showAddFriendDialog() async {
    HapticService().lightImpact();
    _emailController.clear();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Add Friend',
          style: AppTypography.headlineMedium.copyWith(
            color: Colors.white,
          ),
        ),
        content: TextField(
          controller: _emailController,
          decoration: InputDecoration(
            labelText: 'Email Address',
            labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            hintText: 'Enter friend\'s email',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white),
            ),
          ),
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ),
          TextButton(
            onPressed: () async {
              final email = _emailController.text.trim();
              if (email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter an email address'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }

              Navigator.of(context).pop();
              await _addFriendByEmail(email);
            },
            child: const Text(
              'Add',
              style: TextStyle(color: Color(0xFF00D9FF)),
            ),
          ),
        ],
      ),
    );
  }

  /// Add friend by email
  Future<void> _addFriendByEmail(String email) async {
    setState(() => _loading = true);
    HapticService().lightImpact();

    try {
      // Search for user by email
      final results = await _friendsService.searchUsers(email);
      if (results.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User not found'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final user = results.first;
      await _friendsService.sendFriendRequest(
        user['userId'] as String,
        friendEmail: user['email'] as String?,
        friendDisplayName: user['displayName'] as String?,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request sent!'),
            backgroundColor: Colors.green,
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
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// Show friend suggestions screen
  Future<void> _showFriendSuggestions() async {
    HapticService().lightImpact();
    setState(() => _loading = true);

    try {
      final suggestions = await _friendsService.getFriendSuggestions();
      if (!mounted) return;

      setState(() => _loading = false);

      if (suggestions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No suggestions available at this time'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Show suggestions dialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.black.withValues(alpha: 0.95),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            'Friend Suggestions',
            style: AppTypography.headlineMedium.copyWith(
              color: Colors.white,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = suggestions[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF00D9FF),
                    child: Text(
                      (suggestion['displayName'] as String? ?? suggestion['email'] as String? ?? '?')
                          .substring(0, 1)
                          .toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    suggestion['displayName'] as String? ?? suggestion['email'] as String? ?? 'Unknown',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    suggestion['email'] as String? ?? '',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.person_add),
                    color: const Color(0xFF00D9FF),
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _addFriendByEmail(suggestion['email'] as String? ?? '');
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading suggestions: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Show send invite dialog
  Future<void> _showSendInviteDialog() async {
    HapticService().lightImpact();
    _emailController.clear();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Send Invite',
          style: AppTypography.headlineMedium.copyWith(
            color: Colors.white,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Invite a friend to join N3RD Trivia!',
              style: AppTypography.bodyMedium.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email Address',
                labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                hintText: 'Enter email to invite',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ),
          TextButton(
            onPressed: () async {
              final email = _emailController.text.trim();
              if (email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter an email address'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }

              Navigator.of(context).pop();
              
              // Send invitation via share_plus
              try {
                // Create invite link (can be customized with deep link)
                const inviteMessage = 'Join me on N3RD Trivia! Download the app and challenge me: https://n3rdtrivia.app/invite';
                
                // Share via native share sheet (email/SMS/social media)
                await Share.share(
                  inviteMessage,
                  subject: 'Join me on N3RD Trivia!',
                );
                
                // Also save invitation record to Firestore
                await _friendsService.sendInvitation(email);
                
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invite shared successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                LoggerService.error('Error sending invitation', error: e);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error sending invite: ${e.toString()}'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text(
              'Send',
              style: TextStyle(color: Color(0xFF00D9FF)),
            ),
          ),
        ],
      ),
    );
  }

  /// Show block user dialog
  Future<void> _showBlockUserDialog() async {
    HapticService().lightImpact();
    _emailController.clear();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Block User',
          style: AppTypography.headlineMedium.copyWith(
            color: Colors.white,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the email of the user you want to block.',
              style: AppTypography.bodyMedium.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email Address',
                labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                hintText: 'Enter user\'s email',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ),
          TextButton(
            onPressed: () async {
              final email = _emailController.text.trim();
              if (email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter an email address'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }

              Navigator.of(context).pop();
              await _blockUserByEmail(email);
            },
            child: const Text(
              'Block',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  /// Block user by email
  Future<void> _blockUserByEmail(String email) async {
    setState(() => _loading = true);
    HapticService().lightImpact();

    try {
      // Search for user by email
      final results = await _friendsService.searchUsers(email);
      if (results.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User not found'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final user = results.first;
      await _friendsService.blockUser(user['userId'] as String);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User blocked successfully'),
            backgroundColor: Colors.green,
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
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// Show report user dialog
  Future<void> _showReportUserDialog() async {
    HapticService().lightImpact();
    _emailController.clear();

    final reportController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Report User',
          style: AppTypography.headlineMedium.copyWith(
            color: Colors.white,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'User Email',
                labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                hintText: 'Enter user\'s email',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: reportController,
              decoration: InputDecoration(
                labelText: 'Reason',
                labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                hintText: 'Describe the issue...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _emailController.clear();
              reportController.dispose();
              Navigator.of(context).pop();
            },
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ),
          TextButton(
            onPressed: () async {
              final email = _emailController.text.trim();
              final reason = reportController.text.trim();
              if (email.isEmpty || reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all fields'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }

              reportController.dispose();
              Navigator.of(context).pop();
              
              // Submit report to backend
              try {
                // First, find the user ID from email
                final users = await _friendsService.searchUsers(email);
                if (users.isEmpty) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('User not found'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }
                
                final reportedUserId = users.first['userId'] as String;
                await _friendsService.reportUser(reportedUserId, reason);
                
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Report submitted. Thank you!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                LoggerService.error('Error submitting report', error: e);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error submitting report: ${e.toString()}'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text(
              'Submit',
              style: TextStyle(color: Color(0xFF00D9FF)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: iconColor ?? Colors.white,
          size: 24,
        ),
        title: Text(
          title,
          style: AppTypography.titleLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTypography.bodyMedium.copyWith(
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Colors.white.withValues(alpha: 0.6),
        ),
        onTap: _loading ? null : onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BackgroundImageWidget(
        imagePath: 'assets/background n3rd.png',
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF00D9FF),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header removed per user request
                      // Action buttons
                      _buildActionButton(
                        icon: Icons.person_add,
                        title: 'Add Friend',
                        subtitle: 'Search and add friends by email',
                        onTap: _showAddFriendDialog,
                      ),
                      _buildActionButton(
                        icon: Icons.people_outline,
                        title: 'Friend Suggestions',
                        subtitle: 'Discover people you might know',
                        onTap: _showFriendSuggestions,
                      ),
                      _buildActionButton(
                        icon: Icons.mail_outline,
                        title: 'Send Invite',
                        subtitle: 'Invite friends to join N3RD Trivia',
                        onTap: _showSendInviteDialog,
                      ),
                      _buildActionButton(
                        icon: Icons.block,
                        title: 'Block',
                        subtitle: 'Block a user from contacting you',
                        onTap: _showBlockUserDialog,
                        iconColor: AppColors.error,
                      ),
                      _buildActionButton(
                        icon: Icons.flag_outlined,
                        title: 'Report',
                        subtitle: 'Report inappropriate behavior',
                        onTap: _showReportUserDialog,
                        iconColor: AppColors.error,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

