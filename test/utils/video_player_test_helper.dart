import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Video player test helper for mocking video player platform channels
class VideoPlayerTestHelper {
  /// Set up mock video player platform channels
  static void setupVideoPlayerMocks() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/video_player'),
      (methodCall) async {
        switch (methodCall.method) {
          case 'init':
            // Return success for initialization
            return {
              'textureId': 1,
              'width': 1920,
              'height': 1080,
              'duration': 10000, // 10 seconds in milliseconds
            };
          case 'create':
            // Return texture ID for video creation
            return {'textureId': 1};
          case 'dispose':
            // Return success for disposal
            return null;
          case 'setLooping':
            // Return success for setting looping
            return null;
          case 'play':
            // Return success for play
            return null;
          case 'pause':
            // Return success for pause
            return null;
          case 'seekTo':
            // Return success for seek
            return null;
          case 'setVolume':
            // Return success for volume setting
            return null;
          case 'setPlaybackSpeed':
            // Return success for playback speed setting
            return null;
          case 'setMixWithOthers':
            // Return success for mix with others setting
            return null;
          case 'getPosition':
            // Return current position (0 for simplicity)
            return {'position': 0};
          default:
            return null;
        }
      },
    );
  }

  /// Clear video player mock handlers
  static void clearVideoPlayerMocks() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/video_player'),
      null,
    );
  }
}
