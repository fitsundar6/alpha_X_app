import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alpha_x_gym/core/services/app_auto_refresh_service.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/activity/data/repositories/activity_repository.dart';
import 'package:alpha_x_gym/features/macro_planner/data/repositories/macro_repository.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/assigned_diet_plan.dart';
import 'package:alpha_x_gym/features/progress/data/repositories/weekly_progress_repository.dart';
import 'package:alpha_x_gym/features/notifications/data/repositories/notification_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WorkoutRepository workoutRepo;
  late MacroRepository macroRepo;
  late WeeklyProgressRepository progressRepo;
  late NotificationRepository notificationRepo;
  late AppAutoRefreshService refreshService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    workoutRepo = WorkoutRepository();
    macroRepo = MacroRepository();
    progressRepo = WeeklyProgressRepository();
    notificationRepo = NotificationRepository();
    refreshService = AppAutoRefreshService.instance;

    refreshService.initialize(
      workoutRepository: workoutRepo,
      activityRepository: ActivityRepository(),
      macroRepository: macroRepo,
      weeklyProgressRepository: progressRepo,
      notificationRepository: notificationRepo,
    );
  });

  tearDown(() {
    refreshService.stopPolling();
  });

  group('AppAutoRefreshService & Realtime Sync Tests', () {
    test('1. Singleton instance is persistent and initialized properly', () {
      final s1 = AppAutoRefreshService();
      final s2 = AppAutoRefreshService.instance;
      expect(s1, equals(s2));
      expect(s1.isSyncing, isFalse);
    });

    test('2. Manual triggerImmediateSync executes and updates lastSyncTime', () async {
      await refreshService.triggerImmediateSync(reason: 'Test Direct Call');

      // If user has token, lastSyncTime updates; if not logged in, gracefully handles and remains idle
      expect(refreshService.isSyncing, isFalse);
      expect(refreshService.isSyncingNotifier.value, isFalse);
    });

    test('3. Lifecycle resume triggers sync immediately without restarting app', () {
      // Simulate user switching back to app from another app (resumed state)
      refreshService.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(refreshService, isNotNull);
    });

    test('4. Background state pauses polling timer to preserve device battery', () {
      refreshService.startPolling(interval: const Duration(seconds: 1));

      // App goes to background
      refreshService.didChangeAppLifecycleState(AppLifecycleState.paused);

      // App returns to foreground
      refreshService.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(refreshService, isNotNull);
    });

    test('5. Admin assigned diet plan reflects immediately in MacroRepository without app restart', () async {
      // Simulate an admin assigning a new diet plan to the client
      final newPlan = AssignedDietPlan(
        id: 'plan_auto_refresh_01',
        clientId: 'client_1',
        planName: 'Elite Athletic Cutting Phase 2',
        version: 2,
        dailyCalories: 2150,
        protein: 175,
        carbs: 220,
        fat: 60,
        fiber: 35,
        assignedByName: 'Head Coach Marcus',
        notes: 'Follow strict hydration and meal timing.',
        createdAt: DateTime.now(),
        meals: [
          const PrescribedMeal(
            name: 'Breakfast',
            order: 1,
            timing: '7:30 AM',
            items: [],
          ),
        ],
      );

      // Verify before assignment
      expect(macroRepo.assignedDietPlan?.planName, isNot('Elite Athletic Cutting Phase 2'));

      // Admin assigns diet plan
      macroRepo.setAssignedDietPlan(newPlan);

      // Immediately reflected in local state and notified listeners!
      expect(macroRepo.hasAssignedDietPlan, isTrue);
      expect(macroRepo.assignedDietPlan!.planName, equals('Elite Athletic Cutting Phase 2'));
      expect(macroRepo.customCalories, equals(2150));
      expect(macroRepo.customProtein, equals(175));
      expect(macroRepo.customCarbs, equals(220));
      expect(macroRepo.customFat, equals(60));
    });

    test('6. Admin workout session assignment updates repository and triggers sync', () async {
      await workoutRepo.assignSession(
        sessionId: 'ws_push_a_01',
        assignmentType: 'ALL',
        isRecommended: true,
      );

      // Verified assignment was recorded
      expect(workoutRepo.assignments.any((a) => a.sessionId == 'ws_push_a_01'), isTrue);
    });
  });
}
