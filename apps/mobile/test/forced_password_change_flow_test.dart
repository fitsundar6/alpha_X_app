import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/core/auth/forced_change_password_screen.dart';
import 'package:alpha_x_gym/core/auth/login_screen.dart';
import 'package:alpha_x_gym/core/constants/user_role.dart';
import 'package:alpha_x_gym/features/navigation/navigation_shell.dart';
import 'package:alpha_x_gym/features/navigation/role_router.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/activity/data/repositories/activity_repository.dart';
import 'package:alpha_x_gym/features/macro_planner/data/repositories/macro_repository.dart';
import 'package:alpha_x_gym/features/progress/data/repositories/weekly_progress_repository.dart';
import 'package:alpha_x_gym/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AuthService auth;
  late WorkoutRepository workoutRepo;
  late ActivityRepository activityRepo;
  late MacroRepository macroRepo;
  late WeeklyProgressRepository weeklyProgressRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    auth = AuthService();
    auth.resetForTesting();
    await auth.logout();
    workoutRepo = WorkoutRepository();
    activityRepo = ActivityRepository();
    macroRepo = MacroRepository();
    weeklyProgressRepo = WeeklyProgressRepository();
  });

  tearDown(() {
    auth.resetForTesting();
  });

  group('F-01 Forced Password Change State & Persistence Tests', () {
    test('1. AuthService initializes with mustChangePassword = false', () {
      expect(auth.mustChangePassword, isFalse);
    });

    test('2. Setting authenticated session with mustChangePassword = true reflects in getter', () {
      auth.setAuthenticatedSessionForTesting(
        userId: 'client_uuid_0002',
        clientId: 'AXG-0002',
        email: 'axg0002@alphax.test',
        role: UserRole.client,
        status: 'APPROVED',
        onboardingCompleted: true,
        mustChangePassword: true,
      );

      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentRole, UserRole.client);
      expect(auth.currentClientId, 'AXG-0002');
      expect(auth.mustChangePassword, isTrue);
    });

    test('3. Admin role always evaluates mustChangePassword = false even if flag was set', () {
      auth.setAuthenticatedSessionForTesting(
        userId: 'admin_uuid',
        clientId: 'AXG-ADMIN',
        email: 'admin@alphaxgym.com',
        role: UserRole.admin,
        status: 'APPROVED',
        mustChangePassword: true,
      );

      expect(auth.isAdmin, isTrue);
      expect(auth.mustChangePassword, isFalse);
    });

    test('4. Session persistence preserves mustChangePassword across restarts', () async {
      // Mock login response returning mustChangePassword = true
      auth.setHttpClientForTesting(MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'token': 'mock_jwt_token_forced',
                'clientId': 'AXG-0007',
                'mustChangePassword': true,
                'user': {
                  'id': 'uuid_axg_0007',
                  'email': 'axg0007@alphax.test',
                  'role': 'CLIENT',
                  'status': 'APPROVED',
                  'clientId': 'AXG-0007',
                  'mustChangePassword': true,
                  'onboardingCompleted': true,
                  'profile': {
                    'clientId': 'AXG-0007',
                    'name': 'Client Seven',
                    'onboardingCompleted': true,
                    'onboardingStep': 3,
                  },
                },
              },
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      }));

      final loginResult = await auth.loginWithCredentials(
        identifier: 'axg0007@alphax.test',
        password: 'TempPass123!',
      );

      expect(loginResult['role'], 'CLIENT');
      expect(loginResult['clientId'], 'AXG-0007');
      expect(loginResult['mustChangePassword'], isTrue);
      expect(auth.mustChangePassword, isTrue);
      expect(auth.currentClientId, 'AXG-0007');

      // Now create a fresh instance simulating app restart
      final restoredAuth = AuthService();
      await restoredAuth.initialize();

      expect(restoredAuth.isAuthenticated, isTrue);
      expect(restoredAuth.currentClientId, 'AXG-0007');
      expect(restoredAuth.mustChangePassword, isTrue);
    });

    test('5. checkVerificationStatus (/auth/me) updates mustChangePassword flag', () async {
      auth.setAuthenticatedSessionForTesting(
        userId: 'client_uuid_0002',
        clientId: 'AXG-0002',
        email: 'axg0002@alphax.test',
        role: UserRole.client,
        status: 'APPROVED',
        mustChangePassword: false,
      );
      expect(auth.mustChangePassword, isFalse);

      auth.setHttpClientForTesting(MockClient((request) async {
        if (request.url.path.endsWith('/auth/me')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': 'client_uuid_0002',
                'email': 'axg0002@alphax.test',
                'role': 'CLIENT',
                'status': 'APPROVED',
                'mustChangePassword': true,
                'clientId': 'AXG-0002',
                'onboardingCompleted': true,
              },
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      }));

      final res = await auth.checkVerificationStatus();
      expect(res['mustChangePassword'], isTrue);
      expect(auth.mustChangePassword, isTrue);
    });

    test('6. changePassword resets mustChangePassword to false and notifies listeners', () async {
      auth.setAuthenticatedSessionForTesting(
        userId: 'client_uuid_0002',
        clientId: 'AXG-0002',
        email: 'axg0002@alphax.test',
        role: UserRole.client,
        status: 'APPROVED',
        mustChangePassword: true,
      );
      expect(auth.mustChangePassword, isTrue);

      bool notified = false;
      auth.addListener(() {
        notified = true;
      });

      auth.setHttpClientForTesting(MockClient((request) async {
        if (request.url.path.endsWith('/auth/change-password')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'message': 'Password has been successfully updated.'},
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      }));

      final result = await auth.changePassword(
        currentPassword: 'OldPassword123!',
        newPassword: 'NewPassword123!',
        confirmPassword: 'NewPassword123!',
      );

      expect(result['success'], isTrue);
      expect(auth.mustChangePassword, isFalse);
      expect(notified, isTrue);
    });
  });

  group('F-01 Navigation & Route Guard Tests', () {
    test('7. getInitialScreen routes to ForcedChangePasswordScreen when mustChangePassword = true', () {
      auth.setAuthenticatedSessionForTesting(
        userId: 'client_uuid_0002',
        clientId: 'AXG-0002',
        email: 'axg0002@alphax.test',
        role: UserRole.client,
        status: 'APPROVED',
        onboardingCompleted: true,
        mustChangePassword: true,
      );

      final screen = getInitialScreen(
        authService: auth,
        workoutRepository: workoutRepo,
        activityRepository: activityRepo,
        macroRepository: macroRepo,
        weeklyProgressRepository: weeklyProgressRepo,
      );

      expect(screen, isA<ForcedChangePasswordScreen>());
    });

    test('8. getInitialScreen routes to NavigationShell when mustChangePassword = false', () {
      auth.setAuthenticatedSessionForTesting(
        userId: 'client_uuid_0002',
        clientId: 'AXG-0002',
        email: 'axg0002@alphax.test',
        role: UserRole.client,
        status: 'APPROVED',
        onboardingCompleted: true,
        mustChangePassword: false,
      );

      final screen = getInitialScreen(
        authService: auth,
        workoutRepository: workoutRepo,
        activityRepository: activityRepo,
        macroRepository: macroRepo,
        weeklyProgressRepository: weeklyProgressRepo,
      );

      expect(screen, isA<NavigationShell>());
    });

    test('9. buildAppRoute blocks /dashboard and redirects to ForcedChangePasswordScreen', () {
      auth.setAuthenticatedSessionForTesting(
        userId: 'client_uuid_0002',
        clientId: 'AXG-0002',
        email: 'axg0002@alphax.test',
        role: UserRole.client,
        status: 'APPROVED',
        onboardingCompleted: true,
        mustChangePassword: true,
      );

      final route = buildAppRoute(
        const RouteSettings(name: '/dashboard'),
        authService: auth,
        workoutRepository: workoutRepo,
        activityRepository: activityRepo,
        macroRepository: macroRepo,
        weeklyProgressRepository: weeklyProgressRepo,
      );

      expect(route, isNotNull);
      final page = (route as MaterialPageRoute).builder(FakeBuildContext());
      expect(page, isA<ForcedChangePasswordScreen>());
    });

    test('10. buildAppRoute blocks /onboarding and redirects to ForcedChangePasswordScreen', () {
      auth.setAuthenticatedSessionForTesting(
        userId: 'client_uuid_0002',
        clientId: 'AXG-0002',
        email: 'axg0002@alphax.test',
        role: UserRole.client,
        status: 'APPROVED',
        onboardingCompleted: false,
        mustChangePassword: true,
      );

      final route = buildAppRoute(
        const RouteSettings(name: '/onboarding'),
        authService: auth,
        workoutRepository: workoutRepo,
        activityRepository: activityRepo,
        macroRepository: macroRepo,
        weeklyProgressRepository: weeklyProgressRepo,
      );

      expect(route, isNotNull);
      final page = (route as MaterialPageRoute).builder(FakeBuildContext());
      expect(page, isA<ForcedChangePasswordScreen>());
    });

    test('11. buildAppRoute blocks /client/workout and redirects to ForcedChangePasswordScreen', () {
      auth.setAuthenticatedSessionForTesting(
        userId: 'client_uuid_0002',
        clientId: 'AXG-0002',
        email: 'axg0002@alphax.test',
        role: UserRole.client,
        status: 'APPROVED',
        onboardingCompleted: true,
        mustChangePassword: true,
      );

      final route = buildAppRoute(
        const RouteSettings(name: '/client/workout'),
        authService: auth,
        workoutRepository: workoutRepo,
        activityRepository: activityRepo,
        macroRepository: macroRepo,
        weeklyProgressRepository: weeklyProgressRepo,
      );

      expect(route, isNotNull);
      final page = (route as MaterialPageRoute).builder(FakeBuildContext());
      expect(page, isA<ForcedChangePasswordScreen>());
    });

    test('12. buildAppRoute allows /forced-change-password for authenticated client', () {
      auth.setAuthenticatedSessionForTesting(
        userId: 'client_uuid_0002',
        clientId: 'AXG-0002',
        email: 'axg0002@alphax.test',
        role: UserRole.client,
        status: 'APPROVED',
        mustChangePassword: true,
      );

      final route = buildAppRoute(
        const RouteSettings(name: '/forced-change-password'),
        authService: auth,
      );

      expect(route, isNotNull);
      final page = (route as MaterialPageRoute).builder(FakeBuildContext());
      expect(page, isA<ForcedChangePasswordScreen>());
    });

    test('13. buildAppRoute redirects unauthenticated user from /forced-change-password to LoginScreen', () {
      expect(auth.isAuthenticated, isFalse);

      final route = buildAppRoute(
        const RouteSettings(name: '/forced-change-password'),
        authService: auth,
      );

      expect(route, isNotNull);
      final page = (route as MaterialPageRoute).builder(FakeBuildContext());
      expect(page, isA<LoginScreen>());
    });

    testWidgets('14. RoleRouter renders ForcedChangePasswordScreen when mustChangePassword = true', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      auth.setAuthenticatedSessionForTesting(
        userId: 'client_uuid_0002',
        clientId: 'AXG-0002',
        email: 'axg0002@alphax.test',
        role: UserRole.client,
        status: 'APPROVED',
        onboardingCompleted: true,
        mustChangePassword: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RoleRouter(
            workoutRepository: workoutRepo,
            activityRepository: activityRepo,
            macroRepository: macroRepo,
            weeklyProgressRepository: weeklyProgressRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ForcedChangePasswordScreen), findsOneWidget);
      expect(find.text('PASSWORD UPDATE REQUIRED'), findsOneWidget);
    });
  });

  group('F-01 ForcedChangePasswordScreen Widget & Interaction Tests', () {
    testWidgets('15. Screen renders athlete badge, email, and 3 password fields', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      auth.setAuthenticatedSessionForTesting(
        userId: 'client_uuid_0002',
        clientId: 'AXG-0002',
        email: 'axg0002@alphax.test',
        role: UserRole.client,
        status: 'APPROVED',
        onboardingCompleted: true,
        mustChangePassword: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: ForcedChangePasswordScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PASSWORD UPDATE REQUIRED'), findsOneWidget);
      expect(find.text('AXG-0002'), findsOneWidget);
      expect(find.text('axg0002@alphax.test'), findsOneWidget);
      expect(find.text('CURRENT TEMPORARY PASSWORD'), findsOneWidget);
      expect(find.text('NEW PERMANENT PASSWORD'), findsOneWidget);
      expect(find.text('CONFIRM NEW PASSWORD'), findsOneWidget);
      expect(find.text('UPDATE PASSWORD & CONTINUE'), findsOneWidget);
      expect(find.text('Sign Out / Login with another account'), findsOneWidget);
    });

    testWidgets('16. Form validation blocks empty inputs and shows error messages', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      auth.setAuthenticatedSessionForTesting(
        userId: 'client_uuid_0002',
        clientId: 'AXG-0002',
        email: 'axg0002@alphax.test',
        role: UserRole.client,
        status: 'APPROVED',
        onboardingCompleted: true,
        mustChangePassword: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: ForcedChangePasswordScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap submit with empty fields
      await tester.tap(find.text('UPDATE PASSWORD & CONTINUE'));
      await tester.pumpAndSettle();

      expect(find.text('Current password is required.'), findsOneWidget);
      expect(find.text('New password is required.'), findsOneWidget);
      expect(find.text('Please confirm your new password.'), findsOneWidget);
    });

    testWidgets('17. Form validation blocks identical current and new password', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      auth.setAuthenticatedSessionForTesting(
        userId: 'client_uuid_0002',
        clientId: 'AXG-0002',
        email: 'axg0002@alphax.test',
        role: UserRole.client,
        status: 'APPROVED',
        onboardingCompleted: true,
        mustChangePassword: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: ForcedChangePasswordScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'SamePassword123!');
      await tester.enterText(textFields.at(1), 'SamePassword123!');
      await tester.enterText(textFields.at(2), 'SamePassword123!');

      await tester.tap(find.text('UPDATE PASSWORD & CONTINUE'));
      await tester.pumpAndSettle();

      expect(find.text('New password must be different from current password.'), findsOneWidget);
    });

    testWidgets('18. Form validation blocks mismatched password confirmation', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      auth.setAuthenticatedSessionForTesting(
        userId: 'client_uuid_0002',
        clientId: 'AXG-0002',
        email: 'axg0002@alphax.test',
        role: UserRole.client,
        status: 'APPROVED',
        onboardingCompleted: true,
        mustChangePassword: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: ForcedChangePasswordScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'CurrentTemp123!');
      await tester.enterText(textFields.at(1), 'BrandNewPass123!');
      await tester.enterText(textFields.at(2), 'TypoInNewPass123!');

      await tester.tap(find.text('UPDATE PASSWORD & CONTINUE'));
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match.'), findsOneWidget);
    });

    testWidgets('19. Successful password submission navigates to dashboard when onboarding complete', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      auth.setAuthenticatedSessionForTesting(
        userId: 'client_uuid_0002',
        clientId: 'AXG-0002',
        email: 'axg0002@alphax.test',
        role: UserRole.client,
        status: 'APPROVED',
        onboardingCompleted: true,
        mustChangePassword: true,
      );

      auth.setHttpClientForTesting(MockClient((request) async {
        if (request.url.path.endsWith('/auth/change-password')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'message': 'Password has been successfully updated.'},
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      }));

      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/forced-change-password',
          routes: {
            '/forced-change-password': (context) => const ForcedChangePasswordScreen(),
            '/dashboard': (context) => const Scaffold(body: Text('DASHBOARD_LANDING_PAGE')),
            '/onboarding': (context) => const Scaffold(body: Text('ONBOARDING_LANDING_PAGE')),
          },
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'CurrentTemp123!');
      await tester.enterText(textFields.at(1), 'BrandNewPass123!');
      await tester.enterText(textFields.at(2), 'BrandNewPass123!');

      await tester.tap(find.text('UPDATE PASSWORD & CONTINUE'));
      await tester.pumpAndSettle();

      expect(find.text('DASHBOARD_LANDING_PAGE'), findsOneWidget);
      expect(auth.mustChangePassword, isFalse);
    });

    testWidgets('20. Tapping Sign Out calls logout and navigates to login route', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      auth.setAuthenticatedSessionForTesting(
        userId: 'client_uuid_0002',
        clientId: 'AXG-0002',
        email: 'axg0002@alphax.test',
        role: UserRole.client,
        status: 'APPROVED',
        onboardingCompleted: true,
        mustChangePassword: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/forced-change-password',
          routes: {
            '/forced-change-password': (context) => const ForcedChangePasswordScreen(),
            '/login': (context) => const Scaffold(body: Text('LOGIN_SCREEN_LANDING')),
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Sign Out / Login with another account'));
      await tester.tap(find.text('Sign Out / Login with another account'));
      await tester.pumpAndSettle();

      expect(auth.isAuthenticated, isFalse);
      expect(find.text('LOGIN_SCREEN_LANDING'), findsOneWidget);
    });
  });
}

class FakeBuildContext extends Fake implements BuildContext {}
