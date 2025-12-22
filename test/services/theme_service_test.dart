import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/services/theme_service.dart';
import '../utils/test_helpers.dart';

void main() {
  TestHelpers.ensureInitialized();

  group('ThemeService', () {
    late ThemeService service;

    setUpAll(() {
      TestHelpers.setupMockSharedPreferences();
    });

    setUp(() {
      service = ThemeService();
    });

    tearDown(() {
      service.dispose();
    });

    tearDownAll(() {
      TestHelpers.clearMockSharedPreferences();
    });

    test('initializes correctly', () {
      expect(service, isNotNull);
      expect(service.currentTheme, isNotNull);
    });

    test('can get theme by ID', () {
      final theme = service.getThemeById('default');
      expect(theme, isNotNull);
    });

    test('returns null for invalid theme ID', () {
      final theme = service.getThemeById('invalid_theme_id');
      expect(theme, isNull);
    });

    test('can get current theme', () {
      final theme = service.currentTheme;
      expect(theme, isNotNull);
    });

    test('can set theme', () {
      final theme = service.getThemeById('default');
      if (theme != null) {
        expect(() => service.setTheme(theme), returnsNormally);
      }
    });

    test('service can be disposed', () {
      // Create a new service instance for this test since tearDown will dispose the main one
      final testService = ThemeService();
      expect(() => testService.dispose(), returnsNormally);
    });
  });
}

