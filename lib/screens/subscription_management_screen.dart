import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/services/free_tier_service.dart';
import 'package:n3rd_game/services/revenue_cat_service.dart';
import 'package:n3rd_game/services/family_group_service.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/utils/error_handler.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_shadows.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';

class SubscriptionManagementScreen extends StatefulWidget {
  const SubscriptionManagementScreen({super.key});

  @override
  State<SubscriptionManagementScreen> createState() =>
      _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState
    extends State<SubscriptionManagementScreen> {
  bool _isPurchasing = false;
  String? _purchasingTier;

  @override
  void initState() {
    super.initState();
    // Initialize free tier service to show current status
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<FreeTierService>(context, listen: false).init();

      // Log subscription screen viewed
      final analyticsService = Provider.of<AnalyticsService>(
        context,
        listen: false,
      );
      analyticsService.logSubscriptionViewed();
    });
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionService = Provider.of<SubscriptionService>(
      context,
      listen: false,
    );
    final freeTierService = Provider.of<FreeTierService>(
      context,
      listen: false,
    );
    final isFree = subscriptionService.isFree;
    final isPremium = subscriptionService.isPremium;
    final subscriptionTier = subscriptionService.tierName;
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // Background
          Container(
            color: colors.background,
          ),

          // Professional overlay
          SafeArea(
            child: Column(
              children: [
                // Top app bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => NavigationHelper.safePop(context),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Subscriptions',
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
                        // Current subscription status
                        _buildSubscriptionCard(),
                        const SizedBox(height: 24),

                        // Subscription tiers
                        Text(
                          'Available Plans',
                          style: AppTypography.headlineLarge.copyWith(
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Free tier
                        _buildTierCard(
                          context,
                          title: 'Free',
                          price: '\$0',
                          period: 'Forever',
                          features: [
                            'Classic mode only',
                            '5 games per day',
                            'General trivia pool',
                            'No ads',
                            'No editions or online features',
                          ],
                          isCurrent: subscriptionTier == 'Free',
                          isPremium: false,
                          freeTierInfo: isFree ? freeTierService : null,
                          onTap: () {
                            // Already on free tier
                          },
                        ),
                        const SizedBox(height: 12),

                        // Basic tier
                        _buildTierCard(
                          context,
                          title: 'Basic',
                          price: '\$4.99',
                          period: 'per month',
                          features: [
                            'All game modes',
                            'Unlimited play',
                            'Regular trivia database only',
                            'No ads',
                            'Offline play',
                            'No editions or online features',
                          ],
                          isCurrent: subscriptionTier == 'Basic',
                          isPremium: false,
                          onTap: _isPurchasing && _purchasingTier == 'Basic'
                              ? () {} // Disabled during purchase
                              : () {
                                  _showSubscriptionDialog('Basic');
                                },
                        ),
                        const SizedBox(height: 12),

                        // Premium tier
                        _buildTierCard(
                          context,
                          title: 'Premium',
                          price: '\$9.99',
                          period: 'per month',
                          features: [
                            'All Basic features',
                            'All game modes',
                            'All editions & categories',
                            'Online multiplayer',
                            'Daily challenges & leaderboards',
                            'Social features & friends',
                            'Early access to new features',
                          ],
                          isCurrent: subscriptionTier == 'Premium',
                          isPremium: true,
                          highlight: true,
                          onTap: _isPurchasing && _purchasingTier == 'Premium'
                              ? () {} // Disabled during purchase
                              : () {
                                  _showSubscriptionDialog('Premium');
                                },
                        ),
                        const SizedBox(height: 12),

                        // Family & Friends tier
                        _buildTierCard(
                          context,
                          title: 'Family & Friends',
                          price: '\$19.99',
                          period: 'per month',
                          features: [
                            'Up to 4 Premium accounts',
                            'All Premium features for everyone',
                            'Shared progress tracking',
                            'Family leaderboards',
                            'Manage members easily',
                            'Save 50% vs individual Premium',
                          ],
                          isCurrent: subscriptionTier == 'Family & Friends',
                          isPremium: true,
                          highlight: true,
                          onTap: _isPurchasing &&
                                  _purchasingTier == 'Family & Friends'
                              ? () {} // Disabled during purchase
                              : () {
                                  _showSubscriptionDialog('Family & Friends');
                                },
                        ),
                        const SizedBox(height: 24),

                        // Manage subscription section
                        if (isPremium ||
                            subscriptionTier == 'Family & Friends') ...[
                          _buildManageSection(),
                          const SizedBox(height: 24),
                        ],

                        // Family management link (if on Family & Friends plan)
                        if (subscriptionTier == 'Family & Friends') ...[
                          Container(
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
                                  'Manage Family & Friends',
                                  style: AppTypography.headlineLarge.copyWith(
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Invite members, view group status, and manage your Family & Friends plan.',
                                  style: AppTypography.bodyMedium,
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      NavigationHelper.safeNavigate(
                                        context,
                                        '/family-management',
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.success,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14,),
                                    ),
                                    child: const Text('Manage Group'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Restore purchases
                        TextButton(
                          onPressed: () async {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Restoring purchases...'),
                              ),
                            );
                            final revenueCatService =
                                Provider.of<RevenueCatService>(
                              context,
                              listen: false,
                            );
                            await revenueCatService.restorePurchases();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Purchases restored (if any)'),
                                ),
                              );
                            }
                          },
                          child: Text(
                            'Restore Purchases',
                            style: AppTypography.bodyMedium.copyWith(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.8),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
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
  }

  Widget _buildSubscriptionCard() {
    final cardColors = AppColors.of(context);

    // Use Consumer to listen for subscription and free tier changes
    return Consumer2<SubscriptionService, FreeTierService>(
      builder: (context, subscriptionService, freeTierService, _) {
        final isFree = subscriptionService.isFree;
        final isPremium = subscriptionService.isPremium;
        final subscriptionTier = subscriptionService.tierName;

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
                    'Current Plan',
                    style: AppTypography.headlineLarge.copyWith(
                      fontSize: 18,
                      color: AppColors.of(context).primaryText,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isPremium
                          ? AppColors.success.withValues(alpha: 0.2)
                          : cardColors.tertiaryText.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      subscriptionTier,
                      style: AppTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isPremium
                            ? AppColors.success
                            : cardColors.tertiaryText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isFree) ...[
                // Show free tier game limit info
                Text(
                  'Games today: ${freeTierService.gamesStartedToday}/${freeTierService.maxGamesPerDay}',
                  style: AppTypography.bodyMedium.copyWith(
                    color: cardColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 4),
                if (freeTierService.hasGamesRemaining) ...[
                  Text(
                    'Games remaining: ${freeTierService.gamesRemaining}',
                    style: AppTypography.bodyMedium.copyWith(
                      fontSize: 13,
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Resets: ${freeTierService.getNextResetString()}',
                    style: AppTypography.labelSmall.copyWith(
                      color: cardColors.secondaryText,
                    ),
                  ),
                ] else ...[
                  Text(
                    'Daily limit reached. Resets: ${freeTierService.getNextResetString()}',
                    style: AppTypography.bodyMedium.copyWith(
                      fontSize: 13,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ] else ...[
                Text(
                  'Active subscription',
                  style: AppTypography.bodyMedium.copyWith(
                    color: cardColors.secondaryText,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTierCard(
    BuildContext context, {
    required String title,
    required String price,
    required String period,
    required List<String> features,
    required bool isCurrent,
    required bool isPremium,
    bool highlight = false,
    FreeTierService? freeTierInfo,
    required VoidCallback onTap,
  }) {
    final tierColors = AppColors.of(context);
    return InkWell(
      onTap: isCurrent ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppShadows.medium,
          // No border - removed
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: AppTypography.headlineLarge.copyWith(
                    fontSize: 22,
                    color: tierColors.primaryText,
                  ),
                ),
                if (highlight)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'BEST VALUE',
                      style: AppTypography.labelSmall.copyWith(
                        fontSize: 10,
                        color: AppColors.success,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: AppTypography.displayMedium.copyWith(
                    fontSize: 28,
                    color: tierColors.primaryText,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    period,
                    style: AppTypography.bodyMedium.copyWith(
                      color: tierColors.secondaryText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...features.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 18,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature,
                        style: AppTypography.bodyMedium.copyWith(
                          color: tierColors.secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (isCurrent)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: tierColors.tertiaryText.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Current Plan',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tierColors.tertiaryText,
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPremium
                        ? AppColors.success
                        : tierColors.primaryButton,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('Subscribe', style: AppTypography.labelLarge),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildManageSection() {
    final manageColors = AppColors.of(context);
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
            'Manage Subscription',
            style: AppTypography.headlineLarge.copyWith(
              fontSize: 18,
              color: manageColors.primaryText,
            ),
          ),
          const SizedBox(height: 16),
          _buildManageOption(
            context,
            icon: Icons.cancel_outlined,
            title: 'Cancel Subscription',
            subtitle:
                'Your subscription will remain active until the end of the billing period',
            onTap: () {
              _showCancelDialog();
            },
          ),
          const Divider(height: 32),
          _buildManageOption(
            context,
            icon: Icons.payment_outlined,
            title: 'Update Payment Method',
            subtitle: 'Change your payment information',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Payment method update coming soon'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildManageOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final optionColors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: optionColors.primaryText, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: optionColors.primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTypography.bodyMedium.copyWith(
                    fontSize: 13,
                    color: optionColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: optionColors.tertiaryText,
          ),
        ],
      ),
    );
  }

  void _showSubscriptionDialog(String tier) {
    final analyticsService = Provider.of<AnalyticsService>(
      context,
      listen: false,
    );

    // Log tier selected
    analyticsService.logSubscriptionTierSelected(tier.toLowerCase());
    analyticsService.logConversionFunnelStep(
      step: 4,
      stepName: 'tier_selected',
      source: 'subscription_screen',
      targetTier: tier.toLowerCase(),
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Subscribe to $tier',
          style: AppTypography.headlineLarge.copyWith(fontSize: 20),
        ),
        content: Text(
          'This will redirect you to complete your purchase through the App Store.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: Text('Cancel', style: AppTypography.bodyMedium),
          ),
          ElevatedButton(
            onPressed: () async {
              if (context.mounted) {
                Navigator.pop(context);
              }
              if (!context.mounted) return;
              final revenueCatService = Provider.of<RevenueCatService>(
                context,
                listen: false,
              );
              try {
                // Capture BuildContext-dependent objects before ANY async operations
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                final packages = await revenueCatService.getAvailablePackages();

                if (packages.isEmpty) {
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'No subscription packages available. Please try again later.',
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                  return;
                }

                Package? targetPackage;
                if (tier.toLowerCase().contains('family') ||
                    tier.toLowerCase().contains('friends')) {
                  targetPackage = packages.firstWhere(
                    (p) =>
                        p.identifier.contains('family') ||
                        p.identifier.contains('friends'),
                    orElse: () => packages.first,
                  );
                } else if (tier.toLowerCase().contains('basic')) {
                  targetPackage = packages.firstWhere(
                    (p) => p.identifier.contains('basic'),
                    orElse: () => packages.first,
                  );
                } else if (tier.toLowerCase().contains('premium')) {
                  targetPackage = packages.firstWhere(
                    (p) => p.identifier.contains('premium'),
                    orElse: () => packages.first,
                  );
                } else if (packages.isNotEmpty) {
                  targetPackage = packages.first;
                }

                if (targetPackage != null) {
                  // Capture BuildContext-dependent objects before ANY async operations
                  // Note: These are captured before async, but we still need to check context.mounted
                  // when using context after async operations

                  // Set loading state
                  if (mounted) {
                    setState(() {
                      _isPurchasing = true;
                      _purchasingTier = tier;
                    });
                  }

                  // Capture services after checking mounted, but before async operations
                  if (!context.mounted) return;
                  final analyticsService = Provider.of<AnalyticsService>(
                    context,
                    listen: false,
                  );
                  final subscriptionService = Provider.of<SubscriptionService>(
                    context,
                    listen: false,
                  );

                  // Log funnel step 5: Purchase initiated
                  await analyticsService.logConversionFunnelStep(
                    step: 5,
                    stepName: 'purchase_initiated',
                    source: 'subscription_screen',
                    targetTier: tier.toLowerCase(),
                    additionalData: {'package_id': targetPackage.identifier},
                  );

                  // Log purchase attempt (no context needed, already captured)
                  await analyticsService.logPurchaseAttempt(
                    tier,
                    targetPackage.identifier,
                  );

                  try {
                    final success = await revenueCatService.purchasePackage(
                      targetPackage,
                    );

                    // Log funnel step 6: Purchase completed
                    await analyticsService.logConversionFunnelStep(
                      step: 6,
                      stepName:
                          success ? 'purchase_completed' : 'purchase_failed',
                      source: 'subscription_screen',
                      targetTier: tier.toLowerCase(),
                      additionalData: {
                        'package_id': targetPackage.identifier,
                        'success': success,
                      },
                    );

                    // Log purchase result
                    await analyticsService.logPurchase(
                      tier,
                      targetPackage.identifier,
                      success,
                    );

                    if (success) {
                      // Sync subscription service after successful purchase
                      await subscriptionService
                          .init(); // Reload from RevenueCat/Firestore

                      // If Family & Friends plan, create or initialize group
                      if (tier.toLowerCase().contains('family') ||
                          tier.toLowerCase().contains('friends')) {
                        try {
                          if (!context.mounted) return;
                          final familyService = Provider.of<FamilyGroupService>(
                            context,
                            listen: false,
                          );
                          if (!familyService.isInGroup) {
                            await familyService.createFamilyGroup();
                            // Log analytics
                            await analyticsService.logFamilyGroupEvent(
                              'family_group_created',
                              {
                                'group_id': familyService.currentGroup?.id,
                              },
                            );
                          }
                        } catch (e) {
                          // Log but don't fail - group creation can happen later
                          if (kDebugMode) {
                            debugPrint(
                              'Failed to create family group after purchase: $e',
                            );
                          }
                        }
                      }

                      // Check context.mounted directly (not State.mounted)
                      if (!context.mounted) return;

                      final successMessage = tier
                                  .toLowerCase()
                                  .contains('family') ||
                              tier.toLowerCase().contains('friends')
                          ? 'Family & Friends plan purchased! You can now invite up to 3 more members.'
                          : 'Subscription purchased successfully! Premium features are now available.';

                      ErrorHandler.showSuccess(context, successMessage);
                    } else {
                      // Check context.mounted directly (not State.mounted)
                      if (!context.mounted) return;

                      ErrorHandler.showSnackBar(
                        context,
                        'Purchase cancelled or failed. Please try again.',
                      );
                    }
                  } catch (e) {
                    // Check context.mounted directly (not State.mounted)
                    if (context.mounted) {
                      await analyticsService.logError(
                        'purchase_error',
                        e.toString(),
                      );

                      // Check context.mounted again after async operation
                      if (!context.mounted) return;

                      ErrorHandler.showError(
                        context,
                        'An error occurred during purchase: ${e.toString()}',
                        title: 'Purchase Error',
                        onRetry: () => _showSubscriptionDialog(tier),
                      );
                    }
                  } finally {
                    if (mounted) {
                      setState(() {
                        _isPurchasing = false;
                        _purchasingTier = null;
                      });
                    }
                  }
                } else {
                  if (context.mounted) {
                    ErrorHandler.showSnackBar(
                      context,
                      'No subscription packages available. Please try again later.',
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error purchasing subscription: $e'),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.of(context).primaryButton,
            ),
            child: Text(
              'Continue',
              style: AppTypography.inter(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Cancel Subscription',
          style: AppTypography.headlineLarge.copyWith(fontSize: 20),
        ),
        content: Text(
          'Are you sure you want to cancel your subscription? You will lose access to Premium features at the end of your billing period.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: Text('Keep Subscription', style: AppTypography.bodyMedium),
          ),
          TextButton(
            onPressed: () async {
              if (context.mounted) {
                Navigator.pop(context);
              }
              if (!context.mounted) return;
              // Note: RevenueCat doesn't provide a direct cancellation method
              // Users must cancel through App Store (iOS) or Play Store (Android)
              // We can show instructions to the user
              if (context.mounted) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(
                      'Cancel Subscription',
                      style: AppTypography.headlineLarge,
                    ),
                    content: Text(
                      'To cancel your subscription:\n\n'
                      'iOS: Settings > [Your Name] > Subscriptions > N3RD Trivia > Cancel Subscription\n\n'
                      'Android: Play Store > Subscriptions > N3RD Trivia > Cancel\n\n'
                      'You will retain access until the end of your current billing period.',
                      style: AppTypography.bodyMedium,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                        child: Text('Got it', style: AppTypography.bodyMedium),
                      ),
                    ],
                  ),
                );
              }
            },
            child: Text(
              'Cancel Subscription',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
