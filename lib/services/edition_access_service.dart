import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/models/edition_model.dart';
import 'package:n3rd_game/services/revenue_cat_service.dart';
import 'package:n3rd_game/services/subscription_service.dart';

class EditionAccessService extends ChangeNotifier {
  static const _unlockedKey = 'edition_unlocked_ids';
  static const _allAccessKey = 'edition_all_access';

  late SharedPreferences _prefs;
  bool _initialized = false;
  final Set<String> _unlockedEditionIds = {};
  bool _hasAllAccess = false;

  RevenueCatService? _revenueCatService;
  SubscriptionService? _subscriptionService;

  /// Set RevenueCat service (called from main.dart after initialization)
  void setRevenueCatService(RevenueCatService? service) {
    _revenueCatService = service;
    if (service != null) {
      // Listen to RevenueCat updates
      service.addListener(_onRevenueCatUpdate);
      _onRevenueCatUpdate();
    }
  }

  /// Set SubscriptionService (called from main.dart after initialization)
  /// CRITICAL: SubscriptionService is the source of truth for access control
  void setSubscriptionService(SubscriptionService? service) {
    _subscriptionService = service;
  }

  void _onRevenueCatUpdate() {
    if (_revenueCatService != null) {
      // Sync RevenueCat premium status with local access
      final hasPremium = _revenueCatService!.hasPremiumTier;
      if (hasPremium != _hasAllAccess) {
        _hasAllAccess = hasPremium;
        _saveAllAccess();
        notifyListeners();
      }
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    final unlocked = _prefs.getStringList(_unlockedKey);
    if (unlocked != null) {
      _unlockedEditionIds.addAll(unlocked);
    }
    _hasAllAccess = _prefs.getBool(_allAccessKey) ?? false;
    _initialized = true;
  }

  bool hasAccess(EditionModel edition) {
    if (!edition.isPremium) return true;

    // CRITICAL: Check SubscriptionService first (source of truth)
    // This ensures Basic users cannot access editions even if RevenueCat is misconfigured
    if (_subscriptionService != null) {
      if (!_subscriptionService!.hasEditionsAccess) {
        return false; // Explicitly deny if SubscriptionService says no access
      }
    }

    // Double-check with RevenueCat (secondary validation)
    if (_revenueCatService != null && _revenueCatService!.isInitialized) {
      if (_revenueCatService!.hasPremiumTier) return true;
    }

    // Fallback to local storage (should not be used for premium editions in production)
    // Only used for testing/development scenarios
    if (_hasAllAccess) return true;
    return _unlockedEditionIds.contains(edition.id);
  }

  bool get hasAllAccess {
    // CRITICAL: Check SubscriptionService first (source of truth)
    if (_subscriptionService != null) {
      if (!_subscriptionService!.hasEditionsAccess) {
        return false; // Explicitly deny if SubscriptionService says no access
      }
    }

    // Double-check with RevenueCat
    if (_revenueCatService != null && _revenueCatService!.isInitialized) {
      return _revenueCatService!.hasPremiumTier;
    }
    // Fallback to local storage (should not be used in production)
    return _hasAllAccess;
  }

  bool get hasBasicTier {
    if (_revenueCatService != null && _revenueCatService!.isInitialized) {
      return _revenueCatService!.hasBasicTier;
    }
    return false;
  }

  Future<void> unlockEdition(String editionId) async {
    _unlockedEditionIds.add(editionId);
    await _prefs.setStringList(_unlockedKey, _unlockedEditionIds.toList());
    notifyListeners();
  }

  Future<void> unlockAllAccess() async {
    _hasAllAccess = true;
    await _saveAllAccess();
    notifyListeners();
  }

  Future<void> _saveAllAccess() async {
    await _prefs.setBool(_allAccessKey, _hasAllAccess);
  }

  @override
  void dispose() {
    _revenueCatService?.removeListener(_onRevenueCatUpdate);
    super.dispose();
  }
}
