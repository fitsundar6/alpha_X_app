import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_x_gym/core/constants/app_constants.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_splash_screen.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_logo_animation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Alpha X Energy Reveal Launch Animation Tests', () {
    testWidgets('1. Phase 1 & 2: Pure dark background and subtle ambient red energy stage', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AlphaXSplashScreen(),
        ),
      );

      // Verify deep black background
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(Colors.black));

      // Verify AlphaXLogoAnimation is mounted with showBrandLine = true
      final animWidget = tester.widget<AlphaXLogoAnimation>(find.byType(AlphaXLogoAnimation));
      expect(animWidget.showBrandLine, isTrue);
      expect(animWidget.duration, equals(const Duration(milliseconds: 1400)));
    });

    testWidgets('2. Phase 4: Preserves exact Alpha X logo asset without alteration', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AlphaXSplashScreen(),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.image, isA<AssetImage>());
      final asset = imageWidget.image as AssetImage;
      expect(asset.assetName, equals(AppConstants.logoPath));
      expect(imageWidget.fit, equals(BoxFit.contain));
    });

    testWidgets('3. Phase 6: Brand line reveals "STRENGTH • CONDITIONING • BOXING • TRANSFORMATION"', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AlphaXSplashScreen(),
        ),
      );

      // Advance into Phase 6 (around ~800ms)
      await tester.pump(const Duration(milliseconds: 800));

      final brandLineFinder = find.text('STRENGTH • CONDITIONING • BOXING • TRANSFORMATION');
      expect(brandLineFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(brandLineFinder);
      expect(textWidget.style?.letterSpacing, greaterThanOrEqualTo(2.0));
      expect(textWidget.style?.fontWeight, equals(FontWeight.w600));
    });

    testWidgets('4. Phase 7: Smooth transition into destination upon completion', (tester) async {
      bool navigated = false;
      await tester.pumpWidget(
        MaterialApp(
          home: AlphaXSplashScreen(
            destinationBuilder: () {
              navigated = true;
              return const Scaffold(body: Center(child: Text('DASHBOARD_READY')));
            },
          ),
        ),
      );

      expect(navigated, isFalse);

      // Advance past full duration (1400ms + transition)
      await tester.pump(const Duration(milliseconds: 1450));
      await tester.pumpAndSettle();

      expect(navigated, isTrue);
      expect(find.text('DASHBOARD_READY'), findsOneWidget);
      expect(find.byType(AlphaXSplashScreen), findsNothing);
    });

    testWidgets('5. Tap-to-skip bypasses animation immediately to destination', (tester) async {
      bool navigated = false;
      await tester.pumpWidget(
        MaterialApp(
          home: AlphaXSplashScreen(
            destinationBuilder: () {
              navigated = true;
              return const Scaffold(body: Center(child: Text('INSTANT_APP')));
            },
          ),
        ),
      );

      // Tap early in Phase 1 (100ms)
      await tester.pump(const Duration(milliseconds: 100));
      expect(navigated, isFalse);

      await tester.tap(find.byType(AlphaXSplashScreen));
      await tester.pumpAndSettle();

      expect(navigated, isTrue);
      expect(find.text('INSTANT_APP'), findsOneWidget);
    });

    testWidgets('6. Safety watchdog timer prevents indefinite hang', (tester) async {
      bool destinationReached = false;
      await tester.pumpWidget(
        MaterialApp(
          home: AlphaXSplashScreen(
            animationDuration: const Duration(milliseconds: 800),
            destinationBuilder: () {
              destinationReached = true;
              return const Scaffold(body: Text('WATCHDOG_RESCUED'));
            },
          ),
        ),
      );

      // Advance past watchdog threshold (800ms + 400ms safety buffer)
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();

      expect(destinationReached, isTrue);
      expect(find.text('WATCHDOG_RESCUED'), findsOneWidget);
    });

    testWidgets('7. Responsive scaling on small phones (iPhone SE 320w)', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: AlphaXSplashScreen(),
        ),
      );

      await tester.pump(const Duration(milliseconds: 800));
      expect(tester.takeException(), isNull);
      expect(find.text('STRENGTH • CONDITIONING • BOXING • TRANSFORMATION'), findsOneWidget);
    });
  });
}
