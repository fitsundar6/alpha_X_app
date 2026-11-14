import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/constants/user_role.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/features/onboarding/client_onboarding_screen.dart';
import 'package:alpha_x_gym/features/exercise/presentation/client/client_exercise_library_tab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Selection and Badge Contrast Tests (White-on-White Prevention)', () {
    late AuthService auth;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      auth = AuthService();
      await auth.logout();
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'athlete@alphaxgym.com',
        userId: 'athlete_123',
        clientId: 'AXG-7788',
        onboardingCompleted: false,
      );
    });

    tearDown(() async {
      await auth.logout();
    });

    testWidgets('1. Client ID badge in Onboarding Screen has contrasting black text on white background', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/dashboard': (_) => const SizedBox(),
          },
          home: const Scaffold(
            body: ClientOnboardingScreen(initialStep: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the client ID text widget
      final textFinder = find.text('AXG-7788');
      expect(textFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(textFinder);
      expect(textWidget.style?.color, AppColors.onPrimary);
      expect(textWidget.style?.color, isNot(Colors.white));
    });

    testWidgets('2. Choice card checkmark in Onboarding has contrasting black color on selected white circle', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/dashboard': (_) => const SizedBox(),
          },
          home: const Scaffold(
            body: ClientOnboardingScreen(initialStep: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "BEGINNER" to select it
      await tester.tap(find.text('BEGINNER'));
      await tester.pumpAndSettle();

      // The checkmark icon inside the selected radio circle must have onPrimary (black) color
      final checkIconFinder = find.byIcon(Icons.check);
      expect(checkIconFinder, findsOneWidget);

      final checkIcon = tester.widget<Icon>(checkIconFinder);
      expect(checkIcon.color, AppColors.onPrimary);
      expect(checkIcon.color, isNot(Colors.white));
    });

    testWidgets('3. Exercise Library Category FilterChip has contrasting black text when selected', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ClientExerciseLibraryTab(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the 'Chest' filter chip
      final chestChipFinder = find.widgetWithText(FilterChip, 'Chest');
      expect(chestChipFinder, findsOneWidget);

      await tester.tap(chestChipFinder);
      await tester.pumpAndSettle();

      final chipWidget = tester.widget<FilterChip>(chestChipFinder);
      expect(chipWidget.selected, isTrue);
      expect(chipWidget.labelStyle?.color, AppColors.onPrimary);
      expect(chipWidget.labelStyle?.color, isNot(Colors.white));
    });

    testWidgets('4. Step 3 Gender ChoiceChip (Female) has contrasting black text when selected', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/dashboard': (_) => const SizedBox(),
          },
          home: const Scaffold(
            body: ClientOnboardingScreen(initialStep: 3),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'Female' choice chip
      final femaleFinder = find.widgetWithText(ChoiceChip, 'Female');
      expect(femaleFinder, findsOneWidget);

      await tester.tap(femaleFinder);
      await tester.pumpAndSettle();

      final chip = tester.widget<ChoiceChip>(femaleFinder);
      expect(chip.selected, isTrue);
      final textWidget = chip.label as Text;
      expect(textWidget.style?.color, AppColors.onPrimary);
      expect(textWidget.style?.color, isNot(Colors.white));
    });

    testWidgets('5. Step 5 Training Availability day container (4) has contrasting black text when selected', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/dashboard': (_) => const SizedBox(),
          },
          home: const Scaffold(
            body: ClientOnboardingScreen(initialStep: 5),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find '4' days button
      final dayFinder = find.text('4');
      expect(dayFinder, findsOneWidget);

      await tester.tap(dayFinder);
      await tester.pumpAndSettle();

      final textWidget = tester.widget<Text>(dayFinder);
      expect(textWidget.style?.color, AppColors.onPrimary);
      expect(textWidget.style?.color, isNot(Colors.white));
    });
  });
}
