import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:n3rd_game/services/game_history_service.dart';
import 'package:n3rd_game/services/game_service.dart';
import 'package:n3rd_game/models/game_history_entry.dart';
import 'package:n3rd_game/widgets/video_background_widget.dart';
import 'package:n3rd_game/widgets/empty_state_widget.dart';
import 'package:n3rd_game/widgets/standardized_loading_widget.dart';
import 'package:n3rd_game/widgets/error_recovery_widget.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:intl/intl.dart';

class GameHistoryScreen extends StatefulWidget {
  const GameHistoryScreen({super.key});

  @override
  State<GameHistoryScreen> createState() => _GameHistoryScreenState();
}

class _GameHistoryScreenState extends State<GameHistoryScreen> {
  final ScrollController _scrollController = ScrollController();
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
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
      final service = Provider.of<GameHistoryService>(context, listen: false);
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
        _error = e.toString();
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
                    IconButton(
                      onPressed: () => NavigationHelper.safePop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _showFilters,
                      icon: const Icon(Icons.filter_list, color: Colors.white),
                      tooltip: 'Filters',
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      color: Colors.black.withValues(alpha: 0.3),
      child: Row(
        children: [
          const Text(
            'Filters:',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Wrap(
              spacing: AppSpacing.sm,
              children: [
                if (_selectedMode != null)
                  Chip(
                    label: Text(
                      _selectedMode!.toString().split('.').last,
                      style: const TextStyle(fontSize: 11),
                    ),
                    onDeleted: () {
                      setState(() {
                        _selectedMode = null;
                      });
                      _refreshGames();
                    },
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    deleteIconColor: Colors.white,
                  ),
                if (_startDate != null || _endDate != null)
                  Chip(
                    label: Text(
                      _formatDateRange(),
                      style: const TextStyle(fontSize: 11),
                    ),
                    onDeleted: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                      });
                      _refreshGames();
                    },
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    deleteIconColor: Colors.white,
                  ),
                if (_minScore != null || _maxScore != null)
                  Chip(
                    label: Text(
                      _formatScoreRange(),
                      style: const TextStyle(fontSize: 11),
                    ),
                    onDeleted: () {
                      setState(() {
                        _minScore = null;
                        _maxScore = null;
                      });
                      _refreshGames();
                    },
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    deleteIconColor: Colors.white,
                  ),
              ],
            ),
          ),
        ],
      ),
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
      return const StandardizedLoadingWidget(message: 'Loading game history...');
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
    final dateFormat = DateFormat('MMM d, y • h:mm a');

    return Card(
      color: Colors.black.withValues(alpha: 0.6),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
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
                      game.mode.toString().split('.').last.toUpperCase(),
                      style: AppTypography.titleLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    dateFormat.format(game.completedAt),
                    style: AppTypography.labelSmall.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  _buildStatChip('Score', game.score.toString(), Icons.star),
                  const SizedBox(width: AppSpacing.sm),
                  _buildStatChip('Rounds', game.rounds.toString(), Icons.repeat),
                  const SizedBox(width: AppSpacing.sm),
                  _buildStatChip(
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
                    color: Colors.white70,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 4),
          Text(
            '$label: $value',
            style: AppTypography.labelSmall.copyWith(
              color: Colors.white,
              fontSize: 11,
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
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
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
              const Divider(color: Colors.white24),
              _buildDetailRow('Mode', game.mode.toString().split('.').last),
              if (game.difficulty != null)
                _buildDetailRow('Difficulty', game.difficulty!),
              _buildDetailRow('Score', game.score.toString()),
              _buildDetailRow('Rounds', game.rounds.toString()),
              _buildDetailRow('Correct Answers', game.correctAnswers.toString()),
              _buildDetailRow('Wrong Answers', game.wrongAnswers.toString()),
              _buildDetailRow('Accuracy', '${game.accuracy.toStringAsFixed(1)}%'),
              if (game.perfectStreak > 0)
                _buildDetailRow('Perfect Streak', game.perfectStreak.toString()),
              if (game.livesRemaining > 0)
                _buildDetailRow('Lives Remaining', game.livesRemaining.toString()),
              _buildDetailRow('Duration', _formatDuration(game.durationSeconds)),
              _buildDetailRow(
                'Completed',
                DateFormat('MMM d, y • h:mm a').format(game.completedAt),
              ),
              if (game.triviaCategories.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Categories',
                  style: AppTypography.titleLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: game.triviaCategories
                      .map((cat) => Chip(
                            label: Text(cat, style: const TextStyle(fontSize: 12)),
                            backgroundColor: Colors.white.withValues(alpha: 0.1),
                          ),)
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
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: Colors.white70,
            ),
          ),
          Text(
            value,
            style: AppTypography.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
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
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
              const Divider(color: Colors.white24),
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
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _selectedMode = null;
                          _startDate = null;
                          _endDate = null;
                          _minScore = null;
                          _maxScore = null;
                        });
                        Navigator.pop(context);
                        _refreshGames();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                      ),
                      child: const Text('Clear All'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _refreshGames();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Apply'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Game Mode',
          style: AppTypography.titleLarge.copyWith(color: Colors.white),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: GameMode.values.map((mode) {
            final isSelected = _selectedMode == mode;
            return FilterChip(
              label: Text(mode.toString().split('.').last),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedMode = selected ? mode : null;
                });
              },
              selectedColor: Colors.white.withValues(alpha: 0.3),
              checkmarkColor: Colors.white,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDateRangeFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date Range',
          style: AppTypography.titleLarge.copyWith(color: Colors.white),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
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
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                ),
                child: Text(
                  _startDate == null
                      ? 'Start Date'
                      : DateFormat('MMM d, y').format(_startDate!),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton(
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
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                ),
                child: Text(
                  _endDate == null
                      ? 'End Date'
                      : DateFormat('MMM d, y').format(_endDate!),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScoreRangeFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Score Range',
          style: AppTypography.titleLarge.copyWith(color: Colors.white),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'Min Score',
                  labelStyle: const TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    _minScore = value.isEmpty ? null : int.tryParse(value);
                  });
                },
                controller: TextEditingController(
                  text: _minScore?.toString() ?? '',
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'Max Score',
                  labelStyle: const TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    _maxScore = value.isEmpty ? null : int.tryParse(value);
                  });
                },
                controller: TextEditingController(
                  text: _maxScore?.toString() ?? '',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

