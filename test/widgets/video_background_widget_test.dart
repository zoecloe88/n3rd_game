import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/widgets/video_background_widget.dart';
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

  group('VideoBackgroundWidget', () {
    late AnalyticsService analyticsService;

    setUp(() {
      TestHelpers.setupMockSharedPreferences();
      TestHelpers.setupVideoPlayerMocks();
      analyticsService = AnalyticsService();
    });

    tearDown(() {
      analyticsService.dispose();
      TestHelpers.clearMockSharedPreferences();
    });
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: analyticsService),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: VideoBackgroundWidget(
                videoPath: 'test_video.mp4',
                child: Text('Test content'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Test content'), findsOneWidget);
    });

    testWidgets('handles empty video path gracefully', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: analyticsService),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: VideoBackgroundWidget(
                videoPath: '',
                child: Text('Fallback content'),
              ),
            ),
          ),
        ),
      );

      // Should still render child even with invalid video path
      expect(find.text('Fallback content'), findsOneWidget);
    });

    testWidgets('renders with non-looping video', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: analyticsService),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: VideoBackgroundWidget(
                videoPath: 'test_video.mp4',
                loop: false,
                child: Text('Non-looping video'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Non-looping video'), findsOneWidget);
    });

    testWidgets('supports onVideoCompleted callback', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: analyticsService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: VideoBackgroundWidget(
                videoPath: 'test_video.mp4',
                loop: false,
                onVideoCompleted: () {
                  // Callback handler
                },
                child: const Text('Video with callback'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Video with callback'), findsOneWidget);
      // Note: Actual completion callback testing would require video player mocking
    });
  });
}
