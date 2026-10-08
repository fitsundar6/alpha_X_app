import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/main.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/core/constants/user_role.dart';
import 'package:alpha_x_gym/core/auth/login_screen.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_splash_screen.dart';
import 'package:alpha_x_gym/features/onboarding/client_onboarding_screen.dart';
import 'package:alpha_x_gym/features/navigation/navigation_shell.dart';
import 'package:alpha_x_gym/features/dashboard/admin_main_dashboard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Direct Authentication & Navigation Verification Tests', () {
    late AuthService auth;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      auth = AuthService();
    });

    testWidgets('1. App opens to AlphaXSplashScreen and transitions smoothly to LoginScreen', (tester) async {
      await tester.pumpWidget(const AlphaXGymApp());
      await tester.pump();

      // Landing screen elements are completely absent
      expect(find.text('ENTER ALPHA X GYM'), findsNothing);
      expect(find.text('Member Sign In'), findsNothing);

      // App is on AlphaXSplashScreen
      expect(find.byType(AlphaXSplashScreen), findsOneWidget);

      // Settle splash animation
      await tester.pumpAndSettle();

      // App settles onto LoginScreen
      expect(find.byType(LoginScreen), findsOneWidget);

      // Root navigation check: cannot pop from LoginScreen (Android back button closes app)
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      expect(navigator.canPop(), isFalse);
    });

    test('2. getInitialScreen returns LoginScreen for unauthenticated user', () {
      final initialWidget = getInitialScreen(authService: auth);
      expect(initialWidget, isA<LoginScreen>());
    });

    test('3. getInitialScreen returns NavigationShell for authenticated client with completed onboarding', () {
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'athlete@alphaxgym.com',
        userId: 'client_athlete_1',
        onboardingCompleted: true,
      );

      final initialWidget = getInitialScreen(authService: auth);
      expect(initialWidget, isA<NavigationShell>());
    });

    test('4. getInitialScreen returns ClientOnboardingScreen for authenticated client with pending onboarding', () {
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'newbie@alphaxgym.com',
        userId: 'client_newbie_1',
        onboardingCompleted: false,
      );

      final initialWidget = getInitialScreen(authService: auth);
      expect(initialWidget, isA<ClientOnboardingScreen>());
    });

    test('5. getInitialScreen returns AdminMainDashboardScreen for authenticated admin', () {
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.admin,
        email: 'admin@alphaxgym.com',
        userId: 'admin_alex_stone',
      );

      final initialWidget = getInitialScreen(authService: auth);
      expect(initialWidget, isA<AdminMainDashboardScreen>());
    });

    test('6. Route "/" in buildAppRoute directly routes to getInitialScreen', () {
      final route = buildAppRoute(const RouteSettings(name: '/'), authService: auth);
      expect(route, isNotNull);
      expect(route, isA<MaterialPageRoute>());
    });
  });
}
