import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/core/auth/login_screen.dart';
import 'package:alpha_x_gym/core/constants/user_role.dart';
import 'package:alpha_x_gym/features/onboarding/client_onboarding_screen.dart';
import 'package:alpha_x_gym/features/dashboard/client_main_dashboard_screen.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/activity/data/repositories/activity_repository.dart';
import 'package:alpha_x_gym/features/macro_planner/data/repositories/macro_repository.dart';
import 'package:alpha_x_gym/config/admin_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AuthService auth;
  late WorkoutRepository workoutRepo;
  late ActivityRepository activityRepo;
  late MacroRepository macroRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    auth = AuthService();
    await auth.logout();
    await auth.initialize();
    workoutRepo = WorkoutRepository();
    activityRepo = ActivityRepository();
    macroRepo = MacroRepository();
  });

  group('Alpha X Gym - Client ID + Password & 10-Step Assessment Tests', () {
    test('1. Client Registration creates account and generates AXG-XXXX Client ID', () async {
      final res = await auth.registerClientAccount(
        name: 'Samantha Ray',
        email: 'samantha.ray@example.com',
        phone: '+1 (555) 765-4321',
        password: 'Password123!',
        confirmPassword: 'Password123!',
      );

      expect(auth.isAuthenticated, isTrue);
      expect(auth.isClient, isTrue);
      expect(auth.isAdmin, isFalse);
      expect(auth.currentUserEmail, 'samantha.ray@example.com');
      expect(auth.currentUserName, 'Samantha Ray');
      expect(auth.currentUserPhone, '+1 (555) 765-4321');

      final clientId = res['clientId'] as String;
      expect(clientId, startsWith('AXG-'));
      expect(auth.currentClientId, clientId);
      expect(auth.assessmentCompleted, isFalse);
    });

    test('2. Client Login with Client ID (AXG-XXXX) + Password succeeds', () async {
      // First register
      final regRes = await auth.registerClientAccount(
        name: 'Marcus Brody',
        email: 'marcus.brody@example.com',
        phone: '+1 (555) 888-9999',
        password: 'SecretPassword99!',
        confirmPassword: 'SecretPassword99!',
      );
      final clientId = regRes['clientId'] as String;

      // Log out
      await auth.logout();
      expect(auth.isAuthenticated, isFalse);

      // Log in with generated Client ID
      final loginRes = await auth.loginWithCredentials(
        identifier: clientId,
        password: 'SecretPassword99!',
      );

      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentClientId, clientId);
      expect(loginRes['role'], 'CLIENT');
      expect(auth.assessmentCompleted, isFalse);
    });

    test('3. Client Login with Email + Password succeeds', () async {
      final regRes = await auth.registerClientAccount(
        name: 'David Miller',
        email: 'david.miller@example.com',
        phone: '+1 (555) 222-3333',
        password: 'DavidPassword1!',
        confirmPassword: 'DavidPassword1!',
      );
      final clientId = regRes['clientId'] as String;

      await auth.logout();

      final loginRes = await auth.loginWithCredentials(
        identifier: 'david.miller@example.com',
        password: 'DavidPassword1!',
      );

      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentClientId, clientId);
      expect(loginRes['clientId'], clientId);
    });

    test('4. Admin email rejected from Client Registration', () async {
      expect(
        () => auth.registerClientAccount(
          name: 'Hacker',
          email: AdminConfig.adminEmail,
          phone: '+1 (555) 000-0000',
          password: 'Password123!',
          confirmPassword: 'Password123!',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('This email is reserved for administration'),
        )),
      );
    });

    test('5. Progressive Assessment saving and auto-resume', () async {
      await auth.registerClientAccount(
        name: 'Chloe Bennett',
        email: 'chloe.bennett@example.com',
        phone: '+1 (555) 444-5555',
        password: 'Password123!',
        confirmPassword: 'Password123!',
      );

      // Save Step 1 & 2
      await auth.saveOnboardingStep({
        'fitnessLevel': 'intermediate',
        'primaryGoal': 'Fat Loss',
      }, step: 3);

      expect(auth.onboardingStep, 3);
      expect(auth.assessmentCompleted, isFalse);
      expect(auth.clientProfile['fitnessLevel'], 'intermediate');
      expect(auth.clientProfile['primaryGoal'], 'Fat Loss');

      // Complete Step 10
      await auth.saveOnboardingStep({
        'weightKg': 68.0,
        'heightCm': 172.0,
        'age': 27,
        'trainingExperience': '1–2 years',
        'trainingDaysPerWeek': 4,
        'activityLevel': 'MODERATE',
        'sleepHours': '7–8',
        'dailySteps': 8000,
        'trainingPreferences': ['Strength Training', 'Conditioning'],
      }, step: 10, isComplete: true);

      expect(auth.assessmentCompleted, isTrue);
      expect(auth.onboardingCompleted, isTrue);
      expect(auth.clientProfile['weightKg'], 68.0);
    });

    testWidgets('6. LoginScreen renders Login and Create New Account buttons with AXG branding', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ALPHA X GYM'), findsOneWidget);
      expect(find.text('LOG IN TO YOUR ACCOUNT'), findsOneWidget);
      expect(find.text('LOGIN'), findsOneWidget);
      expect(find.text('CREATE NEW ACCOUNT'), findsOneWidget);
      expect(find.text('ADMIN LOGIN'), findsOneWidget);
      expect(find.text('Continue as Guest'), findsNothing);
    });

    testWidgets('7. ClientOnboardingScreen shows 10-step progress and review', (tester) async {
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'athlete.test@alphax.com',
        userName: 'Test Athlete',
        clientId: 'AXG-0001',
        onboardingCompleted: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: ClientOnboardingScreen(initialStep: 1),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('STEP 1 OF 10'), findsOneWidget);
      expect(find.text('WELCOME TO ALPHA X GYM'), findsOneWidget);
      expect(find.text('FITNESS LEVEL'), findsOneWidget);
      expect(find.text('BEGINNER'), findsOneWidget);
      expect(find.text('INTERMEDIATE'), findsOneWidget);
      expect(find.text('NEXT'), findsOneWidget);
    });

    testWidgets('8. ClientMainDashboardScreen renders Client ID, Goal, and 7 core sections', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'alex.athlete@alphax.com',
        userName: 'Alex Mercer',
        clientId: 'AXG-0001',
        onboardingCompleted: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ClientMainDashboardScreen(
            workoutRepository: workoutRepo,
            activityRepository: activityRepo,
            macroRepository: macroRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header and Badges
      expect(find.text('ALPHA X GYM'), findsOneWidget);
      expect(find.text('AXG-0001'), findsOneWidget);

      // Scroll down to reveal quick access sections
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.text('MY ATHLETE PORTAL'), findsOneWidget);

      // Verify core sections
      expect(find.text('MY WORKOUT'), findsOneWidget);
      expect(find.text('EXERCISE LIBRARY'), findsOneWidget);
      expect(find.text('NUTRITION & MACROS'), findsOneWidget);
      expect(find.text('MY PROGRESS'), findsOneWidget);
      expect(find.text('MY ATTENDANCE'), findsNothing);
      expect(find.text('MY CHALLENGE'), findsNothing);
      expect(find.text('MY PROFILE'), findsOneWidget);
    });
  });
}
