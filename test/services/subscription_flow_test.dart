import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/services/game_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('Subscription Flow Tests', () {
    late SubscriptionService subscriptionService;
    late GameService gameService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      subscriptionService = SubscriptionService();
      gameService = GameService();
      await subscriptionService.init();
    });

    tearDown(() {
      subscriptionService.dispose();
      gameService.dispose();
    });

    test('Free tier defaults to Classic mode only', () {
      // Free tier should only allow Classic mode
      expect(subscriptionService.isFree, isTrue);
      expect(subscriptionService.canAccessMode(GameMode.classic), isTrue);
      expect(subscriptionService.canAccessMode(GameMode.ai), isFalse);
      expect(subscriptionService.canAccessMode(GameMode.speed), isFalse);
    });

    test('Basic tier allows all modes except AI', () async {
      // Set to Basic tier
      await subscriptionService.setTier(SubscriptionTier.basic);
      
      expect(subscriptionService.isBasic, isTrue);
      expect(subscriptionService.canAccessMode(GameMode.classic), isTrue);
      expect(subscriptionService.canAccessMode(GameMode.speed), isTrue);
      expect(subscriptionService.canAccessMode(GameMode.ai), isFalse, 
        reason: 'AI mode requires Premium tier',);
    });

    test('Premium tier allows all modes including AI', () async {
      // Set to Premium tier
      await subscriptionService.setTier(SubscriptionTier.premium);
      
      expect(subscriptionService.isPremium, isTrue);
      expect(subscriptionService.canAccessMode(GameMode.classic), isTrue);
      expect(subscriptionService.canAccessMode(GameMode.speed), isTrue);
      expect(subscriptionService.canAccessMode(GameMode.ai), isTrue);
      expect(subscriptionService.hasEditionsAccess, isTrue);
      expect(subscriptionService.hasOnlineAccess, isTrue);
    });

    test('Subscription tier changes are properly tracked', () async {
      // Start with Free tier
      expect(subscriptionService.currentTier, equals(SubscriptionTier.free));
      
      // Upgrade to Basic
      await subscriptionService.setTier(SubscriptionTier.basic);
      expect(subscriptionService.currentTier, equals(SubscriptionTier.basic));
      expect(subscriptionService.isBasic, isTrue);
      
      // Upgrade to Premium
      await subscriptionService.setTier(SubscriptionTier.premium);
      expect(subscriptionService.currentTier, equals(SubscriptionTier.premium));
      expect(subscriptionService.isPremium, isTrue);
      
      // Downgrade back to Free
      await subscriptionService.setTier(SubscriptionTier.free);
      expect(subscriptionService.currentTier, equals(SubscriptionTier.free));
      expect(subscriptionService.isFree, isTrue);
    });

    test('Free tier users are restricted from Premium features', () async {
      await subscriptionService.setTier(SubscriptionTier.free);
      
      expect(subscriptionService.hasEditionsAccess, isFalse);
      expect(subscriptionService.hasOnlineAccess, isFalse);
      expect(subscriptionService.hasAllModesAccess, isFalse);
    });

    test('Basic tier users have access to all modes except Premium features', () async {
      await subscriptionService.setTier(SubscriptionTier.basic);
      
      expect(subscriptionService.hasAllModesAccess, isTrue);
      expect(subscriptionService.hasEditionsAccess, isFalse, 
        reason: 'Editions require Premium tier',);
      expect(subscriptionService.hasOnlineAccess, isFalse,
        reason: 'Online features require Premium tier',);
    });

    test('Premium tier users have full access', () async {
      await subscriptionService.setTier(SubscriptionTier.premium);
      
      expect(subscriptionService.hasAllModesAccess, isTrue);
      expect(subscriptionService.hasEditionsAccess, isTrue);
      expect(subscriptionService.hasOnlineAccess, isTrue);
      expect(subscriptionService.canAccessMode(GameMode.ai), isTrue);
    });

    test('Tier name getter returns correct string', () async {
      await subscriptionService.setTier(SubscriptionTier.free);
      expect(subscriptionService.tierName, equals('Free'));
      
      await subscriptionService.setTier(SubscriptionTier.basic);
      expect(subscriptionService.tierName, equals('Basic'));
      
      await subscriptionService.setTier(SubscriptionTier.premium);
      expect(subscriptionService.tierName, equals('Premium'));
    });
  });
}

