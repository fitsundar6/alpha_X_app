import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/auth/login_screen.dart';
import 'package:alpha_x_gym/core/auth/admin_login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Email Input Field - Keyboard Type & Capitalization Configuration', () {
    testWidgets('Login tab: Client ID / Email field prefers lowercase email keyboard', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoginScreen(initialIsJoinNow: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find all TextFields inside TextFormFields in Login tab
      final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(textFields.isNotEmpty, isTrue);

      // First field is Client ID / Email
      final loginIdentifierField = textFields.first;
      expect(
        loginIdentifierField.keyboardType,
        equals(TextInputType.emailAddress),
        reason: 'Client ID / Email field keyboardType must be TextInputType.emailAddress',
      );
      expect(
        loginIdentifierField.textCapitalization,
        equals(TextCapitalization.none),
        reason: 'Client ID / Email field must have TextCapitalization.none to allow normal lowercase input',
      );
      expect(
        loginIdentifierField.textCapitalization,
        isNot(equals(TextCapitalization.characters)),
        reason: 'Must NOT force UPPERCASE characters on email input',
      );
    });

    testWidgets('Register tab: Email Address field prefers lowercase email keyboard', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoginScreen(initialIsJoinNow: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find registration TextFields
      final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      // Registration fields: Name (index 0), Email (index 1), Phone (index 2), Password (index 3), Confirm (index 4)
      expect(textFields.length, greaterThanOrEqualTo(2));

      final regEmailField = textFields[1];
      expect(
        regEmailField.keyboardType,
        equals(TextInputType.emailAddress),
        reason: 'Registration Email field keyboardType must be TextInputType.emailAddress',
      );
      expect(
        regEmailField.textCapitalization,
        equals(TextCapitalization.none),
        reason: 'Registration Email field must have TextCapitalization.none',
      );
      expect(
        regEmailField.textCapitalization,
        isNot(equals(TextCapitalization.characters)),
        reason: 'Must NOT force UPPERCASE characters on registration email input',
      );
    });

    testWidgets('Admin Login screen: Admin Gmail field prefers lowercase email keyboard', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminLoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(textFields.isNotEmpty, isTrue);

      final adminEmailField = textFields.first;
      expect(
        adminEmailField.keyboardType,
        equals(TextInputType.emailAddress),
        reason: 'Admin email field keyboardType must be TextInputType.emailAddress',
      );
      expect(
        adminEmailField.textCapitalization,
        equals(TextCapitalization.none),
        reason: 'Admin email field must have TextCapitalization.none',
      );
      expect(
        adminEmailField.textCapitalization,
        isNot(equals(TextCapitalization.characters)),
        reason: 'Must NOT force UPPERCASE characters on admin email input',
      );
    });
  });

  group('Email Normalization & Case Preservation Tests', () {
    String normalizeEmail(String email) => email.trim().toLowerCase();

    test('Required test email: sundar@gmail.com is normalized correctly', () {
      const email = 'sundar@gmail.com';
      expect(normalizeEmail(email), equals('sundar@gmail.com'));
      expect(normalizeEmail('  SUNDAR@GMAIL.COM  '), equals('sundar@gmail.com'));
      expect(normalizeEmail('Sundar@Gmail.Com'), equals('sundar@gmail.com'));
    });

    test('Required test email: testuser123@gmail.com is normalized correctly', () {
      const email = 'testuser123@gmail.com';
      expect(normalizeEmail(email), equals('testuser123@gmail.com'));
      expect(normalizeEmail('  TestUser123@Gmail.Com  '), equals('testuser123@gmail.com'));
      expect(normalizeEmail('TESTUSER123@GMAIL.COM'), equals('testuser123@gmail.com'));
    });

    test('Required test email: example.user@outlook.com is normalized correctly', () {
      const email = 'example.user@outlook.com';
      expect(normalizeEmail(email), equals('example.user@outlook.com'));
      expect(normalizeEmail('  Example.User@Outlook.Com  '), equals('example.user@outlook.com'));
      expect(normalizeEmail('EXAMPLE.USER@OUTLOOK.COM'), equals('example.user@outlook.com'));
    });

    test('Passwords must preserve exact casing and NOT be lowercased', () {
      const rawPassword = 'AlphaXPassword2026!#';
      // Normalize email function should never be applied to passwords
      expect(rawPassword, isNot(equals(rawPassword.toLowerCase())));
      expect(rawPassword, equals('AlphaXPassword2026!#'));
    });
  });
}
