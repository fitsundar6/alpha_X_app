import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_x_gym/core/constants/app_constants.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_splash_screen.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_logo_animation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Alpha X Rubber Physics Splash Screen Tests', () {
    testWidgets('1. Pure black background and wordmark animation stage', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AlphaXSplashScreen(),
        ),
      );

      // Verify deep black background (#000000)
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(Colors.black));

      // Verify AlphaXLogoAnimation is mounted with 4800ms duration
      final animWidget = tester.widget<AlphaXLogoAnimation>(find.byType(AlphaXLogoAnimation));
      expect(animWidget.duration, equals(const Duration(milliseconds: 4800)));
    });

    testWidgets('2. Preserves asset image for test and background compatibility', (tester) async {
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

    testWidgets('3. Renders 7 animated wordmark glyphs for Λ L P H Λ - X', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AlphaXSplashScreen(),
        ),
      );

      // Advance into settled state (~2600ms)
      await tester.pump(const Duration(milliseconds: 2600));

      final painters = find.byType(CustomPaint);
      expect(painters, findsWidgets);

      // Check for WordmarkCharPainter instances
      final customPaints = tester.widgetList<CustomPaint>(painters);
      final wordmarkPainters = customPaints
          .where((cp) => cp.painter is WordmarkCharPainter)
          .toList();
      expect(wordmarkPainters.length, equals(7));
    });

    testWidgets('4. Smooth transition into destination upon completion', (tester) async {
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

      // Advance past full duration (4800ms + transition)
      await tester.pump(const Duration(milliseconds: 4850));
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

      // Tap early (100ms)
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

      await tester.pump(const Duration(milliseconds: 2600));
      expect(tester.takeException(), isNull);

      final painters = find.byType(CustomPaint);
      final customPaints = tester.widgetList<CustomPaint>(painters);
      final wordmarkPainters = customPaints
          .where((cp) => cp.painter is WordmarkCharPainter)
          .toList();
      expect(wordmarkPainters.length, equals(7));
    });
  });
}
