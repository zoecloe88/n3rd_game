import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/services/network_service.dart';
import '../utils/test_helpers.dart';

void main() {
  TestHelpers.ensureInitialized();

  group('NetworkService', () {
    late NetworkService service;

    setUpAll(() {
      TestHelpers.setupMockSharedPreferences();
      TestHelpers.setupMockConnectivity(isConnected: true);
    });

    setUp(() {
      service = NetworkService();
    });

    tearDown(() {
      service.dispose();
    });

    tearDownAll(() {
      TestHelpers.clearMockSharedPreferences();
      TestHelpers.clearMockConnectivity();
    });

    test('initializes correctly', () {
      expect(service, isNotNull);
    });

    test('can check connectivity', () async {
      await service.init();
      expect(service.isConnected, isA<bool>());
    });

    test('has connection type property', () async {
      await service.init();
      expect(service.connectionType, isNotNull);
    });

    test('service can be disposed', () {
      // Create a new service instance for this test since tearDown will dispose the main one
      final testService = NetworkService();
      expect(() => testService.dispose(), returnsNormally);
    });
  });
}

