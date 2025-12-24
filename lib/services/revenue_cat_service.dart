import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// RevenueCat service for managing subscriptions and in-app purchases
///
/// Product IDs (configure these in RevenueCat dashboard):
/// - basic_tier: $4.99/month subscription with 7-day free trial
/// - premium_monthly: $9.99/month subscription
/// - family_friends_monthly: $19.99/month subscription (4 members max)
class RevenueCatService extends ChangeNotifier {
  bool _initialized = false;
  bool _hasBasicTier = false;
  bool _hasPremiumTier = false;
  bool _hasFamilyFriendsTier = false;
  CustomerInfo? _customerInfo;
  bool _isPurchasing = false; // Mutex to prevent concurrent purchase attempts

  bool get isInitialized => _initialized;
  bool get hasBasicTier => _hasBasicTier;
  bool get hasPremiumTier => _hasPremiumTier;
  bool get hasFamilyFriendsTier => _hasFamilyFriendsTier;
  CustomerInfo? get customerInfo => _customerInfo;

  /// Initialize RevenueCat with your API key
  ///
  /// Get your API key from: https://app.revenuecat.com
  /// - iOS: Use your Apple API key
  /// - Android: Use your Google API key
  Future<void> initialize(String apiKey) async {
    if (_initialized) return;

    try {
      // Configure RevenueCat
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.info);

      // Get platform-specific configuration
      PurchasesConfiguration configuration;
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        configuration = PurchasesConfiguration(apiKey);
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        configuration = PurchasesConfiguration(apiKey);
      } else {
        debugPrint('RevenueCat: Platform not supported');
        return;
      }

      await Purchases.configure(configuration);

