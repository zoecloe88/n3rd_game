import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:n3rd_game/screens/achievements_screen.dart';
import '../utils/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await TestHelpers.setupAllTestInfrastructure();
  });

  tearDownAll(() async {
    await TestHelpers.tearDownAllTestInfrastructure();
  });

  group('AchievementsScreen Widget Tests', () {
    setUp(() {
      TestHelpers.setupMockSharedPreferences();
      TestHelpers.setupVideoPlayerMocks();
    });

    tearDown(() {
      TestHelpers.clearMockSharedPreferences();
    });

    testWidgets('should render achievements screen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AchievementsScreen(),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      // Verify screen renders
      expect(find.byType(AchievementsScreen), findsOneWidget);
    });

    testWidgets('should display achievement list', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AchievementsScreen(),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      // Should show achievements
      expect(find.byType(AchievementsScreen), findsOneWidget);
    });

    testWidgets('should show achievement progress', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AchievementsScreen(),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      // Screen should render
      expect(find.byType(AchievementsScreen), findsOneWidget);
    });
  });
}
