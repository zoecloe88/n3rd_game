import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/screens/youth_transition_screen.dart';
import 'package:n3rd_game/screens/ai_edition_input_screen.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/theme/app_radius.dart';
import 'package:n3rd_game/theme/app_shadows.dart';
import 'package:n3rd_game/widgets/video_background_widget.dart';
import 'package:n3rd_game/models/edition_model.dart';
import 'package:n3rd_game/data/editions_catalog.dart';
import 'package:n3rd_game/services/edition_access_service.dart';
import 'package:n3rd_game/services/revenue_cat_service.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/utils/error_handler.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class EditionsScreen extends StatefulWidget {
  const EditionsScreen({super.key});

  @override
  State<EditionsScreen> createState() => _EditionsScreenState();
}

class _EditionsScreenState extends State<EditionsScreen> {
  String _selectedCategory = 'All';
  late final List<String> _categories;
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _categories = [
      'All',
      ...{for (final edition in editionsCatalog) edition.category},
    ];
  }

  @override
  Widget build(BuildContext context) {
    // RouteGuard handles subscription checking at route level
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: VideoBackgroundWidget(
        videoPath: 'assets/edition.mp4',
        fit: BoxFit.cover,
        alignment: Alignment.topCenter, // Characters/logos in upper portion
        loop: true,
        autoplay: true,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context),
                const SizedBox(height: AppSpacing.md),
                _buildCategoryFilter(),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(AppRadius.xLarge),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      boxShadow: AppShadows.large,
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    child: _buildEditionsGrid(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => NavigationHelper.safePop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            const Spacer(),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'EDITIONS',
          style: AppTypography.playfairDisplay(
            fontSize: 46,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF5F3ABB),
            letterSpacing: 6,
          ).copyWith(
            shadows: [
              Shadow(
                offset: const Offset(3, 3),
                color: Colors.black.withValues(alpha: 0.25),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Choose your specialized trivia collection',
          style: AppTypography.inter(
            fontSize: 15,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryFilter() {
    final filterColors = AppColors.of(context);
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilterChip(
              label: Text(
                category,
                style: AppTypography.labelSmall.copyWith(
                  color: isSelected ? filterColors.onDarkText : Colors.white,
                ),
              ),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  _selectedCategory = category;
                });
              },
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              selectedColor: filterColors.primaryButton,
              side: BorderSide(
                color: isSelected
                    ? filterColors.primaryButton
                    : Colors.white.withValues(alpha: 0.2),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEditionsGrid() {
    final editions = _getFilteredEditions();
    return Consumer<EditionAccessService>(
      builder: (context, accessService, _) {
        return GridView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(top: AppSpacing.md, bottom: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio: 0.72,
          ),
          itemCount: editions.length,
          itemBuilder: (context, index) =>
              _buildEditionCard(editions[index], accessService),
        );
      },
    );
  }

  Widget _buildEditionCard(
    EditionModel edition,
    EditionAccessService accessService,
  ) {
    final hasAccess = accessService.hasAccess(edition);
    final cardColors = AppColors.of(context);
    return GestureDetector(
      onTap: () {
        if (hasAccess) {
          _onEditionTapped(edition);
        } else {
          _showAccessSheet(edition, accessService);
        }
      },
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: cardColors.cardBackground.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(AppRadius.large),
              border: Border.all(color: const Color(0xFF6B4FC9), width: 2),
              boxShadow: AppShadows.medium,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: edition.gradientColors,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(AppRadius.large - 4),
                        topRight: Radius.circular(AppRadius.large - 4),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        edition.emoji,
                        style: const TextStyle(fontSize: 56),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          edition.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleLarge.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: cardColors.primaryText,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            Text(
                              edition.category,
                              style: AppTypography.labelSmall.copyWith(
                                fontSize: 11,
                                color: cardColors.secondaryText,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              edition.categoryCount,
                              style: AppTypography.bodyMedium.copyWith(
                                fontSize: 12,
                                color: cardColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!hasAccess)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppRadius.large),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock, color: Colors.white, size: 28),
                    const SizedBox(height: 8),
                    Text(
                      'Locked',
                      style: AppTypography.labelLarge.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<EditionModel> _getFilteredEditions() {
    final allEditions = editionsCatalog.toList();
    if (allEditions.isEmpty) return [];

    // AI Edition should always be first
    final aiEdition = allEditions.firstWhere(
      (e) => e.id == 'ai_edition',
      orElse: () => allEditions.first,
    );
    final otherEditions =
        allEditions.where((e) => e.id != 'ai_edition').toList();

    final sorted = [aiEdition, ...otherEditions];

    if (_selectedCategory == 'All') return sorted;
    return sorted
        .where((edition) => edition.category == _selectedCategory)
        .toList();
  }

  void _onEditionTapped(EditionModel edition) {
    // Handle AI Edition specially
    if (edition.id == 'ai_edition') {
      NavigationHelper.safePush(
        context,
        MaterialPageRoute(
          builder: (_) => const AIEditionInputScreen(isYouthEdition: false),
        ),
      );
      return;
    }

    // Navigate to transition screen, then to game with edition info
    NavigationHelper.safePush(
      context,
      MaterialPageRoute(
        builder: (_) => YouthTransitionScreen(
          onFinished: () {
            if (!context.mounted) return;
            NavigationHelper.safePop(context); // Pop transition screen
            // Navigate to game screen with edition info
            // Note: Editions will use their own content system (not trivia generator)
            // For now, pass edition info - content system will be implemented separately
            if (!context.mounted) return;
            NavigationHelper.safeNavigate(
              context,
              '/game',
              arguments: {
                'mode': null, // Editions may have their own modes
                'edition': edition.id,
                'editionName': edition.name,
                // triviaPool will be null - editions need their own content system
              },
            );
          },
        ),
      ),
    );
  }

  void _showAccessSheet(
    EditionModel edition,
    EditionAccessService accessService,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    final sheetColors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: sheetColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.large),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                edition.name,
                style: AppTypography.headlineLarge.copyWith(
                  color: sheetColors.primaryText,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Editions are part of the Premium tier. Get all 100 editions plus online multiplayer.',
                style: AppTypography.bodyMedium.copyWith(
                  color: sheetColors.secondaryText,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Consumer<RevenueCatService>(
                builder: (context, revenueCat, _) {
                  return FutureBuilder<List<Package>>(
                    future: revenueCat.getAvailablePackages(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        // Fallback to simulated purchase if RevenueCat not available
                        return ElevatedButton.icon(
                          onPressed: () async {
                            await accessService.unlockAllAccess();
                            if (!mounted) return;
                            final navigatorContext = context;
                            if (!navigatorContext.mounted) return;
                            NavigationHelper.safePop(navigatorContext);
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Premium tier unlocked - All editions + online play',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.workspace_premium),
                          label: const Text('Premium Tier (\$4.99 / month)'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 52),
                            backgroundColor: sheetColors.primaryButton,
                            foregroundColor: sheetColors.onDarkText,
                          ),
                        );
                      }

                      // Find premium package
                      if (snapshot.data!.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.orange,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No subscription packages available',
                                style: AppTypography.bodyLarge,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      final premiumPackage = snapshot.data!.firstWhere(
                        (pkg) =>
                            pkg.storeProduct.identifier.contains('premium'),
                        orElse: () => snapshot.data!.first,
                      );

                      return ElevatedButton.icon(
                        onPressed: _isPurchasing
                            ? null
                            : () async {
                                // Set loading state
                                if (mounted) {
                                  setState(() => _isPurchasing = true);
                                }

                                // Show loading message
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Row(
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text('Processing purchase...'),
                                      ],
                                    ),
                                    duration: Duration(
                                      seconds: 30,
                                    ), // Long duration for purchase
                                  ),
                                );

                                // Capture BuildContext-dependent objects before async operations
                                final subscriptionService =
                                    Provider.of<SubscriptionService>(
                                  context,
                                  listen: false,
                                );
                                final analyticsService =
                                    Provider.of<AnalyticsService>(
                                  context,
                                  listen: false,
                                );

                                // Log purchase attempt
                                await analyticsService.logPurchaseAttempt(
                                  'premium',
                                  premiumPackage.identifier,
                                );

                                try {
                                  final success = await revenueCat
                                      .purchasePackage(premiumPackage);
                                  if (!mounted) return;

                                  // Hide loading snackbar
                                  messenger.hideCurrentSnackBar();
                                  if (!context.mounted) return;
                                  NavigationHelper.safePop(context);

                                  // Log purchase result
                                  await analyticsService.logPurchase(
                                    'premium',
                                    premiumPackage.identifier,
                                    success,
                                  );

                                  if (success) {
                                    // Sync subscription service after successful purchase
                                    await subscriptionService
                                        .init(); // Reload from RevenueCat/Firestore

                                    // Check context.mounted directly (not State.mounted)
                                    if (!context.mounted) return;

                                    ErrorHandler.showSuccess(
                                      context,
                                      'Premium tier unlocked - All editions + online play',
                                    );
                                  } else {
                                    // Check context.mounted directly (not State.mounted)
                                    if (!context.mounted) return;

                                    ErrorHandler.showSnackBar(
                                      context,
                                      'Purchase cancelled or failed. Please try again.',
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    messenger.hideCurrentSnackBar();
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
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() => _isPurchasing = false);
                                  }
                                }
                              },
                        icon: _isPurchasing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.workspace_premium),
                        label: Text(
                          'Premium Tier (${premiumPackage.storeProduct.priceString} / month)',
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                          backgroundColor: sheetColors.primaryButton,
                          foregroundColor: sheetColors.onDarkText,
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Includes: All 100 editions + Online multiplayer',
                style: AppTypography.labelSmall.copyWith(
                  color: sheetColors.secondaryText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => NavigationHelper.safePop(context),
                child: const Center(child: Text('Maybe Later')),
              ),
            ],
          ),
        );
      },
    );
  }
}
