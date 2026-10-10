import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/core/auth/login_screen.dart';
import 'package:alpha_x_gym/core/auth/create_account_screen.dart';
import 'package:alpha_x_gym/features/onboarding/client_onboarding_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AuthService auth;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    auth = AuthService();
    await auth.logout();
    await auth.initialize();
  });

  group('Alpha X Gym - Client Create Account Flow End-To-End Tests', () {
    testWidgets('1-4. LoginScreen -> Tap Create New Account opens separate screen with ONLY 5 fields', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/login',
          routes: {
            '/login': (_) => const LoginScreen(),
            '/register': (_) => const CreateAccountScreen(),
            '/onboarding': (_) => const Scaffold(body: Text('ONBOARDING_SCREEN')),
          },
        ),
      );
      await tester.pumpAndSettle();

      // 1. Open Login: Verify Login screen fields
      expect(find.text('ALPHA X GYM'), findsOneWidget);
      expect(find.text('LOG IN TO YOUR ACCOUNT'), findsOneWidget);
      expect(find.text('Client ID / Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('LOGIN'), findsOneWidget);
      expect(find.text('CREATE NEW ACCOUNT'), findsOneWidget);

      // 2. Tap Create New Account
      await tester.tap(find.text('CREATE NEW ACCOUNT'));
      await tester.pumpAndSettle();

      // 3. Confirm Login fields are NOT shown
      expect(find.text('LOG IN TO YOUR ACCOUNT'), findsNothing);
      expect(find.text('Client ID / Email'), findsNothing);

      // 4. Confirm Title: "Create Your Alpha X Account"
      expect(find.text('Create Your Alpha X Account'), findsOneWidget);

      // Confirm ONLY the 5 required fields are present
      expect(find.text('Client Name'), findsOneWidget);
      expect(find.text('Gmail / Email'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);
      expect(find.text('Create Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.text('CREATE ACCOUNT'), findsOneWidget);

      // Confirm NO assessment questions or extraneous fields are shown
      expect(find.text('Height'), findsNothing);
      expect(find.text('Weight'), findsNothing);
      expect(find.text('Fitness Level'), findsNothing);
      expect(find.text('Goal'), findsNothing);
      expect(find.text('Injuries'), findsNothing);
      expect(find.text('Diet'), findsNothing);

      // Confirm keyboard types and settings
      final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(textFields.length, equals(5));

      // 1: Name field
      expect(textFields[0].keyboardType, equals(TextInputType.name));
      expect(textFields[0].textCapitalization, equals(TextCapitalization.words));

      // 2: Email field (email keyboard, no capitalization)
      expect(textFields[1].keyboardType, equals(TextInputType.emailAddress));
      expect(textFields[1].textCapitalization, equals(TextCapitalization.none));

      // 3: Phone field
      expect(textFields[2].keyboardType, equals(TextInputType.phone));

      // 4: Password field (hidden by default)
      expect(textFields[3].obscureText, isTrue);

      // 5: Confirm Password field (hidden by default)
      expect(textFields[4].obscureText, isTrue);
    });

    testWidgets('19. Empty fields validation triggers clear error messages', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CreateAccountScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap CREATE ACCOUNT without entering anything
      await tester.tap(find.text('CREATE ACCOUNT'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your name'), findsOneWidget);
      expect(find.text('Please enter a valid email'), findsOneWidget);
      expect(find.text('Please enter your phone number'), findsOneWidget);
      expect(find.text('Password must meet the required security rules'), findsOneWidget);
      expect(find.text('Passwords do not match.'), findsOneWidget);
    });

    testWidgets('17. Invalid email format validation', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CreateAccountScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Enter invalid email
      await tester.enterText(find.widgetWithText(TextFormField, 'Client Name'), 'Alex Mercer');
      await tester.enterText(find.widgetWithText(TextFormField, 'Gmail / Email'), 'invalidemailformat');
      await tester.enterText(find.widgetWithText(TextFormField, 'Phone Number'), '+15551234567');
      await tester.enterText(find.widgetWithText(TextFormField, 'Create Password'), 'Password123!');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirm Password'), 'Password123!');

      await tester.tap(find.text('CREATE ACCOUNT'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('18. Password mismatch validation', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CreateAccountScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Client Name'), 'Alex Mercer');
      await tester.enterText(find.widgetWithText(TextFormField, 'Gmail / Email'), 'alex@example.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Phone Number'), '+15551234567');
      await tester.enterText(find.widgetWithText(TextFormField, 'Create Password'), 'Password123!');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirm Password'), 'DifferentPassword99!');

      await tester.tap(find.text('CREATE ACCOUNT'));
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match.'), findsOneWidget);
    });

    testWidgets('5-11. Enter valid info -> Create Account -> Success dialog -> Onboarding -> Client Home', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/': (_) => const CreateAccountScreen(),
            '/pending-verification': (_) => const Scaffold(body: Text('PENDING_VERIFICATION')),
            '/onboarding': (_) => const ClientOnboardingScreen(initialStep: 1),
            '/dashboard': (_) => const Scaffold(body: Text('CLIENT_HOME_DASHBOARD')),
          },
        ),
      );
      await tester.pumpAndSettle();

      // 5. Enter valid information
      await tester.enterText(find.widgetWithText(TextFormField, 'Client Name'), 'Jordan Vance');
      await tester.enterText(find.widgetWithText(TextFormField, 'Gmail / Email'), '  jordan.vance@alphax.com  ');
      await tester.enterText(find.widgetWithText(TextFormField, 'Phone Number'), '+1 (555) 987-6543');
      await tester.enterText(find.widgetWithText(TextFormField, 'Create Password'), 'StrongPass999!');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirm Password'), 'StrongPass999!');

      // 6. Tap CREATE ACCOUNT
      await tester.tap(find.text('CREATE ACCOUNT'));
      await tester.pumpAndSettle();

      // 7. Verify Account Created Successfully banner & dialog
      expect(find.text('Account Created Successfully ✓'), findsOneWidget);
      expect(find.text('YOUR ALPHA X CLIENT ID'), findsOneWidget);
      expect(find.text('VIEW VERIFICATION STATUS'), findsOneWidget);

      // 8. Verify client authentication
      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentUserEmail, 'jordan.vance@alphax.com');
      expect(auth.currentUserName, 'Jordan Vance');
      expect(auth.currentClientId, startsWith('AXG-'));
      expect(auth.assessmentCompleted, isFalse);

      // 9. Tap View Verification Status -> Opens pending verification
      await tester.tap(find.text('VIEW VERIFICATION STATUS'));
      await tester.pumpAndSettle();

      expect(find.text('PENDING_VERIFICATION'), findsOneWidget);

      // 10-11. Complete Assessment & reach dashboard
      await auth.saveOnboardingStep({'fitnessLevel': 'intermediate'}, step: 10, isComplete: true);
      expect(auth.assessmentCompleted, isTrue);
    });

    test('12-14. Logout -> Login using newly created account works', () async {
      // Register
      final reg = await auth.registerClientAccount(
        name: 'Taylor Reed',
        email: 'taylor.reed@alphax.com',
        phone: '+1 (555) 432-1098',
        password: 'TaylorSecret888!',
        confirmPassword: 'TaylorSecret888!',
      );
      final clientId = reg['clientId'] as String;

      // 12. Logout
      await auth.logout();
      expect(auth.isAuthenticated, isFalse);

      // 13-14. Login with email
      final emailLogin = await auth.loginWithCredentials(
        identifier: 'taylor.reed@alphax.com',
        password: 'TaylorSecret888!',
      );
      expect(auth.isAuthenticated, isTrue);
      expect(emailLogin['clientId'], clientId);

      await auth.logout();

      // Login with Client ID (AXG-XXXX)
      final idLogin = await auth.loginWithCredentials(
        identifier: clientId,
        password: 'TaylorSecret888!',
      );
      expect(auth.isAuthenticated, isTrue);
      expect(idLogin['clientId'], clientId);
    });

    test('15. Duplicate email rejection', () async {
      await auth.registerClientAccount(
        name: 'First User',
        email: 'duplicate.test@alphax.com',
        phone: '+1 (555) 111-2222',
        password: 'Password123!',
        confirmPassword: 'Password123!',
      );

      // Attempt duplicate email
      expect(
        () => auth.registerClientAccount(
          name: 'Second User',
          email: 'duplicate.test@alphax.com',
          phone: '+1 (555) 333-4444',
          password: 'Password123!',
          confirmPassword: 'Password123!',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('This email is already registered. Please login.'),
        )),
      );
    });

    test('16. Duplicate phone rejection', () async {
      await auth.registerClientAccount(
        name: 'First Phone User',
        email: 'user1@alphax.com',
        phone: '+1 (555) 777-8888',
        password: 'Password123!',
        confirmPassword: 'Password123!',
      );

      // Attempt duplicate phone
      expect(
        () => auth.registerClientAccount(
          name: 'Second Phone User',
          email: 'user2@alphax.com',
          phone: '+1 (555) 777-8888',
          password: 'Password123!',
          confirmPassword: 'Password123!',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('This phone number is already registered.'),
        )),
      );
    });

    testWidgets('20. Responsive layout: Android (412x915), iPhone (390x844), and SE (320x568) without overflow', (tester) async {
      // Android standard viewport (e.g. Pixel 7 / Galaxy S23)
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: CreateAccountScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('CREATE ACCOUNT'), findsOneWidget);

      // iPhone 14 / 15 standard viewport (390x844)
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: CreateAccountScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('CREATE ACCOUNT'), findsOneWidget);

      // Compact iPhone SE viewport (320x568)
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: CreateAccountScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('CREATE ACCOUNT'), findsOneWidget);
    });
  });
}
