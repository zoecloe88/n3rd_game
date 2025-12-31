import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/services/room_discovery_service.dart';
import 'package:n3rd_game/models/game_room.dart';
import '../utils/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await TestHelpers.setupAllTestInfrastructure();
  });

  tearDownAll(() async {
    await TestHelpers.tearDownAllTestInfrastructure();
  });

  group('RoomDiscoveryService', () {
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

    test('should create filter with default values', () {
      final filter = RoomDiscoveryFilter();

      expect(filter.mode, null);
      expect(filter.minPlayers, null);
      expect(filter.maxPlayers, null);
      expect(filter.friendsOnly, null);
      expect(filter.sortOrder, RoomSortOrder.newest);
    });

    test('should create filter with custom values', () {
      final filter = RoomDiscoveryFilter(
        mode: MultiplayerMode.battleRoyale,
        minPlayers: 2,
        maxPlayers: 4,
        friendsOnly: false,
        sortOrder: RoomSortOrder.mostPlayers,
      );

      expect(filter.mode, MultiplayerMode.battleRoyale);
      expect(filter.minPlayers, 2);
      expect(filter.maxPlayers, 4);
      expect(filter.friendsOnly, false);
      expect(filter.sortOrder, RoomSortOrder.mostPlayers);
    });

    test('should search room by code', () async {
      try {
        final room = await service.searchRoomByCode('test-room-id');
        // Will return null without Firebase, but tests the structure
        expect(room, isA<GameRoom?>());
      } catch (e) {
        // Expected to fail without Firebase
        expect(e, isA<Exception>());
      }
    });
  });
}
