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
import 'package:alpha_x_gym/features/dashboard/admin_client_detail_screen.dart';
import 'package:alpha_x_gym/features/macro_planner/data/repositories/macro_repository.dart';

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

  group('Alpha X Gym — Accidental Workout Completion & Admin Release Ralph Loop Tests', () {
    late WorkoutRepository repo;
    late AuthService auth;

    // Monday: 2026-10-26 (Push Day A)
    // Tuesday: 2026-10-27 (Pull Day B)
    final mondayPushSession = WorkoutSession(
      id: 'ws_monday_push',
      title: 'Monday Push (Chest & Shoulders)',
      workoutType: 'Strength',
      targetMuscleGroup: 'Chest',
      difficulty: 'Intermediate',
      estimatedDurationMinutes: 50,
      isActive: true,
      recurringSchedule: 'Monday',
      trainingDays: const [1], // Monday
      exercises: const [
        WorkoutExercise(
          id: 'we_bench',
          exerciseId: 'ex_bench',
          exerciseName: 'Flat Barbell Bench Press',
          category: 'Chest',
          primaryMusclesDisplay: 'Chest',
          secondaryMusclesDisplay: 'Triceps',
          trainerNote: 'Arch back, retract scapulae',
          sets: [
            ExerciseSet(id: 's_m1', setNumber: 1, targetRepsMin: 8, targetRepsMax: 10, targetWeight: 80),
            ExerciseSet(id: 's_m2', setNumber: 2, targetRepsMin: 8, targetRepsMax: 10, targetWeight: 80),
          ],
        ),
      ],
    );

    final tuesdayPullSession = WorkoutSession(
      id: 'ws_tuesday_pull',
      title: 'Tuesday Pull (Back & Biceps)',
      workoutType: 'Hypertrophy',
      targetMuscleGroup: 'Back',
      difficulty: 'Advanced',
      estimatedDurationMinutes: 55,
      isActive: true,
      recurringSchedule: 'Tuesday',
      trainingDays: const [2], // Tuesday
      exercises: const [
        WorkoutExercise(
          id: 'we_lat',
          exerciseId: 'ex_lat',
          exerciseName: 'Wide-Grip Lat Pulldown',
          category: 'Back',
          primaryMusclesDisplay: 'Lats',
          secondaryMusclesDisplay: 'Biceps',
          trainerNote: 'Drive elbows down',
          sets: [
            ExerciseSet(id: 's_t1', setNumber: 1, targetRepsMin: 10, targetRepsMax: 12, targetWeight: 65),
          ],
        ),
      ],
    );

    setUp(() {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/workout/admin/unlock-session')) {
          final body = jsonDecode(request.body);
          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'Workout session successfully unlocked by administrator.',
              'data': {
                'recordId': body['recordId'],
                'adminId': body['adminId'],
                'reason': body['reason'],
                'unlockedAt': DateTime.now().toIso8601String(),
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.url.path.contains('workout-history')) {
          final segments = request.url.pathSegments;
          final cId = segments.contains('clients') && segments.indexOf('clients') + 1 < segments.length
              ? segments[segments.indexOf('clients') + 1]
              : '';
          final list = repo.getClientWorkoutHistory(cId);
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'history': list.map((r) => r.toJson()).toList(),
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.url.path.contains('/workout/client/sessions')) {
          final cId = auth.currentUserId;
          final today = repo.getTodaySessionForClient(cId, enforceVisibilityWindow: true);
          final hasAssigned = repo.hasAssignedWorkoutsForClient(cId);
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'todaySession': today?.toJson(),
                'recommended': today?.toJson(),
                'available': today != null ? [today.toJson()] : [],
                'pendingWorkouts': [],
                'isRestDay': today == null && hasAssigned,
                'serverTime': IstDateUtils.nowInIST().toIso8601String(),
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response(
          jsonEncode({'success': true, 'data': {}}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      auth = AuthService();
      auth.setHttpClientForTesting(mockClient);

      repo = WorkoutRepository(httpClient: mockClient);
      repo.createSession(mondayPushSession);
      repo.createSession(tuesdayPullSession);
    });

    testWidgets('1. Completed workout remains visible on client screen until 9:00 PM IST', (tester) async {
      const clientId = 'client_john_01';
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'john@alphaxgym.com',
        userId: clientId,
      );

      // Simulate Monday 2026-10-26 at 10:00 AM IST (UTC: 04:30:00Z)
      IstDateUtils.setDateProviderForTesting(() => DateTime.utc(2026, 10, 26, 4, 30, 0));

      await repo.assignSession(
        sessionId: mondayPushSession.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: clientId,
        scheduledDate: '2026-10-26',
        isRecommended: true,
      );

      // Client starts workout
      repo.startSession(mondayPushSession, clientId: clientId);
      repo.updateSetActual(exerciseIndex: 0, setIndex: 0, weight: 80, reps: 10);
      repo.completeSet(exerciseIndex: 0, setIndex: 0);

      // Client accidentally completes workout prematurely
      final completedRecord = repo.completeWorkout(durationSeconds: 600);
      expect(completedRecord.isCompleted, true);
      expect(completedRecord.isLocked, true);

      // Today session must still be returned by repository during the allowed window
      final todaySession = repo.getTodaySessionForClient(clientId, enforceVisibilityWindow: true);
      expect(todaySession, isNotNull, reason: 'Completed session must remain returned until 9:00 PM IST');
      expect(todaySession!.isLocked, true);
      expect(todaySession.status, 'COMPLETED');
      expect(todaySession.title, 'Monday Push (Chest & Shoulders)');

      // Pump ClientWorkoutScreen
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClientWorkoutScreen(
              workoutRepository: repo,
              showAppBar: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that Monday Push is still visible on screen after completion
      expect(find.text("Monday Push (Chest & Shoulders)"), findsOneWidget);
      expect(find.text("COMPLETED TODAY"), findsOneWidget);
      expect(find.text("COMPLETED & LOCKED"), findsOneWidget);

      // Check later at 8:59:59 PM IST (UTC: 15:29:59Z)
      IstDateUtils.setDateProviderForTesting(() => DateTime.utc(2026, 10, 26, 15, 29, 59));
      final stillVisible = repo.getTodaySessionForClient(clientId, enforceVisibilityWindow: true);
      expect(stillVisible, isNotNull, reason: 'Session must remain visible at 8:59:59 PM IST');
      expect(stillVisible!.isLocked, true);
    });

    testWidgets('2. At 9:00 PM IST, workout disappears automatically, whether completed or not', (tester) async {
      const clientId = 'client_john_01';
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'john@alphaxgym.com',
        userId: clientId,
      );

      await repo.assignSession(
        sessionId: mondayPushSession.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: clientId,
        scheduledDate: '2026-10-26',
        isRecommended: true,
      );

      // A. Completed session test: Completed at 11:00 AM IST
      IstDateUtils.setDateProviderForTesting(() => DateTime.utc(2026, 10, 26, 5, 30, 0));
      repo.startSession(mondayPushSession, clientId: clientId);
      repo.completeWorkout(durationSeconds: 1200);

      // Fast-forward to 9:00:01 PM IST (UTC: 15:30:01Z)
      IstDateUtils.setDateProviderForTesting(() => DateTime.utc(2026, 10, 26, 15, 30, 1));
      final hiddenAfter9PM = repo.getTodaySessionForClient(clientId, enforceVisibilityWindow: true);
      expect(hiddenAfter9PM, isNull, reason: 'Session must be hidden at 9:00:01 PM IST');

      // Verify UI shows Rest & Recovery Day state
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClientWorkoutScreen(
              workoutRepository: repo,
              showAppBar: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Monday Push (Chest & Shoulders)"), findsNothing);
      expect(find.text("REST & RECOVERY DAY"), findsOneWidget);

      // B. Uncompleted workout test: Client 2 has workout assigned but did NOT complete it
      const client2 = 'client_uncompleted_02';
      await repo.assignSession(
        sessionId: mondayPushSession.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: client2,
        scheduledDate: '2026-10-26',
        isRecommended: true,
      );

      // At 9:00:01 PM IST, uncompleted session disappears from client daily view
      final hiddenUncompleted = repo.getTodaySessionForClient(client2, enforceVisibilityWindow: true);
      expect(hiddenUncompleted, isNull, reason: 'Uncompleted session must be hidden after 9:00 PM IST');

      // Uncompleted workout must NOT be marked complete in history
      final history = repo.getClientWorkoutHistory(client2);
      expect(history.where((r) => r.sessionId == mondayPushSession.id && r.isCompleted), isEmpty);
    });

    test('3. At 5:00 AM the next day (Tuesday), next scheduled workout appears automatically according to split order', () async {
      const clientId = 'client_john_01';

      // Monday session
      await repo.assignSession(
        sessionId: mondayPushSession.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: clientId,
        scheduledDate: '2026-10-26',
        isRecommended: true,
      );

      // Tuesday session
      await repo.assignSession(
        sessionId: tuesdayPullSession.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: clientId,
        scheduledDate: '2026-10-27',
        isRecommended: true,
      );

      // Client completed Monday's session on Monday
      IstDateUtils.setDateProviderForTesting(() => DateTime.utc(2026, 10, 26, 4, 30, 0));
      repo.startSession(mondayPushSession, clientId: clientId);
      repo.completeWorkout(durationSeconds: 1200);

      // Fast-forward to Tuesday at 05:00:00 AM IST (UTC: 2026-10-26 23:30:00Z)
      IstDateUtils.setDateProviderForTesting(() => DateTime.utc(2026, 10, 26, 23, 30, 0));

      final tuesdaySession = repo.getTodaySessionForClient(clientId, enforceVisibilityWindow: true);
      expect(tuesdaySession, isNotNull, reason: 'Tuesday workout must automatically appear at 5:00 AM IST');
      expect(tuesdaySession!.id, equals(tuesdayPullSession.id));
      expect(tuesdaySession.title, equals('Tuesday Pull (Back & Biceps)'));
      expect(tuesdaySession.isLocked, false);
      expect(tuesdaySession.isCompleted, false);

      // Monday session is NOT displayed
      expect(tuesdaySession.id, isNot(equals(mondayPushSession.id)));
    });

    testWidgets('4. Admin Release/Unlock option restores access to accidentally completed session within allowed window', (tester) async {
      const clientId = 'client_athlete_release_test';
      const clientName = 'Arjun Verma';
      const adminId = 'admin_coach_vikram';
      const reason = 'Client accidentally hit complete after warm-up set. Session reopened.';

      // Monday 10:00 AM IST
      IstDateUtils.setDateProviderForTesting(() => DateTime.utc(2026, 10, 26, 4, 30, 0));

      await repo.assignSession(
        sessionId: mondayPushSession.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: clientId,
        scheduledDate: '2026-10-26',
        isRecommended: true,
      );

      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'arjun@alphaxgym.com',
        userId: clientId,
      );

      // Client performs 1 set and accidentally completes
      repo.startSession(mondayPushSession, clientId: clientId);
      repo.updateSetActual(exerciseIndex: 0, setIndex: 0, weight: 80, reps: 10);
      repo.completeSet(exerciseIndex: 0, setIndex: 0);
      final lockedRecord = repo.completeWorkout(durationSeconds: 180);
      expect(lockedRecord.isLocked, true);

      // Admin logs in
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.admin,
        email: 'vikram@alphaxgym.com',
        userId: adminId,
      );

      // Admin opens AdminClientDetailScreen
      final clientMap = {
        'id': clientId,
        'clientId': 'AXG-0901',
        'name': clientName,
        'status': 'APPROVED',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: AdminClientDetailScreen(
            client: clientMap,
            workoutRepository: repo,
            macroRepository: MacroRepository.clean(),
            initialTabIndex: 1, // WORKOUT tab
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the completed session ExpansionTile
      expect(find.text(lockedRecord.sessionTitle), findsOneWidget);
      await tester.tap(find.text(lockedRecord.sessionTitle));
      await tester.pumpAndSettle();

      // Verify the Release/Unlock button is displayed
      final unlockBtn = find.byKey(const Key('admin_release_unlock_button'));
      expect(unlockBtn, findsOneWidget);
      await tester.tap(unlockBtn);
      await tester.pumpAndSettle();

      // Confirm release in dialog
      expect(find.text('Release & Unlock Session'), findsOneWidget);
      await tester.tap(find.text('Confirm Release'));
      await tester.pumpAndSettle();

      // Verify SnackBar success feedback
      expect(find.text('Session "${lockedRecord.sessionTitle}" released and unlocked for $clientName.'), findsOneWidget);

      // Verify that history record is preserved and audit metadata is populated
      final history = repo.getClientWorkoutHistory(clientId);
      final unlockedRecord = history.firstWhere((r) => r.id == lockedRecord.id);
      expect(unlockedRecord.isLocked, false);
      expect(unlockedRecord.unlockedAt, isNotNull);
      expect(unlockedRecord.unlockedById, equals(adminId));

      // Client switches back and accesses the released session
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'arjun@alphaxgym.com',
        userId: clientId,
      );

      // Client queries today's session within allowed window (10:15 AM IST)
      final clientSession = repo.getTodaySessionForClient(clientId, enforceVisibilityWindow: true);
      expect(clientSession, isNotNull);
      expect(clientSession!.isLocked, false);
      expect(clientSession.status, equals('IN_PROGRESS'));

      // Client can log set 2 and complete the workout
      expect(repo.hasActiveSavedSession, true);
      repo.updateSetActual(exerciseIndex: 0, setIndex: 1, weight: 85, reps: 8);
      repo.completeSet(exerciseIndex: 0, setIndex: 1);
      expect(repo.activeSession.exercises[0].sets[1].isCompleted, true);
      expect(repo.activeSession.exercises[0].sets[1].actualWeight, 85);
    });

    test('5. Released session is accessible ONLY within the allowed time window (5:00 AM to 9:00 PM IST)', () async {
      const clientId = 'client_time_window_test';
      const adminId = 'admin_coach_1';

      await repo.assignSession(
        sessionId: mondayPushSession.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: clientId,
        scheduledDate: '2026-10-26',
        isRecommended: true,
      );

      // Client completes at 11:00 AM IST
      IstDateUtils.setDateProviderForTesting(() => DateTime.utc(2026, 10, 26, 5, 30, 0));
      repo.startSession(mondayPushSession, clientId: clientId);
      final record = repo.completeWorkout(durationSeconds: 300);

      // Admin unlocks session
      await repo.unlockSession(
        recordId: record.id,
        adminId: adminId,
        reason: 'Client requested reopen',
        reopenSession: true,
        clientId: clientId,
        sessionId: mondayPushSession.id,
      );

      // Within allowed window (e.g. 11:30 AM IST) -> Accessible
      final visibleWithinWindow = repo.getTodaySessionForClient(clientId, enforceVisibilityWindow: true);
      expect(visibleWithinWindow, isNotNull, reason: 'Must be accessible at 11:30 AM IST');
      expect(visibleWithinWindow!.isLocked, false);

      // Outside allowed window (e.g. 21:05 PM IST, UTC: 15:35:00Z) -> Inaccessible / Hidden
      IstDateUtils.setDateProviderForTesting(() => DateTime.utc(2026, 10, 26, 15, 35, 0));
      final hiddenOutsideWindow = repo.getTodaySessionForClient(clientId, enforceVisibilityWindow: true);
      expect(hiddenOutsideWindow, isNull, reason: 'Released session must be hidden after 9:00 PM IST');
    });

    test('6. Isolation & History Preservation: Other clients, sessions, and history remain unaffected', () async {
      const clientA = 'client_A';
      const clientB = 'client_B';

      await repo.assignSession(
        sessionId: mondayPushSession.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: clientA,
        scheduledDate: '2026-10-26',
        isRecommended: true,
      );
      await repo.assignSession(
        sessionId: mondayPushSession.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: clientB,
        scheduledDate: '2026-10-26',
        isRecommended: true,
      );

      // Both clients complete their workouts at 10:00 AM IST
      IstDateUtils.setDateProviderForTesting(() => DateTime.utc(2026, 10, 26, 4, 30, 0));

      repo.startSession(mondayPushSession, clientId: clientA);
      repo.updateSetActual(exerciseIndex: 0, setIndex: 0, weight: 80, reps: 10);
      repo.completeSet(exerciseIndex: 0, setIndex: 0);
      final recordA = repo.completeWorkout(durationSeconds: 500);

      repo.startSession(mondayPushSession, clientId: clientB);
      repo.updateSetActual(exerciseIndex: 0, setIndex: 0, weight: 60, reps: 12);
      repo.completeSet(exerciseIndex: 0, setIndex: 0);
      final recordB = repo.completeWorkout(durationSeconds: 600);

      expect(recordA.isLocked, true);
      expect(recordB.isLocked, true);

      // Admin unlocks ONLY Client A's session
      await repo.unlockSession(
        recordId: recordA.id,
        adminId: 'admin_1',
        reason: 'Release Client A only',
        reopenSession: true,
        clientId: clientA,
        sessionId: mondayPushSession.id,
      );

      // Client A is unlocked
      final sessionA = repo.getTodaySessionForClient(clientA);
      expect(sessionA!.isLocked, false);
      expect(sessionA.status, 'IN_PROGRESS');

      // Client B remains COMPLETELY locked and unchanged
      final sessionB = repo.getTodaySessionForClient(clientB);
      expect(sessionB!.isLocked, true);
      expect(sessionB.status, 'COMPLETED');

      final historyB = repo.getClientWorkoutHistory(clientB);
      expect(historyB.first.isLocked, true);
      expect(historyB.first.unlockedAt, isNull);

      // History for Client A was preserved (not deleted)
      final historyA = repo.getClientWorkoutHistory(clientA);
      expect(historyA.length, equals(1));
      expect(historyA.first.id, equals(recordA.id));
      expect(historyA.first.exercises[0].sets[0].actualWeight, equals(80));
    });
  });
}
