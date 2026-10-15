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
    IstDateUtils.resetDateProviderForTesting();
  });

  tearDown(() {
    IstDateUtils.resetDateProviderForTesting();
  });

  group('Alpha X Gym — Weekly Workout Auto-Unfreeze System Comprehensive Tests', () {
    late WorkoutRepository repo;
    late AuthService auth;

    // Test session templates
    final mondayChestSession = WorkoutSession(
      id: 'ws_monday_chest_auto_unfreeze',
      title: 'Alpha Pure Chest Hypertrophy',
      workoutType: 'Hypertrophy',
      targetMuscleGroup: 'Chest',
      difficulty: 'Intermediate',
      estimatedDurationMinutes: 55,
      isActive: true,
      recurringSchedule: 'Monday',
      trainingDays: const [1], // Monday
      exercises: [
        const WorkoutExercise(
          id: 'we_incline_smith',
          exerciseId: 'ex_incline_smith_bench',
          exerciseName: 'Incline Smith Press',
          category: 'Chest',
          primaryMusclesDisplay: 'Upper Chest',
          secondaryMusclesDisplay: 'Front Delts',
          trainerNote: '3 sets heavy hypertrophy',
          sets: [
            ExerciseSet(id: 's_c1', setNumber: 1, targetRepsMin: 8, targetRepsMax: 10, targetRpe: 8.5, targetWeight: 80.0),
            ExerciseSet(id: 's_c2', setNumber: 2, targetRepsMin: 8, targetRepsMax: 10, targetRpe: 8.5, targetWeight: 80.0),
            ExerciseSet(id: 's_c3', setNumber: 3, targetRepsMin: 8, targetRepsMax: 10, targetRpe: 9.0, targetWeight: 80.0),
          ],
        ),
      ],
    );

    final wednesdayBackSession = WorkoutSession(
      id: 'ws_wednesday_back_auto_unfreeze',
      title: 'Alpha Lat & Upper Back Hypertrophy',
      workoutType: 'Strength',
      targetMuscleGroup: 'Back',
      difficulty: 'Advanced',
      estimatedDurationMinutes: 60,
      isActive: true,
      recurringSchedule: 'Wednesday',
      trainingDays: const [3], // Wednesday
      exercises: [
        const WorkoutExercise(
          id: 'we_lat_pulldown',
          exerciseId: 'ex_lat_pulldown',
          exerciseName: 'Lat Pulldown',
          category: 'Back',
          primaryMusclesDisplay: 'Lats',
          secondaryMusclesDisplay: 'Biceps',
          trainerNote: 'Strict full stretch',
          sets: [
            ExerciseSet(id: 's_b1', setNumber: 1, targetRepsMin: 10, targetRepsMax: 12, targetRpe: 8.0, targetWeight: 65.0),
            ExerciseSet(id: 's_b2', setNumber: 2, targetRepsMin: 10, targetRepsMax: 12, targetRpe: 8.5, targetWeight: 65.0),
          ],
        ),
      ],
    );

    setUp(() {
      auth = AuthService();
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'anubharathi@alphaxgym.com',
        userId: 'AXG-0002',
      );

      repo = WorkoutRepository(
        httpClient: MockClient((request) async {
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );

      repo.createSession(mondayChestSession);
      repo.createSession(wednesdayBackSession);
    });

    test('1. Freeze after completion on Monday Oct 12, 2026', () async {
      // Set test clock to Monday, Oct 12, 2026
      IstDateUtils.setDateProviderForTesting(() => DateTime.utc(2026, 10, 12, 4, 30));
      expect(IstDateUtils.getTodayISTString(), '2026-10-12');
      expect(IstDateUtils.getTodayISTWeekday(), 1); // Monday

      // Admin assigns Chest Day recurring on Monday
      await repo.assignSession(
        sessionId: mondayChestSession.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: 'AXG-0002',
        isRecommended: true,
        scheduledDate: '2026-10-12',
      );

      // Verify session is initially available & unlocked
      final initialAuthorized = repo.getAuthorizedSessionsForClient('AXG-0002');
      expect(initialAuthorized.length, 1);
      expect(initialAuthorized.first.id, mondayChestSession.id);
      expect(initialAuthorized.first.isLocked, false);
      expect(initialAuthorized.first.status, 'ASSIGNED');

      // Client starts session, logs sets, and completes workout
      repo.startSession(initialAuthorized.first, clientId: 'AXG-0002');
      repo.updateSetActual(exerciseIndex: 0, setIndex: 0, weight: 80.0, reps: 10);
      repo.completeSet(exerciseIndex: 0, setIndex: 0);
      repo.updateSetActual(exerciseIndex: 0, setIndex: 1, weight: 80.0, reps: 9);
      repo.completeSet(exerciseIndex: 0, setIndex: 1);
      repo.updateSetActual(exerciseIndex: 0, setIndex: 2, weight: 80.0, reps: 8);
      repo.completeSet(exerciseIndex: 0, setIndex: 2);

      final oct12Record = repo.completeWorkout(durationSeconds: 3150);
      expect(oct12Record.isLocked, true);
      expect(oct12Record.scheduledDate, '2026-10-12');
      expect(oct12Record.totalVolume, 2160.0); // (80*10) + (80*9) + (80*8)

      // Reopening app on same Monday: must show as COMPLETED & LOCKED
      final sameDaySessions = repo.getAuthorizedSessionsForClient('AXG-0002');
      expect(sameDaySessions.length, 1);
      expect(sameDaySessions.first.isLocked, true);
      expect(sameDaySessions.first.status, 'COMPLETED');

      // Further edits must be rejected
      repo.updateSetActual(exerciseIndex: 0, setIndex: 0, weight: 90.0, reps: 10);
      expect(repo.activeSession.exercises[0].sets[0].actualWeight, isNot(90.0));
      final initialCount = repo.activeSession.exercises[0].sets.length;
      repo.addSet(0);
      expect(repo.activeSession.exercises[0].sets.length, initialCount);
    });

    test('2. Clean Exclusion on Non-Scheduled Day (Tuesday Oct 13, 2026)', () async {
      // Monday Oct 12: assign and complete Chest
      IstDateUtils.setDateProviderForTesting(() => DateTime.utc(2026, 10, 12, 4, 30));
      await repo.assignSession(
        sessionId: mondayChestSession.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: 'AXG-0002',
        isRecommended: true,
        scheduledDate: '2026-10-12',
      );
      repo.startSession(mondayChestSession, clientId: 'AXG-0002');
      repo.updateSetActual(exerciseIndex: 0, setIndex: 0, weight: 80.0, reps: 10);
      repo.completeSet(exerciseIndex: 0, setIndex: 0);
      repo.completeWorkout(durationSeconds: 3000);

      // Advance clock to Tuesday Oct 13, 2026
      IstDateUtils.setDateProviderForTesting(() => DateTime.utc(2026, 10, 13, 4, 30));
      expect(IstDateUtils.getTodayISTString(), '2026-10-13');
      expect(IstDateUtils.getTodayISTWeekday(), 2); // Tuesday

      // Chest session should NOT appear on Tuesday
      final tuesdaySessions = repo.getAuthorizedSessionsForClient('AXG-0002');
      expect(tuesdaySessions.isEmpty, true);

      final todayTuesday = repo.getTodaySessionForClient('AXG-0002');
      expect(todayTuesday, isNull);
    });

    test('3. Automatically unfreezes on the next scheduled day (Monday Oct 19, 2026)', () async {
      // Step 1: Monday Oct 12 - Complete and save Chest session
      IstDateUtils.setDateProviderForTesting(() => DateTime.utc(2026, 10, 12, 4, 30));
      await repo.assignSession(
        sessionId: mondayChestSession.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: 'AXG-0002',
        isRecommended: true,
        scheduledDate: '2026-10-12',
      );
      repo.startSession(mondayChestSession, clientId: 'AXG-0002');
      repo.updateSetActual(exerciseIndex: 0, setIndex: 0, weight: 80.0, reps: 10);
      repo.completeSet(exerciseIndex: 0, setIndex: 0);
      final oct12Record = repo.completeWorkout(durationSeconds: 3000);
      expect(oct12Record.isLocked, true);

      // Step 2: Jump clock to Next Monday, Oct 19, 2026
      IstDateUtils.setDateProviderForTesting(() => DateTime.utc(2026, 10, 19, 4, 30));
      expect(IstDateUtils.getTodayISTString(), '2026-10-19');
      expect(IstDateUtils.getTodayISTWeekday(), 1); // Monday

      // Step 3: Chest Day must automatically be available and UNLOCKED
      final oct19Sessions = repo.getAuthorizedSessionsForClient('AXG-0002');
      expect(oct19Sessions.length, 1);
      final oct19Chest = oct19Sessions.first;
      expect(oct19Chest.id, mondayChestSession.id);
      expect(oct19Chest.isLocked, false);
      expect(oct19Chest.status, 'ASSIGNED');

      // Verify all sets are FRESH and clean
      for (final ex in oct19Chest.exercises) {
        for (final s in ex.sets) {
          expect(s.isCompleted, false);
        }
      }

      // Step 4: Client starts new session for Oct 19 and logs heavier weights
      repo.startSession(oct19Chest, clientId: 'AXG-0002');
      expect(repo.hasActiveSavedSession, true);
      expect(repo.activeSession.scheduledDate, '2026-10-19');

      repo.updateSetActual(exerciseIndex: 0, setIndex: 0, weight: 82.5, reps: 10);
      repo.completeSet(exerciseIndex: 0, setIndex: 0);
      repo.updateSetActual(exerciseIndex: 0, setIndex: 1, weight: 82.5, reps: 10);
      repo.completeSet(exerciseIndex: 0, setIndex: 1);

      final oct19Record = repo.completeWorkout(durationSeconds: 3300);
      expect(oct19Record.isLocked, true);
      expect(oct19Record.scheduledDate, '2026-10-19');
      expect(oct19Record.totalVolume, 1650.0); // (82.5*10) + (82.5*10)

      // Step 5: Historical record for Oct 12 must remain untouched
      final history = repo.getClientWorkoutHistory('AXG-0002');
      expect(history.length, 2);

      final histOct12 = history.firstWhere((r) => r.scheduledDate == '2026-10-12');
      final histOct19 = history.firstWhere((r) => r.scheduledDate == '2026-10-19');

      expect(histOct12.id, oct12Record.id);
      expect(histOct12.totalVolume, 800.0); // 80 * 10
      expect(histOct12.isLocked, true);

      expect(histOct19.id, oct19Record.id);
      expect(histOct19.totalVolume, 1650.0);
      expect(histOct19.isLocked, true);
    });

    test('4. Support arbitrary weekdays (Wednesday schedule without hardcoding)', () async {
      // Wednesday Oct 14, 2026
      IstDateUtils.setDateProviderForTesting(() => DateTime.utc(2026, 10, 14, 4, 30));
      expect(IstDateUtils.getTodayISTString(), '2026-10-14');
      expect(IstDateUtils.getTodayISTWeekday(), 3); // Wednesday

      await repo.assignSession(
        sessionId: wednesdayBackSession.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: 'AXG-0002',
        isRecommended: true,
        scheduledDate: '2026-10-14',
      );

      final wed14Sessions = repo.getAuthorizedSessionsForClient('AXG-0002');
      expect(wed14Sessions.length, 1);
      expect(wed14Sessions.first.id, wednesdayBackSession.id);
      expect(wed14Sessions.first.isLocked, false);

      // Complete on Wednesday Oct 14
      repo.startSession(wed14Sessions.first, clientId: 'AXG-0002');
      repo.updateSetActual(exerciseIndex: 0, setIndex: 0, weight: 65.0, reps: 12);
      repo.completeSet(exerciseIndex: 0, setIndex: 0);
      final oct14Record = repo.completeWorkout(durationSeconds: 2400);
      expect(oct14Record.isLocked, true);

      // Thursday Oct 15 - not scheduled
      IstDateUtils.setDateProviderForTesting(() => DateTime.utc(2026, 10, 15, 4, 30));
      expect(repo.getAuthorizedSessionsForClient('AXG-0002').isEmpty, true);

      // Next Wednesday Oct 21 - automatically unfreezes
      IstDateUtils.setDateProviderForTesting(() => DateTime.utc(2026, 10, 21, 4, 30));
      expect(IstDateUtils.getTodayISTWeekday(), 3); // Wednesday
      final wed21Sessions = repo.getAuthorizedSessionsForClient('AXG-0002');
      expect(wed21Sessions.length, 1);
      expect(wed21Sessions.first.id, wednesdayBackSession.id);
      expect(wed21Sessions.first.isLocked, false);
      expect(wed21Sessions.first.status, 'ASSIGNED');
    });

    test('5. Missed workout day does not silently complete', () async {
      // Admin assigned Monday Chest on Oct 12
      IstDateUtils.setDateProviderForTesting(() => DateTime.utc(2026, 10, 12, 4, 30));
      await repo.assignSession(
        sessionId: mondayChestSession.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: 'AXG-0002',
        isRecommended: true,
        scheduledDate: '2026-10-12',
      );

      // Client DID NOT complete Monday's workout
      // Tuesday arrives:
      IstDateUtils.setDateProviderForTesting(() => DateTime.utc(2026, 10, 13, 4, 30));

      // Workout history must be completely empty (missed workout is NOT marked complete)
      final history = repo.getClientWorkoutHistory('AXG-0002');
      expect(history.isEmpty, true);

      // Active session must not exist
      expect(repo.hasActiveSavedSession, false);
    });
  });
}
