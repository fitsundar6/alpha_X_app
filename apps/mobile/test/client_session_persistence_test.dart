import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alpha_x_gym/main.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/core/auth/login_screen.dart';
import 'package:alpha_x_gym/core/auth/secure_token_storage.dart';
import 'package:alpha_x_gym/features/navigation/navigation_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Alpha X Gym - Client Session Persistence & Security Suite', () {
    late AuthService auth;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      LoginScreen.hasPlayedIntro = false;
      auth = AuthService();
      auth.resetForTesting();
    });

    test('1. Valid client session restored on startup into authenticated state', () async {
      final sessionData = {
        'role': 'CLIENT',
        'id': 'athlete_persist_01',
        'clientId': 'AXG-0005',
        'email': 'ajay@alphaxgym.com',
        'name': 'Ajay Athlete',
        'onboardingCompleted': true,
        'status': 'APPROVED',
        'token': 'mock_valid_session_token',
      };

      await SecureTokenStorage.writeAuthToken('mock_valid_session_token');
      await SecureTokenStorage.writeSessionData(sessionData);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('alpha_x_local_active_session', jsonEncode(sessionData));

      // Execute cold-boot startup initialization
      await auth.initialize();

      expect(auth.isAuthenticated, isTrue);
      expect(auth.isClient, isTrue);
      expect(auth.isAdmin, isFalse);
      expect(auth.currentClientId, equals('AXG-0005'));
      expect(auth.currentUserName, equals('Ajay Athlete'));
      expect(auth.currentUserEmail, equals('ajay@alphaxgym.com'));
      expect(auth.token, equals('mock_valid_session_token'));
    });

    testWidgets('2. Cold boot with valid session directly opens Client Dashboard (no login screen)', (tester) async {
      final sessionData = {
        'role': 'CLIENT',
        'id': 'athlete_persist_02',
        'clientId': 'AXG-0005',
        'email': 'ajay@alphaxgym.com',
        'name': 'Ajay Athlete',
        'onboardingCompleted': true,
        'status': 'APPROVED',
        'token': 'mock_valid_session_token',
      };

      await SecureTokenStorage.writeAuthToken('mock_valid_session_token');
      await SecureTokenStorage.writeSessionData(sessionData);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('alpha_x_local_active_session', jsonEncode(sessionData));

      await auth.initialize();
      expect(auth.isAuthenticated, isTrue);

      await tester.pumpWidget(const AlphaXGymApp());
      await tester.pump();

      // Settle startup animation
      await tester.pumpAndSettle();

      // NavigationShell (Client Dashboard) mounted directly
      expect(find.byType(NavigationShell), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    test('3. Passwords are NEVER persisted in plain text in local storage', () async {
      final prefs = await SharedPreferences.getInstance();

      // Simulate client registration / local account save
      await auth.registerClientAccount(
        name: 'Secure Athlete',
        email: 'secure_athlete@alphaxgym.com',
        phone: '+91 98765 43210',
        password: 'SuperSecretPassword123!',
        confirmPassword: 'SuperSecretPassword123!',
      );

      final rawAccounts = prefs.getString('alpha_x_local_client_accounts');
      if (rawAccounts != null && rawAccounts.isNotEmpty) {
        expect(rawAccounts.contains('SuperSecretPassword123!'), isFalse,
            reason: 'Plain text password must never appear in SharedPreferences client accounts');
      }

      final rawSession = prefs.getString('alpha_x_local_active_session');
      if (rawSession != null && rawSession.isNotEmpty) {
        expect(rawSession.contains('SuperSecretPassword123!'), isFalse,
            reason: 'Plain text password must never appear in active session storage');
      }
    });

    test('4. Explicit logout securely wipes SecureTokenStorage and SharedPreferences', () async {
      final sessionData = {
        'role': 'CLIENT',
        'id': 'athlete_persist_04',
        'clientId': 'AXG-0005',
        'email': 'ajay@alphaxgym.com',
        'token': 'token_to_purge',
      };

      await SecureTokenStorage.writeAuthToken('token_to_purge');
      await SecureTokenStorage.writeSessionData(sessionData);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('alpha_x_local_active_session', jsonEncode(sessionData));

      await auth.initialize();
      expect(auth.isAuthenticated, isTrue);

      // Perform user logout
      await auth.logout();

      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentToken, isEmpty);

      // Verify all local storage keys are purged
      final secureToken = await SecureTokenStorage.readAuthToken();
      final secureSession = await SecureTokenStorage.readSessionData();
      final prefsSession = prefs.getString('alpha_x_local_active_session');

      expect(secureToken, isNull);
      expect(secureSession, isNull);
      expect(prefsSession, isNull);
    });

    test('5. Role isolation: Client session cannot restore as Admin, and Admin cannot restore as Client', () async {
      final corruptedSession = {
        'role': 'CLIENT',
        'id': 'admin_imposter',
        'clientId': 'AXG-ADMIN',
        'email': 'fitsundar6@gmail.com', // Admin email tagged as CLIENT
        'token': 'imposter_token',
      };

      await SecureTokenStorage.writeAuthToken('imposter_token');
      await SecureTokenStorage.writeSessionData(corruptedSession);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('alpha_x_local_active_session', jsonEncode(corruptedSession));

      // Attempt initialization with imposter credentials
      await auth.initialize();

      // Must be safely rejected and logged out
      expect(auth.isAuthenticated, isFalse);
      expect(auth.isAdmin, isFalse);
    });

    testWidgets('6. After logout, subsequent app launch correctly displays LoginScreen', (tester) async {
      await auth.logout();

      await tester.pumpWidget(const AlphaXGymApp());
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(NavigationShell), findsNothing);
    });

    test('7. Offline resilience: Valid cached session maintains authentication without network', () async {
      final sessionData = {
        'role': 'CLIENT',
        'id': 'offline_athlete_07',
        'clientId': 'AXG-0007',
        'email': 'offline@alphaxgym.com',
        'name': 'Offline Athlete',
        'onboardingCompleted': true,
        'status': 'APPROVED',
        'token': 'valid_offline_token',
      };

      await SecureTokenStorage.writeAuthToken('valid_offline_token');
      await SecureTokenStorage.writeSessionData(sessionData);

      // Initialize offline
      await auth.initialize();

      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentClientId, equals('AXG-0007'));
      expect(auth.currentUserName, equals('Offline Athlete'));
    });
  });
}
