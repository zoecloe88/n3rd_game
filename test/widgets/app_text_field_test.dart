import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/widgets/app_text_field.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppTextField', () {
    testWidgets('displays label when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppTextField(
              label: 'Test Label',
            ),
          ),
        ),
      );

      expect(find.text('Test Label'), findsOneWidget);
    });

    testWidgets('displays hint when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppTextField(
              hint: 'Test Hint',
            ),
          ),
        ),
      );

      expect(find.text('Test Hint'), findsOneWidget);
    });

    testWidgets('displays error text when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppTextField(
              errorText: 'Test Error',
            ),
          ),
        ),
      );

      expect(find.text('Test Error'), findsOneWidget);
    });

    testWidgets('calls onChanged when text is entered', (tester) async {
      String? changedValue;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTextField(
              onChanged: (value) => changedValue = value,
            ),
          ),
        ),
      );

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'test');
      await tester.pump();

      expect(changedValue, equals('test'));
    });

    testWidgets('uses controller when provided', (tester) async {
      final controller = TextEditingController(text: 'initial');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTextField(
              controller: controller,
            ),
          ),
        ),
      );

      expect(find.text('initial'), findsOneWidget);
    });

    testWidgets('obscures text when obscureText is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppTextField(
              obscureText: true,
            ),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.obscureText, isTrue);
    });

    testWidgets('is disabled when enabled is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppTextField(
              enabled: false,
            ),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, isFalse);
    });

    testWidgets('displays leading icon when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppTextField(
              leadingIcon: Icons.search,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('calls onTrailingIconTap when trailing icon is tapped',
        (tester) async {
      var iconTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTextField(
              trailingIcon: Icons.clear,
              onTrailingIconTap: () => iconTapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      expect(iconTapped, isTrue);
    });

    testWidgets('displays helper text when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppTextField(
              helperText: 'Helper text',
            ),
          ),
        ),
      );

      expect(find.text('Helper text'), findsOneWidget);
    });
  });
}
