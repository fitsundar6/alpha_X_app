import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/core/constants/user_role.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Assigned Workout Flow, Client Isolation & State Resumption Tests', () {
    late WorkoutRepository repo;
    late AuthService auth;

    setUp(() {
      auth = AuthService();
      repo = WorkoutRepository(
        httpClient: MockClient((request) async => http.Response('{}', 200)),
      );
    });

    test('1. Admin assigns Workout A to Client A -> Client A sees and starts Workout A, NOT default Push A', () async {
      // Create distinct Workout A and Workout B
      final workoutA = WorkoutSession(
        id: 'ws_hypertrophy_upper_client_a',
        title: 'Upper Hypertrophy A (Admin Assigned)',
        workoutType: 'Hypertrophy',
        targetMuscleGroup: 'Chest • Back • Arms',
        difficulty: 'Intermediate',
        estimatedDurationMinutes: 55,
        isActive: true,
        exercises: [
          const WorkoutExercise(
            id: 'we_a1',
            exerciseId: 'ex_incline_dumbbell',
            exerciseName: 'Incline DB Press',
            category: 'Chest',
            primaryMusclesDisplay: 'Chest',
            secondaryMusclesDisplay: 'Triceps',
            trainerNote: '3 sets of 8-10 reps @ RPE 8',
            sets: [
              ExerciseSet(id: 's_a1', setNumber: 1, targetRepsMin: 8, targetRepsMax: 10, targetRpe: 8.0, targetWeight: 32.0),
              ExerciseSet(id: 's_a2', setNumber: 2, targetRepsMin: 8, targetRepsMax: 10, targetRpe: 8.0, targetWeight: 32.0),
              ExerciseSet(id: 's_a3', setNumber: 3, targetRepsMin: 8, targetRepsMax: 10, targetRpe: 8.0, targetWeight: 32.0),
            ],
          ),
        ],
      );

      // Admin adds and assigns workoutA specifically to client_user_alpha
      repo.createSession(workoutA);
      await repo.assignSession(
        sessionId: workoutA.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: 'client_user_alpha',
        isRecommended: true,
      );

      // Client A logs in
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'alpha@alphaxgym.com',
        userId: 'client_user_alpha',
        userName: 'Client Alpha',
      );

      // Verify discovery priority: Client A gets Workout A
      final recommended = repo.getRecommendedSessionForClient('client_user_alpha');
      expect(recommended, isNotNull);
      expect(recommended!.title, equals('Upper Hypertrophy A (Admin Assigned)'));
      expect(recommended.id, equals('ws_hypertrophy_upper_client_a'));
      expect(recommended.assignedClientId, equals('client_user_alpha'));

      // Verify target data strictly preserves admin inputs
      final ex = recommended.exercises.first;
      expect(ex.sets.first.targetRepsMin, equals(8));
      expect(ex.sets.first.targetRepsMax, equals(10));
      expect(ex.sets.first.targetRpe, equals(8.0));
      expect(ex.sets.first.targetWeight, equals(32.0));

      // Client A starts workout -> session status is IN_PROGRESS
      repo.startSession(recommended, clientId: 'client_user_alpha');
      expect(repo.hasActiveSavedSession, isTrue);
      expect(repo.activeSession.title, equals('Upper Hypertrophy A (Admin Assigned)'));
      expect(repo.activeSession.status, equals('IN_PROGRESS'));
      expect(repo.activeSession.assignedClientId, equals('client_user_alpha'));
      expect(repo.activeSession.assignedWorkoutId, equals('ws_hypertrophy_upper_client_a'));
    });

    test('2. Admin assigns Workout B to Client A -> Client A next session opens Workout B', () async {
      final workoutB = WorkoutSession(
        id: 'ws_lower_body_client_a',
        title: 'Lower Strength B (Admin Assigned)',
        workoutType: 'Strength',
        targetMuscleGroup: 'Quads • Glutes • Hamstrings',
        difficulty: 'Advanced',
        estimatedDurationMinutes: 65,
        isActive: true,
        exercises: [
          const WorkoutExercise(
            id: 'we_b1',
            exerciseId: 'ex_barbell_squat',
            exerciseName: 'Barbell Back Squat',
            category: 'Legs',
            primaryMusclesDisplay: 'Quads',
            secondaryMusclesDisplay: 'Glutes',
            trainerNote: 'Heavy working sets',
            sets: [
              ExerciseSet(id: 's_b1', setNumber: 1, targetRepsMin: 5, targetRepsMax: 5, targetRpe: 8.5, targetWeight: 120.0),
              ExerciseSet(id: 's_b2', setNumber: 2, targetRepsMin: 5, targetRepsMax: 5, targetRpe: 8.5, targetWeight: 120.0),
            ],
          ),
        ],
      );

      repo.createSession(workoutB);
      await repo.assignSession(
        sessionId: workoutB.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: 'client_user_alpha',
        isRecommended: true,
      );

      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'alpha@alphaxgym.com',
        userId: 'client_user_alpha',
      );

      final nextSession = repo.getRecommendedSessionForClient('client_user_alpha');
      expect(nextSession, isNotNull);
      expect(nextSession!.title, equals('Lower Strength B (Admin Assigned)'));
      expect(nextSession.id, equals('ws_lower_body_client_a'));
    });

    test('3. Client B logs in -> does NOT see Client A workout (Strict Client Isolation)', () async {
      // Workout assigned strictly to Client A
      final workoutA = WorkoutSession(
        id: 'ws_private_client_a',
        title: 'Confidential Client A Program',
        workoutType: 'Hypertrophy',
        targetMuscleGroup: 'Back • Biceps',
        difficulty: 'Elite',
        estimatedDurationMinutes: 60,
        isActive: true,
        exercises: [],
      );

      repo.createSession(workoutA);
      await repo.assignSession(
        sessionId: workoutA.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: 'client_user_alpha',
        isRecommended: true,
      );

      // Client B logs in
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'beta@alphaxgym.com',
        userId: 'client_user_beta',
        userName: 'Client Beta',
      );

      // Client B has no assigned workouts
      final clientBRecommended = repo.getRecommendedSessionForClient('client_user_beta');
      expect(clientBRecommended, isNull, reason: 'Client B must NOT see Client A assigned workout');

      final clientBAvailable = repo.getAuthorizedSessionsForClient('client_user_beta');
      expect(clientBAvailable, isEmpty, reason: 'Client B must NOT see Client A authorized sessions');

      final clientBToday = repo.getTodaySessionForClient('client_user_beta');
      expect(clientBToday, isNull, reason: 'Client B must get null today session, never fallback to Push A or Client A');
    });

    test('4. Client A completes sets -> closes app -> reopens -> resumes session with progress intact', () async {
      final workout = WorkoutSession(
        id: 'ws_resumption_test',
        title: 'Full Body Tracking Test',
        workoutType: 'Hypertrophy',
        targetMuscleGroup: 'Full Body',
        difficulty: 'Intermediate',
        estimatedDurationMinutes: 50,
        isActive: true,
        exercises: [
          const WorkoutExercise(
            id: 'we_overhead_press',
            exerciseId: 'ex_ohp',
            exerciseName: 'Overhead Press (Barbell)',
            category: 'Shoulders',
            primaryMusclesDisplay: 'Shoulders',
            secondaryMusclesDisplay: 'Triceps',
            trainerNote: 'Strict form',
            sets: [
              ExerciseSet(id: 's1', setNumber: 1, targetRepsMin: 5, targetRepsMax: 8, targetRpe: 8.0, targetWeight: 50.0),
              ExerciseSet(id: 's2', setNumber: 2, targetRepsMin: 5, targetRepsMax: 8, targetRpe: 8.0, targetWeight: 50.0),
              ExerciseSet(id: 's3', setNumber: 3, targetRepsMin: 5, targetRepsMax: 8, targetRpe: 8.0, targetWeight: 50.0),
            ],
          ),
          const WorkoutExercise(
            id: 'we_bench_press',
            exerciseId: 'ex_bench',
            exerciseName: 'Bench Press (Dumbbell)',
            category: 'Chest',
            primaryMusclesDisplay: 'Chest',
            secondaryMusclesDisplay: 'Triceps',
            trainerNote: 'Full ROM',
            sets: [
              ExerciseSet(id: 'sb1', setNumber: 1, targetRepsMin: 8, targetRepsMax: 10, targetRpe: 8.0, targetWeight: 26.0),
              ExerciseSet(id: 'sb2', setNumber: 2, targetRepsMin: 8, targetRepsMax: 10, targetRpe: 8.0, targetWeight: 26.0),
              ExerciseSet(id: 'sb3', setNumber: 3, targetRepsMin: 8, targetRepsMax: 10, targetRpe: 8.0, targetWeight: 26.0),
            ],
          ),
        ],
      );

      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'alpha@alphaxgym.com',
        userId: 'client_user_alpha',
      );

      // Start workout session
      repo.startSession(workout, clientId: 'client_user_alpha');

      // Complete Exercise 1: all 3 sets
      repo.updateSetActual(exerciseIndex: 0, setIndex: 0, weight: 50.0, reps: 8, rpe: 8.0);
      repo.completeSet(exerciseIndex: 0, setIndex: 0);
      repo.updateSetActual(exerciseIndex: 0, setIndex: 1, weight: 52.5, reps: 7, rpe: 8.5);
      repo.completeSet(exerciseIndex: 0, setIndex: 1);
      repo.updateSetActual(exerciseIndex: 0, setIndex: 2, weight: 52.5, reps: 6, rpe: 9.0);
      repo.completeSet(exerciseIndex: 0, setIndex: 2);

      // Complete Exercise 2: 2 of 3 sets
      repo.updateSetActual(exerciseIndex: 1, setIndex: 0, weight: 26.0, reps: 10, rpe: 7.5);
      repo.completeSet(exerciseIndex: 1, setIndex: 0);
      repo.updateSetActual(exerciseIndex: 1, setIndex: 1, weight: 28.0, reps: 9, rpe: 8.5);
      repo.completeSet(exerciseIndex: 1, setIndex: 1);

      await repo.saveActiveSessionToLocalStorage(userId: 'client_user_alpha', elapsedSeconds: 1420);

      // Verify immediate local storage persistence
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString('alpha_x_workout_active_session_state_client_user_alpha');
      expect(savedJson, isNotNull);
      final decoded = jsonDecode(savedJson!) as Map<String, dynamic>;
      expect(decoded['status'], equals('IN_PROGRESS'));
      expect(decoded['assignedClientId'], equals('client_user_alpha'));

      // Simulate App Close and Reopen (Cold Start)
      final repoColdStart = WorkoutRepository(
        httpClient: MockClient((request) async => http.Response('{}', 200)),
      );
      await repoColdStart.restoreActiveSessionForClient('client_user_alpha');

      expect(repoColdStart.hasActiveSavedSession, isTrue);
      final restored = repoColdStart.activeSession;
      expect(restored.status, equals('IN_PROGRESS'));

      // Exercise 1: 3/3 sets completed with exact weights and reps
      expect(restored.exercises[0].sets[0].isCompleted, isTrue);
      expect(restored.exercises[0].sets[0].actualWeight, equals(50.0));
      expect(restored.exercises[0].sets[0].actualReps, equals(8));
      expect(restored.exercises[0].sets[1].isCompleted, isTrue);
      expect(restored.exercises[0].sets[1].actualWeight, equals(52.5));
      expect(restored.exercises[0].sets[1].actualReps, equals(7));
      expect(restored.exercises[0].sets[2].isCompleted, isTrue);
      expect(restored.exercises[0].sets[2].actualWeight, equals(52.5));
      expect(restored.exercises[0].sets[2].actualReps, equals(6));

      // Exercise 2: 2/3 sets completed, 3rd set pending
      expect(restored.exercises[1].sets[0].isCompleted, isTrue);
      expect(restored.exercises[1].sets[0].actualWeight, equals(26.0));
      expect(restored.exercises[1].sets[0].actualReps, equals(10));
      expect(restored.exercises[1].sets[1].isCompleted, isTrue);
      expect(restored.exercises[1].sets[1].actualWeight, equals(28.0));
      expect(restored.exercises[1].sets[1].actualReps, equals(9));
      expect(restored.exercises[1].sets[2].isCompleted, isFalse);

      final duration = await repoColdStart.getSavedActiveSessionDuration(userId: 'client_user_alpha');
      expect(duration, equals(1420));
    });

    test('5. No assigned workout -> shows empty state, NEVER loads default or generic workout', () async {
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'unassigned@alphaxgym.com',
        userId: 'client_unassigned_user',
      );

      final rec = repo.getRecommendedSessionForClient('client_unassigned_user');
      final authorized = repo.getAuthorizedSessionsForClient('client_unassigned_user');
      final today = repo.getTodaySessionForClient('client_unassigned_user');

      expect(rec, isNull, reason: 'Must be null when no workout assigned');
      expect(authorized, isEmpty, reason: 'Must be empty when no workout assigned');
      expect(today, isNull, reason: 'Must be null when no workout assigned');
      expect(repo.hasActiveSavedSession, isFalse);
    });

    test('6. Completing workout saves status COMPLETED, completedAt and total duration', () async {
      final session = repo.adminSessions.first;
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'alpha@alphaxgym.com',
        userId: 'client_user_alpha',
      );

      repo.startSession(session, clientId: 'client_user_alpha');
      repo.completeSet(exerciseIndex: 0, setIndex: 0);

      final record = repo.completeWorkout(durationSeconds: 2700);

      expect(record.isCompleted, isTrue);
      expect(record.durationSeconds, equals(2700));
      expect(record.completedAt, isNotNull);
      expect(repo.hasActiveSavedSession, isFalse, reason: 'Active session is cleared upon completion');
    });
  });
}
