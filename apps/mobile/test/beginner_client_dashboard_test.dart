import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/theme/app_theme.dart';
import 'package:alpha_x_gym/core/constants/user_role.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/core/theme/client_theme_service.dart';
import 'package:alpha_x_gym/features/dashboard/client_main_dashboard_screen.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/activity/data/repositories/activity_repository.dart';
import 'package:alpha_x_gym/features/macro_planner/data/repositories/macro_repository.dart';
import 'package:alpha_x_gym/features/macro_planner/presentation/widgets/add_food_bottom_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService().setAuthenticatedSessionForTesting(
      role: UserRole.client,
      email: 'alex.athlete@alphax.com',
      userName: 'Alex Mercer',
      clientId: 'AXG-0001',
      onboardingCompleted: true,
    );
  });

  group('Optimized Beginner Client Dashboard Tests', () {
    testWidgets('Dashboard renders clear beginner hierarchy: Greeting, Today\'s Plan, 3 Core Cards & Secondary Portal', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: ClientMainDashboardScreen(
            workoutRepository: WorkoutRepository(),
            activityRepository: ActivityRepository(),
            macroRepository: MacroRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Personalized Greeting & Client ID
      expect(find.textContaining('ALEX'), findsWidgets);
      expect(find.text('AXG-0001'), findsOneWidget);

      // 2. Clear Section Header: TODAY'S PLAN
      expect(find.text("TODAY'S PLAN"), findsOneWidget);

      // 3. Priority 1: Today's Workout Card with Primary Action
      expect(find.text("TODAY'S WORKOUT"), findsOneWidget);
      expect(find.text('START WORKOUT'), findsOneWidget);

      // 4. Priority 2: Today's Nutrition & Macros Card with Log Food & View Macros Actions
      expect(find.text("TODAY'S NUTRITION"), findsOneWidget);
      expect(find.text('LOG FOOD'), findsOneWidget);
      expect(find.text('VIEW MACROS'), findsOneWidget);

      // 5. Priority 3: Progress Card with Check-In / Summary Action
      expect(find.text("PROGRESS & CHECK-IN"), findsOneWidget);
      expect(find.byIcon(Icons.monitor_weight_outlined), findsOneWidget);
      expect(find.byIcon(Icons.directions_walk_rounded), findsWidgets);

      // 6. Secondary Navigation: MY ATHLETE PORTAL
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.text('MY ATHLETE PORTAL'), findsOneWidget);
      expect(find.text('MY WORKOUT'), findsOneWidget);
      expect(find.text('EXERCISE LIBRARY'), findsOneWidget);
      expect(find.text('NUTRITION & MACROS'), findsOneWidget);
      expect(find.text('FOOD PHOTOS'), findsOneWidget);
      expect(find.text('DAILY STEPS'), findsOneWidget);
      expect(find.text('MY PROGRESS'), findsOneWidget);
      expect(find.text('MY PROFILE'), findsOneWidget);
    });

    testWidgets('Tapping LOG FOOD opens AddFoodBottomSheet directly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: ClientMainDashboardScreen(
            workoutRepository: WorkoutRepository(),
            activityRepository: ActivityRepository(),
            macroRepository: MacroRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final logFoodButton = find.text('LOG FOOD');
      expect(logFoodButton, findsOneWidget);

      await tester.tap(logFoodButton);
      await tester.pumpAndSettle();

      expect(find.byType(AddFoodBottomSheet), findsOneWidget);
    });

    testWidgets('Tapping VIEW MACROS switches to Nutrition tab (tab index 3)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: ClientMainDashboardScreen(
            workoutRepository: WorkoutRepository(),
            activityRepository: ActivityRepository(),
            macroRepository: MacroRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final viewMacrosButton = find.text('VIEW MACROS');
      expect(viewMacrosButton, findsOneWidget);

      await tester.tap(viewMacrosButton);
      await tester.pumpAndSettle();

      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 3);
    });

    testWidgets('Dashboard renders comfortably in Light Mode without contrast or layout issues', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await ClientThemeService().setThemeMode(ClientThemeMode.light);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ClientMainDashboardScreen(
            workoutRepository: WorkoutRepository(),
            activityRepository: ActivityRepository(),
            macroRepository: MacroRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("TODAY'S PLAN"), findsOneWidget);
      expect(find.text("TODAY'S WORKOUT"), findsOneWidget);
      expect(find.text("TODAY'S NUTRITION"), findsOneWidget);
      expect(find.text("PROGRESS & CHECK-IN"), findsOneWidget);

      // Restore dark theme
      await ClientThemeService().setThemeMode(ClientThemeMode.dark);
    });
  });
}
