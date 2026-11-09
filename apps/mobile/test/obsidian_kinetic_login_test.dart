import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/core/auth/login_screen.dart';
import 'package:alpha_x_gym/core/auth/widgets/seismic_disintegration_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Obsidian Kinetic Login Screen & Seismic Disintegration Tests', () {
    late AuthService auth;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      auth = AuthService();
      await auth.initialize();
      LoginScreen.hasPlayedIntro = true;
    });

    tearDown(() async {
      await auth.logout();
    });

    test('TEST 1: Seismic ground offset and rotation calculate accurate waveforms', () {
      // Phase 1 (0ms - 1000ms): subtle tremor
      final offsetEarly = computeQuakeOffset(500);
      expect(offsetEarly.dx.abs(), lessThanOrEqualTo(3.0));
      expect(offsetEarly.dy.abs(), lessThanOrEqualTo(3.0));

      // Phase 3 (2200ms - 2850ms): peak tremor
      final offsetPeak = computeQuakeOffset(2500);
      expect(offsetPeak.dx.abs() + offsetPeak.dy.abs(), greaterThan(0.5));

      // Rotation calculation
      final rotPeak = computeQuakeRotation(2500);
      expect(rotPeak.abs(), lessThanOrEqualTo(1.0));
    });

    test('TEST 2: Debris particles generation builds structured character particles', () {
      final particles = generateLoginDebrisParticles(
        screenSize: const Size(400, 800),
        usernameText: 'alexander.vance@alphax.com',
        passwordText: '••••••••••••',
      );

      expect(particles.isNotEmpty, isTrue);
      expect(particles.any((p) => p.char == 'A'), isTrue);
      expect(particles.any((p) => p.char == 'X'), isTrue);
      // All particles must have detach times within the calibrated disintegration window
      expect(particles.every((p) => p.detachTimeMs >= 2700 && p.detachTimeMs <= 4300), isTrue);
    });

    testWidgets('TEST 3: LoginScreen renders Obsidian Kinetic status bar, logo block, and actions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(animateLogo: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ALPHA X • AUTH'), findsOneWidget);
      expect(find.text('ENCRYPTED'), findsOneWidget);
      expect(find.text('TEST EARTHQUAKE'), findsOneWidget);
      expect(find.text('ALPHA X GYM'), findsOneWidget);
      expect(find.text('MEMBERSHIP ACCESS PORTAL'), findsOneWidget);
      expect(find.text('PREFILL DEFAULTS'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('LOGIN'), findsOneWidget);
      expect(find.text('CREATE ACCOUNT'), findsOneWidget);
    });

    testWidgets('TEST 4: PREFILL DEFAULTS fills email and password fields', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(animateLogo: false),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('PREFILL DEFAULTS'));
      await tester.pumpAndSettle();

      expect(find.text('alexander.vance@alphax.com'), findsOneWidget);
    });

    testWidgets('TEST 5: TEST EARTHQUAKE triggers seismic shake and tap-to-skip completes navigation', (tester) async {
      bool routedToDashboard = false;

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/dashboard': (_) {
              routedToDashboard = true;
              return const Scaffold(body: Text('DASHBOARD_SCREEN'));
            },
          },
          home: const LoginScreen(animateLogo: false),
        ),
      );
      await tester.pumpAndSettle();

      // Tap TEST EARTHQUAKE
      await tester.tap(find.text('TEST EARTHQUAKE'));
      await tester.pump();

      // Screen is now shaking; tap to skip immediately
      await tester.tap(find.byType(LoginScreen));
      await tester.pumpAndSettle();

      expect(routedToDashboard, isTrue);
      expect(find.text('DASHBOARD_SCREEN'), findsOneWidget);
    });

    testWidgets('TEST 6: Validation error banner renders when submitting empty inputs', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(animateLogo: false),
        ),
      );
      await tester.pumpAndSettle();

      // Tap LOGIN with empty inputs
      await tester.tap(find.text('LOGIN'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter valid credentials to continue.'), findsOneWidget);
    });
  });
}

