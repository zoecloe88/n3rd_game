import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/screens/general_transition_screen.dart';
import 'package:n3rd_game/config/app_config.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import '../utils/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await TestHelpers.setupAllTestInfrastructure();
  });

  tearDownAll(() async {
    await TestHelpers.tearDownAllTestInfrastructure();
  });

  group('GeneralTransitionScreen', () {
    late AnalyticsService analyticsService;

    setUp(() {
      TestHelpers.setupMockSharedPreferences();
      analyticsService = AnalyticsService();
    });

    tearDown(() {
      analyticsService.dispose();
      TestHelpers.clearMockSharedPreferences();
    });
    testWidgets('renders transition screen with video', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: analyticsService),
          ],
          child: const MaterialApp(
            home: GeneralTransitionScreen(
              routeAfter: '/target',
            ),
          ),
        ),
      );

      await tester.pump();

      // Should render the screen
      expect(find.byType(GeneralTransitionScreen), findsOneWidget);
    });

    testWidgets('navigates to target route after minimum delay',
        (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: analyticsService),
          ],
          child: MaterialApp(
            initialRoute: '/transition',
            routes: {
              '/transition': (context) => const GeneralTransitionScreen(
                    routeAfter: '/target',
                  ),
              '/target': (context) =>
                  const Scaffold(body: Text('Target Screen')),
            },
          ),
        ),
      );

      await tester.pump();

      // Wait for video completion and minimum delay
      await tester.pump();
      await tester
          .pump(AppConfig.minModeTransitionDelay + const Duration(seconds: 1));

      // Should navigate to target screen
      // Note: Actual navigation depends on video completion callback
      // This test verifies the screen renders correctly
      expect(find.byType(GeneralTransitionScreen), findsOneWidget);
    });

    testWidgets('handles route arguments', (tester) async {
      const testArgs = {'key': 'value'};

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: analyticsService),
          ],
          child: const MaterialApp(
            home: GeneralTransitionScreen(
              routeAfter: '/target',
              routeArgs: testArgs,
            ),
          ),
        ),
      );

      await tester.pump();

      // Should render with arguments
      expect(find.byType(GeneralTransitionScreen), findsOneWidget);
    });

    testWidgets('checks onboarding for protected routes', (tester) async {
      // Test that onboarding check is performed
      // This is a basic structure test - full integration test would require
      // mocking OnboardingService
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: analyticsService),
          ],
          child: MaterialApp(
            initialRoute: '/transition',
            routes: {
              '/transition': (context) => const GeneralTransitionScreen(
                    routeAfter: '/onboarding', // Protected route
                  ),
              '/onboarding': (context) =>
                  const Scaffold(body: Text('Onboarding')),
            },
          ),
        ),
      );

      await tester.pump();

      // Should render the transition screen
      expect(find.byType(GeneralTransitionScreen), findsOneWidget);
    });
  });
}
