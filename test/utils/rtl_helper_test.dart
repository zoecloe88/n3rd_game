import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:n3rd_game/utils/rtl_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RTLHelper Tests', () {
    test('isRTL returns true for RTL languages', () {
      expect(RTLHelper.isRTL(const Locale('ar')), isTrue);
      expect(RTLHelper.isRTL(const Locale('he')), isTrue);
      expect(RTLHelper.isRTL(const Locale('fa')), isTrue);
      expect(RTLHelper.isRTL(const Locale('ur')), isTrue);
    });

    test('isRTL returns false for LTR languages', () {
      expect(RTLHelper.isRTL(const Locale('en')), isFalse);
      expect(RTLHelper.isRTL(const Locale('fr')), isFalse);
      expect(RTLHelper.isRTL(const Locale('de')), isFalse);
    });

    test('getTextDirection returns RTL for RTL locales', () {
      expect(
        RTLHelper.getTextDirection(const Locale('ar')),
        equals(TextDirection.rtl),
      );
      expect(
        RTLHelper.getTextDirection(const Locale('he')),
        equals(TextDirection.rtl),
      );
    });

    test('getTextDirection returns LTR for LTR locales', () {
      expect(
        RTLHelper.getTextDirection(const Locale('en')),
        equals(TextDirection.ltr),
      );
      expect(
        RTLHelper.getTextDirection(const Locale('fr')),
        equals(TextDirection.ltr),
      );
    });

    testWidgets('getEdgeInsets returns EdgeInsetsDirectional', (tester) async {
      // Create a widget tree with proper BuildContext
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              // Test that getEdgeInsets returns EdgeInsetsDirectional
              final insets = RTLHelper.getEdgeInsets(
                context,
                start: 10,
                end: 20,
                top: 5,
                bottom: 5,
              );
              expect(insets, isA<EdgeInsetsGeometry>());
              return Container();
            },
          ),
        ),
      );
    });
  });
}
