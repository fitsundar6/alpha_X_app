import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/constants/app_constants.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/workout/presentation/client/client_workout_execution_screen.dart';
import 'package:alpha_x_gym/features/workout/presentation/client/services/rest_timer_sound_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WorkoutRepository repository;
  late List<Map<String, dynamic>> capturedBackendCalls;

  WorkoutSession createTestSession({String sessionId = 'ws_bench_test'}) {
    return WorkoutSession(
      id: sessionId,
      title: 'Chest Hypertrophy Session',
      workoutType: 'Hypertrophy',
      targetMuscleGroup: 'Chest',
      difficulty: 'Intermediate',
      estimatedDurationMinutes: 45,
      description: 'Test workout session',
      isActive: true,
      availabilityType: 'INDIVIDUAL',
      exercises: [
        WorkoutExercise(
          id: 'ex_bench',
          exerciseId: 'ex_bench_press',
          exerciseName: 'Barbell Bench Press',
          category: 'Chest',
          primaryMusclesDisplay: 'Pectoralis Major',
          secondaryMusclesDisplay: 'Triceps',
          trainerNote: 'Arch upper back and brace core',
          tempo: '3-1-1-0',
          restSeconds: 90,
          sets: [
            const ExerciseSet(
              id: 'set_bench_1',
              setNumber: 1,
              targetWeight: 80.0,
              targetRepsMin: 8,
              targetRepsMax: 10,
              isCompleted: false,
            ),
            const ExerciseSet(
              id: 'set_bench_2',
              setNumber: 2,
              targetWeight: 80.0,
              targetRepsMin: 8,
              targetRepsMax: 10,
              isCompleted: false,
            ),
          ],
        ),
      ],
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    RestTimerSoundService.resetTestHooks();
    capturedBackendCalls = [];

    final mockClient = MockClient((request) async {
      if (request.url.path.contains('/set-completion')) {
        capturedBackendCalls.add({
          'method': request.method,
          'url': request.url.toString(),
          'body': jsonDecode(request.body),
        });
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'sessionId': 'ws_bench_test',
              'exerciseId': 'ex_bench_press',
              'setNumber': 1,
              'isCompleted': true,
              'isExerciseCompleted': false,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
    });

    repository = WorkoutRepository(httpClient: mockClient);
    AuthService().setAuthenticatedSessionForTesting(
      role: UserRole.client,
      email: 'client@alphaxgym.com',
      userId: 'client_test_user',
    );
  });

  tearDown(() {
    RestTimerSoundService.resetTestHooks();
  });

  group('Alpha X Client Workout Session Optimization Tests', () {
    test('1 & 2: Complete set saves to DB; Undo set updates DB immediately', () async {
      final session = createTestSession();
      repository.startSession(session, clientId: 'client_test_user');

      // 1. Complete Set 1
      repository.completeSet(exerciseIndex: 0, setIndex: 0);
      expect(repository.activeSession.exercises[0].sets[0].isCompleted, isTrue);

      // Await async microtasks for backend sync to complete
      await Future.delayed(const Duration(milliseconds: 50));

      // Verify immediate backend call for completion
      expect(capturedBackendCalls.isNotEmpty, isTrue);
      final lastCall = capturedBackendCalls.last;
      expect(lastCall['body']['isCompleted'], isTrue);
      expect(lastCall['body']['setNumber'], equals(1));
      expect(lastCall['body']['exerciseId'], equals('ex_bench_press'));

      // 2. Undo Set 1
      repository.uncompleteSet(exerciseIndex: 0, setIndex: 0);
      expect(repository.activeSession.exercises[0].sets[0].isCompleted, isFalse);

      await Future.delayed(const Duration(milliseconds: 50));

      // Verify immediate backend call for undo
      expect(capturedBackendCalls.length, equals(2));
      final undoCall = capturedBackendCalls.last;
      expect(undoCall['body']['isCompleted'], isFalse);
      expect(undoCall['body']['setNumber'], equals(1));
    });

    test('3 & 4: Exercise ✓✓ double-tick appears only when ALL sets completed, disappears on undo', () {
      final session = createTestSession();
      repository.startSession(session, clientId: 'client_test_user');

      // Initially 0 sets complete
      expect(repository.activeSession.exercises[0].isAllSetsCompleted, isFalse);

      // Complete Set 1 (1/2 sets)
      repository.completeSet(exerciseIndex: 0, setIndex: 0);
      expect(repository.activeSession.exercises[0].isAllSetsCompleted, isFalse);

      // Complete Set 2 (2/2 sets)
      repository.completeSet(exerciseIndex: 0, setIndex: 1);
      expect(repository.activeSession.exercises[0].isAllSetsCompleted, isTrue);

      // Undo Set 2 (now 1/2 sets complete)
      repository.uncompleteSet(exerciseIndex: 0, setIndex: 1);
      expect(repository.activeSession.exercises[0].isAllSetsCompleted, isFalse);
    });

    test('5: Close / reopen workout session preserves completed and incomplete sets', () async {
      final session = createTestSession();
      repository.startSession(session, clientId: 'client_test_user');

      repository.completeSet(exerciseIndex: 0, setIndex: 0);
      expect(repository.activeSession.exercises[0].sets[0].isCompleted, isTrue);
      expect(repository.activeSession.exercises[0].sets[1].isCompleted, isFalse);

      // Simulate app reopen / restoring active session
      await repository.restoreActiveSessionForClient('client_test_user');

      expect(repository.activeSession.exercises[0].sets[0].isCompleted, isTrue);
      expect(repository.activeSession.exercises[0].sets[1].isCompleted, isFalse);
    });

    test('6: Refresh / API load with database set completion reflects correctly', () async {
      final apiResponse = {
        'id': 'ws_bench_test',
        'title': 'Chest Hypertrophy Session',
        'workoutType': 'Hypertrophy',
        'targetMuscleGroup': 'Chest',
        'difficulty': 'Intermediate',
        'estimatedDurationMinutes': 45,
        'isActive': true,
        'availabilityType': 'INDIVIDUAL',
        'exercises': [
          {
            'id': 'ex_bench',
            'exerciseId': 'ex_bench_press',
            'exerciseName': 'Barbell Bench Press',
            'category': 'Chest',
            'numberOfSets': 2,
            'trainerNote': '',
            'sets': [
              {
                'id': 'set_bench_1',
                'setNumber': 1,
                'targetWeight': 80.0,
                'targetRepsMin': 8,
                'targetRepsMax': 10,
                'isCompleted': true, // Persisted as complete in DB
              },
              {
                'id': 'set_bench_2',
                'setNumber': 2,
                'targetWeight': 80.0,
                'targetRepsMin': 8,
                'targetRepsMax': 10,
                'isCompleted': false,
              },
            ],
          },
        ],
      };

      final parsedSession = WorkoutSession.fromJson(apiResponse);
      repository.startSession(parsedSession, clientId: 'client_test_user');

      expect(repository.activeSession.exercises[0].sets[0].isCompleted, isTrue);
      expect(repository.activeSession.exercises[0].sets[1].isCompleted, isFalse);
      expect(repository.activeSession.exercises[0].isAllSetsCompleted, isFalse);
    });

    testWidgets('UI: Set checkbox ☐ → ☑ toggle, double-tick ✓✓, and undo integration', (tester) async {
      final session = createTestSession();
      repository.startSession(session, clientId: 'client_test_user');

      await tester.pumpWidget(
        MaterialApp(
          home: ClientWorkoutExecutionScreen(
            workoutRepository: repository,
            session: session,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find Checkbox for Set 1
      final set1Checkbox = find.byKey(const ValueKey('set_checkbox_0_0'));
      expect(set1Checkbox, findsOneWidget);

      // Initially no double-tick badge
      expect(find.text('✓✓ Completed'), findsNothing);

      // Tap Set 1 (☐ → ☑)
      await tester.tap(set1Checkbox);
      await tester.pumpAndSettle();

      expect(repository.activeSession.exercises[0].sets[0].isCompleted, isTrue);
      expect(find.text('✓✓ Completed'), findsNothing); // Set 2 not yet done

      // Tap Set 2 (☐ → ☑)
      final set2Checkbox = find.byKey(const ValueKey('set_checkbox_0_1'));
      await tester.tap(set2Checkbox);
      await tester.pumpAndSettle();

      expect(repository.activeSession.exercises[0].sets[1].isCompleted, isTrue);
      // Now all sets done: Double-tick ✓✓ must appear!
      expect(find.text('✓✓ Completed'), findsOneWidget);

      // Tap Set 2 again to undo (☑ → ☐)
      await tester.tap(set2Checkbox);
      await tester.pumpAndSettle();

      expect(repository.activeSession.exercises[0].sets[1].isCompleted, isFalse);
      // Double-tick ✓✓ must immediately disappear!
      expect(find.text('✓✓ Completed'), findsNothing);
    });

    testWidgets('7, 8, 9: Rest Timer countdown, 5-second attention beeps, and 0-second completion alert', (tester) async {
      final session = createTestSession();
      repository.startSession(session, clientId: 'client_test_user');

      final beepsPlayed = <int>[];
      bool completionAlertPlayed = false;

      RestTimerSoundService.testBeepCallback = (sec) {
        beepsPlayed.add(sec);
      };
      RestTimerSoundService.testCompletionCallback = () {
        completionAlertPlayed = true;
      };

      await tester.pumpWidget(
        MaterialApp(
          home: ClientWorkoutExecutionScreen(
            workoutRepository: repository,
            session: session,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Set 1 to complete and trigger rest timer
      final set1Checkbox = find.byKey(const ValueKey('set_checkbox_0_0'));
      await tester.tap(set1Checkbox);
      await tester.pump(); // Rest timer starts at 90s

      // Verify floating rest timer bar is shown
      expect(find.byKey(const ValueKey('floating_rest_timer_bar')), findsOneWidget);

      // Fast-forward 84 seconds to 6 seconds remaining
      await tester.pump(const Duration(seconds: 84));
      expect(beepsPlayed, isEmpty);

      // Next tick: 5s -> beep
      await tester.pump(const Duration(seconds: 1));
      expect(beepsPlayed.contains(5), isTrue);

      // Next tick: 4s -> beep
      await tester.pump(const Duration(seconds: 1));
      expect(beepsPlayed.contains(4), isTrue);

      // Next tick: 3s -> beep
      await tester.pump(const Duration(seconds: 1));
      expect(beepsPlayed.contains(3), isTrue);

      // Next tick: 2s -> beep
      await tester.pump(const Duration(seconds: 1));
      expect(beepsPlayed.contains(2), isTrue);

      // Next tick: 1s -> beep
      await tester.pump(const Duration(seconds: 1));
      expect(beepsPlayed.contains(1), isTrue);

      // Next tick: 0s -> completion sound alert & finished banner
      await tester.pump(const Duration(seconds: 1));
      expect(completionAlertPlayed, isTrue);
      expect(find.text('REST FINISHED!'), findsOneWidget);
      expect(find.text('Start your next set now'), findsOneWidget);

      // Fast forward past 4-second auto-dismiss timer
      await tester.pump(const Duration(seconds: 5));
    });

    test('10: Existing workout telemetry, sets, volume, and PR calculation remain intact', () {
      final session = createTestSession();
      repository.startSession(session, clientId: 'client_test_user');

      // Update actual weight & reps
      repository.updateSetActual(exerciseIndex: 0, setIndex: 0, weight: 100.0, reps: 10);
      final pr = repository.completeSet(exerciseIndex: 0, setIndex: 0);

      final completedSet = repository.activeSession.exercises[0].sets[0];
      expect(completedSet.actualWeight, equals(100.0));
      expect(completedSet.actualReps, equals(10));
      expect(completedSet.volume, equals(1000.0));
      expect(pr, isNotNull); // Evaluated PR
    });
  });
}
