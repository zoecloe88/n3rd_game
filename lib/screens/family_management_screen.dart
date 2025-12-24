import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/services/family_group_service.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/models/family_group.dart';
import 'package:n3rd_game/widgets/video_player_widget.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/theme/app_shadows.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/utils/error_handler.dart';
import 'package:n3rd_game/utils/responsive_helper.dart';
import 'package:n3rd_game/widgets/unified_background_widget.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FamilyManagementScreen extends StatefulWidget {
  const FamilyManagementScreen({super.key});

  @override
  State<FamilyManagementScreen> createState() => _FamilyManagementScreenState();
}

class _FamilyManagementScreenState extends State<FamilyManagementScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isInviting = false;
  bool _isRemoving = false;
  String? _removingMemberId;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _inviteMember() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ErrorHandler.showSnackBar(context, 'Please enter an email address');
      return;
    }

    setState(() => _isInviting = true);

    try {
      final familyService =
          Provider.of<FamilyGroupService>(context, listen: false);
      final analyticsService =
          Provider.of<AnalyticsService>(context, listen: false);

      await familyService.inviteMember(email);

      // Log analytics
      await analyticsService.logFamilyGroupEvent('family_member_invited', {
        'group_id': familyService.currentGroup?.id,
        'invited_email': email,
      });

      if (!mounted) return;
      ErrorHandler.showSuccess(context, 'Invitation sent to $email');
      _emailController.clear();
    } on ValidationException catch (e) {
      if (mounted) {
        ErrorHandler.showSnackBar(context, e.toString());
      }
    } on NetworkException catch (e) {
      if (mounted) {
        ErrorHandler.showSnackBar(context, e.toString());
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, 'Failed to send invitation: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isInviting = false);
      }
    }
  }

  Future<void> _removeMember(String memberId, String memberEmail) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
            'Are you sure you want to remove $memberEmail from the group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    final familyService =
        Provider.of<FamilyGroupService>(context, listen: false);
    final analyticsService =
        Provider.of<AnalyticsService>(context, listen: false);

    setState(() {
      _isRemoving = true;
      _removingMemberId = memberId;
    });

    try {
      await familyService.removeMember(memberId);

      // Log analytics
      await analyticsService.logFamilyGroupEvent('family_member_removed', {
        'group_id': familyService.currentGroup?.id,
        'removed_member_id': memberId,
      });

      if (!mounted) return;
      ErrorHandler.showSuccess(context, 'Member removed successfully');
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, 'Failed to remove member: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRemoving = false;
          _removingMemberId = null;
        });
      }
    }
  }

  Future<void> _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text(
          'Are you sure you want to leave this Family & Friends group? You will lose access to Premium features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    final familyService =
        Provider.of<FamilyGroupService>(context, listen: false);
    final analyticsService =
        Provider.of<AnalyticsService>(context, listen: false);

    try {
      await familyService.leaveGroup();

      // Log analytics
      await analyticsService.logFamilyGroupEvent('family_group_left', {
        'group_id': familyService.currentGroup?.id,
      });

      if (!mounted) return;
      ErrorHandler.showSuccess(context, 'Left group successfully');
      NavigationHelper.safePop(context);
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, 'Failed to leave group: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;

    // Use Consumer to listen for subscription and family group changes
    return Consumer2<SubscriptionService, FamilyGroupService>(
      builder: (context, subscriptionService, familyService, _) {
        final group = familyService.currentGroup;
        final isOwner = familyService.isOwner;

        // CRITICAL: Check if user has Family & Friends tier access
        if (!subscriptionService.isFamilyFriends && group == null) {
          // User doesn't have Family & Friends tier and is not in a group

          return Scaffold(
            backgroundColor: colors.background,
            body: UnifiedBackgroundWidget(
              child: SafeArea(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppShadows.large,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 64,
                          color: colors.tertiaryText,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Family & Friends Feature',
                          style: AppTypography.headlineLarge.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: colors.primaryText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Family Management is available for Family & Friends subscribers. '
                          'Join a group or upgrade to access this feature!',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium.copyWith(
                            fontSize: 14,
                            color: colors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            NavigationHelper.safeNavigate(
                              context,
                              '/subscription-management',
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primaryButton,
                            foregroundColor: colors.buttonText,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: Text(
                            'View Subscriptions',
                            style: AppTypography.labelLarge,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => NavigationHelper.safePop(context),
                          child: Text(
                            'Go Back',
                            style: AppTypography.bodyMedium.copyWith(
                              color: colors.secondaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: colors.background,
          body: Stack(
            children: [
              // Video background
              const VideoPlayerWidget(
                videoPath: 'assets/videos/settings_video.mp4',
                loop: true,
                autoplay: true,
              ),

              // Content overlay
              SafeArea(
                child: Column(
                  children: [
                    // App bar
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () => NavigationHelper.safePop(context),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Family & Friends',
                            style: AppTypography.headlineLarge.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (group == null) ...[
                              // No group - show create/join options
                              _buildNoGroupView(context, colors),
                            ] else ...[
                              // Group info card
                              _buildGroupInfoCard(
                                  context, colors, group, subscriptionService),

                              const SizedBox(height: 24),

                              // Members section
                              Text(
                                'Members (${group.members.length}/${group.maxMembers})',
                                style: AppTypography.headlineLarge.copyWith(
                                  fontSize: ResponsiveHelper.responsiveFontSize(
                                    context,
                                    baseSize: 20,
                                    minSize: 16,
                                    maxSize: 24,
                                  ),
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Members list
                              ...group.members.map(
                                (member) => _buildMemberCard(
                                  context,
                                  colors,
                                  member,
                                  isOwner && member.userId != currentUser?.uid,
                                  member.userId == currentUser?.uid,
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Pending invites
                              if (group.pendingInvites.isNotEmpty) ...[
                                Text(
                                  'Pending Invitations',
                                  style: AppTypography.headlineLarge.copyWith(
                                    fontSize:
                                        ResponsiveHelper.responsiveFontSize(
                                      context,
                                      baseSize: 20,
                                      minSize: 16,
                                      maxSize: 24,
                                    ),
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ...group.pendingInvites.map(
                                  (invite) => _buildInviteCard(
                                    context,
                                    colors,
                                    invite,
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Invite member (owner only)
                              if (isOwner && !group.isFull) ...[
                                _buildInviteSection(context, colors),
                                const SizedBox(height: 16),
                              ],

                              // Leave group (member only)
                              if (!isOwner) ...[
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: _leaveGroup,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                    ),
                                    child: const Text('Leave Group'),
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoGroupView(BuildContext context, AppColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppShadows.medium,
      ),
      child: Column(
        children: [
          const Icon(Icons.group, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'No Family Group',
            style: AppTypography.headlineLarge.copyWith(
              fontSize: ResponsiveHelper.responsiveFontSize(
                context,
                baseSize: 20,
                minSize: 16,
                maxSize: 24,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a Family & Friends group to share Premium access with up to 4 people.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Navigate to subscription screen to purchase Family plan
                NavigationHelper.safeNavigate(
                    context, '/subscription-management');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Get Family & Friends Plan'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupInfoCard(
    BuildContext context,
    AppColorScheme colors,
    FamilyGroup group,
    SubscriptionService subscriptionService,
  ) {
    final isActive = group.isSubscriptionActive;
    final expiresAt = group.subscriptionExpiresAt;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppShadows.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Group Status',
                style: AppTypography.headlineLarge.copyWith(
                  fontSize: ResponsiveHelper.responsiveFontSize(
                    context,
                    baseSize: 18,
                    minSize: 16,
                    maxSize: 22,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.success.withValues(alpha: 0.2)
                      : Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isActive ? 'Active' : 'Expired',
                  style: AppTypography.labelSmall.copyWith(
                    color: isActive ? AppColors.success : Colors.orange,
                    fontWeight: FontWeight.w600,
                    fontSize: ResponsiveHelper.responsiveFontSize(
                      context,
                      baseSize: 12,
                      minSize: 10,
                      maxSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Members: ${group.members.length}/${group.maxMembers}',
            style: AppTypography.bodyMedium,
          ),
          if (expiresAt != null) ...[
            const SizedBox(height: 8),
            Text(
              isActive
                  ? 'Expires: ${_formatDate(expiresAt)}'
                  : 'Expired: ${_formatDate(expiresAt)}',
              style: AppTypography.bodyMedium.copyWith(
                color: isActive ? colors.secondaryText : Colors.orange,
                fontSize: ResponsiveHelper.responsiveFontSize(
                  context,
                  baseSize: 12,
                  minSize: 10,
                  maxSize: 14,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMemberCard(
    BuildContext context,
    AppColorScheme colors,
    FamilyMember member,
    bool canRemove,
    bool isCurrentUser,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppShadows.light,
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: colors.primaryText,
            child: Text(
              member.email.substring(0, 1).toUpperCase(),
              style: AppTypography.titleLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: ResponsiveHelper.responsiveFontSize(
                  context,
                  baseSize: 18,
                  minSize: 16,
                  maxSize: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      member.email,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (member.isOwner) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Owner',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.success,
                            fontSize: ResponsiveHelper.responsiveFontSize(
                              context,
                              baseSize: 10,
                              minSize: 9,
                              maxSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (isCurrentUser) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(You)',
                        style: AppTypography.bodyMedium.copyWith(
                          color: colors.secondaryText,
                          fontSize: ResponsiveHelper.responsiveFontSize(
                            context,
                            baseSize: 12,
                            minSize: 10,
                            maxSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Joined ${_formatDate(member.joinedAt)}',
                  style: AppTypography.bodyMedium.copyWith(
                    color: colors.secondaryText,
                    fontSize: ResponsiveHelper.responsiveFontSize(
                      context,
                      baseSize: 12,
                      minSize: 10,
                      maxSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (canRemove)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _isRemoving && _removingMemberId == member.userId
                  ? null
                  : () => _removeMember(member.userId, member.email),
              tooltip: 'Remove member',
            ),
        ],
      ),
    );
  }

  Widget _buildInviteCard(
    BuildContext context,
    AppColorScheme colors,
    PendingInvite invite,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppShadows.light,
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.mail_outline, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invite.email,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Invited ${_formatDate(invite.invitedAt)}',
                  style: AppTypography.bodyMedium.copyWith(
                    color: colors.secondaryText,
                    fontSize: ResponsiveHelper.responsiveFontSize(
                      context,
                      baseSize: 12,
                      minSize: 10,
                      maxSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Pending',
              style: AppTypography.labelSmall.copyWith(
                color: Colors.orange,
                fontSize: ResponsiveHelper.responsiveFontSize(
                  context,
                  baseSize: 10,
                  minSize: 9,
                  maxSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteSection(BuildContext context, AppColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppShadows.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Invite Member',
            style: AppTypography.headlineLarge.copyWith(
              fontSize: ResponsiveHelper.responsiveFontSize(
                context,
                baseSize: 18,
                minSize: 16,
                maxSize: 22,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              hintText: 'Enter email address',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.email_outlined),
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _inviteMember(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isInviting ? null : _inviteMember,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isInviting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Send Invitation'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}
