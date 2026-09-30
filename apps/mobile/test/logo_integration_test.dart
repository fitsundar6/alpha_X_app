import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_x_gym/core/constants/app_constants.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_logo.dart';
import 'package:alpha_x_gym/core/auth/login_screen.dart';
import 'package:alpha_x_gym/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Alpha X Gym Logo & Brand Integration Tests', () {
    test('Official logo image files exist in assets/images/', () {
      final logoFile = File('assets/images/alpha_x_logo.png');
      expect(logoFile.existsSync(), isTrue, reason: 'Official logo must exist');

      final appIconFile = File('assets/images/alpha_x_app_icon.png');
      expect(appIconFile.existsSync(), isTrue, reason: 'App icon must exist');

      final adaptiveFgFile = File('assets/images/alpha_x_adaptive_foreground.png');
      expect(adaptiveFgFile.existsSync(), isTrue, reason: 'Adaptive foreground must exist');
    });

    testWidgets('AlphaXLogo renders Image.asset with correct path and semantics', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AlphaXLogo(size: 64),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.image, isA<AssetImage>());
      final assetImage = imageWidget.image as AssetImage;
      expect(assetImage.assetName, equals(AppConstants.logoPath));
      expect(imageWidget.semanticLabel, equals(AppConstants.appName));
    });

    testWidgets('FoundationSplashScreen displays AlphaXLogo and brand identity', (tester) async {
      await tester.pumpWidget(const AlphaXGymApp());

      // Splash screen displays AlphaXLogo
      expect(find.byType(AlphaXLogo), findsOneWidget);
      expect(find.text('ALPHA X GYM'), findsOneWidget);
      expect(find.text('ENTER ALPHA X GYM'), findsOneWidget);
      expect(find.text('Member Sign In'), findsOneWidget);
    });

    testWidgets('LoginScreen renders official logo and single secure sign-in portal without role selector', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      // Verify official logo on login
      expect(find.byType(AlphaXLogo), findsOneWidget);
      expect(find.text('ALPHA X GYM'), findsOneWidget);
      expect(find.text('MEMBER & ATHLETE PORTAL'), findsOneWidget);
      expect(find.text('CLIENT LOGIN'), findsOneWidget);
      expect(find.text('CREATE ACCOUNT'), findsOneWidget);

      // Verify strict security: NO admin or client toggle options
      expect(find.text('ADMIN'), findsNothing);
      expect(find.text('CLIENT'), findsNothing);
    });
  });
}
