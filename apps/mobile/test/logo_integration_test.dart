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

    testWidgets('AlphaXGymApp launches directly into authentication without landing splash screen', (tester) async {
      await tester.pumpWidget(const AlphaXGymApp());

      // Landing splash screen buttons no longer appear
      expect(find.text('ENTER ALPHA X GYM'), findsNothing);
      expect(find.text('Member Sign In'), findsNothing);

      // Directly renders LoginScreen with official logo & brand title
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(AlphaXLogo), findsOneWidget);
      expect(find.text('ALPHA X GYM'), findsOneWidget);
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

    testWidgets('Responsive Logo Rendering across Small Phone, iPhone, Tablet, and Desktop', (tester) async {
      final devices = [
        const Size(320, 568),   // Small Phone (iPhone SE)
        const Size(390, 844),   // Standard iPhone (iPhone 14/15)
        const Size(412, 915),   // Large Android Phone (Pixel 7)
        const Size(800, 1280),  // Tablet (iPad / Galaxy Tab)
        const Size(1280, 800),  // Desktop / Admin screen
      ];

      for (final deviceSize in devices) {
        tester.view.physicalSize = deviceSize;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(
            home: LoginScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // Verify logo renders without layout overflow or exceptions
        expect(find.byType(AlphaXLogo), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  });
}
