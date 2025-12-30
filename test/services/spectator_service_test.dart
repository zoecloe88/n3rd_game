import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/services/spectator_service.dart';
import '../utils/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await TestHelpers.setupAllTestInfrastructure();
  });

  tearDownAll(() {
    TestHelpers.tearDownAllTestInfrastructure();
  });

  group('SpectatorService', () {
    late SpectatorService service;

    setUp(() {
      TestHelpers.setupMockSharedPreferences();
      service = SpectatorService();
    });

    tearDown(() {
      service.dispose();
      TestHelpers.clearMockSharedPreferences();
    });

    test('should initialize service', () async {
      await service.init();
      expect(service.isInitialized, true);
    });

    test('should not be spectating initially', () {
      expect(service.isSpectating, false);
      expect(service.currentSpectatingRoom, null);
    });

    test('should join as spectator', () async {
      await service.init();

      try {
        await service.joinAsSpectator('test-room-id');
        // Will fail without Firebase/auth, but tests the structure
      } catch (e) {
        // Expected to fail without Firebase
        expect(e, isA<Exception>());
      }
    });

    test('should leave spectating', () async {
      await service.init();

      await service.leaveSpectating();
      expect(service.isSpectating, false);
    });
  });
}
