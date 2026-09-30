import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/exercise/data/repositories/exercise_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Advanced Workout Builder & Plan Assignment Tests', () {
    late WorkoutRepository repo;

    setUp(() {
      repo = WorkoutRepository();
    });

    test('Workout builder supports modular sections (Warm-up, Main, Mobility, Cool-down)', () {
      final sessionWithSections = WorkoutSession(
        id: 'ws_sections_test',
        title: 'Full Body Athletic Performance',
        workoutType: 'Strength & Conditioning',
        targetMuscleGroup: 'Full Body',
        difficulty: 'Advanced',
        estimatedDurationMinutes: 65,
        sections: [
          const WorkoutSection(
            id: 'sec_warmup',
            title: 'Movement Prep & CNS Activation',
            sectionType: WorkoutSectionType.warmUp,
            orderIndex: 0,
            trainerInstructions: '5 min dynamic warm-up and banded activation',
          ),
          const WorkoutSection(
            id: 'sec_main',
            title: 'Compound Strength Cluster',
            sectionType: WorkoutSectionType.mainWorkout,
            orderIndex: 1,
            trainerInstructions: 'Heavy straight sets with RIR 1-2',
          ),
          const WorkoutSection(
            id: 'sec_cooldown',
            title: 'Downregulation & Mobility',
            sectionType: WorkoutSectionType.coolDown,
            orderIndex: 2,
            trainerInstructions: 'Static stretches and deep nasal breathing',
          ),
        ],
        exercises: [
          const WorkoutExercise(
            id: 'we_bench',
            exerciseId: 'ex_incline_smith',
            exerciseName: 'Incline Smith Press',
            category: 'Chest',
            primaryMusclesDisplay: 'Chest',
            secondaryMusclesDisplay: 'Triceps',
            restSeconds: 90,
            trainerNote: 'Primary heavy pressing movement with controlled eccentric.',
            tempo: '3-1-1-0',
            sets: [
              ExerciseSet(
                id: 's_main_1',
                setNumber: 1,
                setType: SetType.working,
                targetWeight: 90.0,
                targetRepsMin: 8,
                targetRepsMax: 10,
                targetRir: 2,
                tempo: '3-1-1-0',
              ),
            ],
          ),
        ],
      );

      repo.createSession(sessionWithSections);

      final created = repo.adminSessions.firstWhere((s) => s.id == 'ws_sections_test');
      expect(created.sections.length, 3);
      expect(created.sections[0].sectionType, WorkoutSectionType.warmUp);
      expect(created.sections[1].sectionType, WorkoutSectionType.mainWorkout);
      expect(created.sections[2].sectionType, WorkoutSectionType.coolDown);
    });

    test('All 8 Set Types and Advanced Training Methods are accurately preserved', () {
      final advancedSets = [
        const ExerciseSet(
          id: 'set_warmup',
          setNumber: 1,
          setType: SetType.warmup,
          targetWeight: 40.0,
          targetRepsMin: 12,
          targetRepsMax: 12,
        ),
        const ExerciseSet(
          id: 'set_working',
          setNumber: 2,
          setType: SetType.working,
          targetWeight: 80.0,
          targetRepsMin: 10,
          targetRepsMax: 10,
          targetRir: 2,
          tempo: '3-1-1-0',
        ),
        const ExerciseSet(
          id: 'set_dropset',
          setNumber: 3,
          setType: SetType.dropSet,
          targetWeight: 60.0,
          targetRepsMin: 8,
          targetRepsMax: 8,
          notes: 'Drop weight by 25% immediately upon failure',
        ),
        const ExerciseSet(
          id: 'set_restpause',
          setNumber: 4,
          setType: SetType.restPause,
          targetWeight: 75.0,
          targetRepsMin: 10,
          targetRepsMax: 12,
          notes: 'Rest 20 sec between mini-clusters',
        ),
        const ExerciseSet(
          id: 'set_amrap',
          setNumber: 5,
          setType: SetType.amrap,
          targetWeight: 70.0,
          targetRepsMin: 15,
          targetRepsMax: 20,
          durationSeconds: 60,
        ),
        const ExerciseSet(
          id: 'set_failure',
          setNumber: 6,
          setType: SetType.failure,
          targetWeight: 65.0,
          targetRepsMin: 12,
          targetRepsMax: 15,
        ),
        const ExerciseSet(
          id: 'set_backoff',
          setNumber: 7,
          setType: SetType.backOff,
          targetWeight: 50.0,
          targetRepsMin: 15,
          targetRepsMax: 15,
        ),
        const ExerciseSet(
          id: 'set_activation',
          setNumber: 8,
          setType: SetType.activation,
          targetWeight: 20.0,
          targetRepsMin: 20,
          targetRepsMax: 20,
        ),
      ];

      expect(advancedSets.length, 8);
      expect(advancedSets[0].setType.displayName, 'Warm-up');
      expect(advancedSets[1].setType.displayName, 'Working');
      expect(advancedSets[2].setType.displayName, 'Drop Set');
      expect(advancedSets[3].setType.displayName, 'Rest-Pause');
      expect(advancedSets[4].setType.displayName, 'AMRAP');
      expect(advancedSets[5].setType.displayName, 'Failure');
      expect(advancedSets[6].setType.displayName, 'Back-off');
      expect(advancedSets[7].setType.displayName, 'Activation');
    });

    test('Plan versioning guarantees historical workout logs are not corrupted when plan changes', () {
      final originalSession = repo.adminSessions.first;
      final initialVersion = originalSession.planVersion.versionNumber;

      // 1. Client completes workout under Version 1
      repo.startSession(originalSession);
      repo.completeSet(exerciseIndex: 0, setIndex: 0);
      final historyRecord = repo.completeWorkout(durationSeconds: 2400);

      expect(historyRecord.planVersion?.versionNumber, initialVersion);
      final historicalExerciseName = historyRecord.exercises.first.exerciseName;

      // 2. Admin edits workout plan with a new title and increments version
      final updatedSession = originalSession.copyWith(
        title: 'Push Phase 2: Incline Focus',
      );
      repo.updateSession(updatedSession);

      final newAdminSession = repo.adminSessions.firstWhere((s) => s.id == originalSession.id);
      expect(newAdminSession.planVersion.versionNumber, initialVersion + 1);
      expect(newAdminSession.title, 'Push Phase 2: Incline Focus');

      // 3. Historical workout record must remain unchanged
      final savedRecord = repo.clientHistory.firstWhere((r) => r.id == historyRecord.id);
      expect(savedRecord.sessionTitle, originalSession.title);
      expect(savedRecord.planVersion?.versionNumber, initialVersion);
      expect(savedRecord.exercises.first.exerciseName, historicalExerciseName);
    });

    test('Weekly schedule assignment maps days of week to workouts', () {
      final session = repo.adminSessions.first;
      final schedule = WeeklyWorkoutSchedule(
        dayOfWeekSessionId: {
          DateTime.now().weekday: session.id, // Scheduled for today
        },
      );

      repo.assignSession(
        sessionId: session.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: 'client_schedule_user',
      );
      repo.updateSession(session.copyWith(
        weeklySchedule: schedule,
        trainingDays: [DateTime.now().weekday],
      ));

      final todaySession = repo.getTodaySessionForClient('client_schedule_user');
      expect(todaySession, isNotNull);
      expect(todaySession!.id, session.id);
    });
  });

  group('Client Execution, Swapping, and Change Request Tests', () {
    late WorkoutRepository repo;

    setUp(() {
      repo = WorkoutRepository();
    });

    test('Client exercise swap is non-destructive and records swap history', () {
      final template = repo.adminSessions.first;
      repo.startSession(template);

      final currentEx = repo.activeSession.exercises.first;
      final originalExerciseId = currentEx.exerciseId;

      // Find an approved alternative or compatible exercise
      final alternatives = ExerciseRepository().getAlternatives(originalExerciseId);
      final alternativeToSwap = alternatives.isNotEmpty ? alternatives.first : ExerciseRepository().allExercises[1];

      // Perform swap during active session
      final swapSuccess = repo.swapExercise(0, alternativeToSwap.id);
      expect(swapSuccess, isTrue);

      final swappedEx = repo.activeSession.exercises.first;
      expect(swappedEx.exerciseId, alternativeToSwap.id);
      expect(swappedEx.exerciseName, alternativeToSwap.displayName);
      expect(swappedEx.swapRecord, isNotNull);
      expect(swappedEx.swapRecord!.originalExerciseId, originalExerciseId);
      expect(swappedEx.swapRecord!.performedExerciseId, alternativeToSwap.id);

      // Verify permanent admin template remains untouched
      final permanentTemplate = repo.adminSessions.firstWhere((s) => s.id == template.id);
      expect(permanentTemplate.exercises.first.exerciseId, originalExerciseId);
    });

    test('Client swap is denied when admin permissions prohibit exercise swapping', () {
      final lockedPermissions = const ClientWorkoutPermissions(allowExerciseSwap: false);
      final lockedSession = repo.adminSessions.first.copyWith(
        id: 'ws_locked_session',
        permissions: lockedPermissions,
      );
      repo.createSession(lockedSession);

      repo.startSession(lockedSession);
      final currentEx = repo.activeSession.exercises.first;

      final swapResult = repo.swapExercise(0, 'ex_lat_raise');
      expect(swapResult, isFalse);

      // Exercise should not have been swapped
      expect(repo.activeSession.exercises.first.exerciseId, currentEx.exerciseId);
    });

    test('Client submits change request and admin approves with replacement', () {
      final session = repo.adminSessions.first;
      final initialRequestCount = repo.changeRequests.length;

      // 1. Client submits change request
      final request = repo.submitChangeRequest(
        clientId: 'client_john_doe',
        clientName: 'John Doe',
        sessionId: session.id,
        sessionTitle: session.title,
        exerciseId: 'ex_incline_smith',
        exerciseName: 'Incline Smith Press',
        reason: 'Right AC joint impingement on barbell pressing.',
      );

      expect(repo.changeRequests.length, initialRequestCount + 1);
      expect(request.isPending, isTrue);
      expect(request.reason, contains('AC joint'));

      // 2. Admin approves request with dumbbell alternative
      repo.approveChangeRequest(
        request.id,
        replacementExerciseId: 'ex_db_bench',
        replacementExerciseName: 'Flat Dumbbell Press',
        adminNote: 'Substituted with neutral-grip dumbbells to alleviate shoulder stress.',
        isPermanent: true,
      );

      final approvedReq = repo.changeRequests.firstWhere((r) => r.id == request.id);
      expect(approvedReq.isApproved, isTrue);
      expect(approvedReq.isPending, isFalse);
      expect(approvedReq.replacementExerciseName, 'Flat Dumbbell Press');
      expect(approvedReq.isPermanent, isTrue);
    });

    test('Client submits change request and admin rejects with coaching feedback', () {
      final session = repo.adminSessions.first;

      final request = repo.submitChangeRequest(
        clientId: 'client_john_doe',
        clientName: 'John Doe',
        sessionId: session.id,
        sessionTitle: session.title,
        exerciseId: 'ex_lat_raise',
        exerciseName: 'Lateral Raise',
        reason: 'Traps taking over the movement.',
      );

      repo.rejectChangeRequest(
        request.id,
        adminNote: 'Keep shoulders depressed, lead with elbows, and drop working weight by 2.5kg.',
      );

      final rejectedReq = repo.changeRequests.firstWhere((r) => r.id == request.id);
      expect(rejectedReq.isRejected, isTrue);
      expect(rejectedReq.isPending, isFalse);
      expect(rejectedReq.adminNote, contains('Keep shoulders depressed'));
    });

    test('Uncomplete set allows editing previously logged sets without data loss', () {
      repo.startSession(repo.adminSessions.first);

      // Complete set 1
      repo.updateSetActual(
        exerciseIndex: 0,
        setIndex: 0,
        weight: 75.0,
        reps: 10,
        rir: 2,
      );
      repo.completeSet(exerciseIndex: 0, setIndex: 0);

      expect(repo.activeSession.exercises.first.sets.first.isCompleted, isTrue);

      // Uncomplete to modify
      repo.uncompleteSet(exerciseIndex: 0, setIndex: 0);
      expect(repo.activeSession.exercises.first.sets.first.isCompleted, isFalse);

      // Update and re-complete
      repo.updateSetActual(
        exerciseIndex: 0,
        setIndex: 0,
        weight: 77.5,
        reps: 10,
        rir: 1,
      );
      repo.completeSet(exerciseIndex: 0, setIndex: 0);

      final finalSet = repo.activeSession.exercises.first.sets.first;
      expect(finalSet.isCompleted, isTrue);
      expect(finalSet.actualWeight, 77.5);
    });
  });
}
