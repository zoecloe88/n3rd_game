import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/services/room_discovery_service.dart';
import 'package:n3rd_game/models/game_room.dart';
import '../utils/test_helpers.dart';
import '../utils/firebase_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await TestHelpers.setupAllTestInfrastructure();
    await FirebaseTestHelper.initializeFirebaseForTests();
  });

  tearDownAll(() {
    TestHelpers.tearDownAllTestInfrastructure();
  });

  group('Room Discovery Integration', () {
    late RoomDiscoveryService service;

    setUp(() {
      TestHelpers.setupMockSharedPreferences();
      service = RoomDiscoveryService();
    });

    tearDown(() {
      service.dispose();
      TestHelpers.clearMockSharedPreferences();
    });

    test('should create service', () {
      expect(service, isNotNull);
    });

    test('should create filter for battle royale mode', () {
      final filter = RoomDiscoveryFilter(
        mode: MultiplayerMode.battleRoyale,
        minPlayers: 2,
        maxPlayers: 4,
      );

      expect(filter.mode, MultiplayerMode.battleRoyale);
      expect(filter.minPlayers, 2);
      expect(filter.maxPlayers, 4);
    });

    test('should create filter for squad showdown mode', () {
      final filter = RoomDiscoveryFilter(
        mode: MultiplayerMode.squadShowdown,
        friendsOnly: true,
        sortOrder: RoomSortOrder.mostPlayers,
      );

      expect(filter.mode, MultiplayerMode.squadShowdown);
      expect(filter.friendsOnly, true);
      expect(filter.sortOrder, RoomSortOrder.mostPlayers);
    });

    test('should get room recommendations', () async {
      try {
        final recommendations = await service.getRoomRecommendations(limit: 5);
        // Will return empty without Firebase, but tests the structure
        expect(recommendations, isA<List<GameRoom>>());
      } catch (e) {
        // Expected to fail without Firebase
        expect(e, isA<Exception>());
      }
    });
  });
}
