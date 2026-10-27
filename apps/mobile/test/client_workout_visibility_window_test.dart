import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/core/constants/user_role.dart';
import 'package:alpha_x_gym/core/utils/ist_date_utils.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';
import 'package:alpha_x_gym/features/workout/presentation/client/client_workout_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IstDateUtils.resetDateProviderForTesting();
    IstDateUtils.resetServerTime();
  });

  tearDown(() {
    IstDateUtils.resetDateProviderForTesting();
    IstDateUtils.resetServerTime();
  });

  group('Alpha X Gym — 5:00 AM to 9:00 PM IST Client Workout Visibility Window', () {
    test('Boundary test: Opening boundary at 05:00:00 IST', () {
      // 04:59:59.000 IST (UTC: 2026-10-25 23:29:59.000Z) -> Hidden
      final beforeOpen = DateTime.utc(2026, 10, 25, 23, 29, 59);
      expect(IstDateUtils.isScheduledWorkoutVisibleInIST(beforeOpen), isFalse,
          reason: '4:59:59 AM IST must be hidden');

      // 04:59:59.999 IST -> Hidden
      final beforeOpenMs = DateTime.utc(2026, 10, 25, 23, 29, 59, 999);
      expect(IstDateUtils.isScheduledWorkoutVisibleInIST(beforeOpenMs), isFalse,
          reason: '4:59:59.999 AM IST must be hidden');

      // 05:00:00.000 IST (UTC: 2026-10-25 23:30:00.000Z) -> Visible (Opening boundary)
      final atOpen = DateTime.utc(2026, 10, 25, 23, 30, 0);
      expect(IstDateUtils.isScheduledWorkoutVisibleInIST(atOpen), isTrue,
          reason: '5:00:00 AM IST exactly must be visible');

      // 05:00:01.000 IST -> Visible
      final afterOpen = DateTime.utc(2026, 10, 25, 23, 30, 1);
      expect(IstDateUtils.isScheduledWorkoutVisibleInIST(afterOpen), isTrue,
          reason: '5:00:01 AM IST must be visible');
    });

    test('Boundary test: Closing boundary at 21:00:00 IST and after 9:00 PM', () {
      // 12:00:00 IST (Midday, UTC: 06:30:00Z) -> Visible
      final midday = DateTime.utc(2026, 10, 26, 6, 30, 0);
      expect(IstDateUtils.isScheduledWorkoutVisibleInIST(midday), isTrue,
          reason: 'Midday 12:00 PM IST must be visible');

      // 20:59:59.000 IST (8:59:59 PM IST, UTC: 15:29:59Z) -> Visible
      final beforeClose = DateTime.utc(2026, 10, 26, 15, 29, 59);
      expect(IstDateUtils.isScheduledWorkoutVisibleInIST(beforeClose), isTrue,
          reason: '8:59:59 PM IST must be visible');

      // 21:00:00.000 IST (9:00:00 PM IST exactly, UTC: 15:30:00Z) -> Visible (Closing boundary)
      final atClose = DateTime.utc(2026, 10, 26, 15, 30, 0);
      expect(IstDateUtils.isScheduledWorkoutVisibleInIST(atClose), isTrue,
          reason: '9:00:00 PM IST exactly must be visible');

      // 21:00:00.001 IST -> Hidden (After 9:00 PM)
      final afterCloseMs = DateTime.utc(2026, 10, 26, 15, 30, 0, 1);
      expect(IstDateUtils.isScheduledWorkoutVisibleInIST(afterCloseMs), isFalse,
          reason: '21:00:00.001 IST must be automatically hidden');

      // 21:00:01.000 IST (9:00:01 PM IST, UTC: 15:30:01Z) -> Hidden
      final afterCloseSec = DateTime.utc(2026, 10, 26, 15, 30, 1);
      expect(IstDateUtils.isScheduledWorkoutVisibleInIST(afterCloseSec), isFalse,
          reason: '9:00:01 PM IST must be automatically hidden');

      // 22:15:00.000 IST (10:15 PM IST) -> Hidden
      final lateNight = DateTime.utc(2026, 10, 26, 16, 45, 0);
      expect(IstDateUtils.isScheduledWorkoutVisibleInIST(lateNight), isFalse,
          reason: '10:15 PM IST must be automatically hidden');
    });

    test('Server-backed time synchronization with Asia/Kolkata timezone offset', () {
      // Simulate server returning UTC timestamp corresponding to 21:00:05 IST
      // 21:00:05 IST = 15:30:05 UTC
      final serverTimestampIso = '2026-10-26T15:30:05.000Z';
      IstDateUtils.syncServerTimeString(serverTimestampIso);

      expect(IstDateUtils.hasSyncedServerTime, isTrue);

      // Now nowInIST() is server-backed
      final nowIst = IstDateUtils.nowInIST();
      expect(nowIst.hour, equals(21));
      expect(nowIst.minute, equals(0));
      expect(nowIst.second, greaterThanOrEqualTo(5));

      // After 9:00 PM IST according to server-backed time
      expect(IstDateUtils.isScheduledWorkoutVisibleInIST(), isFalse);
    });

    test('WorkoutRepository: Today session is visible within window and hidden after 9:00 PM IST', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
      });
      final repo = WorkoutRepository(httpClient: client);
      const testClientId = 'client_vis_001';

      // Monday 2026-10-26
      final mondaySession = WorkoutSession(
        id: 'ws_mon_chest',
        title: 'Monday Chest Press',
        workoutType: 'Strength',
        targetMuscleGroup: 'Chest',
        difficulty: 'Intermediate',
        estimatedDurationMinutes: 45,
        isActive: true,
        recurringSchedule: 'Monday',
        trainingDays: const [1], // Monday
        exercises: const [
          WorkoutExercise(
            id: 'we_bench',
            exerciseId: 'ex_bench',
            exerciseName: 'Bench Press',
            category: 'Chest',
            primaryMusclesDisplay: 'Chest',
            secondaryMusclesDisplay: 'Triceps',
            trainerNote: 'Drive with chest',
            sets: [
              ExerciseSet(id: 's1', setNumber: 1, targetRepsMin: 10, targetRepsMax: 10, targetWeight: 60),
            ],
          ),
        ],
      );

      await repo.createSession(mondaySession);
      await repo.assignSession(
        sessionId: mondaySession.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: testClientId,
        scheduledDate: '2026-10-26',
        isRecommended: true,
      );

      // Test at 10:00:00 AM IST on Monday 2026-10-26 (UTC: 04:30:00Z)
      IstDateUtils.setDateProviderForTesting(() => DateTime.utc(2026, 10, 26, 4, 30, 0));
      final visibleSession = repo.getTodaySessionForClient(testClientId, enforceVisibilityWindow: true);
      expect(visibleSession, isNotNull, reason: 'Session must be visible at 10:00 AM IST');
      expect(visibleSession!.id, equals(mondaySession.id));
      expect(visibleSession.title, equals('Monday Chest Press'));

      // Test at 21:00:01 PM IST on Monday 2026-10-26 (UTC: 15:30:01Z)
      IstDateUtils.setDateProviderForTesting(() => DateTime.utc(2026, 10, 26, 15, 30, 1));
      final hiddenSession = repo.getTodaySessionForClient(testClientId, enforceVisibilityWindow: true);
      expect(hiddenSession, isNull, reason: 'Scheduled workout session must be hidden after 9:00 PM IST');

      final authorizedSessions = repo.getAuthorizedSessionsForClient(testClientId, enforceVisibilityWindow: true);
      expect(authorizedSessions, isEmpty, reason: 'Authorized sessions for today must be empty after 9:00 PM IST');
    });

    test('Preservation: Pending workouts, completion history, and admin split order remain intact after 9:00 PM', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
      });
      final repo = WorkoutRepository(httpClient: client);
      const testClientId = 'client_vis_002';

      // Past session from Sunday 2026-10-25 that was NOT completed (Pending workout)
      final sundaySession = WorkoutSession(
        id: 'ws_sun_cardio',
        title: 'Sunday HIIT Conditioning',
        workoutType: 'Conditioning',
        targetMuscleGroup: 'Full Body',
        difficulty: 'Intermediate',
        estimatedDurationMinutes: 30,
        isActive: true,
        recurringSchedule: 'Sunday',
        trainingDays: const [7],
        exercises: const [],
      );

      // Past session from Saturday 2026-10-24 that WAS completed
      final saturdaySession = WorkoutSession(
        id: 'ws_sat_legs',
        title: 'Saturday Squats',
        workoutType: 'Strength',
        targetMuscleGroup: 'Legs',
        difficulty: 'Advanced',
        estimatedDurationMinutes: 60,
        isActive: true,
        recurringSchedule: 'Saturday',
        trainingDays: const [6],
        exercises: const [],
      );

      // Today Monday session
      final mondaySession = WorkoutSession(
        id: 'ws_mon_chest',
        title: 'Monday Chest',
        workoutType: 'Strength',
        targetMuscleGroup: 'Chest',
        difficulty: 'Intermediate',
        estimatedDurationMinutes: 45,
        isActive: true,
        recurringSchedule: 'Monday',
        trainingDays: const [1],
        exercises: const [],
      );

      await repo.createSession(sundaySession);
      await repo.createSession(saturdaySession);
      await repo.createSession(mondaySession);

      // Assign Sunday as past assignment
      await repo.assignSession(
        sessionId: sundaySession.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: testClientId,
        scheduledDate: '2026-10-25',
        isRecommended: false,
      );

      // Assign Monday
      await repo.assignSession(
        sessionId: mondaySession.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: testClientId,
        scheduledDate: '2026-10-26',
        isRecommended: true,
      );

      // Add completed record for Saturday in history
      repo.addCompletedRecordForTesting(WorkoutRecord(
        id: 'rec_sat_done',
        sessionId: saturdaySession.id,
        clientId: testClientId,
        sessionTitle: saturdaySession.title,
        workoutType: 'Strength',
        targetMuscleGroup: 'Legs',
        scheduledDate: '2026-10-24',
        startedAt: DateTime.utc(2026, 10, 24, 5, 0),
        completedAt: DateTime.utc(2026, 10, 24, 6, 0),
        isCompleted: true,
        isLocked: true,
        exercises: const [],
      ));

      // Simulate time: 21:30:00 IST on Monday 2026-10-26 (After 9:00 PM IST)
      IstDateUtils.setDateProviderForTesting(() => DateTime.utc(2026, 10, 26, 16, 0, 0));

      // 1. Today's scheduled session is hidden
      final todaySession = repo.getTodaySessionForClient(testClientId, enforceVisibilityWindow: true);
      expect(todaySession, isNull, reason: "Today's scheduled workout must be hidden after 9:00 PM IST");

      // 2. Pending workouts MUST be preserved and accessible
      final pending = repo.getPendingWorkoutsForClient(testClientId);
      expect(pending.isNotEmpty, isTrue);
      expect(pending.any((p) => p.id == sundaySession.id), isTrue);
      expect(pending.any((p) => p.title == 'Sunday HIIT Conditioning'), isTrue);

      // 3. Completion history MUST be preserved
      expect(repo.workoutHistory.isNotEmpty, isTrue);
      expect(repo.workoutHistory.any((r) => r.id == 'rec_sat_done' && r.isCompleted), isTrue);

      // 4. Admin sessions and assignments MUST be preserved
      expect(repo.adminSessions.length, greaterThanOrEqualTo(3));
      expect(repo.adminSessions.any((s) => s.id == mondaySession.id), isTrue);
      expect(repo.adminSessions.any((s) => s.id == saturdaySession.id), isTrue);
      expect(repo.adminSessions.any((s) => s.id == sundaySession.id), isTrue);
      expect(repo.assignments.length, greaterThanOrEqualTo(2));
    });

    testWidgets('Dynamic update: UI automatically transitions to Rest Day when time passes 9:00 PM IST without app restart', (tester) async {
      // Set initial time before repo creation: 20:59:58 IST (8:59:58 PM IST, UTC: 15:29:58Z) -> Visible
      IstDateUtils.setDateProviderForTesting(() => DateTime.utc(2026, 10, 26, 15, 29, 58));

      const testClientId = 'client_dyn_001';

      final todaySession = WorkoutSession(
        id: 'ws_dynamic_today',
        title: 'Upper Body Blitz',
        workoutType: 'Strength',
        targetMuscleGroup: 'Upper Body',
        difficulty: 'Intermediate',
        estimatedDurationMinutes: 50,
        isActive: true,
        recurringSchedule: 'Monday',
        trainingDays: const [1],
        exercises: const [
          WorkoutExercise(
            id: 'we_press',
            exerciseId: 'ex_press',
            exerciseName: 'Overhead Press',
            category: 'Shoulders',
            primaryMusclesDisplay: 'Shoulders',
            secondaryMusclesDisplay: 'Triceps',
            trainerNote: 'Press overhead smoothly',
            sets: [
              ExerciseSet(id: 's1', setNumber: 1, targetRepsMin: 8, targetRepsMax: 12, targetWeight: 40),
            ],
          ),
        ],
      );

      final client = MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'success': true,
            'data': {
              'todaySession': todaySession.copyWith(isRecommended: true, scheduledDate: '2026-10-26').toJson(),
              'available': [todaySession.copyWith(scheduledDate: '2026-10-26').toJson()],
              'pendingWorkouts': [],
              'isRestDay': false,
            }
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final repo = WorkoutRepository(httpClient: client);
      final auth = AuthService();

      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'athlete@alphax.com',
        userId: testClientId,
        userName: 'Alex Athlete',
      );

      await repo.createSession(todaySession);
      await repo.assignSession(
        sessionId: todaySession.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: testClientId,
        scheduledDate: '2026-10-26',
        isRecommended: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClientWorkoutScreen(workoutRepository: repo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify today's workout is visible on screen before 9:00 PM IST
      expect(find.text("⭐ TODAY'S WORKOUT"), findsOneWidget);
      expect(find.text('Upper Body Blitz'), findsOneWidget);
      expect(find.text('REST & RECOVERY DAY'), findsNothing);

      // Advance time across the 9:00 PM closing boundary to 21:00:02 IST (UTC: 15:30:02Z)
      IstDateUtils.setDateProviderForTesting(() => DateTime.utc(2026, 10, 26, 15, 30, 2));

      // Trigger visibility window change check (as performed by periodic ticker / heartbeat)
      final changed = repo.checkVisibilityWindowChange();
      expect(changed, isTrue, reason: 'Visibility window transition must be detected');

      // Pump UI to reflect state without restarting widget or logging out
      await tester.pump();

      // Today's workout session is now hidden automatically
      expect(find.text("⭐ TODAY'S WORKOUT"), findsNothing);
      expect(find.text('Upper Body Blitz'), findsNothing);

      // Rest Day recovery card is now displayed automatically
      expect(find.text('REST & RECOVERY DAY'), findsOneWidget);
      expect(find.text('Active Recovery & Muscle Repair'), findsOneWidget);
    });

    test('HTTP fetchClientWorkouts synchronizes authoritative server time header and meta', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/workout/client/sessions')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'todaySession': null,
                'available': [],
                'pendingWorkouts': [],
                'isRestDay': true,
                'serverTime': '2026-10-26T15:35:00.000Z', // 21:05:00 IST (after 9 PM)
              },
              'meta': {
                'timestamp': '2026-10-26T15:35:00.000Z',
              },
            }),
            200,
            headers: {
              'content-type': 'application/json',
              'date': '2026-10-26T15:35:00.000Z',
            },
          );
        }
        return http.Response('Not Found', 404);
      });

      final repo = WorkoutRepository(httpClient: mockClient);
      final auth = AuthService();
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'sync@alphax.com',
        userId: 'client_srv_sync',
        token: 'valid_test_token',
      );

      expect(IstDateUtils.hasSyncedServerTime, isFalse);

      await repo.fetchClientWorkouts(forceRefresh: true);

      expect(IstDateUtils.hasSyncedServerTime, isTrue);
      expect(IstDateUtils.isScheduledWorkoutVisibleInIST(), isFalse,
          reason: 'Server time is 21:05:00 IST, so scheduled workout must be hidden');
    });

    testWidgets('Full 6-phase verification: Before 5 AM, at 5 AM, during day, at 9 PM, after 9 PM, and next day 5 AM in split order', (tester) async {
      const clientId = 'client_six_phase_001';
      final auth = AuthService();
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'athlete@alphax.com',
        userId: clientId,
      );

      // Admin assigned 2-day split: Monday (Chest) and Tuesday (Back)
      final mondayChest = WorkoutSession(
        id: 'ws_monday_chest',
        title: 'Monday Chest Hypertrophy',
        workoutType: 'Hypertrophy',
        targetMuscleGroup: 'Chest',
        difficulty: 'Intermediate',
        estimatedDurationMinutes: 45,
        isActive: true,
        recurringSchedule: 'Monday',
        trainingDays: const [1], // Monday
        exercises: const [],
      );

      final tuesdayBack = WorkoutSession(
        id: 'ws_tuesday_back',
        title: 'Tuesday Back Hypertrophy',
        workoutType: 'Hypertrophy',
        targetMuscleGroup: 'Back',
        difficulty: 'Intermediate',
        estimatedDurationMinutes: 50,
        isActive: true,
        recurringSchedule: 'Tuesday',
        trainingDays: const [2], // Tuesday
        exercises: const [],
      );

      final client = MockClient((request) async {
        final isVisible = IstDateUtils.isScheduledWorkoutVisibleInIST();
        final todayStr = IstDateUtils.getTodayISTString();
        final sessionForToday = todayStr == '2026-10-26'
            ? mondayChest.copyWith(isRecommended: true, scheduledDate: '2026-10-26')
            : tuesdayBack.copyWith(isRecommended: true, scheduledDate: '2026-10-27');

        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'success': true,
            'data': {
              'todaySession': isVisible ? sessionForToday.toJson() : null,
              'available': [
                mondayChest.copyWith(scheduledDate: '2026-10-26').toJson(),
                tuesdayBack.copyWith(scheduledDate: '2026-10-27').toJson(),
              ],
              'pendingWorkouts': todayStr == '2026-10-27'
                  ? [mondayChest.copyWith(scheduledDate: '2026-10-26').toJson()]
                  : [],
              'isRestDay': !isVisible,
              'serverTime': IstDateUtils.nowInIST().toUtc().toIso8601String(),
            }
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final repo = WorkoutRepository(httpClient: client);

      await repo.createSession(mondayChest);
      await repo.createSession(tuesdayBack);

      await repo.assignSession(
        sessionId: mondayChest.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: clientId,
        scheduledDate: '2026-10-26', // Monday
        isRecommended: true,
      );

      await repo.assignSession(
        sessionId: tuesdayBack.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: clientId,
        scheduledDate: '2026-10-27', // Tuesday
        isRecommended: false,
      );

      // Phase 1: Before 5:00 AM IST on Monday (04:59:59 IST, UTC: 2026-10-25 23:29:59Z)
      IstDateUtils.setDateProviderForTesting(() => DateTime.utc(2026, 10, 25, 23, 29, 59));
      repo.checkVisibilityWindowChange();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClientWorkoutScreen(workoutRepository: repo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("⭐ TODAY'S WORKOUT"), findsNothing, reason: 'Before 5 AM IST: workout must be hidden');
      expect(find.text('Monday Chest Hypertrophy'), findsNothing);
      expect(find.text('REST & RECOVERY DAY'), findsOneWidget, reason: 'Before 5 AM IST: rest/recovery card is shown');

      // Phase 2: At 5:00:00 AM IST on Monday (UTC: 2026-10-25 23:30:00Z)
      IstDateUtils.setDateProviderForTesting(() => DateTime.utc(2026, 10, 25, 23, 30, 0));
      repo.checkVisibilityWindowChange();
      await tester.pump();

      expect(find.text("⭐ TODAY'S WORKOUT"), findsOneWidget, reason: 'At 5:00 AM IST: Monday workout must automatically appear');
      expect(find.text('Monday Chest Hypertrophy'), findsOneWidget);
      expect(find.text('REST & RECOVERY DAY'), findsNothing);

      // Phase 3: During the day on Monday (12:00:00 PM IST, UTC: 2026-10-26 06:30:00Z)
      IstDateUtils.setDateProviderForTesting(() => DateTime.utc(2026, 10, 26, 6, 30, 0));
      repo.checkVisibilityWindowChange();
      await tester.pump();

      expect(find.text("⭐ TODAY'S WORKOUT"), findsOneWidget, reason: 'During day: Monday workout must remain visible');
      expect(find.text('Monday Chest Hypertrophy'), findsOneWidget);

      // Phase 4: At 9:00:00 PM IST on Monday (UTC: 2026-10-26 15:30:00Z)
      IstDateUtils.setDateProviderForTesting(() => DateTime.utc(2026, 10, 26, 15, 30, 0));
      repo.checkVisibilityWindowChange();
      await tester.pump();

      expect(find.text("⭐ TODAY'S WORKOUT"), findsOneWidget, reason: 'At 9:00 PM IST exactly: Monday workout must remain visible');
      expect(find.text('Monday Chest Hypertrophy'), findsOneWidget);

      // Phase 5: After 9:00:00 PM IST on Monday (21:00:01 IST, UTC: 2026-10-26 15:30:01Z)
      IstDateUtils.setDateProviderForTesting(() => DateTime.utc(2026, 10, 26, 15, 30, 1));
      repo.checkVisibilityWindowChange();
      await tester.pump();

      expect(find.text("⭐ TODAY'S WORKOUT"), findsNothing, reason: 'After 9:00 PM IST: Monday workout must automatically hide');
      expect(find.text('Monday Chest Hypertrophy'), findsNothing);
      expect(find.text('REST & RECOVERY DAY'), findsOneWidget, reason: 'After 9:00 PM IST: rest/recovery card is shown');

      // Phase 6: Next day at 5:00:00 AM IST on Tuesday (UTC: 2026-10-26 23:30:00Z)
      IstDateUtils.setDateProviderForTesting(() => DateTime.utc(2026, 10, 26, 23, 30, 0));
      repo.checkVisibilityWindowChange();
      await tester.pump();

      expect(find.text("⭐ TODAY'S WORKOUT"), findsOneWidget, reason: 'Next day 5:00 AM: Tuesday workout in split order must automatically appear');
      expect(find.text('Tuesday Back Hypertrophy'), findsOneWidget);
      expect(find.text('Monday Chest Hypertrophy'), findsNothing, reason: 'Previous day workout must NOT be shown');
      expect(find.textContaining('PENDING WORKOUTS'), findsNothing, reason: 'Pending workouts must NOT be shown in client workout screen');

      // Verify that Monday's workout remains preserved as pending in the repository/backend
      final pendingInRepo = repo.getPendingWorkoutsForClient(clientId);
      expect(pendingInRepo.any((p) => p.id == mondayChest.id), isTrue, reason: 'Monday workout is safely preserved in repository');
    });
  });
}
