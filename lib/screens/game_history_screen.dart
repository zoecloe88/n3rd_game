import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:n3rd_game/services/game_history_service.dart';
import 'package:n3rd_game/models/game_mode_config.dart';
import 'package:n3rd_game/models/game_history_entry.dart';
import 'package:n3rd_game/widgets/video_background_widget.dart';
import 'package:n3rd_game/widgets/empty_state_widget.dart';
import 'package:n3rd_game/widgets/standardized_loading_widget.dart';
import 'package:n3rd_game/widgets/error_recovery_widget.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_radius.dart';
import 'package:n3rd_game/widgets/app_button.dart';
import 'package:n3rd_game/widgets/app_text_field.dart';
import 'package:n3rd_game/widgets/app_card.dart';
import 'package:n3rd_game/utils/feedback_helper.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/utils/provider_helper.dart';
import 'package:n3rd_game/utils/error_handler.dart';
import 'package:n3rd_game/utils/game_mode_extensions.dart';
import 'package:intl/intl.dart';

class GameHistoryScreen extends StatefulWidget {
  const GameHistoryScreen({super.key});

  @override
  State<GameHistoryScreen> createState() => _GameHistoryScreenState();
}

class _GameHistoryScreenState extends State<GameHistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _minScoreController = TextEditingController();
  final TextEditingController _maxScoreController = TextEditingController();

  List<GameHistoryEntry> _games = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;

  // Filters
  GameMode? _selectedMode;
  DateTime? _startDate;
  DateTime? _endDate;
  int? _minScore;
  int? _maxScore;

  @override
  void initState() {
    super.initState();
    _loadGames();
    _scrollController.addListener(_onScroll);
    // Initialize controllers with current values
    _minScoreController.text = _minScore?.toString() ?? '';
    _maxScoreController.text = _maxScore?.toString() ?? '';
    // Add listeners to update state
    _minScoreController.addListener(_onMinScoreChanged);
    _maxScoreController.addListener(_onMaxScoreChanged);
  }

  void _onMinScoreChanged() {
    final value = _minScoreController.text;
    setState(() {
      if (value.isEmpty) {
        _minScore = null;
      } else {
        final parsed = int.tryParse(value);
        // Validate: must be >= 0
        _minScore = (parsed != null && parsed >= 0) ? parsed : null;
      }
    });
  }

  void _onMaxScoreChanged() {
    final value = _maxScoreController.text;
    setState(() {
      if (value.isEmpty) {
        _maxScore = null;
      } else {
        final parsed = int.tryParse(value);
        // Validate: must be >= 0
        _maxScore = (parsed != null && parsed >= 0) ? parsed : null;
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _minScoreController.dispose();
    _maxScoreController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_loadingMore &&
        _hasMore) {
      _loadMoreGames();
    }
  }

  Future<void> _loadGames({bool refresh = false}) async {
    if (!mounted) return;

    setState(() {
      _loading = refresh || _games.isEmpty;
      _error = null;
      if (refresh) {
        _lastDocument = null;
        _hasMore = true;
        _games = [];
      }
    });

    try {
      final service = ProviderHelper.safeGetOrThrow<GameHistoryService>(context, listen: false);
      final games = await service.getGameHistory(
        limit: 20,
        startAfter: _lastDocument,
        mode: _selectedMode,
        startDate: _startDate,
        endDate: _endDate,
        minScore: _minScore,
        maxScore: _maxScore,
      );

      if (!mounted) return;

      setState(() {
        if (refresh) {
          _games = games;
        } else {
          _games.addAll(games);
        }
        _hasMore = games.length >= 20;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorHandler.getLocalizedErrorMessage(e, context);
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _loadMoreGames() async {
    if (_loadingMore || !_hasMore) return;

    setState(() {
      _loadingMore = true;
    });

    await _loadGames();
  }

  Future<void> _refreshGames() async {
    await _loadGames(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      body: VideoBackgroundWidget(
        videoPath: 'assets/statscreen.mp4',
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        loop: true,
        autoplay: true,
        child: SafeArea(
          child: Column(
            children: [
              // Minimal header (just back button)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    AppButton(
                      icon: Icons.arrow_back,
                      onPressed: () => NavigationHelper.safePop(context),
                      variant: AppButtonVariant.icon,
                      backgroundColor: Colors.transparent,
                      foregroundColor: colors.onDarkText,
                    ),
                    const Spacer(),
                    // Sync status indicator
                    Consumer<GameHistoryService>(
                      builder: (context, service, _) {
                        final queueSize = service.retryQueueSize;
                        if (queueSize > 0) {
                          return Row(
                            children: [
                              Icon(
                                Icons.sync_problem,
                                color: colors.warning,
                                size: 20,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                '$queueSize pending',
                                style: AppTypography.labelSmall.copyWith(
                                  color: colors.warning,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                            ],
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    AppButton(
                      icon: Icons.filter_list,
                      onPressed: _showFilters,
                      variant: AppButtonVariant.icon,
                      backgroundColor: Colors.transparent,
                      foregroundColor: colors.onDarkText,
                      semanticsLabel: 'Filters',
                    ),
                  ],
                ),
              ),

              // Filters bar (if any filters are active)
              if (_hasActiveFilters()) _buildActiveFilters(),

              // Content
              Expanded(
                child: _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _hasActiveFilters() {
    return _selectedMode != null ||
        _startDate != null ||
        _endDate != null ||
        _minScore != null ||
        _maxScore != null;
  }

  Widget _buildActiveFilters() {
    return Builder(
      builder: (context) {
        final colors = AppColors.of(context);
        return Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.sm,),
          color: AppColors.overlayDark.withValues(alpha: 0.3),
          child: Row(
            children: [
              Text(
                'Filters:',
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onDarkText,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    if (_selectedMode != null)
                      Chip(
                        label: Text(
                          _selectedMode!.displayName,
                          style: AppTypography.labelSmall,
                        ),
                        onDeleted: () {
                          setState(() {
                            _selectedMode = null;
                          });
                          _refreshGames();
                        },
                        backgroundColor:
                            colors.onDarkText.withValues(alpha: 0.2),
                        deleteIconColor: colors.onDarkText,
                      ),
                    if (_startDate != null || _endDate != null)
                      Chip(
                        label: Text(
                          _formatDateRange(),
                          style: AppTypography.labelSmall,
                        ),
                        onDeleted: () {
                          setState(() {
                            _startDate = null;
                            _endDate = null;
                          });
                          _refreshGames();
                        },
                        backgroundColor:
                            colors.onDarkText.withValues(alpha: 0.2),
                        deleteIconColor: colors.onDarkText,
                      ),
                    if (_minScore != null || _maxScore != null)
                      Chip(
                        label: Text(
                          _formatScoreRange(),
                          style: AppTypography.labelSmall,
                        ),
                        onDeleted: () {
                          setState(() {
                            _minScore = null;
                            _maxScore = null;
                          });
                          _refreshGames();
                        },
                        backgroundColor:
                            colors.onDarkText.withValues(alpha: 0.2),
                        deleteIconColor: colors.onDarkText,
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

  String _formatDateRange() {
    if (_startDate != null && _endDate != null) {
      return '${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('MMM d').format(_endDate!)}';
    } else if (_startDate != null) {
      return 'After ${DateFormat('MMM d').format(_startDate!)}';
    } else if (_endDate != null) {
      return 'Before ${DateFormat('MMM d').format(_endDate!)}';
    }
    return '';
  }

  String _formatScoreRange() {
    if (_minScore != null && _maxScore != null) {
      return '$_minScore - $_maxScore';
    } else if (_minScore != null) {
      return 'Min: $_minScore';
    } else if (_maxScore != null) {
      return 'Max: $_maxScore';
    }
    return '';
  }

  Widget _buildContent() {
    if (_loading && _games.isEmpty) {
      return const StandardizedLoadingWidget(
          message: 'Loading game history...',);
    }

    if (_error != null && _games.isEmpty) {
      return ErrorRecoveryWidget(
        errorMessage: _error!,
        onRetry: _refreshGames,
      );
    }

    if (_games.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.history,
        title: 'No Game History',
        description: _hasActiveFilters()
            ? 'No games match your current filters. Try adjusting your filters.'
            : 'You haven\'t played any games yet. Start playing to see your history here!',
        actionLabel: _hasActiveFilters() ? 'Clear Filters' : null,
        onAction: _hasActiveFilters()
            ? () {
                setState(() {
                  _selectedMode = null;
                  _startDate = null;
                  _endDate = null;
                  _minScore = null;
                  _maxScore = null;
                });
                _refreshGames();
              }
            : null,
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshGames,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: _games.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _games.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: CircularProgressIndicator(),
              ),
            );
          }

          return _buildGameCard(_games[index]);
        },
      ),
    );
  }

  Widget _buildGameCard(GameHistoryEntry game) {
    return Builder(
      builder: (context) {
        final colors = AppColors.of(context);
        final dateFormat = DateFormat('MMM d, y • h:mm a');

        return AppCard.filled(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          backgroundColor: AppColors.overlayDark.withValues(alpha: 0.6),
          onTap: () => _showGameDetails(game),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        game.mode.displayName.toUpperCase(),
                        style: AppTypography.titleLarge.copyWith(
                          color: colors.onDarkText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      dateFormat.format(game.completedAt),
                      style: AppTypography.labelSmall.copyWith(
                        color: colors.onDarkText.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    _buildStatChip(
                        context, 'Score', game.score.toString(), Icons.star,),
                    const SizedBox(width: AppSpacing.sm),
                    _buildStatChip(context, 'Rounds', game.rounds.toString(),
                        Icons.repeat,),
                    const SizedBox(width: AppSpacing.sm),
                    _buildStatChip(
                      context,
                      'Accuracy',
                      '${game.accuracy.toStringAsFixed(1)}%',
                      Icons.check_circle,
                    ),
                  ],
                ),
                if (game.durationSeconds > 0) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Duration: ${_formatDuration(game.durationSeconds)}',
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.onDarkText.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatChip(
      BuildContext context, String label, String value, IconData icon,) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs,),
      decoration: BoxDecoration(
        color: colors.onDarkText.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.onDarkText.withValues(alpha: 0.7)),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$label: $value',
            style: AppTypography.labelSmall.copyWith(
              color: colors.onDarkText,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${remainingSeconds}s';
    }
    return '${remainingSeconds}s';
  }

  void _showGameDetails(GameHistoryEntry game) {
    final colors = AppColors.of(context);
    FeedbackHelper.showBottomSheet(
      context,
      isScrollControlled: true,
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Game Details',
                    style: AppTypography.headlineMedium.copyWith(
                      color: colors.onDarkText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  AppButton(
                    icon: Icons.close,
                    onPressed: () => NavigationHelper.safePop(context),
                    variant: AppButtonVariant.icon,
                    backgroundColor: Colors.transparent,
                    foregroundColor: colors.onDarkText,
                  ),
                ],
              ),
              Divider(color: colors.onDarkText.withValues(alpha: 0.24)),
              _buildDetailRow('Mode', game.mode.displayName),
              if (game.difficulty != null)
                _buildDetailRow('Difficulty', game.difficulty!),
              _buildDetailRow('Score', game.score.toString()),
              _buildDetailRow('Rounds', game.rounds.toString()),
              _buildDetailRow(
                  'Correct Answers', game.correctAnswers.toString(),),
              _buildDetailRow('Wrong Answers', game.wrongAnswers.toString()),
              _buildDetailRow(
                  'Accuracy', '${game.accuracy.toStringAsFixed(1)}%',),
              if (game.perfectStreak > 0)
                _buildDetailRow(
                    'Perfect Streak', game.perfectStreak.toString(),),
              if (game.livesRemaining > 0)
                _buildDetailRow(
                    'Lives Remaining', game.livesRemaining.toString(),),
              _buildDetailRow(
                  'Duration', _formatDuration(game.durationSeconds),),
              _buildDetailRow(
                'Completed',
                DateFormat('MMM d, y • h:mm a').format(game.completedAt),
              ),
              if (game.triviaCategories.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Categories',
                  style: AppTypography.titleLarge.copyWith(
                    color: colors.onDarkText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: game.triviaCategories
                      .map(
                        (cat) => Chip(
                          label: Text(cat, style: AppTypography.labelSmall),
                          backgroundColor:
                              colors.onDarkText.withValues(alpha: 0.1),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Builder(
      builder: (context) {
        final colors = AppColors.of(context);
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: AppTypography.bodyMedium.copyWith(
                  color: colors.onDarkText.withValues(alpha: 0.7),
                ),
              ),
              Text(
                value,
                style: AppTypography.bodyMedium.copyWith(
                  color: colors.onDarkText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFilters() {
    final colors = AppColors.of(context);
    FeedbackHelper.showBottomSheet(
      context,
      isScrollControlled: true,
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filters',
                    style: AppTypography.headlineMedium.copyWith(
                      color: colors.onDarkText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  AppButton(
                    icon: Icons.close,
                    onPressed: () => NavigationHelper.safePop(context),
                    variant: AppButtonVariant.icon,
                    backgroundColor: Colors.transparent,
                    foregroundColor: colors.onDarkText,
                  ),
                ],
              ),
              Divider(color: colors.onDarkText.withValues(alpha: 0.24)),
              const SizedBox(height: AppSpacing.md),
              _buildModeFilter(),
              const SizedBox(height: AppSpacing.md),
              _buildDateRangeFilter(),
              const SizedBox(height: AppSpacing.md),
              _buildScoreRangeFilter(),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      variant: AppButtonVariant.secondary,
                      label: 'Clear All',
                      onPressed: () {
                        setState(() {
                          _selectedMode = null;
                          _startDate = null;
                          _endDate = null;
                          _minScore = null;
                          _maxScore = null;
                        });
                        NavigationHelper.safePop(context);
                        _refreshGames();
                      },
                      foregroundColor: colors.onDarkText,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton(
                      variant: AppButtonVariant.primary,
                      label: 'Apply',
                      onPressed: () {
                        NavigationHelper.safePop(context);
                        _refreshGames();
                      },
                      backgroundColor: AppColors.overlayDark,
                      foregroundColor: colors.onDarkText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeFilter() {
    return Builder(
      builder: (context) {
        final colors = AppColors.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Game Mode',
              style:
                  AppTypography.titleLarge.copyWith(color: colors.onDarkText),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: GameMode.values.map((mode) {
                final isSelected = _selectedMode == mode;
                return FilterChip(
                  label: Text(mode.displayName),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedMode = selected ? mode : null;
                    });
                  },
                  selectedColor: colors.onDarkText.withValues(alpha: 0.3),
                  checkmarkColor: colors.onDarkText,
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateRangeFilter() {
    return Builder(
      builder: (context) {
        final colors = AppColors.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Date Range',
              style:
                  AppTypography.titleLarge.copyWith(color: colors.onDarkText),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    variant: AppButtonVariant.secondary,
                    label: _startDate == null
                        ? 'Start Date'
                        : DateFormat('MMM d, y').format(_startDate!),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() {
                          _startDate = date;
                        });
                      }
                    },
                    foregroundColor: colors.onDarkText,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    variant: AppButtonVariant.secondary,
                    label: _endDate == null
                        ? 'End Date'
                        : DateFormat('MMM d, y').format(_endDate!),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() {
                          _endDate = date;
                        });
                      }
                    },
                    foregroundColor: colors.onDarkText,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildScoreRangeFilter() {
    return Builder(
      builder: (context) {
        final colors = AppColors.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Score Range',
              style:
                  AppTypography.titleLarge.copyWith(color: colors.onDarkText),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _minScoreController,
                    label: 'Min Score',
                    leadingIcon: Icons.trending_up,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppTextField(
                    controller: _maxScoreController,
                    label: 'Max Score',
                    leadingIcon: Icons.trending_down,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
