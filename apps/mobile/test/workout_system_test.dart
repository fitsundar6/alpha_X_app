import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_x_gym/core/constants/user_role.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';

void main() {
  group('Role-Based Authentication & Permissions Tests', () {
    test('UserRole contains only admin and client; no coach role exists', () {
      expect(UserRole.values, containsAll([UserRole.admin, UserRole.client]));
      expect(UserRole.values.length, 2);
    });

    test('Unknown or invalid roles fallback safely to client and deny admin permissions', () {
      expect(UserRole.fromString('coach'), UserRole.client);
      expect(UserRole.fromString('trainer'), UserRole.client);
      expect(UserRole.fromString('guest'), UserRole.client);
      expect(UserRole.fromString(null), UserRole.client);
      expect(UserRole.fromString('unknown'), UserRole.client);

      expect(UserRole.fromString('coach').isAdmin, isFalse);
      expect(UserRole.fromString('trainer').isAdmin, isFalse);
    });

    test('AuthService session management and role reflection', () async {
      final auth = AuthService();
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.admin,
        email: 'admin@alphaxgym.com',
        userId: 'admin_alex_stone',
      );
      expect(auth.isAdmin, isTrue);
      expect(auth.isClient, isFalse);
      expect(auth.currentUserId, 'admin_alex_stone');

      await auth.logout();
      expect(auth.isAdmin, isFalse);
      expect(auth.isClient, isTrue);
      expect(auth.currentUserId, 'client_guest');
      expect(auth.isAuthenticated, isFalse);
    });
  });

  group('Admin Workout Session Management Tests', () {
    late WorkoutRepository repository;

    setUp(() {
      repository = WorkoutRepository();
    });

    test('Admin creates new workout session with supersets', () {
      final initialCount = repository.adminSessions.length;

      final newSession = WorkoutSession(
        id: 'ws_test_upper_b',
        title: 'Upper B — Antagonist Focus',
        workoutType: 'Hypertrophy',
        targetMuscleGroup: 'Chest • Back • Arms',
        difficulty: 'Advanced',
        estimatedDurationMinutes: 60,
        description: 'Antagonist superset session.',
        isActive: true,
        exercises: [
          const WorkoutExercise(
            id: 'ex_test_1',
            exerciseId: 'ex_incline_smith',
            exerciseName: 'Incline Smith Press',
            category: 'Chest',
            primaryMusclesDisplay: 'Chest',
            secondaryMusclesDisplay: 'Delts',
            supersetTag: 'A1',
            restSeconds: 30,
            trainerNote: 'Superset A1 with Cable Row',
            sets: [
              ExerciseSet(
                id: 's_1',
                setNumber: 1,
                targetWeight: 80.0,
                targetRepsMin: 8,
                targetRepsMax: 10,
              ),
            ],
          ),
          const WorkoutExercise(
            id: 'ex_test_2',
            exerciseId: 'ex_cable_row',
            exerciseName: 'Seated Cable Row',
            category: 'Back',
            primaryMusclesDisplay: 'Back',
            secondaryMusclesDisplay: 'Biceps',
            supersetTag: 'A2',
            restSeconds: 90,
            trainerNote: 'Superset A2: Rest 90s after this set',
            sets: [
              ExerciseSet(
                id: 's_2',
                setNumber: 1,
                targetWeight: 70.0,
                targetRepsMin: 8,
                targetRepsMax: 10,
              ),
            ],
          ),
        ],
      );

      repository.createSession(newSession);

      expect(repository.adminSessions.length, initialCount + 1);
      final created = repository.adminSessions.first;
      expect(created.title, 'Upper B — Antagonist Focus');
      expect(created.exercises.first.supersetTag, 'A1');
      expect(created.exercises[1].supersetTag, 'A2');
      expect(created.exercises.first.isSuperset, isTrue);
      expect(created.exercises.first.supersetGroupName, 'SUPERSET A');
    });

    test('Admin edits existing workout session', () {
      final original = repository.adminSessions.first;
      final updated = original.copyWith(
        title: 'Push A — Updated Phase 2',
        estimatedDurationMinutes: 50,
      );

      repository.updateSession(updated);

      final found = repository.adminSessions.firstWhere((s) => s.id == original.id);
      expect(found.title, 'Push A — Updated Phase 2');
      expect(found.estimatedDurationMinutes, 50);
    });

    test('Admin duplicates workout session', () {
      final original = repository.adminSessions.first;
      final initialCount = repository.adminSessions.length;

      repository.duplicateSession(original.id);

      expect(repository.adminSessions.length, initialCount + 1);
      final copy = repository.adminSessions.first;
      expect(copy.title, '${original.title} (Copy)');
      expect(copy.id, isNot(original.id));
      expect(copy.exercises.length, original.exercises.length);
    });

    test('Admin activates and deactivates session', () {
      final session = repository.adminSessions.first;
      expect(session.isActive, isTrue);

      repository.toggleSessionActive(session.id);
      expect(repository.adminSessions.firstWhere((s) => s.id == session.id).isActive, isFalse);

      repository.toggleSessionActive(session.id);
      expect(repository.adminSessions.firstWhere((s) => s.id == session.id).isActive, isTrue);
    });

    test('Admin deletes workout session', () {
      final session = repository.adminSessions.first;
      final initialCount = repository.adminSessions.length;

      repository.deleteSession(session.id);

      expect(repository.adminSessions.length, initialCount - 1);
      expect(repository.adminSessions.any((s) => s.id == session.id), isFalse);
    });

    test('Admin assigns session to All, Selected, and Individual clients without duplicating session', () {
      final session = repository.adminSessions.first;

      // Assign to Individual Client as recommended
      repository.assignSession(
        sessionId: session.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: 'client_john_doe',
        isRecommended: true,
      );

      final recommended = repository.getRecommendedSessionForClient('client_john_doe');
      expect(recommended, isNotNull);
      expect(recommended!.id, session.id);
      expect(recommended.isRecommended, isTrue);

      // Verify sessions list did not duplicate the session
      final countOfSameId = repository.adminSessions.where((s) => s.id == session.id).length;
      expect(countOfSameId, 1);
    });
  });

  group('Client Workout Execution & Tracking Tests', () {
    late WorkoutRepository repository;

    setUp(() {
      repository = WorkoutRepository();
    });

    test('Client starts workout without modifying original prescribed template', () {
      final template = repository.adminSessions.first;
      final initialTitle = template.title;

      repository.startSession(template);

      final active = repository.activeSession;
      expect(active.id, template.id);
      expect(active.isCompleted, isFalse);

      // Perform set tracking on active session
      repository.updateSetActual(
        exerciseIndex: 0,
        setIndex: 0,
        weight: 85.0,
        reps: 8,
        rir: 1,
        rpe: 8.5,
      );

      // Template in admin sessions remains unmodified
      final foundTemplate = repository.adminSessions.firstWhere((s) => s.id == template.id);
      expect(foundTemplate.title, initialTitle);
      expect(foundTemplate.exercises.first.sets.first.isCompleted, isFalse);
    });

    test('Client completes sets, tracks actual performance, and detects PRs', () {
      repository.startSession(repository.adminSessions.first);

      repository.updateSetActual(
        exerciseIndex: 0,
        setIndex: 0,
        weight: 85.0, // Exceeds baseline 80kg PR
        reps: 8,
        rir: 1,
        rpe: 8.5,
      );

      final pr = repository.completeSet(exerciseIndex: 0, setIndex: 0);

      expect(pr, isNotNull);
      expect(pr!.type, PRType.weight);
      expect(pr.value, 85.0);

      final completedSet = repository.activeSession.exercises.first.sets.first;
      expect(completedSet.isCompleted, isTrue);
      expect(completedSet.actualWeight, 85.0);
      expect(completedSet.actualReps, 8);
    });

    test('Client can add personal note without altering Admin instruction', () {
      repository.startSession(repository.adminSessions.first);
      final adminNoteBefore = repository.activeSession.exercises.first.trainerNote;

      repository.updateExerciseNote(0, 'Felt great stability in right shoulder today.');

      final exerciseAfter = repository.activeSession.exercises.first;
      expect(exerciseAfter.clientNote, 'Felt great stability in right shoulder today.');
      expect(exerciseAfter.trainerNote, adminNoteBefore); // Admin note unchanged
    });

    test('Client skips exercise with reason without modifying Admin template', () {
      repository.startSession(repository.adminSessions.first);

      repository.skipExercise(0, reason: 'Bench was occupied');

      expect(repository.activeSession.exercises.first.isSkipped, isTrue);
      expect(repository.activeSession.exercises.first.skipReason, 'Bench was occupied');

      // Admin template exercise remains not skipped
      final adminTemplate = repository.adminSessions.firstWhere((s) => s.id == repository.activeSession.id);
      expect(adminTemplate.exercises.first.isSkipped, isFalse);
    });

    test('Completing workout creates a new record and saves to client history without overwriting', () {
      final initialHistoryLength = repository.clientHistory.length;
      repository.startSession(repository.adminSessions.first);

      // Complete a set
      repository.completeSet(exerciseIndex: 0, setIndex: 0);

      final record = repository.completeWorkout(notes: 'Solid session completed', durationSeconds: 3200);

      expect(record.isCompleted, isTrue);
      expect(record.notes, 'Solid session completed');
      expect(record.durationSeconds, 3200);
      expect(repository.clientHistory.length, initialHistoryLength + 1);
      expect(repository.clientHistory.first.id, record.id);
    });

    test('Previous performance lookup returns informational baseline', () {
      final prev = repository.getPreviousPerformance('ex_incline_smith');
      expect(prev, isNotNull);
      expect(prev!.isNotEmpty, isTrue);
      expect(prev.first.actualWeight, greaterThan(0));
    });
  });
}