      // Set user ID if Firebase user is logged in
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        await Purchases.logIn(firebaseUser.uid);
      }

      // Load customer info
      await _loadCustomerInfo();

      // Listen to customer info updates
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdate);

      _initialized = true;
      notifyListeners();

      debugPrint('RevenueCat initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('RevenueCat initialization error: $e');
      debugPrint('Stack trace: $stackTrace');
      // Continue without RevenueCat - app will use local storage fallback
    }
  }

  /// Load current customer info and update tier status
  Future<void> _loadCustomerInfo() async {
    try {
      _customerInfo = await Purchases.getCustomerInfo();
      _updateTierStatus();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading customer info: $e');
    }
  }

  /// Handle customer info updates
  void _onCustomerInfoUpdate(CustomerInfo customerInfo) {
    _customerInfo = customerInfo;
    _updateTierStatus();
    notifyListeners();
  }

  /// Update tier status based on entitlements
  void _updateTierStatus() {
    if (_customerInfo == null) {
      _hasBasicTier = false;
      _hasPremiumTier = false;
      _hasFamilyFriendsTier = false;
      return;
    }

    // Check entitlements (configure these in RevenueCat dashboard)
    final entitlements = _customerInfo!.entitlements.all;

    // Family & Friends tier: Check for family_friends entitlement
    // Family members get premium access through their group
    _hasFamilyFriendsTier = entitlements.containsKey('family_friends') &&
        entitlements['family_friends']?.isActive == true;

    // Premium tier: Check for premium entitlement
    _hasPremiumTier = entitlements.containsKey('premium') &&
        entitlements['premium']?.isActive == true;

    // Basic tier: Check for basic entitlement (subscription with trial support)
    // RevenueCat's isActive includes trial periods automatically
    if (entitlements.containsKey('basic')) {
      final basicEntitlement = entitlements['basic'];
      // Check if subscription is active (includes trial periods)
      _hasBasicTier = basicEntitlement?.isActive == true;

      // Also explicitly check if in trial period (for clarity)
      if (!_hasBasicTier && basicEntitlement != null) {
        final periodType = basicEntitlement.periodType;
        // If period type is trial, user has access
        if (periodType == PeriodType.trial) {
          _hasBasicTier = true;
        }
      }
    } else {
      _hasBasicTier = false;
    }

    // Notify listeners so SubscriptionService can sync
    notifyListeners();
  }

  /// Get current subscription tier based on entitlements
  String get currentTierString {
    if (_hasFamilyFriendsTier) return 'familyFriends';
    if (_hasPremiumTier) return 'premium';
    if (_hasBasicTier) return 'basic';
    return 'free';
  }

  /// Get available products for purchase
  /// Returns empty list if RevenueCat is not initialized
  Future<List<Package>> getAvailablePackages() async {
    if (!_initialized) {
      if (kDebugMode) {
        debugPrint('RevenueCat not initialized, cannot get packages');
      }
      return [];
    }

    try {
      final offerings = await Purchases.getOfferings();
      if (offerings.current != null) {
        return offerings.current!.availablePackages;
      }
      return [];
    } catch (e) {
      debugPrint('Error getting available packages: $e');
      return [];
    }
  }

  /// Purchase a package
  /// Returns false if RevenueCat is not initialized or if purchase is already in progress
  Future<bool> purchasePackage(Package package) async {
    if (!_initialized) {
      if (kDebugMode) {
        debugPrint('RevenueCat not initialized, cannot purchase package');
      }
      return false;
    }

    // CRITICAL: Prevent concurrent purchase attempts (race condition protection)
    if (_isPurchasing) {
      if (kDebugMode) {
        debugPrint('Purchase already in progress - ignoring duplicate request');
      }
      return false;
    }

    _isPurchasing = true;
    try {
      final customerInfo = await Purchases.purchasePackage(package);
      _customerInfo = customerInfo;
      _updateTierStatus();
      notifyListeners();
      return true;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('User cancelled purchase');
        return false;
      } else if (errorCode == PurchasesErrorCode.purchaseNotAllowedError) {
        debugPrint('Purchase not allowed');
        return false;
      } else if (errorCode == PurchasesErrorCode.purchaseInvalidError) {
        debugPrint('Purchase invalid');
        return false;
      } else {
        debugPrint('Purchase error: ${e.message}');
        return false;
      }
    } catch (e) {
      debugPrint('Unexpected purchase error: $e');
      return false;
    } finally {
      // CRITICAL: Always reset mutex flag, even if purchase fails or throws
      _isPurchasing = false;
    }
  }

  /// Restore purchases
  /// Returns false if RevenueCat is not initialized
  Future<bool> restorePurchases() async {
    if (!_initialized) {
      if (kDebugMode) {
        debugPrint('RevenueCat not initialized, cannot restore purchases');
      }
      return false;
    }

    try {
      _customerInfo = await Purchases.restorePurchases();
      _updateTierStatus();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error restoring purchases: $e');
      return false;
    }
  }

  /// Sync Firebase user ID with RevenueCat
  Future<void> syncFirebaseUser() async {
    if (!_initialized) return;

    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        await Purchases.logIn(firebaseUser.uid);
        await _loadCustomerInfo();
      }
    } catch (e) {
      debugPrint('Error syncing Firebase user: $e');
    }
  }

  /// Log out current user
  Future<void> logOut() async {
    if (!_initialized) return;

    try {
      await Purchases.logOut();
      _customerInfo = null;
      _hasBasicTier = false;
      _hasPremiumTier = false;
      _hasFamilyFriendsTier = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error logging out: $e');
    }
  }

  /// Check if user can make purchases
  Future<bool> canMakePurchases() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.all.isNotEmpty ||
          await Purchases.canMakePayments();
    } catch (e) {
      debugPrint('Error checking purchase capability: $e');
      return false;
    }
  }

  /// Dispose of the service and clean up resources
  /// Note: RevenueCat SDK's addCustomerInfoUpdateListener doesn't have a corresponding
  /// remove method, but we mark the service as disposed to prevent operations after disposal
  @override
  void dispose() {
    // Mark as not initialized to prevent operations after disposal
    _initialized = false;
    // Reset purchase mutex to ensure clean state
    _isPurchasing = false;
    // Clear customer info reference
    _customerInfo = null;
    // Reset tier flags
    _hasBasicTier = false;
    _hasPremiumTier = false;
    _hasFamilyFriendsTier = false;
    super.dispose();
  }
}
