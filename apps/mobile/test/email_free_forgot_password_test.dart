import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_x_gym/core/auth/forgot_password_screen.dart';
import 'package:alpha_x_gym/core/auth/reset_password_screen.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/config/admin_config.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    AuthService().resetForTesting();
  });

  group('Email-Free Forgot Password: Contact Admin Flow Tests', () {
    testWidgets('ForgotPasswordScreen renders Contact Admin details and zero-cost action button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 950));

      await tester.pumpWidget(
        const MaterialApp(
          home: ForgotPasswordScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify Contact Admin section presence
      expect(find.text('Password Recovery'), findsOneWidget);
      expect(find.text('Forgot your password? Contact your gym admin to get a 6-digit reset code.'), findsOneWidget);
      expect(find.text(AdminConfig.adminEmail), findsOneWidget);
      expect(find.text('Alpha X Front Desk & Administration'), findsOneWidget);

      // 2. Verify 6-digit code entry button
      expect(find.byKey(const Key('enter_admin_code_button')), findsOneWidget);
      expect(find.text('ENTER 6-DIGIT RESET CODE'), findsOneWidget);

      // 3. Verify instructions presence
      expect(find.text('HOW RECOVERY WORKS'), findsOneWidget);
      expect(find.text('Codes expire after 15 minutes and can be used only once.'), findsOneWidget);
    });

    testWidgets('Tapping "ENTER 6-DIGIT RESET CODE" navigates to ResetPasswordScreen with code mode', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 950));

      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/forgot-password',
          routes: {
            '/forgot-password': (_) => const ForgotPasswordScreen(),
            '/reset-password': (_) => const ResetPasswordScreen(),
          },
        ),
      );
      await tester.pumpAndSettle();

      final enterCodeButton = find.byKey(const Key('enter_admin_code_button'));
      expect(enterCodeButton, findsOneWidget);

      await tester.tap(enterCodeButton);
      await tester.pumpAndSettle();

      // Should now be on ResetPasswordScreen in code mode
      expect(find.text('SET NEW PASSWORD'), findsOneWidget);
      expect(find.byKey(const Key('reset_identifier_field')), findsOneWidget);
      expect(find.byKey(const Key('reset_password_token_field')), findsOneWidget);
      expect(find.byKey(const Key('reset_new_password_field')), findsOneWidget);
      expect(find.byKey(const Key('reset_confirm_password_field')), findsOneWidget);
    });

    testWidgets('ResetPasswordScreen in code mode validates identifier and 6-digit code', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 950));

      await tester.pumpWidget(
        const MaterialApp(
          home: ResetPasswordScreen(initialToken: '123456'), // 6-digit triggers code mode
        ),
      );
      await tester.pumpAndSettle();

      // Submit with empty identifier
      final submitButton = find.byKey(const Key('reset_password_submit_button'));
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('Please enter your registered Email or Client ID.'), findsOneWidget);

      // Enter identifier and too short password (< 6 chars)
      final idField = find.byKey(const Key('reset_identifier_field'));
      final pwdField = find.byKey(const Key('reset_new_password_field'));
      final confirmPwdField = find.byKey(const Key('reset_confirm_password_field'));

      await tester.enterText(idField, 'AXG-0001');
      await tester.enterText(pwdField, '123');
      await tester.enterText(confirmPwdField, '123');
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('Password must be at least 6 characters.'), findsOneWidget);

      // Enter valid password and mismatch confirm password
      await tester.enterText(pwdField, 'ValidPassword123!');
      await tester.enterText(confirmPwdField, 'Mismatch456!');
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match.'), findsOneWidget);
    });

    testWidgets('ResetPasswordScreen in code mode successfully resets password and shows success view', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 950));

      await tester.pumpWidget(
        const MaterialApp(
          home: ResetPasswordScreen(initialToken: '654321'),
        ),
      );
      await tester.pumpAndSettle();

      final idField = find.byKey(const Key('reset_identifier_field'));
      final pwdField = find.byKey(const Key('reset_new_password_field'));
      final confirmPwdField = find.byKey(const Key('reset_confirm_password_field'));
      final submitButton = find.byKey(const Key('reset_password_submit_button'));

      await tester.enterText(idField, 'AXG-0042');
      await tester.enterText(pwdField, 'NewStrongPassword123!');
      await tester.enterText(confirmPwdField, 'NewStrongPassword123!');
      await tester.tap(submitButton);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Expect success view
      expect(find.text('Password Reset Successful'), findsOneWidget);
      expect(find.byKey(const Key('continue_to_login_button')), findsOneWidget);
    });

    testWidgets('ResetPasswordScreen displays error banner on invalid or expired code', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 950));

      await tester.pumpWidget(
        const MaterialApp(
          home: ResetPasswordScreen(initialToken: '000000'), // 000000 triggers mock error
        ),
      );
      await tester.pumpAndSettle();

      final idField = find.byKey(const Key('reset_identifier_field'));
      final pwdField = find.byKey(const Key('reset_new_password_field'));
      final confirmPwdField = find.byKey(const Key('reset_confirm_password_field'));
      final submitButton = find.byKey(const Key('reset_password_submit_button'));

      await tester.enterText(idField, 'AXG-0001');
      await tester.enterText(pwdField, 'NewStrongPassword123!');
      await tester.enterText(confirmPwdField, 'NewStrongPassword123!');
      await tester.tap(submitButton);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Error banner
      expect(find.text('Invalid reset code. Please check the 6-digit code provided by your administrator.'), findsOneWidget);
    });
  });
}
