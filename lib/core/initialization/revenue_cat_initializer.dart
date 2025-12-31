import 'package:firebase_auth/firebase_auth.dart';
import 'package:n3rd_game/config/app_config.dart';
import 'package:n3rd_game/services/revenue_cat_service.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/utils/firebase_helper.dart';

/// RevenueCat initializer
class RevenueCatInitializer {
  /// Initialize RevenueCat
  static Future<RevenueCatService> initialize() async {
    final revenueCatService = RevenueCatService();

    try {
      String revenueCatApiKey;
      try {
        revenueCatApiKey = AppConfig.revenueCatApiKey;
      } catch (e) {
        LoggerService.warning(
          'RevenueCat API key not set. Subscriptions will not work.',
          error: e,
        );
        revenueCatApiKey = '';
      }

      if (revenueCatApiKey.isEmpty) {
        LoggerService.warning(
          'RevenueCat API key is empty. Subscriptions will not work.',
        );
      } else {
        await revenueCatService.initialize(revenueCatApiKey);

        // Sync Firebase user if already logged in
        if (FirebaseHelper.isInitialized()) {
          final firebaseUser = FirebaseHelper.getCurrentUser();
          if (firebaseUser != null) {
            await revenueCatService.syncFirebaseUser();
          }

          // Listen to auth changes to sync RevenueCat
          FirebaseAuth.instance.authStateChanges().listen((user) {
            if (user != null && revenueCatService.isInitialized) {
              revenueCatService.syncFirebaseUser();
            } else if (user == null && revenueCatService.isInitialized) {
              revenueCatService.logOut();
            }
          });
        }

        LoggerService.info('RevenueCat initialized successfully');
      }
    } catch (e) {
      LoggerService.warning('RevenueCat initialization error', error: e);
    }

    return revenueCatService;
  }
}








