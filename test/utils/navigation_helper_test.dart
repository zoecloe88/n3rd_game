import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';

void main() {
  group('NavigationHelper', () {
    test('is a utility class', () {
      expect(NavigationHelper, isNotNull);
    });

    test('has safeNavigate method', () {
      // NavigationHelper.safeNavigate is a static method
      // We can't easily test navigation without a widget context,
      // but we can verify the method exists
      expect(NavigationHelper.safeNavigate, isA<Function>());
    });

    test('has safePop method', () {
      expect(NavigationHelper.safePop, isA<Function>());
    });

    test('has safePushReplacementNamed method', () {
      expect(NavigationHelper.safePushReplacementNamed, isA<Function>());
    });
  });
}

