import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/constants/app_constants.dart';
import 'package:alpha_x_gym/core/config/api_config.dart';
import 'package:alpha_x_gym/core/auth/forgot_password_screen.dart';
import 'package:alpha_x_gym/core/auth/reset_password_screen.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    ApiConfig.customServerUrl = null;
    AuthService().resetForTesting();
  });

  group('Password Recovery Configuration & Resilience Tests', () {
    test('ApiConfig.defaultHostIp is set to active LAN host IP 192.168.1.5', () {
      expect(ApiConfig.defaultHostIp, equals('192.168.1.5'));
      expect(ApiConfig.physicalLanUrl, equals('http://192.168.1.5:5000/api/v1'));
    });

    test('ApiConfig retains saved 192.168.x.x LAN server configuration upon initialize', () async {
      SharedPreferences.setMockInitialValues({
        ApiConfig.storageKey: 'http://192.168.1.5:5000/api/v1',
      });

      await ApiConfig.initialize();

      expect(ApiConfig.customServerUrl, equals('http://192.168.1.5:5000/api/v1'));
      expect(ApiConfig.baseUrl, equals('http://192.168.1.5:5000/api/v1'));
    });

    testWidgets('ForgotPasswordScreen renders server configuration button in top bar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));

      await tester.pumpWidget(
        const MaterialApp(
          home: ForgotPasswordScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('forgot_password_server_config_button')), findsOneWidget);
      expect(find.byIcon(Icons.settings_ethernet), findsOneWidget);
    });

    testWidgets('ResetPasswordScreen renders server configuration button in top bar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));

      await tester.pumpWidget(
        const MaterialApp(
          home: ResetPasswordScreen(initialToken: 'test_token_123'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reset_password_server_config_button')), findsOneWidget);
      expect(find.byIcon(Icons.settings_ethernet), findsOneWidget);
    });

    test('AuthService requestPasswordReset returns safe anti-enumeration message', () async {
      final res = await AuthService().requestPasswordReset('nonexistent@example.com');
      expect(res['success'], isTrue);
      expect(
        res['message'],
        contains('If an account exists with this email, a password reset link has been sent.'),
      );
    });

    test('AuthService verifyResetToken validates format and returns safe error for empty', () async {
      final res = await AuthService().verifyResetToken('');
      expect(res['valid'], isFalse);
      expect(res['message'], contains('cannot be empty'));
    });

    test('AuthService resetPasswordWithCode enforces invalid code protection', () async {
      final res = await AuthService().resetPasswordWithCode(
        identifier: 'athlete@example.com',
        code: '000000',
        newPassword: 'NewPassword123!',
        confirmPassword: 'NewPassword123!',
      );
      expect(res['success'], isFalse);
      expect(res['error'], equals('INVALID_CODE'));
    });
  });
}
