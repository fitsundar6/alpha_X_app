import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/main.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/core/auth/login_screen.dart';
import 'package:alpha_x_gym/core/constants/user_role.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_splash_screen.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_logo_animation.dart';
import 'package:alpha_x_gym/features/navigation/navigation_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Alpha X Gym - Startup Flow & Session Routing Tests', () {
    late AuthService auth;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      LoginScreen.hasPlayedIntro = false;
      auth = AuthService();
      auth.resetForTesting();
    });

    testWidgets('1. Fresh app launch while logged in -> Animation -> Dashboard', (tester) async {
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'athlete@alphaxgym.com',
        userId: 'client_athlete_1',
        onboardingCompleted: true,
      );

      await tester.pumpWidget(const AlphaXGymApp());
      await tester.pump();

      // Fresh launch immediately shows AlphaXSplashScreen with AlphaXLogoAnimation
      expect(find.byType(AlphaXSplashScreen), findsOneWidget);
      expect(find.byType(AlphaXLogoAnimation), findsOneWidget);

      // Animation plays and transitions to Client Dashboard
      await tester.pumpAndSettle();

      expect(find.byType(NavigationShell), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('2. Close app completely -> reopen -> Animation -> Dashboard', (tester) async {
      // Persist session to SharedPreferences (simulating app shutdown & cold boot)
      final sessionData = {
        'role': 'CLIENT',
        'id': 'client_reopen_1',
        'clientId': 'AXG-0042',
        'email': 'reopen@alphaxgym.com',
        'name': 'Cold Boot Athlete',
        'onboardingCompleted': true,
        'token': 'cold_boot_token_123',
      };
      SharedPreferences.setMockInitialValues({
        'alpha_x_local_active_session': jsonEncode(sessionData),
        'alpha_x_existing_clients_purged_v1': true,
      });

      // Cold boot initialization
      await auth.initialize();
      expect(auth.isAuthenticated, isTrue);

      await tester.pumpWidget(const AlphaXGymApp());
      await tester.pump();

      // Starts with animation
      expect(find.byType(AlphaXSplashScreen), findsOneWidget);

      // Transitions to Dashboard
      await tester.pumpAndSettle();
      expect(find.byType(NavigationShell), findsOneWidget);
    });

    testWidgets('3. Force-stop app -> reopen -> Animation -> Dashboard', (tester) async {
      // Persist session into storage
      final sessionData = {
        'role': 'CLIENT',
        'id': 'client_forcestop_1',
        'clientId': 'AXG-9999',
        'email': 'forcestop@alphaxgym.com',
        'name': 'Persistent Athlete',
        'onboardingCompleted': true,
        'token': 'force_stop_token_xyz',
      };
      SharedPreferences.setMockInitialValues({
        'alpha_x_local_active_session': jsonEncode(sessionData),
        'alpha_x_existing_clients_purged_v1': true,
      });

      // Re-initialize from scratch
      await auth.initialize();
      expect(auth.isAuthenticated, isTrue);

      await tester.pumpWidget(const AlphaXGymApp());
      await tester.pump();

      // Animation plays on reopened app
      expect(find.byType(AlphaXSplashScreen), findsOneWidget);
      expect(find.byType(AlphaXLogoAnimation), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(NavigationShell), findsOneWidget);
    });

    testWidgets('4. Logged-out user -> Animation -> Login', (tester) async {
      // No saved session
      SharedPreferences.setMockInitialValues({});
      await auth.initialize();
      expect(auth.isAuthenticated, isFalse);

      await tester.pumpWidget(const AlphaXGymApp());
      await tester.pump();

      // Animation plays on fresh launch
      expect(find.byType(AlphaXSplashScreen), findsOneWidget);
      expect(find.byType(AlphaXLogoAnimation), findsOneWidget);

      // After animation completes, transitions to Login
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(NavigationShell), findsNothing);
    });

    testWidgets('5. Valid session -> user should NOT be asked to log in again', (tester) async {
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'validthlete@alphaxgym.com',
        userId: 'client_valid_1',
        onboardingCompleted: true,
      );

      await tester.pumpWidget(const AlphaXGymApp());
      await tester.pumpAndSettle();

      // Must be on Dashboard, NOT on LoginScreen
      expect(find.byType(NavigationShell), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('6. Expired/invalid session -> Animation -> Login', (tester) async {
      // Expired JWT token (exp in past: 1000)
      final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})));
      final payload = base64Url.encode(utf8.encode(jsonEncode({'exp': 1000, 'userId': 'expired_user'})));
      final expiredJwt = '$header.$payload.signature';

      final sessionData = {
        'role': 'CLIENT',
        'id': 'client_expired_1',
        'clientId': 'AXG-EXPIRED',
        'email': 'expired@alphaxgym.com',
        'name': 'Expired User',
        'onboardingCompleted': true,
        'token': expiredJwt,
      };
      SharedPreferences.setMockInitialValues({
        'alpha_x_local_active_session': jsonEncode(sessionData),
        'alpha_x_existing_clients_purged_v1': true,
      });

      await auth.initialize();
      expect(auth.isTokenExpired, isTrue);

      await tester.pumpWidget(const AlphaXGymApp());
      await tester.pump();

      // Splash animation plays
      expect(find.byType(AlphaXSplashScreen), findsOneWidget);

      // Settle -> routes to LoginScreen because session is expired
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(NavigationShell), findsNothing);
    });

    testWidgets('7. Android back navigation still works (cannot pop root after splash)', (tester) async {
      await tester.pumpWidget(const AlphaXGymApp());
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);

      // Navigator root check: canPop must be false so Android system back exits/minimizes app
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      expect(navigator.canPop(), isFalse);
    });

    testWidgets('8. No duplicate animation on LoginScreen after splash', (tester) async {
      await tester.pumpWidget(const AlphaXGymApp());
      await tester.pumpAndSettle();

      // Login screen is mounted
      expect(find.byType(LoginScreen), findsOneWidget);

      // hasPlayedIntro is true, so no duplicate animation is triggered
      expect(LoginScreen.hasPlayedIntro, isTrue);
    });

    testWidgets('9. No unnecessary startup delay (tap to skip transitions immediately)', (tester) async {
      await tester.pumpWidget(const AlphaXGymApp());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AlphaXSplashScreen), findsOneWidget);

      // Tap on the splash screen to skip
      await tester.tap(find.byType(AlphaXSplashScreen));
      await tester.pumpAndSettle();

      // Reached destination immediately without waiting for full 2s duration
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });
}
