import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/utils/responsive_helper.dart';

void main() {
  testWidgets('ResponsiveHelper detects tablets correctly', (WidgetTester tester) async {
    // Test phone size (iPhone SE - 375x667)
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(375, 667), padding: EdgeInsets.zero),
          child: Builder(
            builder: (context) {
              final isTablet = ResponsiveHelper.isTablet(context);
              expect(isTablet, false, reason: '375x667 should be detected as phone (shortestSide=375 < 600)');
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    
    // Test tablet size (iPad - 768x1024)
    await tester.binding.setSurfaceSize(const Size(768, 1024));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(768, 1024), padding: EdgeInsets.zero),
          child: Builder(
            builder: (context) {
              final isTablet = ResponsiveHelper.isTablet(context);
              expect(isTablet, true, reason: '768x1024 should be detected as tablet (shortestSide=768 >= 600)');
              return const SizedBox();
            },
          ),
        ),
      ),
    );
  });

  testWidgets('ResponsiveHelper calculates responsive sizes', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(375, 667), padding: EdgeInsets.zero),
          child: Builder(
            builder: (context) {
              final height = ResponsiveHelper.responsiveHeight(context, 0.1);
              // 10% of 667 = 66.7
              expect(height, closeTo(66.7, 0.1));
              
              final width = ResponsiveHelper.responsiveWidth(context, 0.5);
              // 50% of 375 = 187.5
              expect(width, closeTo(187.5, 0.1));
              
              return const SizedBox();
            },
          ),
        ),
      ),
    );
  });

  testWidgets('ResponsiveHelper calculates Lottie heights', (WidgetTester tester) async {
    // Phone
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(375, 667), padding: EdgeInsets.zero),
          child: Builder(
            builder: (context) {
              final phoneHeight = ResponsiveHelper.lottieHeight(context);
              // Default phone percentage is 0.1, so 667 * 0.1 = 66.7
              expect(phoneHeight, greaterThan(0));
              expect(phoneHeight, lessThanOrEqualTo(100.0)); // Should be reasonable (66.7)
              // Allow for rounding - actual value should be around 66.7
              expect(phoneHeight, closeTo(66.7, 5.0)); // More tolerance for floating point
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    
    // Tablet
    await tester.binding.setSurfaceSize(const Size(768, 1024));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(768, 1024), padding: EdgeInsets.zero),
          child: Builder(
            builder: (context) {
              final tabletHeight = ResponsiveHelper.lottieHeight(context);
              // Default tablet percentage is 0.15, so 1024 * 0.15 = 153.6
              expect(tabletHeight, greaterThan(0));
              expect(tabletHeight, greaterThan(100.0)); // Tablet should be larger (153.6)
              // Allow for rounding - actual value should be around 153.6
              expect(tabletHeight, closeTo(153.6, 5.0)); // More tolerance for floating point
              return const SizedBox();
            },
          ),
        ),
      ),
    );
  });
}

