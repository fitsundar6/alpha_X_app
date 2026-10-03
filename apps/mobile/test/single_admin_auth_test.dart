import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/config/admin_config.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/core/auth/login_screen.dart';
import 'package:alpha_x_gym/core/auth/admin_login_screen.dart';
import 'package:alpha_x_gym/core/constants/user_role.dart';
import 'package:alpha_x_gym/features/dashboard/admin_main_dashboard_screen.dart';
import 'package:alpha_x_gym/features/dashboard/client_main_dashboard_screen.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/activity/data/repositories/activity_repository.dart';
import 'package:alpha_x_gym/features/macro_planner/data/repositories/macro_repository.dart';
import 'package:alpha_x_gym/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Single Admin Architecture & Access Control Tests', () {
    late AuthService auth;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      auth = AuthService();
    });

    tearDown(() async {
      await auth.logout();
    });

    test('TEST 1: Authorized Admin session grants ADMIN privileges', () {
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.admin,
        email: 'admin@alphaxgym.com',
        userId: 'admin_alex_stone',
      );

      expect(auth.isAdmin, isTrue);
      expect(auth.isClient, isFalse);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentRole, UserRole.admin);
      expect(auth.currentUserEmail, 'admin@alphaxgym.com');
    });

    test('TEST 2: Normal Client session strictly grants CLIENT privileges', () {
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'john.doe@alphaxgym.com',
        userId: 'client_john_doe',
      );

      expect(auth.isAdmin, isFalse);
      expect(auth.isClient, isTrue);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentRole, UserRole.client);
    });

    test('TEST 3: Admin logout wipes all admin privileges and resets state', () async {
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.admin,
        email: 'admin@alphaxgym.com',
        userId: 'admin_alex_stone',
      );
      expect(auth.isAdmin, isTrue);

      await auth.logout();
      expect(auth.isAdmin, isFalse);
      expect(auth.isClient, isTrue);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentToken, 'alpha_x_mock_token_for_client');
      expect(auth.currentUserId, isEmpty);
    });

    test('TEST 4: Client login after Admin logout never inherits admin privileges', () async {
      // First, Admin logs in
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.admin,
        email: 'admin@alphaxgym.com',
      );
      expect(auth.isAdmin, isTrue);

      // Admin logs out
      await auth.logout();
      expect(auth.isAdmin, isFalse);

      // Next, Client logs in
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'new.client@alphaxgym.com',
      );
      expect(auth.isAdmin, isFalse);
      expect(auth.isClient, isTrue);
    });

    testWidgets('TEST 5: Client attempting to open /admin route receives ACCESS DENIED', (tester) async {
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'client@alphaxgym.com',
      );

      final route = buildAppRoute(
        const RouteSettings(name: '/admin'),
        authService: auth,
      ) as MaterialPageRoute;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (ctx) => route.builder(ctx)),
        ),
      );

      expect(find.text('ACCESS DENIED'), findsOneWidget);
      expect(find.text('UNAUTHORIZED ACCESS'), findsOneWidget);
      expect(find.text('Return to Client Dashboard'), findsOneWidget);
      expect(find.byType(AdminMainDashboardScreen), findsNothing);
    });

    testWidgets('TEST 6: Authorized Admin successfully opens /admin route', (tester) async {
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.admin,
        email: 'admin@alphaxgym.com',
      );

      final route = buildAppRoute(
        const RouteSettings(name: '/admin'),
        authService: auth,
      ) as MaterialPageRoute;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (ctx) => route.builder(ctx)),
        ),
      );

      expect(find.byType(AdminMainDashboardScreen), findsOneWidget);
      expect(find.text('ACCESS DENIED'), findsNothing);
    });

    testWidgets('TEST 7: Client Dashboard completely hides all Admin controls and switches', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'athlete@alphaxgym.com',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ClientMainDashboardScreen(
            workoutRepository: WorkoutRepository(),
            activityRepository: ActivityRepository(),
            macroRepository: MacroRepository(),
          ),
        ),
      );
      await tester.pump();

      // 1. No "Admin Mode" in AppBar
      expect(find.text('Admin Mode'), findsNothing);
      expect(find.text('Switch to Admin Mode'), findsNothing);
      expect(find.text('Switch Role to Admin Mode'), findsNothing);

      // Open drawer
      final scaffoldFinder = find.byType(Scaffold).first;
      final scaffoldState = tester.firstState<ScaffoldState>(scaffoldFinder);
      scaffoldState.openDrawer();
      await tester.pump();

      // 2. No "Switch to Admin Mode" in Drawer
      expect(find.text('Switch to Admin Mode'), findsNothing);
      expect(find.text('Admin Mode'), findsNothing);
    });

    testWidgets('TEST 8: LoginScreen renders CLIENT LOGIN and ADMIN LOGIN options', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CLIENT LOGIN'), findsOneWidget);
      expect(find.text('CREATE ACCOUNT'), findsOneWidget);
      expect(find.text('ADMIN LOGIN'), findsOneWidget);
      expect(find.text('MEMBER & ATHLETE PORTAL'), findsOneWidget);
    });

    testWidgets('TEST 9: AdminLoginScreen renders Admin Gmail, password toggle, and authenticate button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AdminLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ADMINISTRATOR ACCESS'), findsOneWidget);
      expect(find.text('Admin Gmail'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);

      // Tap password visibility toggle
      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    test('TEST 10: Local Admin login verifies against AdminConfig and rejects wrong credentials', () async {
      await auth.initialize();

      // Successful Admin Login with configured credentials
      final role = await auth.login(
        email: AdminConfig.adminEmail,
        password: AdminConfig.adminPassword,
      );
      expect(role, UserRole.admin);
      expect(auth.isAdmin, isTrue);

      await auth.logout();

      // Successful Admin Login with fitsundar6@gmail.com and AlphaXAdmin2026!
      final role1 = await auth.login(
        email: 'fitsundar6@gmail.com',
        password: 'AlphaXAdmin2026!',
      );
      expect(role1, UserRole.admin);
      expect(auth.isAdmin, isTrue);

      await auth.logout();

      // Successful Admin Login without exclamation mark
      final role2 = await auth.login(
        email: 'fitsundar6@gmail.com',
        password: 'AlphaXAdmin2026',
      );
      expect(role2, UserRole.admin);
      expect(auth.isAdmin, isTrue);

      await auth.logout();

      // Failed Admin Login with incorrect password
      expect(
        () => auth.login(
          email: AdminConfig.adminEmail,
          password: 'WrongPassword123!',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Invalid admin email or password.'),
        )),
      );
    });

    test('TEST 11: Client ID and Password Authentication flow', () async {
      await auth.initialize();

      final clientEmail = 'athlete_${DateTime.now().millisecondsSinceEpoch}@alphaxgym.com';
      const clientPassword = 'Password123!';
      const clientPhone = '+1 (555) 345-6789';

      // 1. Reserved admin email rejected for client registration
      expect(
        () => auth.registerClientAccount(
          name: 'Imposter Admin',
          email: AdminConfig.adminEmail,
          phone: clientPhone,
          password: clientPassword,
          confirmPassword: clientPassword,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('This email is reserved for administration.'),
        )),
      );

      // 2. Successful Client Registration -> Generates AXG-XXXX Client ID
      final result = await auth.registerClientAccount(
        name: 'New Athlete',
        email: clientEmail,
        phone: clientPhone,
        password: clientPassword,
        confirmPassword: clientPassword,
      );
      expect(auth.isClient, isTrue);
      expect(auth.isAdmin, isFalse);
      expect(result['clientId'], isNotNull);
      expect(auth.currentUserEmail, clientEmail);
      expect(auth.currentClientId, isNotNull);
      expect(auth.currentClientId.startsWith('AXG-'), isTrue);

      // 3. Repeat login with Client ID and password preserves same Client ID
      final savedId = auth.currentClientId;
      await auth.logout();
      expect(auth.isAuthenticated, isFalse);

      final loginResult = await auth.loginWithCredentials(
        identifier: savedId,
        password: clientPassword,
      );
      expect(auth.currentClientId, savedId);
      expect(loginResult['clientId'], savedId);
    });

    testWidgets('TEST 12: Route /admin/login opens AdminLoginScreen directly', (tester) async {
      final route = buildAppRoute(
        const RouteSettings(name: '/admin/login'),
        authService: auth,
      ) as MaterialPageRoute;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (ctx) => route.builder(ctx)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AdminLoginScreen), findsOneWidget);
      expect(find.text('ADMINISTRATOR ACCESS'), findsOneWidget);
    });
  });
}
