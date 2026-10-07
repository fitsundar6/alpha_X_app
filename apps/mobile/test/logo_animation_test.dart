import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_x_gym/core/constants/app_constants.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_logo_animation.dart';
import 'package:alpha_x_gym/core/auth/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Alpha X Gym - Logo Animation & Continuous Login Transition Tests', () {
    testWidgets('AlphaXLogoAnimation renders exact source PNG asset', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AlphaXLogoAnimation(
                size: 140,
                autoPlay: false,
              ),
            ),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.image, isA<AssetImage>());
      final assetImage = imageWidget.image as AssetImage;
      expect(assetImage.assetName, equals(AppConstants.logoPath));
    });

    testWidgets('AlphaXLogoAnimation startSettled initializes at 1.0 immediately', (tester) async {
      bool completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlphaXLogoAnimation(
              size: 140,
              startSettled: true,
              onComplete: () => completed = true,
            ),
          ),
        ),
      );

      final state = tester.state<AlphaXLogoAnimationState>(find.byType(AlphaXLogoAnimation));
      expect(state.settleAnimation.value, equals(1.0));
      expect(completed, isTrue);
    });

    testWidgets('AlphaXLogoAnimation tap to skip fast-forwards to settled state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AlphaXLogoAnimation(
              size: 140,
              autoPlay: true,
              allowTapToSkip: true,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      final state = tester.state<AlphaXLogoAnimationState>(find.byType(AlphaXLogoAnimation));
      expect(state.settleAnimation.value, lessThan(1.0));

      // Tap to skip
      await tester.tap(find.byType(AlphaXLogoAnimation));
      await tester.pumpAndSettle();

      expect(state.settleAnimation.value, equals(1.0));
    });

    testWidgets('AlphaXLogoAnimation fires onTransitionStart and onComplete callbacks', (tester) async {
      bool transitionStarted = false;
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlphaXLogoAnimation(
              size: 140,
              autoPlay: true,
              onTransitionStart: () => transitionStarted = true,
              onComplete: () => completed = true,
            ),
          ),
        ),
      );

      // Advance to 3.9 seconds
      await tester.pump(const Duration(milliseconds: 3900));
      expect(transitionStarted, isTrue);
      expect(completed, isFalse);

      // Advance to full completion
      await tester.pump(const Duration(milliseconds: 1000));
      expect(completed, isTrue);
    });

    testWidgets('LoginScreen seamless continuous transition unfolds login card', (tester) async {
      LoginScreen.hasPlayedIntro = false;

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(animateLogo: true),
        ),
      );

      // Initially at 0ms: Hero logo animation is active
      expect(find.byType(AlphaXLogoAnimation), findsOneWidget);

      // Fast forward past the transition phase (5 seconds)
      await tester.pump(const Duration(milliseconds: 5000));
      await tester.pumpAndSettle();

      // Login form is completely visible and interactive
      expect(find.text('CLIENT LOGIN'), findsOneWidget);
      expect(find.text('CREATE ACCOUNT'), findsOneWidget);
      expect(find.text('ALPHA X GYM'), findsOneWidget);
      expect(find.text('MEMBER & ATHLETE PORTAL'), findsOneWidget);
      expect(LoginScreen.hasPlayedIntro, isTrue);
    });

    testWidgets('LoginScreen does NOT replay full animation on subsequent entry', (tester) async {
      // Simulate that the user has already seen the intro animation
      LoginScreen.hasPlayedIntro = true;

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      // Login form is immediately ready without waiting 4.5 seconds
      expect(find.text('CLIENT LOGIN'), findsOneWidget);
      expect(find.text('CREATE ACCOUNT'), findsOneWidget);
    });

    testWidgets('Responsive Logo Animation across multiple phone viewports', (tester) async {
      final viewports = [
        const Size(320, 568), // iPhone SE
        const Size(390, 844), // iPhone 14/15
        const Size(412, 915), // Pixel 8
        const Size(768, 1024), // Tablet
      ];

      for (final size in viewports) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        LoginScreen.hasPlayedIntro = false;

        await tester.pumpWidget(
          const MaterialApp(
            home: LoginScreen(animateLogo: true),
          ),
        );

        await tester.pump(const Duration(milliseconds: 1000)); // mid-animation
        expect(tester.takeException(), isNull);

        await tester.pumpAndSettle(); // settled state
        expect(tester.takeException(), isNull);
        expect(find.text('CLIENT LOGIN'), findsOneWidget);
      }
    });
  });
}
