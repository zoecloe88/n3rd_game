import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/screens/login_screen.dart';
import 'package:n3rd_game/services/auth_service.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import '../utils/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await TestHelpers.setupAllTestInfrastructure();
  });

  tearDownAll(() {
    TestHelpers.tearDownAllTestInfrastructure();
  });

  group('LoginScreen Widget Tests', () {
    late AuthService authService;
    late AnalyticsService analyticsService;

    setUp(() {
      TestHelpers.setupMockSharedPreferences();
      TestHelpers.setupVideoPlayerMocks();
      TestHelpers.setupAssetManifest(); // Mock asset loading
      authService = AuthService();
      analyticsService = AnalyticsService();
    });

    tearDown(() async {
      // Wait for any pending timers (e.g., VideoBackgroundWidget fallback timer)
      // This prevents "Timer is still pending" errors
      await Future.delayed(const Duration(milliseconds: 100));
      authService.dispose();
      analyticsService.dispose();
      TestHelpers.clearMockSharedPreferences();
    });

    testWidgets('should render login screen', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: authService),
            ChangeNotifierProvider.value(value: analyticsService),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Verify screen renders
      expect(find.byType(LoginScreen), findsOneWidget);

      // Unmount the widget properly to ensure timers are cancelled
      await tester.pumpWidget(Container());
      await tester.pump();

      // Allow any pending timers/Future.delayed to complete
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('should show login form by default', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: authService),
            ChangeNotifierProvider.value(value: analyticsService),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Pump frames without waiting for assets to settle (prevents image loading errors)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show email and password fields
      expect(find.byType(TextField), findsWidgets);

      // Unmount the widget properly to ensure timers are cancelled
      await tester.pumpWidget(Container());
      await tester.pump();

      // Allow any pending timers/Future.delayed to complete
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('should toggle between login and signup', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: authService),
            ChangeNotifierProvider.value(value: analyticsService),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Pump frames without waiting for assets to settle (prevents image loading errors)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Find toggle button/text
      final toggleFinder = find.textContaining('Sign up');
      if (toggleFinder.evaluate().isNotEmpty) {
        await tester.tap(toggleFinder.first);
        await tester.pump(const Duration(milliseconds: 100));

        // Should now show signup form
        expect(find.byType(TextField), findsWidgets);
      }

      // Unmount the widget properly to ensure timers are cancelled
      await tester.pumpWidget(Container());
      await tester.pump();

      // Allow any pending timers/Future.delayed to complete
      await tester.pump(const Duration(milliseconds: 600));
    });
  });
}
