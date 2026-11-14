import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/constants/user_role.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/features/dashboard/admin_main_dashboard_screen.dart';
import 'package:alpha_x_gym/features/ai_coach/presentation/admin_ai_coach_screen.dart';
import 'package:alpha_x_gym/features/workout/presentation/admin/admin_workout_sessions_screen.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/activity/data/repositories/activity_repository.dart';
import 'package:alpha_x_gym/features/macro_planner/data/repositories/macro_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Admin UI Contrast, Avatars & Layout Verification Tests', () {
    late AuthService auth;
    late WorkoutRepository workoutRepo;
    late ActivityRepository activityRepo;
    late MacroRepository macroRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      auth = AuthService();
      await auth.logout();
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.admin,
        email: 'fitsundar6@gmail.com',
        userId: 'admin_001',
        clientId: 'AXG-ADMIN',
        onboardingCompleted: true,
      );
      workoutRepo = WorkoutRepository();
      activityRepo = ActivityRepository();
      macroRepo = MacroRepository();

      workoutRepo.setClientsForTesting([
        {
          'id': 'user_001',
          'clientId': 'AXG-0012',
          'name': 'Shyam Anandr',
          'email': 's***@gmail.com',
          'primaryGoal': 'Strength',
          'status': 'ACTIVE',
        },
        {
          'id': 'user_002',
          'clientId': 'AXG-0014',
          'name': 'Rajapandi',
          'email': 'i***@gmail.com',
          'primaryGoal': 'Muscle Gain',
          'status': 'ACTIVE',
        },
      ]);
    });

    tearDown(() async {
      await auth.logout();
    });

    testWidgets('1. Admin Clients Tab: CircleAvatar client initials render with contrasting onPrimary (black) text', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminMainDashboardScreen(
              workoutRepository: workoutRepo,
              activityRepository: activityRepo,
              macroRepository: macroRepo,
              initialIndex: 1, // Tab 1 = CLIENTS
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find any CircleAvatar in the client list
      final avatarFinder = find.byType(CircleAvatar);
      expect(avatarFinder, findsWidgets);

      // Verify each text child inside CircleAvatar has non-white contrasting text
      final textList = tester.widgetList<Text>(
        find.descendant(of: avatarFinder, matching: find.byType(Text)),
      );

      expect(textList.isNotEmpty, isTrue);
      for (final textWidget in textList) {
        expect(textWidget.style?.color, equals(AppColors.onPrimary));
        expect(textWidget.style?.color, isNot(Colors.white));
      }
    });

    testWidgets('2. Admin AI Coach: Send Button Icon renders with contrasting onPrimary (black) color on white circular button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminAiCoachScreen(showAppBar: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sendIconFinder = find.byIcon(Icons.send);
      expect(sendIconFinder, findsOneWidget);

      final iconWidget = tester.widget<Icon>(sendIconFinder);
      expect(iconWidget.color, equals(AppColors.onPrimary));
      expect(iconWidget.color, isNot(Colors.white));
    });

    testWidgets('3. Admin Workout Command Tab: Sub-tab bar has contrasting onPrimary labelColor and isScrollable', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminMainDashboardScreen(
              workoutRepository: workoutRepo,
              activityRepository: activityRepo,
              macroRepository: macroRepo,
              initialIndex: 2, // Tab 2 = WORKOUT COMMAND
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tabBarFinder = find.byType(TabBar);
      expect(tabBarFinder, findsWidgets);

      final tabBar = tester.widget<TabBar>(tabBarFinder.first);
      expect(tabBar.labelColor, equals(AppColors.onPrimary));
      expect(tabBar.labelColor, isNot(Colors.white));
      expect(tabBar.isScrollable, isTrue);
    });

    testWidgets('4. Admin Macro & Diet Command Tab: Sub-tab bar has contrasting onPrimary labelColor and isScrollable', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminMainDashboardScreen(
              workoutRepository: workoutRepo,
              activityRepository: activityRepo,
              macroRepository: macroRepo,
              initialIndex: 3, // Tab 3 = MACRO & DIET
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tabBarFinder = find.byType(TabBar);
      expect(tabBarFinder, findsWidgets);

      final tabBar = tester.widget<TabBar>(tabBarFinder.first);
      expect(tabBar.labelColor, equals(AppColors.onPrimary));
      expect(tabBar.labelColor, isNot(Colors.white));
      expect(tabBar.isScrollable, isTrue);
    });

    testWidgets('5. Admin Workout Sessions: Selected filter chip has contrasting onPrimary text color on white pill', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminWorkoutSessionsScreen(
              workoutRepository: workoutRepo,
              showAppBar: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the 'All (' filter chip text widget
      final allTextFinder = find.textContaining('All (');
      expect(allTextFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(allTextFinder);
      expect(textWidget.style?.color, equals(AppColors.onPrimary));
      expect(textWidget.style?.color, isNot(Colors.white));
    });

    testWidgets('6. Admin AppBar Title is wrapped in FittedBox to prevent title ellipsis on narrow screens', (tester) async {
      // Small screen: iPhone SE 320px
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminMainDashboardScreen(
              workoutRepository: workoutRepo,
              activityRepository: activityRepo,
              macroRepository: macroRepo,
              initialIndex: 2, // WORKOUT COMMAND
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Title should not overflow or cause RenderFlex error
      expect(tester.takeException(), isNull);

      final fittedBoxFinder = find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(FittedBox),
      );
      expect(fittedBoxFinder, findsWidgets);
    });

    testWidgets('7. Admin Clients Tab: Client names use FittedBox to preserve full legibility on narrow viewports', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminMainDashboardScreen(
              workoutRepository: workoutRepo,
              activityRepository: activityRepo,
              macroRepository: macroRepo,
              initialIndex: 1, // CLIENTS
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Shyam Anandr'), findsOneWidget);

      final nameFittedBoxFinder = find.descendant(
        of: find.byType(ListTile),
        matching: find.byType(FittedBox),
      );
      expect(nameFittedBoxFinder, findsWidgets);
    });
  });
}
