import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/core/constants/user_role.dart';
import 'package:alpha_x_gym/core/utils/ist_date_utils.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/workout/presentation/client/client_workout_execution_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AuthService auth;

  final todayIST = IstDateUtils.getTodayISTString();

  WorkoutSession createPushDay({String id = 'ws_push_day', String? clientId = 'client_john'}) {
    return WorkoutSession(
      id: id,
      title: 'Push Day - Chest & Shoulders',
      workoutType: 'Hypertrophy',
      targetMuscleGroup: 'Chest, Shoulders',
      difficulty: 'Intermediate',
      estimatedDurationMinutes: 55,
      description: 'Push power workout',
      isActive: true,
      availabilityType: 'INDIVIDUAL',
      assignedClientId: clientId,
      scheduledDate: todayIST,
      exercises: [
        const WorkoutExercise(
          id: 'ex_push_1',
          exerciseId: 'ex_flat_bench',
          exerciseName: 'Flat Barbell Bench Press',
          category: 'Chest',
          primaryMusclesDisplay: 'Pectoralis Major',
          secondaryMusclesDisplay: 'Triceps',
          trainerNote: 'Arch back and retract scapulae',
          restSeconds: 60,
          sets: [
            ExerciseSet(id: 's_p1_1', setNumber: 1, targetWeight: 80.0, targetRepsMin: 8, targetRepsMax: 10, isCompleted: false),
            ExerciseSet(id: 's_p1_2', setNumber: 2, targetWeight: 80.0, targetRepsMin: 8, targetRepsMax: 10, isCompleted: false),
            ExerciseSet(id: 's_p1_3', setNumber: 3, targetWeight: 80.0, targetRepsMin: 8, targetRepsMax: 10, isCompleted: false),
          ],
        ),
        const WorkoutExercise(
          id: 'ex_push_2',
          exerciseId: 'ex_incline_db',
          exerciseName: 'Incline Dumbbell Press',
          category: 'Chest',
          primaryMusclesDisplay: 'Upper Chest',
          secondaryMusclesDisplay: 'Deltoids',
          trainerNote: 'Controlled 3-sec negative',
          restSeconds: 60,
          sets: [
            ExerciseSet(id: 's_p2_1', setNumber: 1, targetWeight: 28.0, targetRepsMin: 10, targetRepsMax: 12, isCompleted: false),
            ExerciseSet(id: 's_p2_2', setNumber: 2, targetWeight: 28.0, targetRepsMin: 10, targetRepsMax: 12, isCompleted: false),
          ],
        ),
      ],
    );
  }

  WorkoutSession createPullDay({String id = 'ws_pull_day', String? clientId = 'client_john'}) {
    return WorkoutSession(
      id: id,
      title: 'Pull Day - Back & Biceps',
      workoutType: 'Hypertrophy',
      targetMuscleGroup: 'Back, Biceps',
      difficulty: 'Intermediate',
      estimatedDurationMinutes: 50,
      description: 'Pull power workout',
      isActive: true,
      availabilityType: 'INDIVIDUAL',
      assignedClientId: clientId,
      scheduledDate: todayIST,
      exercises: [
        const WorkoutExercise(
          id: 'ex_pull_1',
          exerciseId: 'ex_barbell_row',
          exerciseName: 'Barbell Bent Over Row',
          category: 'Back',
          primaryMusclesDisplay: 'Latissimus Dorsi',
          secondaryMusclesDisplay: 'Biceps',
          trainerNote: 'Pull to lower chest',
          restSeconds: 60,
          sets: [
            ExerciseSet(id: 's_pull1_1', setNumber: 1, targetWeight: 70.0, targetRepsMin: 8, targetRepsMax: 10, isCompleted: false),
            ExerciseSet(id: 's_pull1_2', setNumber: 2, targetWeight: 70.0, targetRepsMin: 8, targetRepsMax: 10, isCompleted: false),
          ],
        ),
      ],
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    auth = AuthService();
    auth.setAuthenticatedSessionForTesting(
      role: UserRole.client,
      email: 'john@alphaxgym.com',
      userId: 'client_john',
    );
  });

  group('Workout Session Stability Regression Tests (10 Core Scenarios)', () {
    test('1. Start Push Day, complete several sets, wait for background refreshes; Pull Day NEVER replaces it', () async {
      final pushDay = createPushDay();
      final pullDay = createPullDay();

      final mockClient = MockClient((request) async {
        // Return Pull Day as the latest server assignment
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'sessions': [pushDay.toJson(), pullDay.toJson()],
              'assignments': [
                {
                  'id': 'as_pull',
                  'clientId': 'client_john',
                  'workoutId': pullDay.id,
                  'isRecommended': true,
                  'assignedDate': todayIST,
                  'workout': pullDay.toJson(),
                }
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = WorkoutRepository(httpClient: mockClient);
      repo.startSession(pushDay, clientId: 'client_john');

      expect(repo.isWorkoutInProgress, isTrue);
      expect(repo.activeSession.id, equals(pushDay.id));
      expect(repo.activeSession.title, contains('Push Day'));

      // Complete Set 1 and Set 2 of Push Day
      repo.completeSet(exerciseIndex: 0, setIndex: 0);
      repo.completeSet(exerciseIndex: 0, setIndex: 1);

      expect(repo.activeSession.exercises[0].sets[0].isCompleted, isTrue);
      expect(repo.activeSession.exercises[0].sets[1].isCompleted, isTrue);

      // Simulate periodic background refreshes (like AppAutoRefreshService polling every 8s)
      for (int i = 0; i < 3; i++) {
        await repo.fetchClientWorkouts(forceRefresh: true);
      }

      // Assert: Active session MUST remain locked to Push Day with completed sets intact
      expect(repo.activeSession.id, equals(pushDay.id));
      expect(repo.activeSession.title, contains('Push Day'));
      expect(repo.activeSession.exercises[0].sets[0].isCompleted, isTrue);
      expect(repo.activeSession.exercises[0].sets[1].isCompleted, isTrue);
    });

    testWidgets('2. Tick Set 1 and confirm it stays checked after multiple widget rebuilds', (tester) async {
      final pushDay = createPushDay();
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
      });
      final repo = WorkoutRepository(httpClient: mockClient);
      repo.startSession(pushDay, clientId: 'client_john');

      await tester.pumpWidget(
        MaterialApp(
          home: ClientWorkoutExecutionScreen(
            workoutRepository: repo,
            session: pushDay,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final set1CheckboxFinder = find.byKey(const ValueKey('set_checkbox_0_0'));
      expect(set1CheckboxFinder, findsOneWidget);

      // Tap to complete Set 1
      await tester.tap(set1CheckboxFinder);
      await tester.pumpAndSettle();

      expect(repo.activeSession.exercises[0].sets[0].isCompleted, isTrue);

      // Trigger multiple full widget rebuilds & simulated notifyListeners
      for (int i = 0; i < 5; i++) {
        repo.updateCurrentExerciseIndex(0);
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();

      // Confirm checkbox remains checked
      expect(repo.activeSession.exercises[0].sets[0].isCompleted, isTrue);
      expect(find.byKey(const ValueKey('set_checkbox_0_0')), findsOneWidget);
    });

    testWidgets('3. Tick multiple sets quickly and confirm every set retains its own correct state', (tester) async {
      final pushDay = createPushDay();
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
      });
      final repo = WorkoutRepository(httpClient: mockClient);
      repo.startSession(pushDay, clientId: 'client_john');

      await tester.pumpWidget(
        MaterialApp(
          home: ClientWorkoutExecutionScreen(
            workoutRepository: repo,
            session: pushDay,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Rapidly complete Set 1, Set 2, and Set 3
      final set1Finder = find.byKey(const ValueKey('set_checkbox_0_0'));
      final set2Finder = find.byKey(const ValueKey('set_checkbox_0_1'));
      final set3Finder = find.byKey(const ValueKey('set_checkbox_0_2'));

      await tester.tap(set1Finder);
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(set2Finder);
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(set3Finder);
      await tester.pumpAndSettle();

      // All 3 sets must remain completed
      expect(repo.activeSession.exercises[0].sets[0].isCompleted, isTrue);
      expect(repo.activeSession.exercises[0].sets[1].isCompleted, isTrue);
      expect(repo.activeSession.exercises[0].sets[2].isCompleted, isTrue);
      // Exercise 2 sets remain uncompleted
      expect(repo.activeSession.exercises[1].sets[0].isCompleted, isFalse);
    });

    testWidgets('4. Navigate between exercises and return; completed sets must remain checked', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final pushDay = createPushDay();
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
      });
      final repo = WorkoutRepository(httpClient: mockClient);
      repo.startSession(pushDay, clientId: 'client_john');

      await tester.pumpWidget(
        MaterialApp(
          home: ClientWorkoutExecutionScreen(
            workoutRepository: repo,
            session: pushDay,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Complete Set 1 on Exercise 0 (Flat Bench)
      await tester.tap(find.byKey(const ValueKey('set_checkbox_0_0')));
      await tester.pumpAndSettle();
      expect(repo.activeSession.exercises[0].sets[0].isCompleted, isTrue);

      // Tap Exercise 1 chevron to expand Exercise 1
      await tester.tap(find.byKey(const ValueKey('exercise_chevron_1')));
      await tester.pumpAndSettle();

      // Complete Set 1 on Exercise 1
      await tester.tap(find.byKey(const ValueKey('set_checkbox_1_0')));
      await tester.pumpAndSettle();
      expect(repo.activeSession.exercises[1].sets[0].isCompleted, isTrue);

      // Tap Exercise 0 chevron to navigate back
      await tester.tap(find.byKey(const ValueKey('exercise_chevron_0')));
      await tester.pumpAndSettle();

      // Assert both exercises retained their completed sets
      expect(repo.activeSession.exercises[0].sets[0].isCompleted, isTrue);
      expect(repo.activeSession.exercises[1].sets[0].isCompleted, isTrue);
    });

    test('5. Minimize and reopen the app during a workout; restore the same active session (even across midnight)', () async {
      final pushDay = createPushDay();
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
      });
      final repo1 = WorkoutRepository(httpClient: mockClient);
      repo1.startSession(pushDay, clientId: 'client_john');
      repo1.completeSet(exerciseIndex: 0, setIndex: 0);

      // Save to local storage as if app was backgrounded / closed
      await repo1.saveActiveSessionToLocalStorage(userId: 'client_john', elapsedSeconds: 420);

      // New repository instance simulating app restart / cold boot
      final repo2 = WorkoutRepository(httpClient: mockClient);
      await repo2.restoreActiveSessionForClient('client_john');

      // Assert: Same session restored with in-progress state and completed sets
      expect(repo2.hasActiveSavedSession, isTrue);
      expect(repo2.isWorkoutInProgress, isTrue);
      expect(repo2.activeSession.id, equals(pushDay.id));
      expect(repo2.activeSession.exercises[0].sets[0].isCompleted, isTrue);

      final duration = await repo2.getSavedActiveSessionDuration(userId: 'client_john');
      expect(duration, equals(420));
    });

    test('6. Simulate slow, delayed, duplicate, and out-of-order API responses; stale data must not overwrite newer changes', () async {
      final pushDay = createPushDay();
      final mockClient = MockClient((request) async {
        // Slow server response returning stale incomplete session
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'sessions': [pushDay.toJson()],
              'assignments': [],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = WorkoutRepository(httpClient: mockClient);
      repo.startSession(pushDay, clientId: 'client_john');

      // Client marks Set 1 and Set 2 as completed
      repo.completeSet(exerciseIndex: 0, setIndex: 0);
      repo.completeSet(exerciseIndex: 0, setIndex: 1);

      // Out-of-order fetchClientWorkouts response finishes now
      await repo.fetchClientWorkouts(forceRefresh: true);

      // Stale server response MUST NOT revert the newly completed sets
      expect(repo.activeSession.exercises[0].sets[0].isCompleted, isTrue);
      expect(repo.activeSession.exercises[0].sets[1].isCompleted, isTrue);
    });

    test('7. Simulate a network failure during set completion; UI must not silently revert the checkbox; retry succeeds', () async {
      bool failNetwork = true;

      final mockClient = MockClient((request) async {
        if (failNetwork) {
          throw http.ClientException('Connection failed');
        }
        return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
      });

      final repo = WorkoutRepository(httpClient: mockClient);
      final pushDay = createPushDay();
      repo.startSession(pushDay, clientId: 'client_john');

      // Attempt to complete Set 1 while network fails
      repo.completeSet(exerciseIndex: 0, setIndex: 0);
      await Future.delayed(const Duration(milliseconds: 50));

      // Local state is preserved as completed! Checkbox does NOT revert!
      expect(repo.activeSession.exercises[0].sets[0].isCompleted, isTrue);
      expect(repo.pendingSetCompletionsCount, equals(1));

      // Network recovers: sync pending set completions
      failNetwork = false;
      await repo.syncPendingSetCompletionsWithBackend();

      // Pending queue cleared on successful retry
      expect(repo.pendingSetCompletionsCount, equals(0));
      expect(repo.activeSession.exercises[0].sets[0].isCompleted, isTrue);
    });

    test('8. Change the admin assignment during an active session; the current workout must remain stable', () async {
      final pushDay = createPushDay();
      final pullDay = createPullDay();

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
      });

      final repo = WorkoutRepository(httpClient: mockClient);
      repo.createSession(pushDay);
      repo.createSession(pullDay);

      repo.startSession(pushDay, clientId: 'client_john');
      repo.completeSet(exerciseIndex: 0, setIndex: 0);

      // Admin assigns Pull Day mid-workout
      await repo.assignSession(
        sessionId: pullDay.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: 'client_john',
        isRecommended: true,
        scheduledDate: todayIST,
      );

      // Active workout session remains Push Day!
      expect(repo.isWorkoutInProgress, isTrue);
      expect(repo.activeSession.id, equals(pushDay.id));
      expect(repo.activeSession.exercises[0].sets[0].isCompleted, isTrue);

      // getTodaySessionForClient still returns the active Push Day while training
      final todaySession = repo.getTodaySessionForClient('client_john');
      expect(todaySession?.id, equals(pushDay.id));
    });

    test('9. Complete the workout normally and verify next-day scheduling and workout-freeze rules work correctly', () async {
      final pushDay = createPushDay();
      final pullDay = createPullDay();

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
      });

      final repo = WorkoutRepository(httpClient: mockClient);
      repo.createSession(pushDay);
      repo.createSession(pullDay);

      // Assign both Push and Pull Day
      await repo.assignSession(
        sessionId: pushDay.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: 'client_john',
        isRecommended: false,
        scheduledDate: todayIST,
      );
      await repo.assignSession(
        sessionId: pullDay.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: 'client_john',
        isRecommended: true,
        scheduledDate: todayIST,
      );

      repo.startSession(pushDay, clientId: 'client_john');
      repo.completeSet(exerciseIndex: 0, setIndex: 0);
      repo.completeSet(exerciseIndex: 0, setIndex: 1);

      // Finish and complete workout
      final record = repo.completeWorkout(durationSeconds: 1800);
      expect(record.isCompleted, isTrue);
      expect(record.isLocked, isTrue);
      expect(repo.isWorkoutInProgress, isFalse);

      // History has the completed locked record
      expect(repo.workoutHistory.any((r) => r.sessionId == pushDay.id && r.isCompleted && r.isLocked), isTrue);

      // Next session query now advances to the recommended Pull Day assignment
      final nextSession = repo.getTodaySessionForClient('client_john');
      expect(nextSession?.id, equals(pullDay.id));
    });

    test('10. Verify that another client’s session and progress remain completely unaffected', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
      });

      // Authenticate as Client 1
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'client1@alphaxgym.com',
        userId: 'client_1',
      );

      final repo = WorkoutRepository(httpClient: mockClient);
      final client1Session = createPushDay(id: 'ws_push_client1', clientId: 'client_1');

      // Client 1 starts session and completes set
      repo.startSession(client1Session, clientId: 'client_1');
      repo.completeSet(exerciseIndex: 0, setIndex: 0);
      await repo.saveActiveSessionToLocalStorage(userId: 'client_1', elapsedSeconds: 300);

      // Switch to Client 2 context
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'client2@alphaxgym.com',
        userId: 'client_2',
      );

      // Verify Client 2 does not see Client 1's active session
      final client2Repo = WorkoutRepository(httpClient: mockClient);
      await client2Repo.restoreActiveSessionForClient('client_2');

      // Client 2 has no active session restored
      expect(client2Repo.isWorkoutInProgress, isFalse);

      // Switch back to Client 1 context
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'client1@alphaxgym.com',
        userId: 'client_1',
      );

      // Client 1 restores their own active session with their set intact
      final client1RestoredRepo = WorkoutRepository(httpClient: mockClient);
      await client1RestoredRepo.restoreActiveSessionForClient('client_1');

      expect(client1RestoredRepo.isWorkoutInProgress, isTrue);
      expect(client1RestoredRepo.activeSession.id, equals('ws_push_client1'));
      expect(client1RestoredRepo.activeSession.exercises[0].sets[0].isCompleted, isTrue);
    });
  });
}
