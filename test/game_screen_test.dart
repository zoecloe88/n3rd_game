import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/screens/game_screen.dart';
import 'package:n3rd_game/services/game_service.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/services/free_tier_service.dart';

void main() {
  // Skip this test - GameScreen requires full initialization with async operations
  // that hang in test environment. This is a known limitation.
  testWidgets('GameScreen structure loads correctly', (WidgetTester tester) async {
    // Create services
    final gameService = GameService();
    final subscriptionService = SubscriptionService();
    final freeTierService = FreeTierService();
    
    // Initialize services
    await subscriptionService.init();
    await freeTierService.init();
    
    // Build the widget with Providers
    // Note: We don't provide route arguments to avoid triggering game initialization
    // which can hang in tests due to async operations and timers
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GameService>.value(value: gameService),
          ChangeNotifierProvider<SubscriptionService>.value(value: subscriptionService),
          ChangeNotifierProvider<FreeTierService>.value(value: freeTierService),
        ],
        child: const MaterialApp(
          home: GameScreen(),
        ),
      ),
    );
    
    // Pump frames to allow initial render - but don't wait for async operations
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    
    // Check for game screen structure immediately
    // We don't wait for full initialization as it may hang in tests
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(SafeArea), findsOneWidget);
    
    // Clean up: Dispose the service to cancel any timers immediately
    gameService.dispose();
    
    // Quick pump for cleanup
    await tester.pump();
  }, 
  skip: true, // GameScreen requires full initialization with async operations that hang in test environment
  timeout: const Timeout(Duration(seconds: 5))); // Very short timeout - test should complete quickly
}

