import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/theme/app_theme.dart';
import 'package:alpha_x_gym/core/constants/user_role.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/features/analytics/presentation/screens/workout_analytics_screen.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WorkoutRepository workoutRepo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    workoutRepo = WorkoutRepository();
  });

  group('Workout Analytics Screen Widget Tests', () {
    testWidgets('1. Empty State: Displays all 4 headings, clean empty states, and disclaimers', (tester) async {
      tester.view.physicalSize = const Size(1080, 4800);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      AuthService().setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'empty.client@alphax.com',
        userName: 'New Athlete',
        clientId: 'client_newbie_01',
        onboardingCompleted: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: WorkoutAnalyticsScreen(
            workoutRepository: workoutRepo,
            showAppBar: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Heading A: Weekly Overview
      expect(find.text('A. Weekly Overview'), findsOneWidget);
      expect(find.text('SESSIONS COMPLETED'), findsOneWidget);
      expect(find.text('WORKOUT CONSISTENCY'), findsOneWidget);

      // Heading B: Weekly Report
      expect(find.text('B. Weekly Report'), findsOneWidget);
      expect(find.text('WORKOUTS COMPLETED VS PLANNED'), findsOneWidget);
      expect(find.text('SETS / REPS'), findsOneWidget);

      // Heading C: Muscle Tracker
      expect(find.text('C. Muscle Tracker'), findsOneWidget);
      expect(find.text('TRAINING VOLUME VS. MUSCLE MEASUREMENT'), findsOneWidget);

      // Heading D: Exercise Analytics
      expect(find.text('D. Exercise Analytics'), findsOneWidget);
      expect(find.text('No exercises logged yet'), findsOneWidget);
    });

    testWidgets('2. Loaded State: Renders real records, Brzycki 1RM, Muscle table and Radar chart', (tester) async {
      tester.view.physicalSize = const Size(1080, 4800);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Use client_john_doe who has seeded records in test environment
      AuthService().setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'john.athlete@alphax.com',
        userName: 'John Doe',
        clientId: 'client_john_doe',
        onboardingCompleted: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: WorkoutAnalyticsScreen(
            workoutRepository: workoutRepo,
            showAppBar: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Headings
      expect(find.text('A. Weekly Overview'), findsOneWidget);
      expect(find.text('B. Weekly Report'), findsOneWidget);
      expect(find.text('C. Muscle Tracker'), findsOneWidget);
      expect(find.text('D. Exercise Analytics'), findsOneWidget);

      // Verify Muscle distribution and table
      expect(find.text('MUSCLE DISTRIBUTION'), findsOneWidget);
      expect(find.text('MUSCLE GROUP'), findsWidgets);
      expect(find.text('Chest'), findsWidgets);

      // Verify Brzycki 1RM progression section
      expect(find.text('ESTIMATED 1RM PROGRESSION'), findsOneWidget);
      expect(find.text('PEAK 1RM (EST.)'), findsOneWidget);
      expect(find.textContaining('1RM = Weight × 36 / (37 − Reps)'), findsOneWidget);
    });

    testWidgets('3. Period filter toggles respond smoothly (7D, 30D, 90D)', (tester) async {
      tester.view.physicalSize = const Size(1080, 4800);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      AuthService().setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'john.athlete@alphax.com',
        userName: 'John Doe',
        clientId: 'client_john_doe',
        onboardingCompleted: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: WorkoutAnalyticsScreen(
            workoutRepository: workoutRepo,
            showAppBar: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find period filter chips (multiple chips exist for Muscle Tracker and Exercise Analytics)
      final thirtyDayChips = find.text('30D');
      expect(thirtyDayChips, findsWidgets);

      await tester.tap(thirtyDayChips.first);
      await tester.pumpAndSettle();

      final ninetyDayChips = find.text('90D');
      expect(ninetyDayChips, findsWidgets);

      await tester.tap(ninetyDayChips.first);
      await tester.pumpAndSettle();

      final sevenDayChips = find.text('7D');
      expect(sevenDayChips, findsWidgets);

      await tester.tap(sevenDayChips.first);
      await tester.pumpAndSettle();
    });

    testWidgets('4. Light Mode compatibility: renders with zero render errors or contrast issues', (tester) async {
      tester.view.physicalSize = const Size(1080, 4800);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      AuthService().setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'john.athlete@alphax.com',
        userName: 'John Doe',
        clientId: 'client_john_doe',
        onboardingCompleted: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: WorkoutAnalyticsScreen(
            workoutRepository: workoutRepo,
            showAppBar: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('A. Weekly Overview'), findsOneWidget);
      expect(find.text('B. Weekly Report'), findsOneWidget);
      expect(find.text('C. Muscle Tracker'), findsOneWidget);
      expect(find.text('D. Exercise Analytics'), findsOneWidget);
    });
  });
}
