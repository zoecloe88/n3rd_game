import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:n3rd_game/services/game_service.dart';
import 'package:n3rd_game/services/revenue_cat_service.dart';
import 'package:n3rd_game/services/auth_service.dart';

/// Service to manage subscription tiers
/// Integrates with RevenueCat for actual subscription management
enum SubscriptionTier {
  free,
  basic, // Changed from 'base' for consistency
  premium,
  familyFriends, // Family & Friends plan (4 members, $19.99/month)
}

class SubscriptionService extends ChangeNotifier {
  static const String _prefKeyTier = 'subscription_tier';
  static const String _prefKeyActiveGameStart = 'active_game_start_time';
  static const String _prefKeyActiveGameTier = 'active_game_start_tier';
  static const Duration _gracePeriod = Duration(
    minutes: 30,
  ); // 30 minute grace period for active games
  SubscriptionTier _currentTier = SubscriptionTier.free;
  RevenueCatService? _revenueCat;
  bool _isSettingTier = false; // Mutex to prevent concurrent tier updates

  SubscriptionTier get currentTier => _currentTier;
  bool get isFree => _currentTier == SubscriptionTier.free;
  bool get isBasic => _currentTier == SubscriptionTier.basic;
  bool get isPremium => _currentTier == SubscriptionTier.premium;
  bool get isFamilyFriends => _currentTier == SubscriptionTier.familyFriends;
  // Keep isBase for backward compatibility during transition
  bool get isBase => _currentTier == SubscriptionTier.basic;

  /// Check if user has access to editions (Premium and Family & Friends)
  bool get hasEditionsAccess => 
      _currentTier == SubscriptionTier.premium || 
      _currentTier == SubscriptionTier.familyFriends;

  /// Check if user has access to online features (Premium and Family & Friends)
  bool get hasOnlineAccess => 
      _currentTier == SubscriptionTier.premium || 
      _currentTier == SubscriptionTier.familyFriends;

  /// Check if user has access to all game modes (Basic and Premium)
  bool get hasAllModesAccess => _currentTier != SubscriptionTier.free;

  /// Check if user has active game session (for grace period during subscription expiration)
  Future<bool> hasActiveGameSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gameStartTimeStr = prefs.getString(_prefKeyActiveGameStart);
      if (gameStartTimeStr == null) return false;

      final gameStartTime = DateTime.parse(gameStartTimeStr);
      final now = DateTime.now();
      final elapsed = now.difference(gameStartTime);

