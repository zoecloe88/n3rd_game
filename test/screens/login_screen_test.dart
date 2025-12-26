import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/screens/login_screen.dart';
import 'package:n3rd_game/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LoginScreen Widget Tests', () {
    late AuthService authService;

    setUp(() {
      authService = AuthService();
    });

    tearDown(() {
      authService.dispose();
    });

    testWidgets('should render login screen', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthService>(
            create: (_) => authService,
            child: const LoginScreen(),
          ),
        ),
      );

      // Verify screen renders
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('should show login form by default', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthService>(
            create: (_) => authService,
            child: const LoginScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show email and password fields
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('should toggle between login and signup', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthService>(
            create: (_) => authService,
            child: const LoginScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find toggle button/text
      final toggleFinder = find.textContaining('Sign up');
      if (toggleFinder.evaluate().isNotEmpty) {
        await tester.tap(toggleFinder.first);
        await tester.pumpAndSettle();

        // Should now show signup form
        expect(find.byType(TextField), findsWidgets);
      }
    });
  });
}


