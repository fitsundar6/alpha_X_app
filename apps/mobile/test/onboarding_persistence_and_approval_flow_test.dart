import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/core/auth/pending_verification_screen.dart';
import 'package:alpha_x_gym/core/constants/app_constants.dart';
import 'package:alpha_x_gym/features/navigation/navigation_shell.dart';
import 'package:alpha_x_gym/features/onboarding/client_onboarding_screen.dart';
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

  group('Onboarding Persistence & Admin Approval Flow Tests', () {
    test('1. First-time registration creates account with PENDING status and incomplete assessment', () async {
      final res = await auth.registerClientAccount(
        name: 'Jordan Sparks',
        email: 'jordan.sparks@example.com',
        phone: '+1 (555) 123-4567',
        password: 'Password123!',
        confirmPassword: 'Password123!',
      );

      expect(res['clientId'], startsWith('AXG-'));
      expect(auth.isAuthenticated, isTrue);
      expect(auth.isClient, isTrue);
      expect(auth.userStatus, 'PENDING');
      expect(auth.isPending, isTrue);
      expect(auth.isApproved, isFalse);
      expect(auth.onboardingCompleted, isFalse);
      expect(auth.assessmentCompleted, isFalse);

      final initialScreen = getInitialScreen(
        authService: auth,
        workoutRepository: workoutRepo,
        activityRepository: activityRepo,
        macroRepository: macroRepo,
        weeklyProgressRepository: weeklyProgressRepo,
      );
      expect(initialScreen, isA<PendingVerificationScreen>());
    });

    test('2. Admin approval updates user status to APPROVED without marking assessment complete', () async {
      await auth.registerClientAccount(
        name: 'Alex Mercer',
        email: 'alex.mercer@example.com',
        phone: '+1 (555) 987-6543',
        password: 'Password123!',
        confirmPassword: 'Password123!',
      );
      expect(auth.isPending, isTrue);
      expect(auth.onboardingCompleted, isFalse);

      // Mock backend /auth/me returning APPROVED status from Admin approval
      auth.setHttpClientForTesting(MockClient((request) async {
        if (request.url.path.endsWith('/auth/me')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': 'user_alex_1',
                'email': 'alex.mercer@example.com',
                'name': 'Alex Mercer',
                'role': 'CLIENT',
                'status': 'APPROVED',
                'assessmentCompleted': false,
                'onboardingCompleted': false,
                'onboardingStep': 0,
                'profile': {
                  'clientId': 'AXG-1002',
                  'onboardingCompleted': false,
                  'onboardingStep': 0,
                },
              },
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      }));

      final result = await auth.checkVerificationStatus();

      expect(result['status'], 'APPROVED');
      expect(result['isApproved'], isTrue);
      expect(result['onboardingCompleted'], isFalse);
      expect(result['assessmentCompleted'], isFalse);

      // Verify AuthService state: Approved, but assessment is genuinely incomplete
      expect(auth.isApproved, isTrue);
      expect(auth.isPending, isFalse);
      expect(auth.onboardingCompleted, isFalse);

      // Route check: Approved user with incomplete assessment routes to ClientOnboardingScreen
      final initialScreen = getInitialScreen(
        authService: auth,
        workoutRepository: workoutRepo,
        activityRepository: activityRepo,
        macroRepository: macroRepo,
        weeklyProgressRepository: weeklyProgressRepo,
      );
      expect(initialScreen, isA<ClientOnboardingScreen>());
    });

    test('3. Successful assessment submission persists completion to backend and SharedPreferences', () async {
      await auth.registerClientAccount(
        name: 'Taylor Swift',
        email: 'taylor.swift@example.com',
        phone: '+1 (555) 333-4444',
        password: 'Password123!',
        confirmPassword: 'Password123!',
      );

      // Mock backend profile update
      auth.setHttpClientForTesting(MockClient((request) async {
        if (request.url.path.contains('/client/me/profile') || request.url.path.contains('/auth/onboarding')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['onboardingCompleted'], isTrue);
          expect(body['assessmentCompleted'], isTrue);
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'message': 'Fitness assessment saved successfully',
                'assessmentCompleted': true,
                'onboardingCompleted': true,
                'onboardingStep': 10,
                'profile': {
                  'clientId': auth.currentClientId,
                  'fitnessLevel': body['fitnessLevel'],
                  'primaryGoal': body['primaryGoal'],
                  'weightKg': body['weightKg'],
                  'heightCm': body['heightCm'],
                  'onboardingCompleted': true,
                  'onboardingStep': 10,
                },
              },
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      }));

      // Submit assessment step 10 as complete
      await auth.saveOnboardingStep({
        'fitnessLevel': 'INTERMEDIATE',
        'primaryGoal': 'Strength',
        'weightKg': 75.0,
        'heightCm': 180.0,
      }, step: 10, isComplete: true);

      expect(auth.onboardingCompleted, isTrue);
      expect(auth.assessmentCompleted, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppConstants.onboardingCompleteKey), isTrue);
      if (auth.currentClientId.isNotEmpty) {
        expect(prefs.getBool('${AppConstants.onboardingCompleteKey}_${auth.currentClientId}'), isTrue);
      }
    });

    test('4. App restart restores approved client with completed assessment directly to NavigationShell', () async {
      // Setup persisted approved session with completed onboarding
      final sessionData = {
        'role': 'CLIENT',
        'id': 'user_completed_1',
        'clientId': 'AXG-8888',
        'email': 'completed.athlete@example.com',
        'name': 'Completed Athlete',
        'status': 'APPROVED',
        'onboardingCompleted': true,
        'assessmentCompleted': true,
        'onboardingStep': 10,
        'token': 'valid_test_token',
      };

      SharedPreferences.setMockInitialValues({
        'alpha_x_local_active_session': jsonEncode(sessionData),
        'alpha_x_existing_clients_purged_v1': true,
        AppConstants.onboardingCompleteKey: true,
        '${AppConstants.onboardingCompleteKey}_AXG-8888': true,
      });

      // Simulate app restart
      await auth.initialize();

      expect(auth.isAuthenticated, isTrue);
      expect(auth.isApproved, isTrue);
      expect(auth.isPending, isFalse);
      expect(auth.onboardingCompleted, isTrue);
      expect(auth.assessmentCompleted, isTrue);

      // getInitialScreen directly routes to NavigationShell
      final initialScreen = getInitialScreen(
        authService: auth,
        workoutRepository: workoutRepo,
        activityRepository: activityRepo,
        macroRepository: macroRepo,
        weeklyProgressRepository: weeklyProgressRepo,
      );
      expect(initialScreen, isA<NavigationShell>());

      // Route guards: navigating to /onboarding or /pending-verification redirects to NavigationShell
      final onboardingRoute = buildAppRoute(
        const RouteSettings(name: '/onboarding'),
        authService: auth,
        workoutRepository: workoutRepo,
        activityRepository: activityRepo,
        macroRepository: macroRepo,
        weeklyProgressRepository: weeklyProgressRepo,
      );
      expect(onboardingRoute, isNotNull);
      final onboardingWidget = (onboardingRoute as MaterialPageRoute).builder(MockBuildContext());
      expect(onboardingWidget, isA<NavigationShell>());

      final pendingRoute = buildAppRoute(
        const RouteSettings(name: '/pending-verification'),
        authService: auth,
        workoutRepository: workoutRepo,
        activityRepository: activityRepo,
        macroRepository: macroRepo,
        weeklyProgressRepository: weeklyProgressRepo,
      );
      expect(pendingRoute, isNotNull);
      final pendingWidget = (pendingRoute as MaterialPageRoute).builder(MockBuildContext());
      expect(pendingWidget, isA<NavigationShell>());
    });

    test('5. Logout and subsequent Login restores APPROVED status and completed assessment', () async {
      // Mock login endpoint
      auth.setHttpClientForTesting(MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'token': 'auth_jwt_token_456',
                'status': 'APPROVED',
                'clientId': 'AXG-7777',
                'assessmentCompleted': true,
                'onboardingCompleted': true,
                'onboardingStep': 10,
                'user': {
                  'id': 'user_7777',
                  'clientId': 'AXG-7777',
                  'name': 'Veteran Athlete',
                  'email': 'veteran@alphax.com',
                  'status': 'APPROVED',
                },
                'profile': {
                  'clientId': 'AXG-7777',
                  'onboardingCompleted': true,
                  'onboardingStep': 10,
                },
              },
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      }));

      final loginResult = await auth.loginWithCredentials(
        identifier: 'AXG-7777',
        password: 'Password123!',
      );

      expect(loginResult['isApproved'], isTrue);
      expect(loginResult['status'], 'APPROVED');
      expect(loginResult['assessmentCompleted'], isTrue);
      expect(loginResult['onboardingCompleted'], isTrue);

      expect(auth.isAuthenticated, isTrue);
      expect(auth.isApproved, isTrue);
      expect(auth.onboardingCompleted, isTrue);

      final screen = getInitialScreen(
        authService: auth,
        workoutRepository: workoutRepo,
        activityRepository: activityRepo,
        macroRepository: macroRepo,
        weeklyProgressRepository: weeklyProgressRepo,
      );
      expect(screen, isA<NavigationShell>());
    });

    test('6. Failed assessment submission (API error 500) does NOT mark onboarding complete and throws error', () async {
      await auth.registerClientAccount(
        name: 'Casey Jones',
        email: 'casey.jones@example.com',
        phone: '+1 (555) 777-8888',
        password: 'Password123!',
        confirmPassword: 'Password123!',
      );

      // Mock backend failure (HTTP 500)
      auth.setHttpClientForTesting(MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'error': {
              'message': 'Database connection error during assessment save',
            },
          }),
          500,
        );
      }));

      expect(
        () => auth.saveOnboardingStep({
          'fitnessLevel': 'ADVANCED',
          'primaryGoal': 'Hypertrophy',
        }, step: 10, isComplete: true),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Database connection error during assessment save'),
        )),
      );

      // Onboarding must NOT be marked complete when saving fails
      expect(auth.onboardingCompleted, isFalse);
      expect(auth.assessmentCompleted, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppConstants.onboardingCompleteKey), isNot(isTrue));
    });

    testWidgets('7. PendingVerificationScreen routes directly to /dashboard if user is already approved and assessment completed', (tester) async {
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'approved.done@alphax.com',
        userName: 'Approved User',
        clientId: 'AXG-5555',
        onboardingCompleted: true,
        status: 'APPROVED',
      );

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/dashboard': (context) => const Scaffold(body: Text('DASHBOARD_SCREEN')),
            '/onboarding': (context) => const Scaffold(body: Text('ONBOARDING_SCREEN')),
          },
          home: const PendingVerificationScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('DASHBOARD_SCREEN'), findsOneWidget);
      expect(find.text('ONBOARDING_SCREEN'), findsNothing);
      expect(find.text('Account Pending Verification'), findsNothing);
    });

    testWidgets('8. ClientOnboardingScreen automatically redirects to /dashboard if onboardingCompleted is true', (tester) async {
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'completed.redirect@alphax.com',
        userName: 'Redirect User',
        clientId: 'AXG-6666',
        onboardingCompleted: true,
        status: 'APPROVED',
      );

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/dashboard': (context) => const Scaffold(body: Text('DASHBOARD_SCREEN')),
          },
          home: const ClientOnboardingScreen(initialStep: 1),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('DASHBOARD_SCREEN'), findsOneWidget);
      expect(find.text('STEP 1 OF 10'), findsNothing);
      expect(find.text('FITNESS LEVEL'), findsNothing);
    });
  });
}

class MockBuildContext extends Fake implements BuildContext {}
