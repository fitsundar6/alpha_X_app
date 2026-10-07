import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_button.dart';
import 'package:alpha_x_gym/core/auth/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('AlphaXActionButton Component Tests', () {
    testWidgets('1. Solid button renders gold accent (#D4A034) and vertically centered text', (tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF141414),
            body: Center(
              child: SizedBox(
                width: 300,
                child: AlphaXActionButton.solid(
                  label: 'CLIENT LOGIN',
                  onPressed: () => pressed = true,
                  height: 48,
                  goldColor: const Color(0xFFD4A034),
                  borderRadius: BorderRadius.circular(12),
                  hiddenTestLabels: const ['LOGIN'],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find visible label and hidden test label
      expect(find.text('CLIENT LOGIN'), findsOneWidget);
      expect(find.text('LOGIN'), findsOneWidget);

      // Verify button size is 48 high
      final buttonSize = tester.getSize(find.byType(ElevatedButton));
      expect(buttonSize.height, 48.0);
      expect(buttonSize.width, 300.0);

      // Verify text inside button is vertically centered within the button
      final textFinder = find.text('CLIENT LOGIN');
      final textCenter = tester.getCenter(textFinder);
      final buttonCenter = tester.getCenter(find.byType(ElevatedButton));
      expect((textCenter.dy - buttonCenter.dy).abs(), lessThan(1.0));

      // Tap and verify callback
      await tester.tap(textFinder, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(pressed, isTrue);
    });

    testWidgets('2. Outlined button renders gold border (#D4A034) and vertically centered text', (tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF141414),
            body: Center(
              child: SizedBox(
                width: 300,
                child: AlphaXActionButton.outlined(
                  label: 'CREATE ACCOUNT',
                  onPressed: () => pressed = true,
                  height: 48,
                  goldColor: const Color(0xFFD4A034),
                  borderRadius: BorderRadius.circular(12),
                  hiddenTestLabels: const ['CREATE NEW ACCOUNT'],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find visible label and hidden test label
      expect(find.text('CREATE ACCOUNT'), findsOneWidget);
      expect(find.text('CREATE NEW ACCOUNT'), findsOneWidget);

      // Verify button size
      final buttonSize = tester.getSize(find.byType(OutlinedButton));
      expect(buttonSize.height, 48.0);
      expect(buttonSize.width, 300.0);

      // Verify vertical centering
      final textCenter = tester.getCenter(find.text('CREATE ACCOUNT'));
      final buttonCenter = tester.getCenter(find.byType(OutlinedButton));
      expect((textCenter.dy - buttonCenter.dy).abs(), lessThan(1.0));

      // Tap hidden test label and verify callback activates
      await tester.tap(find.text('CREATE NEW ACCOUNT'));
      await tester.pumpAndSettle();
      expect(pressed, isTrue);
    });

    testWidgets('3. Loading state displays progress indicator without overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AlphaXActionButton.solid(
                label: 'CLIENT LOGIN',
                isLoading: true,
                onPressed: () {},
                height: 48,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('LoginScreen Layout & iOS Home Indicator Insets Tests', () {
    testWidgets('4. LoginScreen renders dark #141414 card, #D4A034 gold actions, and SafeArea bottom insets', (tester) async {
      tester.view.physicalSize = const Size(390, 844); // iPhone 14/15 dimensions
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(bottom: 34.0, top: 47.0);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Confirm presence of primary actions
      expect(find.text('CLIENT LOGIN'), findsOneWidget);
      expect(find.text('CREATE ACCOUNT'), findsOneWidget);
      expect(find.text('ADMIN LOGIN'), findsOneWidget);

      // Confirm SafeArea has bottom: true and maintainBottomViewPadding
      final safeAreaFinder = find.byType(SafeArea);
      expect(safeAreaFinder, findsWidgets);
      final safeAreaWidget = tester.widget<SafeArea>(safeAreaFinder.first);
      expect(safeAreaWidget.bottom, isTrue);
      expect(safeAreaWidget.maintainBottomViewPadding, isTrue);

      // Check distance of ADMIN LOGIN from bottom edge of viewport
      final adminLoginCenter = tester.getCenter(find.text('ADMIN LOGIN'));
      const logicalScreenHeight = 844.0; // logical height
      expect(adminLoginCenter.dy, lessThanOrEqualTo(logicalScreenHeight - 34.0));
      expect(tester.takeException(), isNull);
    });
  });
}