      // Check if game started within grace period
      return elapsed < _gracePeriod;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error checking active game session: $e');
      }
      return false;
    }
  }

  /// Mark game session as active (call when game starts)
  /// Stores both the start time and the tier at game start for accurate grace period validation
  Future<void> markGameSessionActive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefKeyActiveGameStart,
        DateTime.now().toIso8601String(),
      );
      // Store tier at game start for accurate grace period validation
      await prefs.setString(
        _prefKeyActiveGameTier,
        _currentTier.toString().split('.').last,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error marking game session active: $e');
      }
    }
  }

  /// Clear active game session (call when game ends)
  Future<void> clearGameSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyActiveGameStart);
      await prefs.remove(_prefKeyActiveGameTier);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error clearing game session: $e');
      }
    }
  }

  /// Check if user should have access considering grace period
  /// Returns true if user has tier access OR has active game session within grace period
  ///
  /// Edge cases handled:
  /// - Grace period only applies to features that were accessible when game started
  /// - Grace period does not apply to new premium features during active game
  /// - Grace period persists across app restarts (stored in SharedPreferences)
  /// - Grace period expires after 30 minutes based on elapsed time, not app restarts
  /// - Family & Friends members get premium access through their group membership
  Future<bool> hasAccessWithGracePeriod({
    required bool requiresPremium,
    required bool requiresBasic,
  }) async {
    // Check direct tier access first
    if (requiresPremium && 
        (_currentTier == SubscriptionTier.premium || 
         _currentTier == SubscriptionTier.familyFriends)) {
      return true;
    }
    if (requiresBasic &&
        (_currentTier == SubscriptionTier.basic ||
            _currentTier == SubscriptionTier.premium)) {
      return true;
    }
    if (!requiresPremium && !requiresBasic) {
      return true;
    }

    // If no direct access, check grace period for active games
    // CRITICAL: Grace period only applies if user had access when game started
    // This prevents users from starting a free game, then accessing premium features
    final hasActiveGame = await hasActiveGameSession();
    if (hasActiveGame) {
      // Get the tier at game start for accurate validation
      SubscriptionTier? tierAtGameStart;
      try {
        final prefs = await SharedPreferences.getInstance();
        final tierString = prefs.getString(_prefKeyActiveGameTier);
        if (tierString != null) {
          tierAtGameStart = SubscriptionTier.values.firstWhere(
            (tier) => tier.toString().split('.').last == tierString,
            orElse: () => _currentTier, // Fallback to current tier if not found
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error reading tier at game start: $e');
        }
      }

      // Use tier at game start if available, otherwise use current tier (conservative)
      final effectiveTier = tierAtGameStart ?? _currentTier;

      if (kDebugMode) {
        debugPrint(
          'User has active game session - checking grace period access '
          '(requiresPremium: $requiresPremium, requiresBasic: $requiresBasic, '
          'tierAtGameStart: $effectiveTier, currentTier: $_currentTier)',
        );
      }

      // Check if the tier at game start had the required access
      if (requiresPremium && effectiveTier != SubscriptionTier.premium) {
        if (kDebugMode) {
          debugPrint(
            'Grace period: Denying premium access - tier at game start was $effectiveTier',
          );
        }
        return false;
      }

      if (requiresBasic && effectiveTier == SubscriptionTier.free) {
        if (kDebugMode) {
          debugPrint(
            'Grace period: Denying basic access - tier at game start was free',
          );
        }
        return false;
      }

      // User had the required tier when game started - allow grace period access
      return true;
    }

    return false;
  }

  /// Initialize and load subscription tier
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final tierString = prefs.getString(_prefKeyTier) ?? 'free';

    // Map 'base' to 'basic' for backward compatibility
    final normalizedTierString = tierString == 'base' ? 'basic' : tierString;

    _currentTier = SubscriptionTier.values.firstWhere(
      (tier) => tier.toString().split('.').last == normalizedTierString,
      orElse: () => SubscriptionTier.free,
    );

    // Try to load from Firestore if user is authenticated
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _loadFromFirestore(user.uid);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to load subscription tier from Firestore: $e');
      }
      // Continue with local value
    }

    notifyListeners();
  }

  /// Sync subscription tier from RevenueCat
  void syncWithRevenueCat(RevenueCatService? revenueCat, AuthService? auth) {
    // Remove existing listener first to prevent duplicates
    _revenueCat?.removeListener(_onRevenueCatUpdate);

    _revenueCat = revenueCat;
    // AuthService parameter kept for potential future use

    if (revenueCat == null || !revenueCat.isInitialized) return;

    // Listen to RevenueCat updates (only once)
    revenueCat.addListener(_onRevenueCatUpdate);

    // Initial sync
    _onRevenueCatUpdate();
  }

  /// Handle RevenueCat updates
  /// This is called when RevenueCat notifies listeners of subscription changes
  /// Safety checks ensure RevenueCat is initialized before syncing
  void _onRevenueCatUpdate() {
    // Safety check: Ensure RevenueCat is initialized before syncing
    if (_revenueCat == null || !_revenueCat!.isInitialized) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ SubscriptionService: RevenueCat not initialized, skipping tier update',
        );
      }
      return;
    }

    SubscriptionTier newTier;
    if (_revenueCat!.hasFamilyFriendsTier) {
      newTier = SubscriptionTier.familyFriends;
    } else if (_revenueCat!.hasPremiumTier) {
      newTier = SubscriptionTier.premium;
    } else if (_revenueCat!.hasBasicTier) {
      newTier = SubscriptionTier.basic;
    } else {
      newTier = SubscriptionTier.free;
    }

    // Only update if tier changed (prevents unnecessary Firestore syncs and notifications)
    if (newTier != _currentTier) {
      setTier(newTier);
    }
  }

  /// Set subscription tier (called by RevenueCat service when subscription changes)
  /// CRITICAL: Protected by mutex to prevent race conditions from concurrent updates
  Future<void> setTier(SubscriptionTier tier) async {
    // Skip if already setting tier to prevent race conditions
    if (_isSettingTier) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ Warning: Subscription tier update already in progress, skipping duplicate request',
        );
      }
      return;
    }

    final oldTier = _currentTier;

    // Only update if tier actually changed (prevents unnecessary syncs)
    if (oldTier == tier) {
      return; // No change needed
    }

    _isSettingTier = true;
    try {
      _currentTier = tier;
      final prefs = await SharedPreferences.getInstance();
      final tierString = tier.toString().split('.').last;
      await prefs.setString(_prefKeyTier, tierString);

      // Sync to Firestore if user is authenticated (only when tier changed)
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _syncToFirestore(user.uid, tier);
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Failed to sync subscription tier to Firestore: $e');
        }
        // Continue - local tier is set
      }

      // Notify listeners of tier change
      notifyListeners();

      // Log tier change (we know it changed since we checked above)
      if (kDebugMode) {
        debugPrint(
          'Subscription tier changed: ${oldTier.toString().split('.').last} -> ${tier.toString().split('.').last}',
        );
      }
    } finally {
      // CRITICAL: Always reset mutex flag, even if sync fails
      _isSettingTier = false;
    }
  }

  /// Sync subscription tier to Firestore with retry logic
  Future<void> _syncToFirestore(String userId, SubscriptionTier tier) async {
    const maxRetries = 3;
    String? lastError;

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final firestore = FirebaseFirestore.instance;
        final tierString = tier.toString().split('.').last;

        await firestore
            .collection('users')
            .doc(userId)
            .set({
              'subscriptionTier': tierString,
              'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true))
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw TimeoutException(
                  'Firestore subscription sync timeout after 10s',
                );
              },
            );

        if (kDebugMode) {
          debugPrint('Synced subscription tier to Firestore: $tierString');
        }
        return; // Success - exit retry loop
      } catch (e) {
        lastError = e.toString();
        if (kDebugMode) {
          debugPrint(
            'Failed to sync subscription tier to Firestore (attempt ${attempt + 1}/$maxRetries): $e',
          );
        }

        // Retry with exponential backoff (1s, 2s, 4s)
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(milliseconds: 1000 * (1 << attempt)));
          continue;
        }
      }
    }

    // All retries failed - log error but continue (local tier is still set)
    if (kDebugMode) {
      debugPrint(
        '⚠️ Warning: Failed to sync subscription tier to Firestore after $maxRetries attempts. Last error: $lastError',
      );
      debugPrint(
        '   Local tier is set correctly, but Firestore sync failed. Tier will be synced on next app start.',
      );
    }
    // Continue - local tier is still set, sync will retry on next init
  }

  /// Load subscription tier from Firestore on init with retry logic
  Future<void> _loadFromFirestore(String userId) async {
    const maxRetries = 2; // Fewer retries for read operations

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final firestore = FirebaseFirestore.instance;
        final doc = await firestore
            .collection('users')
            .doc(userId)
            .get()
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw TimeoutException(
                  'Firestore subscription load timeout after 10s',
                );
              },
            );

        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final tierString = data['subscriptionTier'] as String?;

          if (tierString != null) {
            // Map 'base' to 'basic' for backward compatibility
            final normalizedTierString = tierString == 'base'
                ? 'basic'
                : tierString;

            final tier = SubscriptionTier.values.firstWhere(
              (t) => t.toString().split('.').last == normalizedTierString,
              orElse: () => SubscriptionTier.free,
            );

            if (tier != _currentTier) {
              _currentTier = tier;
              // Update local storage
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(_prefKeyTier, normalizedTierString);
              notifyListeners();
            }
          }
        }
        return; // Success - exit retry loop
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            'Failed to load subscription tier from Firestore (attempt ${attempt + 1}/$maxRetries): $e',
          );
        }

        // Retry with exponential backoff (0.5s, 1s)
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(milliseconds: 500 * (1 << attempt)));
          continue;
        }
      }
    }

    // All retries failed - continue with local storage value (graceful degradation)
    if (kDebugMode) {
      debugPrint(
        '⚠️ Warning: Failed to load subscription tier from Firestore after $maxRetries attempts. Using local storage value.',
      );
    }
  }

  /// Check if a game mode is accessible for current tier
  bool canAccessMode(GameMode mode) {
    // AI mode requires Premium or Family & Friends
    if (mode == GameMode.ai) {
      return _currentTier == SubscriptionTier.premium || 
             _currentTier == SubscriptionTier.familyFriends;
    }

    // Flip Mode requires Basic, Premium, or Family & Friends
    // Explicitly listed for clarity, though it falls under the "all modes except AI" rule below
    if (mode == GameMode.flip) {
      return _currentTier != SubscriptionTier.free;
    }

    if (_currentTier != SubscriptionTier.free) {
      return true; // Basic, Premium, and Family & Friends have access to all modes (except AI which needs Premium/Family)
    }
    // Free tier only has access to Classic mode
    return mode == GameMode.classic;
  }

  /// Get tier name as string
  String get tierName {
    switch (_currentTier) {
      case SubscriptionTier.free:
        return 'Free';
      case SubscriptionTier.basic:
        return 'Basic';
      case SubscriptionTier.premium:
        return 'Premium';
      case SubscriptionTier.familyFriends:
        return 'Family & Friends';
    }
  }

  @override
  void dispose() {
    _revenueCat?.removeListener(_onRevenueCatUpdate);
    super.dispose();
  }
}
