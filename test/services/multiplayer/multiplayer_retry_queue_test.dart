import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/services/multiplayer/multiplayer_retry_queue.dart';

void main() {
  group('MultiplayerRetryQueue', () {
    late MultiplayerRetryQueue queue;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      queue = MultiplayerRetryQueue();
      await queue.init();
    });

    tearDown(() {
      queue.dispose();
    });

    test('should enqueue submit round answer operation', () async {
      await queue.enqueueSubmitRoundAnswer(
        roomId: 'room1',
        userId: 'user1',
        score: 100,
        correctAnswers: 5,
        wrongAnswers: 2,
      );

      expect(queue.queueSize, 1);
    });

    test('should enqueue set player ready operation', () async {
      await queue.enqueueSetPlayerReady(
        roomId: 'room1',
        userId: 'user1',
        ready: true,
      );

      expect(queue.queueSize, 1);
    });

    test('should persist queue across app restarts', () async {
      await queue.enqueueSubmitRoundAnswer(
        roomId: 'room1',
        userId: 'user1',
        score: 100,
        correctAnswers: 5,
        wrongAnswers: 2,
      );

      final newQueue = MultiplayerRetryQueue();
      await newQueue.loadQueue();

      expect(newQueue.queueSize, 1);
      newQueue.dispose();
    });

    test('should process queue successfully', () async {
      bool operationCalled = false;

      await queue.enqueueSubmitRoundAnswer(
        roomId: 'room1',
        userId: 'user1',
        score: 100,
        correctAnswers: 5,
        wrongAnswers: 2,
      );

      await queue.processQueue(
        submitRoundAnswerFunction: ({
          required roomId,
          required userId,
          required score,
          required correctAnswers,
          required wrongAnswers,
        }) async {
          operationCalled = true;
          expect(roomId, 'room1');
          expect(userId, 'user1');
          expect(score, 100);
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

      expect(operationCalled, true);
      expect(queue.queueSize, 0);
    });

    test('should clear queue', () async {
      await queue.enqueueSubmitRoundAnswer(
        roomId: 'room1',
        userId: 'user1',
        score: 100,
        correctAnswers: 5,
        wrongAnswers: 2,
      );

      await queue.clear();

      expect(queue.queueSize, 0);
    });
  });
}



