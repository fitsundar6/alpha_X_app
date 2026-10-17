import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:alpha_x_gym/main.dart';
import 'package:alpha_x_gym/core/constants/user_role.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/core/auth/login_screen.dart';
import 'package:alpha_x_gym/core/auth/secure_token_storage.dart';
import 'package:alpha_x_gym/core/services/app_auto_refresh_service.dart';
import 'package:alpha_x_gym/features/navigation/navigation_shell.dart';

String buildJwt({required int expSeconds, String id = 'test_id', String email = 'athlete@alphaxgym.com'}) {
  final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'}))).replaceAll('=', '');
  final payload = base64Url.encode(utf8.encode(jsonEncode({
    'id': id,
    'email': email,
    'role': 'CLIENT',
    'exp': expSeconds,
  }))).replaceAll('=', '');
  return '$header.$payload.mock_signature';
}

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
      expect(auth.rawToken, isEmpty);

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

    test('8. App restart with expired JWT: token refresh succeeds and preserves authenticated session', () async {
      final pastExp = DateTime.now().toUtc().subtract(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000;
      final futureExp = DateTime.now().toUtc().add(const Duration(days: 7)).millisecondsSinceEpoch ~/ 1000;
      final expiredToken = buildJwt(expSeconds: pastExp);
      final freshToken = buildJwt(expSeconds: futureExp);

      final sessionData = {
        'role': 'CLIENT',
        'id': 'athlete_persist_08',
        'clientId': 'AXG-0008',
        'email': 'athlete08@alphaxgym.com',
        'name': 'Refreshed Athlete',
        'onboardingCompleted': true,
        'status': 'APPROVED',
        'token': expiredToken,
      };

      await SecureTokenStorage.writeAuthToken(expiredToken);
      await SecureTokenStorage.writeSessionData(sessionData);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('alpha_x_local_active_session', jsonEncode(sessionData));

      // Inject mock HTTP client that returns fresh token on POST /auth/refresh
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/auth/refresh')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'token': freshToken},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });
      auth.setHttpClientForTesting(mockClient);

      // Perform cold-boot startup initialization
      await auth.initialize();

      expect(auth.isAuthenticated, isTrue);
      expect(auth.token, equals(freshToken));
      expect(auth.isTokenExpired, isFalse);

      final storedToken = await SecureTokenStorage.readAuthToken();
      expect(storedToken, equals(freshToken));
    });

    test('9. App restart with expired JWT while offline (network failure): preserves session and does NOT logout', () async {
      final pastExp = DateTime.now().toUtc().subtract(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000;
      final expiredToken = buildJwt(expSeconds: pastExp);

      final sessionData = {
        'role': 'CLIENT',
        'id': 'athlete_persist_09',
        'clientId': 'AXG-0009',
        'email': 'offline09@alphaxgym.com',
        'name': 'Offline Athlete 09',
        'onboardingCompleted': true,
        'status': 'APPROVED',
        'token': expiredToken,
      };

      await SecureTokenStorage.writeAuthToken(expiredToken);
      await SecureTokenStorage.writeSessionData(sessionData);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('alpha_x_local_active_session', jsonEncode(sessionData));

      // Mock network failure (e.g. SocketException / ClientException)
      final mockClient = MockClient((request) async {
        throw http.ClientException('Network unreachable (Offline mode)');
      });
      auth.setHttpClientForTesting(mockClient);

      // Cold-boot startup while offline
      await auth.initialize();

      // Session MUST be preserved!
      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentClientId, equals('AXG-0009'));
      expect(auth.currentUserName, equals('Offline Athlete 09'));
      expect(auth.token, equals(expiredToken));
    });

    test('10. App restart with expired JWT and confirmed unrecoverable failure (401 TOKEN_EXPIRED): explicitly purges session', () async {
      final pastExp = DateTime.now().toUtc().subtract(const Duration(days: 35)).millisecondsSinceEpoch ~/ 1000;
      final expiredToken = buildJwt(expSeconds: pastExp);

      final sessionData = {
        'role': 'CLIENT',
        'id': 'athlete_persist_10',
        'clientId': 'AXG-0010',
        'email': 'expired10@alphaxgym.com',
        'name': 'Expired Athlete 10',
        'onboardingCompleted': true,
        'status': 'APPROVED',
        'token': expiredToken,
      };

      await SecureTokenStorage.writeAuthToken(expiredToken);
      await SecureTokenStorage.writeSessionData(sessionData);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('alpha_x_local_active_session', jsonEncode(sessionData));

      // Mock backend 401 response for expired token beyond grace period
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'error': {
              'code': 'TOKEN_EXPIRED',
              'message': 'Session has expired beyond recovery. Please log in again.',
            },
          }),
          401,
          headers: {'content-type': 'application/json'},
        );
      });
      auth.setHttpClientForTesting(mockClient);

      // Cold-boot startup
      await auth.initialize();

      // Confirmed unrecoverable failure -> explicitly logged out
      expect(auth.isAuthenticated, isFalse);
      expect(auth.rawToken, isEmpty);

      final storedToken = await SecureTokenStorage.readAuthToken();
      expect(storedToken, isNull);
    });

    testWidgets('11. Cold boot with expired JWT directly opens Client Dashboard (no premature logout)', (tester) async {
      final pastExp = DateTime.now().toUtc().subtract(const Duration(hours: 5)).millisecondsSinceEpoch ~/ 1000;
      final expiredToken = buildJwt(expSeconds: pastExp);

      final sessionData = {
        'role': 'CLIENT',
        'id': 'athlete_persist_11',
        'clientId': 'AXG-0011',
        'email': 'athlete11@alphaxgym.com',
        'name': 'Athlete 11',
        'onboardingCompleted': true,
        'status': 'APPROVED',
        'token': expiredToken,
      };

      await SecureTokenStorage.writeAuthToken(expiredToken);
      await SecureTokenStorage.writeSessionData(sessionData);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('alpha_x_local_active_session', jsonEncode(sessionData));

      // Network unreachable
      final mockClient = MockClient((request) async {
        throw http.ClientException('Network unreachable');
      });
      auth.setHttpClientForTesting(mockClient);

      await auth.initialize();
      expect(auth.isAuthenticated, isTrue);

      await tester.pumpWidget(const AlphaXGymApp());
      await tester.pump();
      await tester.pumpAndSettle();

      // NavigationShell (Client Dashboard) mounted, user is NOT kicked out to LoginScreen
      expect(find.byType(NavigationShell), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    test('12. App background / resume with expired JWT triggers proactive token refresh without logout', () async {
      final pastExp = DateTime.now().toUtc().subtract(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000;
      final futureExp = DateTime.now().toUtc().add(const Duration(days: 7)).millisecondsSinceEpoch ~/ 1000;
      final expiredToken = buildJwt(expSeconds: pastExp);
      final freshToken = buildJwt(expSeconds: futureExp);

      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'resume@alphaxgym.com',
        userId: 'athlete_resume_12',
        clientId: 'AXG-0012',
        userName: 'Resume Athlete',
        token: expiredToken,
      );

      bool refreshCalled = false;
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/auth/refresh')) {
          refreshCalled = true;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'token': freshToken},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      });
      auth.setHttpClientForTesting(mockClient);

      expect(auth.isTokenExpired, isTrue);

      // Simulate app resuming from background
      AppAutoRefreshService.instance.didChangeAppLifecycleState(AppLifecycleState.resumed);

      // Allow background microtask / future to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(auth.isAuthenticated, isTrue);
      expect(refreshCalled, isTrue);
      expect(auth.token, equals(freshToken));
    });

    test('13. Normal API 500 error or temporary network failure does not clear user session', () async {
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'stable@alphaxgym.com',
        userId: 'athlete_stable_13',
        clientId: 'AXG-0013',
        userName: 'Stable Athlete',
        token: 'active_valid_token',
      );

      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });
      auth.setHttpClientForTesting(mockClient);

      // Trigger sync pass with 500 error
      await AppAutoRefreshService.instance.triggerImmediateSync(reason: 'Test Trigger');

      // User session MUST remain intact
      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentClientId, equals('AXG-0013'));
    });
  });
}
