import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/widgets/animated_logo_loading_screen.dart';
import 'package:n3rd_game/widgets/shimmer.dart';
import 'package:n3rd_game/widgets/skeleton_loader.dart';
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

  group('AnimatedLogoLoadingScreen', () {
    late AnalyticsService analyticsService;

    setUp(() {
      TestHelpers.setupMockSharedPreferences();
      analyticsService = AnalyticsService();
    });

    tearDown(() {
      analyticsService.dispose();
      TestHelpers.clearMockSharedPreferences();
    });
    testWidgets('renders loading screen', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: analyticsService),
          ],
          child: const MaterialApp(
            home: AnimatedLogoLoadingScreen(),
          ),
        ),
      );

      expect(find.byType(AnimatedLogoLoadingScreen), findsOneWidget);
    });

    testWidgets('supports onVideoCompleted callback', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: analyticsService),
          ],
          child: MaterialApp(
            home: AnimatedLogoLoadingScreen(
              onVideoCompleted: () {
                // Callback handler
              },
            ),
          ),
        ),
      );

      expect(find.byType(AnimatedLogoLoadingScreen), findsOneWidget);
      // Note: Actual completion testing would require video player mocking
    });
  });

  group('Shimmer', () {
    testWidgets('renders shimmer widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Shimmer(
              child: Text('Content'),
            ),
          ),
        ),
      );

      expect(find.byType(Shimmer), findsOneWidget);
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('wraps child widget correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Shimmer(
              child: SizedBox(
                width: 100,
                height: 100,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Shimmer), findsOneWidget);
    });
  });

  group('SkeletonLoader', () {
    testWidgets('renders skeleton loader with required dimensions',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonLoader(
              width: 100,
              height: 20,
            ),
          ),
        ),
      );

      expect(find.byType(SkeletonLoader), findsOneWidget);
    });

    testWidgets('renders with custom width and height', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonLoader(
              width: 200,
              height: 50,
            ),
          ),
        ),
      );

      expect(find.byType(SkeletonLoader), findsOneWidget);
    });

    testWidgets('renders with custom borderRadius', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonLoader(
              width: 100,
              height: 20,
              borderRadius: 8.0,
            ),
          ),
        ),
      );

      expect(find.byType(SkeletonLoader), findsOneWidget);
    });
  });
}
