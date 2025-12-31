import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:n3rd_game/models/game_mode_config.dart';

/// View model for game history screen filters
///
/// Manages filter state and provides debounced filter updates
/// to prevent excessive API calls.
class GameHistoryViewModel extends ChangeNotifier {
  // Filter state
  GameMode? _selectedMode;
  DateTime? _startDate;
  DateTime? _endDate;
  int? _minScore;
  int? _maxScore;

  // Debounce timer
  Timer? _debounceTimer;
  static const Duration _debounceDuration = Duration(milliseconds: 500);

  // Getters
  GameMode? get selectedMode => _selectedMode;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  int? get minScore => _minScore;
  int? get maxScore => _maxScore;

  /// Check if any filters are active
  bool get hasActiveFilters {
    return _selectedMode != null ||
        _startDate != null ||
        _endDate != null ||
        _minScore != null ||
        _maxScore != null;
  }

  /// Set game mode filter
  void setMode(GameMode? mode) {
    if (_selectedMode != mode) {
      _selectedMode = mode;
      _notifyDebounced();
    }
  }

  /// Set start date filter
  void setStartDate(DateTime? date) {
    if (_startDate != date) {
      _startDate = date;
      _notifyDebounced();
    }
  }

  /// Set end date filter
  void setEndDate(DateTime? date) {
    if (_endDate != date) {
      _endDate = date;
      _notifyDebounced();
    }
  }

  /// Set minimum score filter
  void setMinScore(int? score) {
    // Validate: must be >= 0
    if (score != null && score < 0) {
      return;
    }
    if (_minScore != score) {
      _minScore = score;
      _notifyDebounced();
    }
  }

  /// Set maximum score filter
  void setMaxScore(int? score) {
    // Validate: must be >= 0
    if (score != null && score < 0) {
      return;
    }
    if (_maxScore != score) {
      _maxScore = score;
      _notifyDebounced();
    }
  }

  /// Clear all filters
  void clearAllFilters() {
    bool changed = false;
    if (_selectedMode != null) {
      _selectedMode = null;
      changed = true;
    }
    if (_startDate != null) {
      _startDate = null;
      changed = true;
    }
    if (_endDate != null) {
      _endDate = null;
      changed = true;
    }
    if (_minScore != null) {
      _minScore = null;
      changed = true;
    }
    if (_maxScore != null) {
      _maxScore = null;
      changed = true;
    }
    if (changed) {
      _notifyDebounced();
    }
  }

  /// Get filter parameters for service call
  Map<String, dynamic> getFilterParams() {
    return {
      'mode': _selectedMode,
      'startDate': _startDate,
      'endDate': _endDate,
      'minScore': _minScore,
      'maxScore': _maxScore,
    };
  }

  /// Notify listeners with debouncing
  void _notifyDebounced() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      notifyListeners();
    });
  }

  /// Notify listeners immediately (for apply button)
  void notifyImmediately() {
    _debounceTimer?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
