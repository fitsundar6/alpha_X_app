import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/core/constants/user_role.dart';
import 'package:alpha_x_gym/core/utils/ist_date_utils.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Admin-Controlled Daily Workout Assignment and Session Lock System Tests', () {
    late WorkoutRepository repo;
    late AuthService auth;

    final yesterdayDate = IstDateUtils.toISTDateString(
      IstDateUtils.nowInIST().subtract(const Duration(days: 1)),
    );
    final todayDate = IstDateUtils.getTodayISTString();

    final chestWorkout = WorkoutSession(
      id: 'ws_chest_day_yesterday',
      title: 'Chest & Hypertrophy A',
      workoutType: 'Hypertrophy',
      targetMuscleGroup: 'Chest',
      difficulty: 'Intermediate',
      estimatedDurationMinutes: 50,
      isActive: true,
      exercises: [
        const WorkoutExercise(
          id: 'we_bench',
          exerciseId: 'ex_bench_press',
          exerciseName: 'Barbell Flat Bench Press',
          category: 'Chest',
          primaryMusclesDisplay: 'Chest',
          secondaryMusclesDisplay: 'Triceps',
          trainerNote: '4 sets heavy',
          sets: [
            ExerciseSet(id: 's_c1', setNumber: 1, targetRepsMin: 8, targetRepsMax: 10, targetRpe: 8.0, targetWeight: 80.0),
            ExerciseSet(id: 's_c2', setNumber: 2, targetRepsMin: 8, targetRepsMax: 10, targetRpe: 8.0, targetWeight: 80.0),
          ],
        ),
      ],
    );

    final latWorkout = WorkoutSession(
      id: 'ws_lat_back_today',
      title: 'Lat & Back Pull Power',
      workoutType: 'Strength',
      targetMuscleGroup: 'Back & Lats',
      difficulty: 'Advanced',
      estimatedDurationMinutes: 60,
      isActive: true,
      exercises: [
        const WorkoutExercise(
          id: 'we_lat_pulldown',
          exerciseId: 'ex_lat_pulldown',
          exerciseName: 'Lat Pulldown (Neutral Grip)',
          category: 'Back',
          primaryMusclesDisplay: 'Lats',
          secondaryMusclesDisplay: 'Biceps',
          trainerNote: 'Full stretch at the top',
          sets: [
            ExerciseSet(id: 's_l1', setNumber: 1, targetRepsMin: 10, targetRepsMax: 12, targetRpe: 8.0, targetWeight: 65.0),
            ExerciseSet(id: 's_l2', setNumber: 2, targetRepsMin: 10, targetRepsMax: 12, targetRpe: 8.0, targetWeight: 65.0),
          ],
        ),
      ],
    );

    setUp(() {
      auth = AuthService();
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'client@alphaxgym.com',
        userId: 'client_ist_user_1',
      );

      repo = WorkoutRepository(
        httpClient: MockClient((request) async {
          if (request.url.path.contains('/workout/admin/unlock-session')) {
            final body = jsonDecode(request.body);
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'recordId': body['recordId'],
                  'isLocked': false,
                  'unlockedAt': DateTime.now().toIso8601String(),
                  'unlockReason': body['reason'],
                },
              }),
              200,
            );
          }
          return http.Response('{}', 200);
        }),
      );

      repo.createSession(chestWorkout);
      repo.createSession(latWorkout);
    });

    test('1. Date-Based Assignments: Yesterday Chest vs Today Lat', () async {
      // Assign Chest for yesterday
      await repo.assignSession(
        sessionId: chestWorkout.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: 'client_ist_user_1',
        isRecommended: true,
        scheduledDate: yesterdayDate,
      );

      // Assign Lat for today
      await repo.assignSession(
        sessionId: latWorkout.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: 'client_ist_user_1',
        isRecommended: true,
        scheduledDate: todayDate,
      );

      // Verify getAuthorizedSessionsForClient ONLY returns today's Lat workout
      final authorized = repo.getAuthorizedSessionsForClient('client_ist_user_1');
      expect(authorized.length, 1);
      expect(authorized.first.id, latWorkout.id);
      expect(authorized.first.title, 'Lat & Back Pull Power');

      // Verify getTodaySessionForClient returns today's Lat workout
      final todaySession = repo.getTodaySessionForClient('client_ist_user_1');
      expect(todaySession, isNotNull);
      expect(todaySession!.id, latWorkout.id);
      expect(todaySession.title, 'Lat & Back Pull Power');
      expect(todaySession.scheduledDate, todayDate);
    });

    test('2. Single Correct Session & Isolation from Completed Yesterday Workout', () async {
      // Yesterday Chest assignment
      await repo.assignSession(
        sessionId: chestWorkout.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: 'client_ist_user_1',
        scheduledDate: yesterdayDate,
      );

      // Client started and completed Chest yesterday
      repo.startSession(chestWorkout, clientId: 'client_ist_user_1');
      repo.updateSetActual(exerciseIndex: 0, setIndex: 0, weight: 80.0, reps: 10);
      repo.completeSet(exerciseIndex: 0, setIndex: 0);
      final chestRecord = repo.completeWorkout(durationSeconds: 2400);

      expect(chestRecord.isLocked, true);
      expect(chestRecord.workoutType, 'Hypertrophy');

      // Verify active session is cleared after workout completion
      expect(repo.hasActiveSavedSession, false);

      // Assign Today Lat
      await repo.assignSession(
        sessionId: latWorkout.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: 'client_ist_user_1',
        isRecommended: true,
        scheduledDate: todayDate,
      );

      // Calling restoreActiveSessionForClient must NOT reopen yesterday's completed Chest
      await repo.restoreActiveSessionForClient('client_ist_user_1');
      expect(repo.hasActiveSavedSession, false);

      // Client starts today's Lat workout
      final todayLat = repo.getTodaySessionForClient('client_ist_user_1');
      expect(todayLat, isNotNull);
      repo.startSession(todayLat!, clientId: 'client_ist_user_1');

      expect(repo.hasActiveSavedSession, true);
      expect(repo.activeSession.id, latWorkout.id);
      expect(repo.activeSession.scheduledDate, todayDate);
      expect(repo.activeSession.status, 'IN_PROGRESS');
    });

    test('3. Completion Lock: Prevent accidental reopening and reject edits on completed session', () async {
      await repo.assignSession(
        sessionId: latWorkout.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: 'client_ist_user_1',
        scheduledDate: todayDate,
      );

      repo.startSession(latWorkout, clientId: 'client_ist_user_1');
      repo.updateSetActual(exerciseIndex: 0, setIndex: 0, weight: 65.0, reps: 12);
      repo.completeSet(exerciseIndex: 0, setIndex: 0);

      // Complete and save workout
      final record = repo.completeWorkout(durationSeconds: 1800);
      expect(record.isLocked, true);
      expect(record.lockedAt, isNotNull);

      // History contains the completed locked record
      final history = repo.getClientWorkoutHistory('client_ist_user_1');
      expect(history.length, 1);
      expect(history.first.isLocked, true);

      // Active session is no longer active
      expect(repo.hasActiveSavedSession, false);

      // Attempting to modify set on locked session must be rejected
      final activeLocked = repo.activeSession.copyWith(isLocked: true);
      repo.startSession(activeLocked, clientId: 'client_ist_user_1');

      repo.updateSetActual(exerciseIndex: 0, setIndex: 0, weight: 99.0, reps: 99);
      expect(repo.activeSession.exercises[0].sets[0].actualWeight, isNot(99.0));

      // Attempting to add set on locked session must be rejected
      final initialSetCount = repo.activeSession.exercises[0].sets.length;
      repo.addSet(0);
      expect(repo.activeSession.exercises[0].sets.length, initialSetCount);
    });

    test('4. Admin Unlock/Release: Admin can unlock session with recorded reason and timestamp', () async {
      await repo.assignSession(
        sessionId: chestWorkout.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: 'client_ist_user_1',
        scheduledDate: yesterdayDate,
      );

      repo.startSession(chestWorkout, clientId: 'client_ist_user_1');
      repo.updateSetActual(exerciseIndex: 0, setIndex: 0, weight: 80.0, reps: 10);
      repo.completeSet(exerciseIndex: 0, setIndex: 0);
      final chestRecord = repo.completeWorkout(durationSeconds: 2000);

      expect(chestRecord.isLocked, true);

      // Admin unlocks session with audit trail
      final success = await repo.unlockSession(
        recordId: chestRecord.id,
        adminId: 'admin_super_1',
        reason: 'Client reported incorrect weight logged on set 1',
        reopenSession: true,
      );
      expect(success, true);

      final updatedHistory = repo.getClientWorkoutHistory('client_ist_user_1');
      final unlockedRecord = updatedHistory.firstWhere((r) => r.id == chestRecord.id);

      expect(unlockedRecord.isLocked, false);
      expect(unlockedRecord.unlockedAt, isNotNull);
      expect(unlockedRecord.unlockReason, 'Client reported incorrect weight logged on set 1');
      expect(unlockedRecord.unlockedById, 'admin_super_1');

      // Active session was reopened and unlocked
      expect(repo.hasActiveSavedSession, true);
      expect(repo.activeSession.isLocked, false);

      // Modifications now succeed
      repo.updateSetActual(exerciseIndex: 0, setIndex: 0, weight: 85.0, reps: 10);
      expect(repo.activeSession.exercises[0].sets[0].actualWeight, 85.0);
    });

    test('5. Accidental Completion Protection: In-progress session is safely preserved across checks', () async {
      await repo.assignSession(
        sessionId: latWorkout.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: 'client_ist_user_1',
        scheduledDate: todayDate,
      );

      repo.startSession(latWorkout, clientId: 'client_ist_user_1');
      repo.updateSetActual(exerciseIndex: 0, setIndex: 0, weight: 70.0, reps: 10);
      repo.completeSet(exerciseIndex: 0, setIndex: 0);

      // Simulating user navigating away or app backgrounding
      // hasActiveSavedSession must remain true, status IN_PROGRESS, not locked
      expect(repo.hasActiveSavedSession, true);
      expect(repo.activeSession.isLocked, false);
      expect(repo.activeSession.status, 'IN_PROGRESS');
      expect(repo.activeSession.exercises[0].sets[0].isCompleted, true);
      expect(repo.activeSession.exercises[0].sets[0].actualWeight, 70.0);

      // Simulating app restart / screen reload restoring session
      await repo.restoreActiveSessionForClient('client_ist_user_1');
      expect(repo.hasActiveSavedSession, true);
      expect(repo.activeSession.id, latWorkout.id);
      expect(repo.activeSession.status, 'IN_PROGRESS');
      expect(repo.activeSession.isLocked, false);
      expect(repo.activeSession.exercises[0].sets[0].isCompleted, true);
      expect(repo.activeSession.exercises[0].sets[0].actualWeight, 70.0);
    });
  });
}
