import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/theme/app_theme.dart';
import 'package:alpha_x_gym/core/constants/user_role.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/features/dashboard/client_main_dashboard_screen.dart';
import 'package:alpha_x_gym/features/dashboard/admin_main_dashboard_screen.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/activity/data/repositories/activity_repository.dart';
import 'package:alpha_x_gym/features/macro_planner/data/repositories/macro_repository.dart';
import 'package:alpha_x_gym/features/exercise/presentation/widgets/exercise_detail_modal.dart';
import 'package:alpha_x_gym/features/exercise/data/repositories/exercise_repository.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_bottom_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Client Back Navigation & History Stack Tests', () {
    testWidgets('Dashboard -> Workout -> Exercises -> Back -> Workout -> Back -> Dashboard flow', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      AuthService().setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'client@alphaxgym.com',
      );

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

      // Initially at tab 0: Home / Dashboard
      expect(find.text('ALPHA X GYM'), findsOneWidget);

      // 1. Navigate to Workout tab (Tab 1)
      var navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      navBar.onDestinationSelected!(1);
      await tester.pumpAndSettle();

      navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 1);

      // 2. Navigate to Exercises tab (Tab 2)
      navBar.onDestinationSelected!(2);
      await tester.pumpAndSettle();

      navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 2);

      // 3. Trigger Android System Back (PopScope invocation)
      final popScopeFinder = find.byWidgetPredicate((w) => w is PopScope);
      expect(popScopeFinder, findsWidgets);

      final popScopeWidget = tester.widget(popScopeFinder.first) as PopScope;
      popScopeWidget.onPopInvokedWithResult?.call(false, null);
      await tester.pumpAndSettle();

      // Verify we returned to Workout tab (Tab 1)
      navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 1);

      // 4. Trigger Back again -> should return to Home (Tab 0)
      popScopeWidget.onPopInvokedWithResult?.call(false, null);
      await tester.pumpAndSettle();

      navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 0);

      // 5. Trigger Back at root -> should show double-back exit snackbar
      popScopeWidget.onPopInvokedWithResult?.call(false, null);
      await tester.pumpAndSettle();

      expect(find.text('Press back again to exit Alpha X Gym'), findsOneWidget);
    });

    testWidgets('Client Dashboard responds to right-to-left edge swipe gesture', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      AuthService().setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'client@alphaxgym.com',
      );

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

      var navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      navBar.onDestinationSelected!(1);
      await tester.pumpAndSettle();

      navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 1);

      // Perform fling from the RIGHT EDGE toward left (dx from screenWidth - 10, speed 1000)
      final screenWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;
      await tester.flingFrom(Offset(screenWidth - 10, 800), const Offset(-300, 0), 1000.0);
      await tester.pumpAndSettle();

      // Should have navigated back to tab 0 (Home)
      navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 0);
    });

    testWidgets('Client Drawer closes on back without changing tab', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      AuthService().setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'client@alphaxgym.com',
      );

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

      // Switch to Workout tab (Tab 1)
      var navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      navBar.onDestinationSelected!(1);
      await tester.pumpAndSettle();

      navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 1);

      // Open drawer
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold).first);
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // Verify drawer is open
      expect(scaffoldState.isDrawerOpen, isTrue);

      // Invoke back
      final popScopeFinder = find.byWidgetPredicate((w) => w is PopScope);
      final popScope = tester.widget(popScopeFinder.first) as PopScope;
      popScope.onPopInvokedWithResult?.call(false, null);
      await tester.pumpAndSettle();

      // Drawer is closed, but tab is still Workout (tab 1)
      expect(scaffoldState.isDrawerOpen, isFalse);
      navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 1);
    });
  });

  group('Admin Back Navigation & History Stack Tests', () {
    testWidgets('Admin Dashboard -> Clients -> Workout Sessions -> Back -> Clients -> Back -> Dashboard flow', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      AuthService().setAuthenticatedSessionForTesting(
        role: UserRole.admin,
        email: 'admin@alphaxgym.com',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: AdminMainDashboardScreen(
            workoutRepository: WorkoutRepository(),
            activityRepository: ActivityRepository(),
            macroRepository: MacroRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially at tab 0: AI Coach
      expect(find.text('🤖 AI COACH'), findsOneWidget);

      var adminNavBar = tester.widget<NavigationBar>(find.byType(NavigationBar));

      // Select Clients tab (index 1)
      adminNavBar.onDestinationSelected!(1);
      await tester.pumpAndSettle();
      expect(find.text('👥 CLIENTS'), findsOneWidget);

      // Select Sessions tab (index 2)
      adminNavBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      adminNavBar.onDestinationSelected!(2);
      await tester.pumpAndSettle();
      expect(find.text('🏋️ WORKOUT COMMAND'), findsOneWidget);

      // Back 1: returns to Clients
      final popScopeFinder = find.byWidgetPredicate((w) => w is PopScope);
      final popScope = tester.widget(popScopeFinder.first) as PopScope;
      popScope.onPopInvokedWithResult?.call(false, null);
      await tester.pumpAndSettle();
      expect(find.text('👥 CLIENTS'), findsOneWidget);

      // Back 2: returns to AI Coach
      popScope.onPopInvokedWithResult?.call(false, null);
      await tester.pumpAndSettle();
      expect(find.text('🤖 AI COACH'), findsOneWidget);

      // Back 3: shows double-back exit snackbar
      popScope.onPopInvokedWithResult?.call(false, null);
      await tester.pumpAndSettle();
      expect(find.text('Press back again to exit Admin Panel'), findsOneWidget);
    });

    testWidgets('Admin Dashboard responds to right-to-left edge swipe gesture', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      AuthService().setAuthenticatedSessionForTesting(
        role: UserRole.admin,
        email: 'admin@alphaxgym.com',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: AdminMainDashboardScreen(
            workoutRepository: WorkoutRepository(),
            activityRepository: ActivityRepository(),
            macroRepository: MacroRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Clients tab
      final adminNavBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      adminNavBar.onDestinationSelected!(1);
      await tester.pumpAndSettle();
      expect(find.text('👥 CLIENTS'), findsOneWidget);

      // Perform fling from the RIGHT EDGE toward left
      final screenWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;
      await tester.flingFrom(Offset(screenWidth - 10, 400), const Offset(-300, 0), 1000.0);
      await tester.pumpAndSettle();

      // Should have navigated back to tab 0 (AI Coach)
      expect(find.text('🤖 AI COACH'), findsOneWidget);
    });
  });

  group('Modal and Sheet Right-Edge Swipe Tests', () {
    testWidgets('ExerciseDetailModal closes on right-to-left swipe', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final exercise = ExerciseRepository().allExercises.first;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => ExerciseDetailModal.show(ctx, exercise),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open the modal
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text(exercise.displayName), findsOneWidget);

      // Perform right-to-left swipe from the right edge
      final screenWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;
      await tester.flingFrom(Offset(screenWidth - 10, 500), const Offset(-300, 0), 1000.0);
      await tester.pumpAndSettle();

      // Modal should be dismissed
      expect(find.text(exercise.displayName), findsNothing);
    });

    testWidgets('AlphaXBottomSheet closes on right-to-left swipe', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => AlphaXBottomSheet.show(
                  context: ctx,
                  child: const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Custom Sheet Content'),
                  ),
                ),
                child: const Text('Open Custom Sheet'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open sheet
      await tester.tap(find.text('Open Custom Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Custom Sheet Content'), findsOneWidget);

      // Swipe from right edge to left at the exact Y center of the sheet content
      final screenWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;
      final sheetCenterY = tester.getCenter(find.text('Custom Sheet Content')).dy;
      await tester.flingFrom(Offset(screenWidth - 10, sheetCenterY), const Offset(-300, 0), 1000.0);
      await tester.pumpAndSettle();

      // Sheet should be dismissed
      expect(find.text('Custom Sheet Content'), findsNothing);
    });
  });
}
