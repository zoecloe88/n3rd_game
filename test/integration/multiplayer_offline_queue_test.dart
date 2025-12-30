import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/services/multiplayer/multiplayer_retry_queue.dart';
import '../utils/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await TestHelpers.setupAllTestInfrastructure();
  });

  tearDownAll(() {
    TestHelpers.tearDownAllTestInfrastructure();
  });

  group('Multiplayer Offline Queue Integration', () {
    late MultiplayerRetryQueue queue;

    setUp(() async {
      TestHelpers.setupMockSharedPreferences();
      queue = MultiplayerRetryQueue();
      await queue.init();
    });

    tearDown(() {
      queue.dispose();
      TestHelpers.clearMockSharedPreferences();
    });

    test('should queue and process multiple operations', () async {
      int operationsProcessed = 0;

      // Queue multiple operations
      await queue.enqueueSubmitRoundAnswer(
        roomId: 'room1',
        userId: 'user1',
        score: 100,
        correctAnswers: 5,
        wrongAnswers: 2,
      );

      await queue.enqueueSetPlayerReady(
        roomId: 'room1',
        userId: 'user1',
        ready: true,
      );

      expect(queue.queueSize, 2);

      // Process queue
      await queue.processQueue(
        submitRoundAnswerFunction: ({
          required roomId,
          required userId,
          required score,
          required correctAnswers,
          required wrongAnswers,
        }) async {
          operationsProcessed++;
        },
        setPlayerReadyFunction: ({
          required roomId,
          required userId,
          required ready,
        }) async {
          operationsProcessed++;
        },
        sendPingFunction: ({
          required roomId,
          required userId,
        }) async {},
        nextRoundFunction: ({
          required roomId,
          required userId,
        }) async {},
        leaveRoomFunction: ({
          required roomId,
          required userId,
        }) async {},
      );

      expect(operationsProcessed, 2);
      expect(queue.queueSize, 0);
    });

    test('should handle failed operations with retry', () async {
      int attempts = 0;

      await queue.enqueueSubmitRoundAnswer(
        roomId: 'room1',
        userId: 'user1',
        score: 100,
        correctAnswers: 5,
        wrongAnswers: 2,
      );

      // Process queue with failing operation
      await queue.processQueue(
        submitRoundAnswerFunction: ({
          required roomId,
          required userId,
          required score,
          required correctAnswers,
          required wrongAnswers,
        }) async {
          attempts++;
          throw Exception('Network error');
        },
        setPlayerReadyFunction: ({
          required roomId,
          required userId,
          required ready,
        }) async {},
        sendPingFunction: ({
          required roomId,
          required userId,
        }) async {},
        nextRoundFunction: ({
          required roomId,
          required userId,
        }) async {},
        leaveRoomFunction: ({
          required roomId,
          required userId,
        }) async {},
      );

      // Operation should still be in queue after failure
      expect(queue.queueSize, 1);
      expect(attempts, 1);
    });
  });
}
