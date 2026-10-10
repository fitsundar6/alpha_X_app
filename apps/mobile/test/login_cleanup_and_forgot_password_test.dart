import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_x_gym/core/auth/login_screen.dart';
import 'package:alpha_x_gym/core/auth/forgot_password_screen.dart';
import 'package:alpha_x_gym/core/auth/reset_password_screen.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    AuthService().resetForTesting();
  });

  group('Login Page Cleanup Tests', () {
    testWidgets('Unwanted FINISH WORKOUT DEMO section is completely removed from LoginScreen', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));

      await tester.pumpWidget(
        MaterialApp(
          home: const LoginScreen(animateLogo: false),
          routes: {
            '/admin/login': (_) => const Scaffold(body: Text('Admin Login Page')),
            '/forgot-password': (_) => const Scaffold(body: Text('Forgot Password Page')),
          },
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify "FINISH WORKOUT DEMO" is completely absent
      expect(find.text('FINISH WORKOUT DEMO'), findsNothing);
      expect(find.byIcon(Icons.sports_gymnastics_rounded), findsNothing);

      // 2. Verify "ADMIN LOGIN" is present and cleanly rendered
      expect(find.text('ADMIN LOGIN'), findsOneWidget);
      expect(find.byKey(const Key('admin_login_link_button')), findsOneWidget);

      // 3. Verify "Forgot Password?" link is clearly present
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.byKey(const Key('forgot_password_button')), findsOneWidget);

      // 4. Verify standard Client Login actions are intact
      expect(find.text('CLIENT LOGIN'), findsOneWidget);
      expect(find.text('CREATE ACCOUNT'), findsOneWidget);
    });

    testWidgets('Tapping "Forgot Password?" navigates to /forgot-password route', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));

      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/login',
          routes: {
            '/login': (_) => const LoginScreen(animateLogo: false),
            '/forgot-password': (_) => const ForgotPasswordScreen(),
          },
        ),
      );
      await tester.pumpAndSettle();

      final forgotPasswordButton = find.byKey(const Key('forgot_password_button'));
      expect(forgotPasswordButton, findsOneWidget);

      await tester.tap(forgotPasswordButton);
      await tester.pumpAndSettle();

      // Should now be on ForgotPasswordScreen
      expect(find.text('PASSWORD RECOVERY'), findsOneWidget);
      expect(find.text('Password Recovery'), findsOneWidget);
      expect(find.text('Forgot your password? Contact your gym admin to get a 6-digit reset code.'), findsOneWidget);
      expect(find.byKey(const Key('enter_admin_code_button')), findsOneWidget);
      expect(find.text('ENTER 6-DIGIT RESET CODE'), findsOneWidget);
    });

    testWidgets('LoginScreen adapts cleanly across mobile screen sizes without layout overflow', (tester) async {
      // Small screen test (e.g. iPhone SE / compact Android)
      await tester.binding.setSurfaceSize(const Size(320, 600));

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(animateLogo: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('ADMIN LOGIN'), findsOneWidget);
      expect(find.text('FINISH WORKOUT DEMO'), findsNothing);

      // Large screen test (e.g. tablet or modern flagship)
      await tester.binding.setSurfaceSize(const Size(600, 1000));
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(animateLogo: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('ADMIN LOGIN'), findsOneWidget);
      expect(find.text('FINISH WORKOUT DEMO'), findsNothing);
    });
  });

  group('ForgotPasswordScreen Tests', () {
    testWidgets('Renders admin-assisted recovery UI, instructions, and contact details', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));

      await tester.pumpWidget(
        const MaterialApp(
          home: ForgotPasswordScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Password Recovery'), findsOneWidget);
      expect(find.text('Forgot your password? Contact your gym admin to get a 6-digit reset code.'), findsOneWidget);
      expect(find.text('HOW RECOVERY WORKS'), findsOneWidget);
      expect(find.text('Contact the gym admin.'), findsOneWidget);
      expect(find.text('Get your 6-digit reset code.'), findsOneWidget);
      expect(find.text('Codes expire after 15 minutes and can be used only once.'), findsOneWidget);
      expect(find.byKey(const Key('enter_admin_code_button')), findsOneWidget);
      expect(find.text('ENTER 6-DIGIT RESET CODE'), findsOneWidget);
      expect(find.byKey(const Key('return_to_login_button')), findsOneWidget);
    });

    testWidgets('Tapping ENTER 6-DIGIT RESET CODE navigates to ResetPasswordScreen with code mode', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));

      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/forgot-password',
          routes: {
            '/forgot-password': (_) => const ForgotPasswordScreen(initialEmail: 'athlete@example.com'),
            '/reset-password': (_) => const ResetPasswordScreen(),
          },
        ),
      );
      await tester.pumpAndSettle();

      final enterCodeButton = find.byKey(const Key('enter_admin_code_button'));
      expect(enterCodeButton, findsOneWidget);

      await tester.tap(enterCodeButton);
      await tester.pumpAndSettle();

      expect(find.text('SET NEW PASSWORD'), findsOneWidget);
      expect(find.byKey(const Key('reset_identifier_field')), findsOneWidget);
      expect(find.byKey(const Key('reset_password_token_field')), findsOneWidget);
    });
  });

  group('ResetPasswordScreen Tests', () {
    testWidgets('Validates password length and password mismatch', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));

      await tester.pumpWidget(
        const MaterialApp(
          home: ResetPasswordScreen(initialToken: 'test_sample_token'),
        ),
      );
      await tester.pumpAndSettle();

      final pwdField = find.byKey(const Key('reset_new_password_field'));
      final confirmPwdField = find.byKey(const Key('reset_confirm_password_field'));
      final submitButton = find.byKey(const Key('reset_password_submit_button'));

      // Test password too short (< 6 chars)
      await tester.enterText(pwdField, '123');
      await tester.enterText(confirmPwdField, '123');
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('Password must be at least 6 characters.'), findsOneWidget);

      // Test password mismatch
      await tester.enterText(pwdField, 'ValidPassword123!');
      await tester.enterText(confirmPwdField, 'DifferentPassword456!');
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match.'), findsOneWidget);
    });

    testWidgets('Handles password toggle visibility correctly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));

      await tester.pumpWidget(
        const MaterialApp(
          home: ResetPasswordScreen(initialToken: 'test_token'),
        ),
      );
      await tester.pumpAndSettle();

      final pwdField = find.byKey(const Key('reset_new_password_field'));
      expect(pwdField, findsOneWidget);

      // Check obscureText is initially true
      EditableText editable = tester.widget<EditableText>(
        find.descendant(of: pwdField, matching: find.byType(EditableText)),
      );
      expect(editable.obscureText, isTrue);

      // Tap visibility toggle icon
      final toggleIcon = find.descendant(
        of: pwdField,
        matching: find.byType(IconButton),
      );
      await tester.tap(toggleIcon);
      await tester.pumpAndSettle();

      editable = tester.widget<EditableText>(
        find.descendant(of: pwdField, matching: find.byType(EditableText)),
      );
      expect(editable.obscureText, isFalse);
    });
  });
}
