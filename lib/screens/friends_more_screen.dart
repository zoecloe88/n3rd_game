import 'dart:io';
import 'package:n3rd_game/utils/unawaited_helper.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:n3rd_game/services/haptic_service.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/screens/friends_more_view_model.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/theme/app_radius.dart';
import 'package:n3rd_game/widgets/background_image_widget.dart';
import 'package:n3rd_game/widgets/app_button.dart';
import 'package:n3rd_game/widgets/app_text_field.dart';
import 'package:n3rd_game/widgets/app_card.dart';
import 'package:n3rd_game/utils/feedback_helper.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';

/// More tab screen for Friends section
/// Provides additional friend management features: Add Friend, Suggestions, Invite, Block, Report
/// Also displays friend scores for comparison
class FriendsMoreScreen extends StatefulWidget {
  const FriendsMoreScreen({super.key});

  @override
  State<FriendsMoreScreen> createState() => _FriendsMoreScreenState();
}

class _FriendsMoreScreenState extends State<FriendsMoreScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// Show dialog to add friend by email or phone
  Future<void> _showAddFriendDialog() async {
    unawaited(HapticService().lightImpact());
    _emailController.clear();
    _phoneController.clear();
    int selectedTab = 0; // 0 = email, 1 = phone, 2 = QR code

    final colors = AppColors.of(context);
    await FeedbackHelper.showBottomSheet(
      context,
      child: StatefulBuilder(
        builder: (context, setDialogState) => Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add Friend',
                style: AppTypography.headlineMedium.copyWith(
                  color: colors.onDarkText,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // Tab selector
              Row(
                children: [
                  Expanded(
                    child: _buildTabButton(
                      'Email',
                      selectedTab == 0,
                      () => setDialogState(() => selectedTab = 0),
                      context,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _buildTabButton(
                      'Phone',
                      selectedTab == 1,
                      () => setDialogState(() => selectedTab = 1),
                      context,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _buildTabButton(
                      'QR Code',
                      selectedTab == 2,
                      () => setDialogState(() => selectedTab = 2),
                      context,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // Content based on selected tab
              if (selectedTab == 0)
                AppTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  hint: 'Enter friend\'s email',
                  keyboardType: TextInputType.emailAddress,
                  leadingIcon: Icons.email,
                  semanticsLabel: 'Email Address',
                  semanticsHint: 'Enter friend\'s email',
                )
              else if (selectedTab == 1)
                AppTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  hint: 'Enter friend\'s phone number',
                  keyboardType: TextInputType.phone,
                  leadingIcon: Icons.phone,
                  semanticsLabel: 'Phone Number',
                  semanticsHint: 'Enter friend\'s phone number',
                )
              else
                Column(
                  children: [
                    Icon(
                      Icons.qr_code_scanner,
                      size: 64,
                      color: colors.onDarkText.withValues(alpha: 0.7),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Share your QR code or scan a friend\'s code',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(
                        color: colors.onDarkText.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      icon: Icons.share,
                      label: 'Share QR Code',
                      onPressed: () {
                        NavigationHelper.safePop(context);
                        _shareQRCode();
                      },
                      variant: AppButtonVariant.primary,
                      backgroundColor: colors.accent,
                      foregroundColor: colors.onDarkText,
                    ),
                  ],
                ),
              const SizedBox(height: AppSpacing.lg),
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: 'Cancel',
                    onPressed: () => NavigationHelper.safePop(context),
                    variant: AppButtonVariant.text,
                    foregroundColor: colors.onDarkText.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppButton(
                    variant: AppButtonVariant.primary,
                    onPressed: () async {
                      if (selectedTab == 0) {
                        final email = _emailController.text.trim();
                        final localizations = AppLocalizations.of(context);
                        if (email.isEmpty || !email.contains('@')) {
                          FeedbackHelper.showError(
                            context,
                            localizations?.pleaseEnterValidEmail ??
                                'Please enter a valid email address',
                          );
                          return;
                        }
                        NavigationHelper.safePop(context);
                        await _addFriendByEmail(email);
                      } else if (selectedTab == 1) {
                        final phone = _phoneController.text.trim();
                        final localizations = AppLocalizations.of(context);
                        if (phone.isEmpty || phone.length < 10) {
                          FeedbackHelper.showError(
                            context,
                            localizations?.pleaseEnterValidPhone ??
                                'Please enter a valid phone number',
                          );
                          return;
                        }
                        NavigationHelper.safePop(context);
                        await _addFriendByPhone(phone);
                      } else {
                        NavigationHelper.safePop(context);
                      }
                    },
                    label: () {
                      final localizations = AppLocalizations.of(context);
                      return selectedTab == 2
                          ? (localizations?.close ?? 'Close')
                          : (localizations?.add ?? 'Add');
                    }(),
                    backgroundColor: colors.accent,
                    foregroundColor: colors.onDarkText,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(
      String label, bool isSelected, VoidCallback onTap, BuildContext context,) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm, horizontal: AppSpacing.md,),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.accent.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(
            color: isSelected
                ? colors.accent
                : colors.onDarkText.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.labelSmall.copyWith(
            color: isSelected
                ? colors.accent
                : colors.onDarkText.withValues(alpha: 0.7),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Future<void> _shareQRCode() async {
    unawaited(HapticService().lightImpact());

    try {
      // Get current user ID
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.uid.isEmpty) {
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          FeedbackHelper.showError(
            context,
            localizations?.youMustBeSignedInToShareQR ??
                'You must be signed in to share your QR code',
          );
        }
        return;
      }

      // Create invitation data - encode user ID in a format that can be scanned
      // Format: n3rdgame://friend/invite?userId=xxx
      final inviteData = 'n3rdgame://friend/invite?userId=${user.uid}';

      // Show dialog with QR code preview and share option
      if (!mounted) return;
      final colors = AppColors.of(context);

      await FeedbackHelper.showBottomSheet(
        context,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your Friend Invitation Code',
                style: AppTypography.headlineMedium.copyWith(
                  color: colors.onDarkText,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // QR Code widget
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.onDarkText,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                child: QrImageView(
                  data: inviteData,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: colors.onDarkText,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Scan this code to add me as a friend',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: colors.onDarkText.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppButton(
                    variant: AppButtonVariant.text,
                    label: 'Close',
                    onPressed: () => NavigationHelper.safePop(context),
                    foregroundColor: colors.onDarkText.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  AppButton(
                    variant: AppButtonVariant.primary,
                    icon: Icons.share,
                    label: 'Share',
                    onPressed: () async {
                      NavigationHelper.safePop(context);
                      await _shareQRCodeImage(inviteData);
                    },
                    backgroundColor: colors.accent,
                    foregroundColor: colors.onDarkText,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      LoggerService.error(
        'Failed to generate QR code',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        FeedbackHelper.showError(
          context,
          localizations?.qrCodeGenerationError ??
              'Failed to generate QR code. Please try again.',
        );
      }
    }
  }

  /// Share QR code as image file
  Future<void> _shareQRCodeImage(String inviteData) async {
    try {
      // Create QR code painter
      final painter = QrPainter(
        data: inviteData,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.L,
        dataModuleStyle: const QrDataModuleStyle(
          color: Colors.black,
        ),
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        embeddedImage: null,
        embeddedImageStyle: null,
      );

      // Render QR code to image
      final picRecorder = ui.PictureRecorder();
      final canvas = Canvas(picRecorder);
      const size = 512.0;

      // Fill background with white (replaces deprecated emptyColor)
      final colors = AppColors.of(context);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 512.0, 512.0),
        Paint()..color = colors.onDarkText,
      );
      painter.paint(canvas, const Size(size, size));
      final picture = picRecorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Failed to convert QR code to image');
      }

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/friend_invite_qr_${DateTime.now().millisecondsSinceEpoch}.png',);
      await file.writeAsBytes(byteData.buffer.asUint8List());

      // Share the image
      final result = await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Scan this QR code to add me as a friend on N3RD Game!',
        subject: 'Friend Invitation - N3RD Game',
      );

      // Clean up temporary file after a delay
      Future.delayed(const Duration(seconds: 5), () {
        try {
          if (file.existsSync()) {
            file.deleteSync();
          }
        } catch (e) {
          // Ignore cleanup errors
        }
      });

      if (mounted && result.status == ShareResultStatus.success) {
        unawaited(HapticService().success());
        final localizations = AppLocalizations.of(context);
        FeedbackHelper.showSuccess(
          context,
          localizations?.qrCodeSharedSuccessfully ??
              'QR code shared successfully!',
        );
      }
    } catch (e) {
      LoggerService.error(
        'Failed to share QR code image',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        FeedbackHelper.showError(
          context,
          localizations?.qrCodeShareError ??
              'Failed to share QR code. Please try again.',
        );
      }
    }
  }

  Future<void> _addFriendByPhone(String phone) async {
    final viewModel = context.read<FriendsMoreViewModel>();
    unawaited(HapticService().lightImpact());

    // Normalize phone number (remove spaces, dashes, etc.)
    final normalizedPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Search for user by phone
    final results = await viewModel.searchUsers(normalizedPhone);
    if (results.isEmpty) {
      if (mounted) {
        FeedbackHelper.showError(context, 'User not found');
      }
      return;
    }

    final user = results.first;
    final success = await viewModel.sendFriendRequest(
      user['userId'] as String,
      friendEmail: user['email'] as String?,
      friendDisplayName: user['displayName'] as String?,
    );

    if (mounted) {
      if (success) {
        FeedbackHelper.showSuccess(context, 'Friend request sent!');
      } else {
        FeedbackHelper.showError(
          context,
          viewModel.errorMessage ?? 'Failed to send friend request',
        );
      }
    }
  }

  /// Add friend by email
  Future<void> _addFriendByEmail(String email) async {
    final viewModel = context.read<FriendsMoreViewModel>();
    unawaited(HapticService().lightImpact());

    // Search for user by email
    final results = await viewModel.searchUsers(email);
    if (results.isEmpty) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations?.userNotFound ?? 'User not found',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final user = results.first;
    final success = await viewModel.sendFriendRequest(
      user['userId'] as String,
      friendEmail: user['email'] as String?,
      friendDisplayName: user['displayName'] as String?,
    );

    if (mounted) {
      if (success) {
        final localizations = AppLocalizations.of(context);
        FeedbackHelper.showSuccess(
          context,
          localizations?.friendRequestSent ?? 'Friend request sent!',
        );
      } else {
        FeedbackHelper.showError(
          context,
          viewModel.errorMessage ?? 'Failed to send friend request',
        );
      }
    }
  }

  /// Show friend suggestions screen
  Future<void> _showFriendSuggestions() async {
    final viewModel = context.read<FriendsMoreViewModel>();
    unawaited(HapticService().lightImpact());

    final suggestions = await viewModel.getFriendSuggestions();
    if (!mounted) return;

    if (suggestions.isEmpty) {
      final localizations = AppLocalizations.of(context);
      FeedbackHelper.showWarning(
        context,
        localizations?.noSuggestionsAvailable ??
            'No suggestions available at this time',
      );
      return;
    }

    // Show suggestions dialog
    final colors = AppColors.of(context);
    await FeedbackHelper.showBottomSheet(
      context,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Friend Suggestions',
              style: AppTypography.headlineMedium.copyWith(
                color: colors.onDarkText,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = suggestions[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colors.accent,
                      child: Text(
                        (suggestion['displayName'] as String? ??
                                suggestion['email'] as String? ??
                                '?')
                            .substring(0, 1)
                            .toUpperCase(),
                        style: TextStyle(color: colors.onDarkText),
                      ),
                    ),
                    title: Text(
                      suggestion['displayName'] as String? ??
                          suggestion['email'] as String? ??
                          'Unknown',
                      style: TextStyle(color: colors.onDarkText),
                    ),
                    subtitle: Text(
                      suggestion['email'] as String? ?? '',
                      style: TextStyle(
                          color: colors.onDarkText.withValues(alpha: 0.7),),
                    ),
                    trailing: viewModel.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : AppButton(
                            icon: Icons.person_add,
                            onPressed: () async {
                              NavigationHelper.safePop(context);
                              await _addFriendByEmail(
                                  suggestion['email'] as String? ?? '',);
                            },
                            variant: AppButtonVariant.icon,
                            backgroundColor: Colors.transparent,
                            foregroundColor: colors.accent,
                          ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  variant: AppButtonVariant.text,
                  label: 'Close',
                  onPressed: () => NavigationHelper.safePop(context),
                  foregroundColor: colors.onDarkText.withValues(alpha: 0.7),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Show send invite dialog
  Future<void> _showSendInviteDialog() async {
    unawaited(HapticService().lightImpact());
    _emailController.clear();
    final colors = AppColors.of(context);

    await FeedbackHelper.showBottomSheet(
      context,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send Invite',
              style: AppTypography.headlineMedium.copyWith(
                color: colors.onDarkText,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Invite a friend to join N3RD Trivia!',
              style: AppTypography.bodyMedium.copyWith(
                color: colors.onDarkText,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _emailController,
              label: 'Email Address',
              hint: 'Enter email to invite',
              keyboardType: TextInputType.emailAddress,
              leadingIcon: Icons.email,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  variant: AppButtonVariant.text,
                  label: 'Cancel',
                  onPressed: () => NavigationHelper.safePop(context),
                  foregroundColor: colors.onDarkText.withValues(alpha: 0.7),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppButton(
                  variant: AppButtonVariant.primary,
                  label: AppLocalizations.of(context)?.sendButton ?? 'Send',
                  onPressed: () async {
                    final email = _emailController.text.trim();
                    final localizations = AppLocalizations.of(context);
                    if (email.isEmpty) {
                      FeedbackHelper.showError(
                        context,
                        localizations?.pleaseEnterEmailAddress ??
                            'Please enter an email address',
                      );
                      return;
                    }

                    NavigationHelper.safePop(context);

                    // Send invitation via share_plus
                    final viewModel = context.read<FriendsMoreViewModel>();
                    try {
                      // Create invite link (can be customized with deep link)
                      const inviteMessage =
                          'Join me on N3RD Trivia! Download the app and challenge me: https://n3rdtrivia.app/invite';

                      // Share via native share sheet (email/SMS/social media)
                      await Share.share(
                        inviteMessage,
                        subject: 'Join me on N3RD Trivia!',
                      );

                      // Also save invitation record to Firestore
                      final success = await viewModel.sendInvitation(email);

                      if (!mounted) return;
                      final localizations2 = AppLocalizations.of(context);
                      if (success) {
                        FeedbackHelper.showSuccess(
                          context,
                          localizations2?.inviteSharedSuccessfully ??
                              'Invite shared successfully',
                        );
                      } else {
                        FeedbackHelper.showError(
                          context,
                          viewModel.errorMessage ??
                              (localizations2?.sendInviteError ??
                                  'Failed to send invite. Please try again.'),
                        );
                      }
                    } catch (e) {
                      LoggerService.error('Error sending invitation', error: e);
                      if (!mounted) return;
                      final localizations = AppLocalizations.of(context);
                      FeedbackHelper.showError(
                        context,
                        localizations?.sendInviteError ??
                            'Failed to send invite. Please try again.',
                      );
                    }
                  },
                  backgroundColor: colors.accent,
                  foregroundColor: colors.onDarkText,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Show block user dialog
  Future<void> _showBlockUserDialog() async {
    unawaited(HapticService().lightImpact());
    _emailController.clear();
    final colors = AppColors.of(context);

    await FeedbackHelper.showBottomSheet(
      context,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)?.blockUser ?? 'Block User',
              style: AppTypography.headlineMedium.copyWith(
                color: colors.onDarkText,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              AppLocalizations.of(context)?.enterEmailToBlock ??
                  'Enter the email of the user you want to block.',
              style: AppTypography.bodyMedium.copyWith(
                color: colors.onDarkText,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _emailController,
              label: AppLocalizations.of(context)?.emailAddressLabel ??
                  'Email Address',
              hint: AppLocalizations.of(context)?.enterUserEmailHint ??
                  'Enter user\'s email',
              keyboardType: TextInputType.emailAddress,
              leadingIcon: Icons.email,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  variant: AppButtonVariant.text,
                  label: 'Cancel',
                  onPressed: () => NavigationHelper.safePop(context),
                  foregroundColor: colors.onDarkText.withValues(alpha: 0.7),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppButton(
                  label: AppLocalizations.of(context)?.blockButton ?? 'Block',
                  onPressed: () async {
                    final email = _emailController.text.trim();
                    final localizations = AppLocalizations.of(context);
                    if (email.isEmpty) {
                      FeedbackHelper.showError(
                        context,
                        localizations?.pleaseEnterEmailAddress ??
                            'Please enter an email address',
                      );
                      return;
                    }

                    NavigationHelper.safePop(context);
                    await _blockUserByEmail(email);
                  },
                  variant: AppButtonVariant.text,
                  foregroundColor: colors.error,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Block user by email
  Future<void> _blockUserByEmail(String email) async {
    final viewModel = context.read<FriendsMoreViewModel>();
    unawaited(HapticService().lightImpact());

    // Search for user by email
    final results = await viewModel.searchUsers(email);
    if (results.isEmpty) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        FeedbackHelper.showError(
          context,
          localizations?.userNotFound ?? 'User not found',
        );
      }
      return;
    }

    final user = results.first;
    final success = await viewModel.blockUser(user['userId'] as String);

    if (mounted) {
      if (success) {
        final localizations = AppLocalizations.of(context);
        FeedbackHelper.showSuccess(
          context,
          localizations?.userBlockedSuccessfully ?? 'User blocked successfully',
        );
      } else {
        FeedbackHelper.showError(
          context,
          viewModel.errorMessage ?? 'Failed to block user',
        );
      }
    }
  }

  /// Show report user dialog
  Future<void> _showReportUserDialog() async {
    unawaited(HapticService().lightImpact());
    _emailController.clear();
    final colors = AppColors.of(context);

    final reportController = TextEditingController();

    await FeedbackHelper.showBottomSheet(
      context,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)?.reportUser ?? 'Report User',
              style: AppTypography.headlineMedium.copyWith(
                color: colors.onDarkText,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _emailController,
              label:
                  AppLocalizations.of(context)?.userEmailLabel ?? 'User Email',
              hint: AppLocalizations.of(context)?.enterUserEmailHint ??
                  'Enter user\'s email',
              keyboardType: TextInputType.emailAddress,
              leadingIcon: Icons.email,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: reportController,
              label: AppLocalizations.of(context)?.reasonLabel ?? 'Reason',
              hint: AppLocalizations.of(context)?.describeIssueHint ??
                  'Describe the issue...',
              maxLines: 3,
              leadingIcon: Icons.description,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  variant: AppButtonVariant.text,
                  label: 'Cancel',
                  onPressed: () {
                    _emailController.clear();
                    reportController.dispose();
                    NavigationHelper.safePop(context);
                  },
                ),
                const SizedBox(width: AppSpacing.sm),
                AppButton(
                  variant: AppButtonVariant.primary,
                  label: AppLocalizations.of(context)?.sendButton ?? 'Submit',
                  onPressed: () async {
                    final email = _emailController.text.trim();
                    final reason = reportController.text.trim();
                    final localizations = AppLocalizations.of(context);
                    if (email.isEmpty || reason.isEmpty) {
                      FeedbackHelper.showError(
                        context,
                        localizations?.pleaseFillInAllFields ??
                            'Please fill in all fields',
                      );
                      return;
                    }

                    reportController.dispose();
                    NavigationHelper.safePop(context);

                    // Submit report to backend
                    final viewModel = context.read<FriendsMoreViewModel>();
                    try {
                      // First, find the user ID from email
                      final users = await viewModel.searchUsers(email);
                      if (users.isEmpty) {
                        if (!mounted) return;
                        final localizations2 = AppLocalizations.of(context);
                        FeedbackHelper.showError(
                          context,
                          localizations2?.userNotFound ?? 'User not found',
                        );
                        return;
                      }

                      final reportedUserId = users.first['userId'] as String;
                      final success =
                          await viewModel.reportUser(reportedUserId, reason);

                      if (!mounted) return;
                      final localizations3 = AppLocalizations.of(context);
                      if (success) {
                        FeedbackHelper.showSuccess(
                          context,
                          localizations3?.reportSubmittedThankYou ??
                              'Report submitted. Thank you!',
                        );
                      } else {
                        FeedbackHelper.showError(
                          context,
                          viewModel.errorMessage ??
                              (localizations3?.submitReportError ??
                                  'Failed to submit report. Please try again.'),
                        );
                      }
                    } catch (e) {
                      LoggerService.error('Error submitting report', error: e);
                      if (!mounted) return;
                      final localizations = AppLocalizations.of(context);
                      FeedbackHelper.showError(
                        context,
                        localizations?.submitReportError ??
                            'Failed to submit report. Please try again.',
                      );
                    }
                  },
                  backgroundColor: colors.accent,
                  foregroundColor: colors.onDarkText,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    bool isRedButton = false,
  }) {
    return Builder(
      builder: (context) {
        final colors = AppColors.of(context);
        final backgroundColor =
            isRedButton ? colors.error : colors.cardBackground;
        final textColor = isRedButton ? colors.onDarkText : colors.primaryText;
        final subtitleColor = isRedButton
            ? colors.onDarkText.withValues(alpha: 0.9)
            : colors.secondaryText;

        return AppCard.filled(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          backgroundColor: backgroundColor,
          onTap: onTap,
          child: ListTile(
            leading: Icon(
              icon,
              color: isRedButton
                  ? colors.onDarkText
                  : (iconColor ?? colors.primaryText),
              size: 24,
            ),
            title: Text(
              title,
              style: AppTypography.titleLarge.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: AppTypography.bodyMedium.copyWith(
                color: subtitleColor,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: textColor.withValues(alpha: 0.6),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm,),
          ),
        );
      },
    );
  }

  /// Build friend scores section
  Widget _buildFriendScoresSection(FriendsMoreViewModel viewModel) {
    return Builder(
      builder: (context) {
        final colors = AppColors.of(context);

        if (viewModel.isLoadingScores) {
          return AppCard.filled(
            padding: const EdgeInsets.all(AppSpacing.md),
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            backgroundColor: colors.onDarkText.withValues(alpha: 0.1),
            child: Center(
              child: CircularProgressIndicator(
                color: colors.accent,
              ),
            ),
          );
        }

        if (viewModel.scoresErrorMessage != null) {
          return AppCard.filled(
            padding: const EdgeInsets.all(AppSpacing.md),
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            backgroundColor: colors.error.withValues(alpha: 0.2),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: colors.error),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    viewModel.scoresErrorMessage!,
                    style: AppTypography.bodyMedium.copyWith(
                      color: colors.onDarkText,
                    ),
                  ),
                ),
                AppButton(
                  icon: Icons.refresh,
                  onPressed: () => viewModel.refreshFriendScores(),
                  variant: AppButtonVariant.icon,
                  backgroundColor: Colors.transparent,
                  foregroundColor: colors.onDarkText,
                ),
              ],
            ),
          );
        }

        if (viewModel.friendScores.isEmpty) {
          return AppCard.filled(
            padding: const EdgeInsets.all(AppSpacing.md),
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            backgroundColor: colors.onDarkText.withValues(alpha: 0.1),
            child: Column(
              children: [
                Icon(
                  Icons.emoji_events_outlined,
                  size: 48,
                  color: colors.onDarkText.withValues(alpha: 0.7),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'No friend scores yet',
                  style: AppTypography.bodyMedium.copyWith(
                    color: colors.onDarkText.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Add friends and play games to see scores!',
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onDarkText.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return AppCard.filled(
          padding: const EdgeInsets.all(AppSpacing.md),
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          backgroundColor: colors.onDarkText.withValues(alpha: 0.1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Friend Scores',
                    style: AppTypography.titleLarge.copyWith(
                      color: colors.onDarkText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  AppButton(
                    icon: Icons.refresh,
                    onPressed: () => viewModel.refreshFriendScores(),
                    variant: AppButtonVariant.icon,
                    backgroundColor: Colors.transparent,
                    foregroundColor: colors.accent,
                    semanticsLabel: 'Refresh scores',
                  ),
                ],
              ),
              if (viewModel.currentUserScore != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person, color: colors.accent),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Your Score: ${viewModel.currentUserScore}',
                        style: AppTypography.bodyMedium.copyWith(
                          color: colors.onDarkText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              ...viewModel.friendScores.take(5).map(
                    (score) => Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.overlayDark.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: colors.accent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text(
                                '#${score.rank}',
                                style: AppTypography.labelSmall.copyWith(
                                  color: colors.onDarkText,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  score.displayName ?? score.email ?? 'Unknown',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: colors.onDarkText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (score.email != null &&
                                    score.email != score.displayName)
                                  Text(
                                    score.email!,
                                    style: AppTypography.labelSmall.copyWith(
                                      color: colors.onDarkText
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '${score.score}',
                            style: AppTypography.titleLarge.copyWith(
                              color: colors.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FriendsMoreViewModel(),
      child: Consumer<FriendsMoreViewModel>(
        builder: (context, viewModel, child) {
          final colors = AppColors.of(context);
          return Scaffold(
            backgroundColor: AppColors.overlayDark,
            body: BackgroundImageWidget(
              imagePath: 'assets/background n3rd.png',
              child: SafeArea(
                child: viewModel.isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: colors.accent,
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Friend scores section
                            _buildFriendScoresSection(viewModel),
                            // Action buttons
                            _buildActionButton(
                              icon: Icons.person_add,
                              title: 'Add Friend',
                              subtitle:
                                  'Search and add friends by email or phone',
                              onTap: _showAddFriendDialog,
                              isRedButton: false,
                            ),
                            _buildActionButton(
                              icon: Icons.people_outline,
                              title: 'Friend Suggestions',
                              subtitle: 'Discover people you might know',
                              onTap: _showFriendSuggestions,
                              isRedButton: false,
                            ),
                            _buildActionButton(
                              icon: Icons.mail_outline,
                              title: 'Send Invite',
                              subtitle: 'Invite friends to join N3RD Trivia',
                              onTap: _showSendInviteDialog,
                              isRedButton: false,
                            ),
                            _buildActionButton(
                              icon: Icons.block,
                              title: 'Block',
                              subtitle: 'Block a user from contacting you',
                              onTap: _showBlockUserDialog,
                              isRedButton: true,
                            ),
                            _buildActionButton(
                              icon: Icons.flag_outlined,
                              title: 'Report',
                              subtitle: 'Report inappropriate behavior',
                              onTap: _showReportUserDialog,
                              isRedButton: true,
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}