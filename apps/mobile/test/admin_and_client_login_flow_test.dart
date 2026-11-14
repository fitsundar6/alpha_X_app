import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/core/auth/secure_token_storage.dart';
import 'package:alpha_x_gym/core/auth/login_screen.dart';
import 'package:alpha_x_gym/core/auth/admin_login_screen.dart';
import 'package:alpha_x_gym/core/constants/user_role.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Focused Admin & Client Login Flow Verification', () {
    late AuthService auth;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      auth = AuthService();
      await auth.logout();
      auth.setHttpClientForTesting(null);
      AuthService.setTestAdminCredentials(email: null, password: null);
    });

    tearDown(() async {
      await auth.logout();
      auth.setHttpClientForTesting(null);
      AuthService.setTestAdminCredentials(email: null, password: null);
    });

    test('1A. AuthService.loginWithCredentials recognizes ADMIN role returned from /auth/login', () async {
      const adminToken = 'mock_jwt_admin_token_abcdef';
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/auth/login')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final id = body['clientIdOrEmail'] ?? body['email'] ?? body['identifier'];
          if (id == 'fitsundar6@gmail.com' && body['password'] == 'AlphaXAdmin2026!') {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'token': adminToken,
                  'user': {
                    'id': 'admin_fitsundar6',
                    'email': 'fitsundar6@gmail.com',
                    'name': 'Fit Sundar Admin',
                    'role': 'ADMIN',
                  },
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
        }
        return http.Response(jsonEncode({'success': false, 'message': 'Invalid credentials'}), 401);
      });

      auth.setHttpClientForTesting(mockClient);

      final result = await auth.loginWithCredentials(
        identifier: 'fitsundar6@gmail.com',
        password: 'AlphaXAdmin2026!',
      );

      expect(result['role'], 'ADMIN');
      expect(result['clientId'], 'AXG-ADMIN');
      expect(auth.isAdmin, isTrue);
      expect(auth.isClient, isFalse);
      expect(auth.currentRole, UserRole.admin);
      expect(auth.currentUserEmail, 'fitsundar6@gmail.com');
      expect(auth.isAuthenticated, isTrue);

      final storedToken = await SecureTokenStorage.readAuthToken();
      expect(storedToken, adminToken);
    });

    test('1B. AuthService.adminLogin succeeds with /admin/login endpoint', () async {
      const adminToken = 'mock_jwt_admin_direct_token_xyz';
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/admin/login')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['email'] == 'fitsundar6@gmail.com' && body['password'] == 'AlphaXAdmin2026!') {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'token': adminToken,
                  'user': {
                    'id': 'admin_fitsundar6',
                    'email': 'fitsundar6@gmail.com',
                    'name': 'Fit Sundar Admin',
                    'role': 'ADMIN',
                  },
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
        }
        return http.Response(jsonEncode({'success': false, 'message': 'Invalid credentials'}), 401);
      });

      auth.setHttpClientForTesting(mockClient);

      await auth.adminLogin(
        email: 'fitsundar6@gmail.com',
        password: 'AlphaXAdmin2026!',
      );

      expect(auth.isAdmin, isTrue);
      expect(auth.isClient, isFalse);
      expect(auth.currentRole, UserRole.admin);
      expect(auth.currentUserEmail, 'fitsundar6@gmail.com');
      expect(auth.isAuthenticated, isTrue);

      final storedToken = await SecureTokenStorage.readAuthToken();
      expect(storedToken, adminToken);
    });

    test('2. AuthService.loginWithCredentials authenticates CLIENT and sets client role', () async {
      const clientToken = 'mock_jwt_client_token_123456';
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/auth/login')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'token': clientToken,
                'clientId': 'AXG-1001',
                'user': {
                  'id': 'user_athlete_1',
                  'email': 'athlete@example.com',
                  'name': 'John Athlete',
                  'role': 'CLIENT',
                  'clientId': 'AXG-1001',
                },
                'onboardingCompleted': true,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(jsonEncode({'success': false}), 400);
      });

      auth.setHttpClientForTesting(mockClient);

      final result = await auth.loginWithCredentials(
        identifier: 'athlete@example.com',
        password: 'ClientPassword123!',
      );

      expect(result['role'], 'CLIENT');
      expect(result['clientId'], 'AXG-1001');
      expect(auth.isAdmin, isFalse);
      expect(auth.isClient, isTrue);
      expect(auth.currentRole, UserRole.client);
      expect(auth.isAuthenticated, isTrue);
    });

    testWidgets('3. LoginScreen routes Admin to /admin on successful admin login', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/auth/login')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'token': 'mock_admin_token',
                'user': {
                  'id': 'admin_1',
                  'email': 'fitsundar6@gmail.com',
                  'name': 'Admin',
                  'role': 'ADMIN',
                },
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 400);
      });

      auth.setHttpClientForTesting(mockClient);

      bool navigatedToAdmin = false;

      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) {
            if (settings.name == '/admin') {
              navigatedToAdmin = true;
              return MaterialPageRoute(
                builder: (_) => const Scaffold(body: Text('ADMIN_DASHBOARD_LANDING')),
              );
            }
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          },
        ),
      );
      await tester.pumpAndSettle();

      // Enter admin credentials
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Client ID / Email'),
        'fitsundar6@gmail.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'AlphaXAdmin2026!',
      );

      // Tap Login button
      await tester.tap(find.widgetWithText(ElevatedButton, 'CLIENT LOGIN'));
      await tester.pumpAndSettle();

      expect(navigatedToAdmin, isTrue);
      expect(find.text('ADMIN_DASHBOARD_LANDING'), findsOneWidget);
      expect(auth.isAdmin, isTrue);
    });

    testWidgets('4. LoginScreen routes Client to /dashboard on completed client login', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/auth/login')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'token': 'mock_client_token',
                'clientId': 'AXG-2002',
                'user': {
                  'id': 'user_2',
                  'email': 'athlete@alphaxgym.com',
                  'name': 'Athlete Bob',
                  'role': 'CLIENT',
                  'clientId': 'AXG-2002',
                },
                'assessmentCompleted': true,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 400);
      });

      auth.setHttpClientForTesting(mockClient);

      bool navigatedToDashboard = false;

      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) {
            if (settings.name == '/dashboard') {
              navigatedToDashboard = true;
              return MaterialPageRoute(
                builder: (_) => const Scaffold(body: Text('CLIENT_DASHBOARD_LANDING')),
              );
            }
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          },
        ),
      );
      await tester.pumpAndSettle();

      // Enter client credentials
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Client ID / Email'),
        'AXG-2002',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'AthleteSecret1!',
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'CLIENT LOGIN'));
      await tester.pumpAndSettle();

      expect(navigatedToDashboard, isTrue);
      expect(find.text('CLIENT_DASHBOARD_LANDING'), findsOneWidget);
      expect(auth.isClient, isTrue);
    });

    testWidgets('5. AdminLoginScreen authorizes Admin and routes to /admin', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/admin/login')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'token': 'mock_admin_token_from_admin_login',
                'user': {
                  'id': 'admin_fitsundar6',
                  'email': 'fitsundar6@gmail.com',
                  'name': 'Fit Sundar Admin',
                  'role': 'ADMIN',
                },
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 401);
      });

      auth.setHttpClientForTesting(mockClient);

      bool navigatedToAdmin = false;

      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) {
            if (settings.name == '/admin') {
              navigatedToAdmin = true;
              return MaterialPageRoute(
                builder: (_) => const Scaffold(body: Text('ADMIN_DASHBOARD_LANDING')),
              );
            }
            return MaterialPageRoute(builder: (_) => const AdminLoginScreen());
          },
        ),
      );
      await tester.pumpAndSettle();

      // Enter credentials
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Admin Gmail'),
        'fitsundar6@gmail.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'AlphaXAdmin2026!',
      );

      // Tap authenticate button
      await tester.tap(find.widgetWithText(ElevatedButton, 'AUTHENTICATE ADMINISTRATOR'));
      await tester.pumpAndSettle();

      expect(navigatedToAdmin, isTrue);
      expect(find.text('ADMIN_DASHBOARD_LANDING'), findsOneWidget);
      expect(auth.isAdmin, isTrue);
    });
  });
}
