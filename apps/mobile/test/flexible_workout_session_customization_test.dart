import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/constants/user_role.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/workout/presentation/client/client_workout_execution_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WorkoutRepository repository;
  late List<http.Request> capturedBackendRequests;

  WorkoutSession createTestSession({String id = 'session_push_monday', String title = 'Monday Push'}) {
    return WorkoutSession(
      id: id,
      title: title,
      workoutType: 'Strength',
      targetMuscleGroup: 'Chest, Shoulders & Triceps',
      recurringSchedule: 'MONDAY',
      difficulty: 'Intermediate',
      estimatedDurationMinutes: 60,
      description: 'Heavy compound pushing session',
      assignedClientId: 'client_123',
      exercises: [
        const WorkoutExercise(
          id: 'we_bench',
          exerciseId: 'ex_bb_bench',
          exerciseName: 'Barbell Flat Bench Press',
          category: 'Chest',
          primaryMusclesDisplay: 'Pectoralis Major',
          secondaryMusclesDisplay: 'Triceps',
          trainerNote: 'Keep elbows tucked at 45 degrees',
          restSeconds: 90,
          sets: [
            ExerciseSet(
              id: 'set_bench_1',
              setNumber: 1,
              targetWeight: 80.0,
              targetRepsMin: 8,
              targetRepsMax: 10,
              actualWeight: 80.0,
              actualReps: 8,
              isCompleted: true,
            ),
            ExerciseSet(
              id: 'set_bench_2',
              setNumber: 2,
              targetWeight: 80.0,
              targetRepsMin: 8,
              targetRepsMax: 10,
              actualWeight: 80.0,
              actualReps: 8,
              isCompleted: true,
            ),
            ExerciseSet(
              id: 'set_bench_3',
              setNumber: 3,
              targetWeight: 80.0,
              targetRepsMin: 8,
              targetRepsMax: 10,
              actualWeight: 80.0,
              actualReps: 8,
              isCompleted: false,
            ),
          ],
        ),
        const WorkoutExercise(
          id: 'we_ohp',
          exerciseId: 'ex_cable_fly',
          exerciseName: 'Standing Cable Chest Fly',
          category: 'Chest',
          primaryMusclesDisplay: 'Chest',
          secondaryMusclesDisplay: '',
          trainerNote: 'Strict form, no momentum',
          restSeconds: 60,
          sets: [
            ExerciseSet(
              id: 'set_fly_1',
              setNumber: 1,
              targetWeight: 15.0,
              targetRepsMin: 10,
              targetRepsMax: 12,
              actualWeight: 15.0,
              actualReps: 10,
              isCompleted: false,
            ),
            ExerciseSet(
              id: 'set_fly_2',
              setNumber: 2,
              targetWeight: 15.0,
              targetRepsMin: 10,
              targetRepsMax: 12,
              actualWeight: 15.0,
              actualReps: 10,
              isCompleted: false,
            ),
          ],
        ),
      ],
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    capturedBackendRequests = [];

    final mockClient = MockClient((request) async {
      capturedBackendRequests.add(request);

      if (request.url.path.contains('/override/replace')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'Saved exercise replacement for future sessions',
            'data': {'persisted': true},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (request.url.path.contains('/override/add-exercise')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'Saved custom added exercise for future sessions',
            'data': {'persisted': true},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (request.url.path.contains('/override/remove-exercise')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'Saved exercise removal for future sessions',
            'data': {'persisted': true},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (request.url.path.contains('/override') && request.method == 'DELETE') {
        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'Reset session customizations back to coach template',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (request.url.path.contains('/sessions')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'available': [],
              'recommended': null,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'available': [],
            'recommended': null,
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    repository = WorkoutRepository(httpClient: mockClient);
    AuthService().setAuthenticatedSessionForTesting(
      role: UserRole.client,
      email: 'client@alphaxgym.com',
      userId: 'client_123',
    );
  });

  group('Requirement 1: User-Controlled Sets', () {
    test('1.1 User can add sets to an exercise and set numbers increment correctly', () {
      final session = createTestSession();
      repository.startSession(session, clientId: 'client_123');

      expect(repository.activeSession.exercises[0].sets.length, equals(3));

      // Add a 4th set
      repository.addSet(0);
      expect(repository.activeSession.exercises[0].sets.length, equals(4));
      expect(repository.activeSession.exercises[0].sets[3].setNumber, equals(4));

      // Add a 5th set
      repository.addSet(0);
      expect(repository.activeSession.exercises[0].sets.length, equals(5));
      expect(repository.activeSession.exercises[0].sets[4].setNumber, equals(5));
    });

    test('1.2 User can delete individual sets whenever they want and indices renumber correctly', () {
      final session = createTestSession();
      repository.startSession(session, clientId: 'client_123');

      expect(repository.activeSession.exercises[0].sets.length, equals(3));

      // Delete set 2 (index 1)
      final deleted = repository.deleteSet(0, 1);
      expect(deleted, isTrue);

      final updatedSets = repository.activeSession.exercises[0].sets;
      expect(updatedSets.length, equals(2));
      expect(updatedSets[0].setNumber, equals(1));
      expect(updatedSets[1].setNumber, equals(2));
    });

    test('1.3 Accidental deletion is safely preventable via undo (insertSet)', () {
      final session = createTestSession();
      repository.startSession(session, clientId: 'client_123');

      final targetSet = repository.activeSession.exercises[0].sets[1];
      repository.deleteSet(0, 1);
      expect(repository.activeSession.exercises[0].sets.length, equals(2));

      // Undo: insert deleted set back at index 1
      final restored = repository.insertSet(0, 1, targetSet);
      expect(restored, isTrue);
      expect(repository.activeSession.exercises[0].sets.length, equals(3));
      expect(repository.activeSession.exercises[0].sets[1].targetWeight, equals(targetSet.targetWeight));
      expect(repository.activeSession.exercises[0].sets[0].setNumber, equals(1));
      expect(repository.activeSession.exercises[0].sets[1].setNumber, equals(2));
      expect(repository.activeSession.exercises[0].sets[2].setNumber, equals(3));
    });

    test('1.4 User can edit reps and weight for each set dynamically without rigid constraints', () {
      final session = createTestSession();
      repository.startSession(session, clientId: 'client_123');

      // Update actual weight and reps for set 3
      repository.updateSetActual(
        exerciseIndex: 0,
        setIndex: 2,
        weight: 85.0,
        reps: 12,
        rpe: 9.0,
      );
      repository.completeSet(
        exerciseIndex: 0,
        setIndex: 2,
      );

      final set3 = repository.activeSession.exercises[0].sets[2];
      expect(set3.isCompleted, isTrue);
      expect(set3.actualWeight, equals(85.0));
      expect(set3.actualReps, equals(12));
      expect(set3.actualRpe, equals(9.0));
    });
  });

  group('Requirement 2: Exercise Swipe, Skip & Replacement Safety', () {
    test('2.1 User can skip an exercise without deleting it or losing previous logs', () {
      final session = createTestSession();
      repository.startSession(session, clientId: 'client_123');

      expect(repository.activeSession.exercises[0].isSkipped, isFalse);

      repository.skipExercise(0, reason: 'Bench press stations busy');
      expect(repository.activeSession.exercises[0].isSkipped, isTrue);
      expect(repository.activeSession.exercises[0].skipReason, equals('Bench press stations busy'));
      // Completed set logs remain completely intact
      expect(repository.activeSession.exercises[0].sets[0].isCompleted, isTrue);
      expect(repository.activeSession.exercises[0].sets[0].actualWeight, equals(80.0));

      // User can resume/unskip
      repository.unskipExercise(0);
      expect(repository.activeSession.exercises[0].isSkipped, isFalse);
    });

    test('2.2 Removing an exercise from active session persists removal to backend', () async {
      final session = createTestSession();
      repository.startSession(session, clientId: 'client_123');

      expect(repository.activeSession.exercises.length, equals(2));

      final removed = repository.removeExerciseFromActiveSession(1);
      expect(removed, isTrue);
      expect(repository.activeSession.exercises.length, equals(1));
      expect(repository.activeSession.exercises[0].exerciseName, equals('Barbell Flat Bench Press'));
      expect(repository.activeSession.hasClientCustomization, isTrue);

      await Future.delayed(const Duration(milliseconds: 30));

      // Verify backend removal sync request was issued
      expect(
        capturedBackendRequests.any((r) => r.url.path.contains('/override/remove-exercise')),
        isTrue,
      );
    });
  });

  group('Requirement 3 & 4: Persistent Exercise Customization Across Future Sessions', () {
    test('3.1 Replacing an exercise marks isCustomReplacement and issues backend persistence', () async {
      final session = createTestSession();
      repository.startSession(session, clientId: 'client_123');

      final success = repository.swapExercise(0, 'ex_db_bench');
      expect(success, isTrue);

      final replacedEx = repository.activeSession.exercises[0];
      expect(replacedEx.isCustomReplacement, isTrue);
      expect(replacedEx.originalExerciseId, equals('ex_bb_bench'));
      expect(replacedEx.originalExerciseName, equals('Barbell Flat Bench Press'));
      expect(replacedEx.exerciseName, equals('Flat Dumbbell Bench Press'));
      expect(repository.activeSession.hasClientCustomization, isTrue);

      await Future.delayed(const Duration(milliseconds: 30));

      // Verify backend replacement sync request was issued
      final swapReq = capturedBackendRequests.firstWhere(
        (r) => r.url.path.contains('/override/replace'),
      );
      expect(swapReq.method, equals('POST'));
      final body = jsonDecode(swapReq.body);
      expect(body['originalExerciseId'], equals('ex_bb_bench'));
      expect(body['replacementExerciseId'], equals('ex_db_bench'));
      expect(body['replacementExerciseName'], equals('Flat Dumbbell Bench Press'));
    });

    test('3.2 Adding a custom exercise marks isCustomAdded and issues backend persistence', () async {
      final session = createTestSession();
      repository.startSession(session, clientId: 'client_123');

      const customEx = WorkoutExercise(
        id: 'we_custom_cable',
        exerciseId: 'ex_cable_fly_low_high',
        exerciseName: 'Low-to-High Cable Fly',
        category: 'Chest',
        primaryMusclesDisplay: 'Pectoralis Major',
        secondaryMusclesDisplay: '',
        trainerNote: 'Peak contraction focus',
        sets: [
          ExerciseSet(id: 'cs_1', setNumber: 1, targetWeight: 15.0, targetRepsMin: 12, targetRepsMax: 15),
        ],
      );

      repository.addExerciseToActiveSession(customEx);

      final added = repository.activeSession.exercises.last;
      expect(added.isCustomAdded, isTrue);
      expect(added.exerciseName, equals('Low-to-High Cable Fly'));
      expect(repository.activeSession.hasClientCustomization, isTrue);

      await Future.delayed(const Duration(milliseconds: 30));

      // Verify backend addition sync request was issued
      final addReq = capturedBackendRequests.firstWhere(
        (r) => r.url.path.contains('/override/add-exercise'),
      );
      expect(addReq.method, equals('POST'));
    });

    test('4.1 Resetting session customizations restores the coach base template', () async {
      final session = createTestSession();
      repository.startSession(session, clientId: 'client_123');

      repository.swapExercise(0, 'ex_db_bench');
      expect(repository.activeSession.exercises[0].isCustomReplacement, isTrue);

      final resetSuccess = await repository.resetSessionCustomizations(session.id);
      expect(resetSuccess, isTrue);

      final deleteReq = capturedBackendRequests.firstWhere(
        (r) => r.url.path.contains('/override') && r.method == 'DELETE',
      );
      expect(deleteReq, isNotNull);
    });
  });

  group('Requirement 5: Preserve Workout-Day Scheduling', () {
    test('5.1 Session schedule day and category remain unchanged after customizations', () {
      final session = createTestSession(id: 'session_mon_push', title: 'Monday Push');
      repository.startSession(session, clientId: 'client_123');

      expect(repository.activeSession.recurringSchedule, equals('MONDAY'));
      expect(repository.activeSession.title, equals('Monday Push'));

      // Perform a swap and an addition
      repository.swapExercise(0, 'ex_db_bench');
      repository.addSet(0);

      // Verify schedule day, category, and muscle groups are fully preserved
      expect(repository.activeSession.recurringSchedule, equals('MONDAY'));
      expect(repository.activeSession.title, equals('Monday Push'));
      expect(repository.activeSession.targetMuscleGroup, equals('Chest, Shoulders & Triceps'));
      expect(repository.activeSession.workoutType, equals('Strength'));
    });
  });

  group('Requirement 6 & 7: Set Logs, History, and Widget Integration', () {
    testWidgets('6.1 Execution screen displays delete set button and allows deleting set with immediate UI update', (tester) async {
      final session = createTestSession();
      repository.startSession(session, clientId: 'client_123');

      await tester.pumpWidget(
        MaterialApp(
          home: ClientWorkoutExecutionScreen(
            workoutRepository: repository,
            session: session,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify set 3 delete button is present
      final deleteSetBtn = find.byKey(const ValueKey('delete_set_button_0_2'));
      expect(deleteSetBtn, findsOneWidget);

      // Tap delete set button
      await tester.tap(deleteSetBtn);
      await tester.pumpAndSettle();

      // Verify set 3 is deleted and SnackBar with UNDO is displayed
      expect(find.byKey(const ValueKey('delete_set_button_0_2')), findsNothing);
      expect(find.text('Set 3 deleted.'), findsOneWidget);
      expect(find.text('UNDO'), findsOneWidget);

      // Tap UNDO to restore
      await tester.tap(find.text('UNDO'));
      await tester.pumpAndSettle();

      // Verify set 3 is restored
      expect(find.byKey(const ValueKey('delete_set_button_0_2')), findsOneWidget);
    });

    testWidgets('6.2 Action sheet opens with safe skip, replace, and remove options', (tester) async {
      final session = createTestSession();
      repository.startSession(session, clientId: 'client_123');

      await tester.pumpWidget(
        MaterialApp(
          home: ClientWorkoutExecutionScreen(
            workoutRepository: repository,
            session: session,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Action Sheet via long press on exercise header
      final header = find.byKey(const ValueKey('exercise_header_0'));
      expect(header, findsOneWidget);
      await tester.longPress(header);
      await tester.pumpAndSettle();

      // Action sheet must open showing safe options
      expect(find.text('Skip Exercise for Today'), findsOneWidget);
      expect(find.text('Replace Exercise'), findsOneWidget);
      expect(find.text('Remove from Session'), findsOneWidget);

      // Verify exercise was NOT deleted or marked complete
      expect(repository.activeSession.exercises.length, equals(2));
      expect(repository.activeSession.exercises[0].isAllSetsCompleted, isFalse);
    });

    testWidgets('6.3 Customization badge appears in header when session is customized', (tester) async {
      final session = createTestSession();
      repository.startSession(session, clientId: 'client_123');
      repository.swapExercise(0, 'ex_db_bench');

      await tester.pumpWidget(
        MaterialApp(
          home: ClientWorkoutExecutionScreen(
            workoutRepository: repository,
            session: repository.activeSession,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify CUSTOMIZED badge is visible in header
      expect(find.text('CUSTOMIZED'), findsOneWidget);
    });
  });
}
