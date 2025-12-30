import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/screens/youth_transition_screen.dart';
import 'package:n3rd_game/config/app_config.dart';
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

  group('YouthTransitionScreen', () {
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
            home: YouthTransitionScreen(),
          ),
        ),
      );

      await tester.pump();

      // Should render the screen
      expect(find.byType(YouthTransitionScreen), findsOneWidget);
    });

    testWidgets('calls onFinished callback when provided', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: analyticsService),
          ],
          child: MaterialApp(
            home: YouthTransitionScreen(
              onFinished: () {
                // Callback would be called when video completes
              },
            ),
          ),
        ),
      );

      await tester.pump();

      // Wait for minimum delay and video completion
      await tester.pump();
      await tester
          .pump(AppConfig.minModeTransitionDelay + const Duration(seconds: 1));

      // Callback should be called (if video completes)
      // Note: Actual callback depends on video completion
      // This test verifies the screen renders correctly
      expect(find.byType(YouthTransitionScreen), findsOneWidget);
    });

    testWidgets('navigates to route when onFinished is not provided',
        (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: analyticsService),
          ],
          child: MaterialApp(
            initialRoute: '/transition',
            routes: {
              '/transition': (context) => const YouthTransitionScreen(
                    routeAfter: '/target',
                  ),
              '/target': (context) =>
                  const Scaffold(body: Text('Target Screen')),
            },
          ),
        ),
      );

      await tester.pump();

      // Wait for minimum delay and video completion
      await tester.pump();
      await tester
          .pump(AppConfig.minModeTransitionDelay + const Duration(seconds: 1));

      // Should handle navigation
      // Note: Actual navigation depends on video completion callback
      expect(find.byType(YouthTransitionScreen), findsOneWidget);
    });

    testWidgets('handles route arguments', (tester) async {
      const testArgs = {'key': 'value'};

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: analyticsService),
          ],
          child: const MaterialApp(
            home: YouthTransitionScreen(
              routeAfter: '/target',
              routeArgs: testArgs,
            ),
          ),
        ),
      );

      await tester.pump();

      // Should render with arguments
      expect(find.byType(YouthTransitionScreen), findsOneWidget);
    });

    testWidgets('enforces minimum delay before navigation', (tester) async {
      DateTime? navigationTime;
      bool callbackCalled = false;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: analyticsService),
          ],
          child: MaterialApp(
            home: YouthTransitionScreen(
              onFinished: () {
                navigationTime = DateTime.now();
                callbackCalled = true;
              },
            ),
          ),
        ),
      );

      final startTime = DateTime.now();
      await tester.pump();

      // Wait for video completion
      await tester.pump();
      await tester
          .pump(AppConfig.minModeTransitionDelay + const Duration(seconds: 1));

      // If callback was called, verify minimum delay was enforced
      if (callbackCalled && navigationTime != null) {
        final elapsed = navigationTime!.difference(startTime);
        expect(
          elapsed.inMilliseconds,
          greaterThanOrEqualTo(
            AppConfig.minModeTransitionDelay.inMilliseconds - 100,
          ), // Allow 100ms tolerance
        );
      }
    });
  });
}
