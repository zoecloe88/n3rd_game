import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/services/family_group_service.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/services/auth_service.dart';
import 'package:n3rd_game/widgets/video_player_widget.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/theme/app_shadows.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/utils/error_handler.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';

class FamilyInvitationScreen extends StatefulWidget {
  final String? groupId;

  const FamilyInvitationScreen({super.key, this.groupId});

  @override
  State<FamilyInvitationScreen> createState() => _FamilyInvitationScreenState();
}

class _FamilyInvitationScreenState extends State<FamilyInvitationScreen> {
  bool _isLoading = false;
  bool _isAccepting = false;

  @override
  void initState() {
    super.initState();
    _checkInvitation();
  }

  Future<void> _checkInvitation() async {
    final groupId = widget.groupId;
    if (groupId == null) {
      if (mounted) {
        ErrorHandler.showSnackBar(context, 'Invalid invitation link');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            NavigationHelper.safePop(context);
          }
        });
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      // Check if user is authenticated
      if (!authService.isAuthenticated) {
        if (mounted) {
          ErrorHandler.showSnackBar(
            context,
            'Please log in to accept the invitation',
          );
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              NavigationHelper.safeNavigate(context, '/login');
            }
          });
        }
        return;
      }

      final familyService =
          Provider.of<FamilyGroupService>(context, listen: false);

      // Check if user is already in a group
      if (familyService.isInGroup) {
        if (mounted) {
          ErrorHandler.showSnackBar(
            context,
            'You are already in a Family & Friends group',
          );
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              NavigationHelper.safePop(context);
            }
          });
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, 'Error checking invitation: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _acceptInvitation() async {
    final groupId = widget.groupId;
    if (groupId == null) return;

    setState(() => _isAccepting = true);

    try {
      final familyService =
          Provider.of<FamilyGroupService>(context, listen: false);
      final analyticsService =
          Provider.of<AnalyticsService>(context, listen: false);

      await familyService.acceptInvitation(groupId);

      // CRITICAL: Check mounted after async operation
      if (!mounted) return;

      // Log analytics
      await analyticsService.logFamilyGroupEvent('family_invitation_accepted', {
        'group_id': groupId,
      });

      // CRITICAL: Check mounted again after another async operation
      if (!mounted || !context.mounted) return;

      ErrorHandler.showSuccess(
        context,
        'Successfully joined Family & Friends group!',
      );

      // Navigate to family management screen after a delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && context.mounted) {
          NavigationHelper.safeNavigate(context, '/family-management');
        }
      });
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
        ErrorHandler.showError(context, 'Failed to accept invitation: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isAccepting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final groupId = widget.groupId;

    // Use Consumer to listen for auth state changes
    return Consumer<AuthService>(
      builder: (context, authService, _) {
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
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: AppShadows.medium,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isLoading) ...[
                            const CircularProgressIndicator(),
                            const SizedBox(height: 24),
                            Text(
                              'Checking invitation...',
                              style: AppTypography.bodyMedium,
                            ),
                          ] else if (!authService.isAuthenticated) ...[
                            const Icon(Icons.login,
                                size: 64, color: Colors.orange),
                            const SizedBox(height: 16),
                            Text(
                              'Login Required',
                              style: AppTypography.headlineLarge
                                  .copyWith(fontSize: 20),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Please log in to accept the Family & Friends invitation.',
                              textAlign: TextAlign.center,
                              style: AppTypography.bodyMedium,
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  NavigationHelper.safeNavigate(
                                      context, '/login');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: const Text('Log In'),
                              ),
                            ),
                          ] else if (groupId == null) ...[
                            const Icon(Icons.error_outline,
                                size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(
                              'Invalid Invitation',
                              style: AppTypography.headlineLarge
                                  .copyWith(fontSize: 20),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'This invitation link is invalid or has expired.',
                              textAlign: TextAlign.center,
                              style: AppTypography.bodyMedium,
                            ),
                          ] else ...[
                            const Icon(Icons.group,
                                size: 64, color: AppColors.success),
                            const SizedBox(height: 16),
                            Text(
                              'Family & Friends Invitation',
                              style: AppTypography.headlineLarge
                                  .copyWith(fontSize: 20),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'You\'ve been invited to join a Family & Friends group! Accept to get Premium access.',
                              textAlign: TextAlign.center,
                              style: AppTypography.bodyMedium,
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed:
                                    _isAccepting ? null : _acceptInvitation,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: _isAccepting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : const Text('Accept Invitation'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () =>
                                  NavigationHelper.safePop(context),
                              child: const Text('Cancel'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
