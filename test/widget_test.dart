// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:n3rd_game/screens/title_screen.dart';
import 'package:n3rd_game/services/subscription_service.dart';

void main() {
  testWidgets('TitleScreen loads and displays content', (WidgetTester tester) async {
    // Build the widget with required providers
    // TitleScreen uses SubscriptionService via Consumer widgets
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SubscriptionService()..init()),
        ],
        child: const MaterialApp(home: TitleScreen()),
      ),
    );
    
    // Pump frames to allow initial render
    // Don't use pumpAndSettle() - video loading will timeout
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    
    // Check for title screen elements
    // Video may not load in tests, but UI elements should be visible
    expect(find.text('N3RD Trivia'), findsOneWidget);
    
    // Check for button text (updated to "Choose Mode")
    expect(find.textContaining('Choose Mode'), findsOneWidget);
    
    // Verify the screen structure exists
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(SafeArea), findsOneWidget);
  });
}
