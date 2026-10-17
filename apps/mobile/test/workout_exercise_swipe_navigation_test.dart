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

  WorkoutSession createThreeExerciseSession() {
    return WorkoutSession(
      id: 'ws_swipe_test',
      title: 'Chest & Arms Push Session',
      workoutType: 'Hypertrophy',
      targetMuscleGroup: 'Chest • Arms',
      difficulty: 'Intermediate',
      estimatedDurationMinutes: 50,
      description: 'Swipe navigation test session',
      isActive: true,
      availabilityType: 'INDIVIDUAL',
      exercises: [
        WorkoutExercise(
          id: 'we_bench',
          exerciseId: 'ex_bench_press',
          exerciseName: 'Barbell Bench Press',
          category: 'Chest',
          primaryMusclesDisplay: 'Pectoralis Major',
          secondaryMusclesDisplay: 'Triceps',
          trainerNote: '',
          restSeconds: 60,
          sets: [
            ExerciseSet(
              id: 'set_bench_1',
              setNumber: 1,
              targetWeight: 80.0,
              targetRepsMin: 8,
              targetRepsMax: 10,
              isCompleted: false,
            ),
            ExerciseSet(
              id: 'set_bench_2',
              setNumber: 2,
              targetWeight: 80.0,
              targetRepsMin: 8,
              targetRepsMax: 10,
              isCompleted: false,
            ),
          ],
        ),
        WorkoutExercise(
          id: 'we_incline_db',
          exerciseId: 'ex_incline_db_press',
          exerciseName: 'Incline Dumbbell Press',
          category: 'Chest',
          primaryMusclesDisplay: 'Upper Chest',
          secondaryMusclesDisplay: 'Front Deltoids',
          trainerNote: '',
          restSeconds: 60,
          sets: [
            ExerciseSet(
              id: 'set_inc_1',
              setNumber: 1,
              targetWeight: 28.0,
              targetRepsMin: 10,
              targetRepsMax: 12,
              isCompleted: false,
            ),
          ],
        ),
        WorkoutExercise(
          id: 'we_cable_fly',
          exerciseId: 'ex_cable_fly',
          exerciseName: 'Cable Chest Fly',
          category: 'Chest',
          primaryMusclesDisplay: 'Chest',
          secondaryMusclesDisplay: '',
          trainerNote: '',
          restSeconds: 45,
          sets: [
            ExerciseSet(
              id: 'set_fly_1',
              setNumber: 1,
              targetWeight: 15.0,
              targetRepsMin: 12,
              targetRepsMax: 15,
              isCompleted: false,
            ),
          ],
        ),
      ],
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({'success': true, 'data': {}}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    repository = WorkoutRepository(httpClient: mockClient);
    AuthService().setAuthenticatedSessionForTesting(
      role: UserRole.client,
      email: 'alex@alphaxgym.com',
      userId: 'client_alex',
    );
  });

  group('Workout Exercise Swipe Navigation Tests', () {
    testWidgets('Initial state: Exercise 1 is expanded, Exercise 2 and 3 are collapsed', (tester) async {
      final session = createThreeExerciseSession();
      repository.startSession(session, clientId: 'client_alex');

      await tester.pumpWidget(
        MaterialApp(
          home: ClientWorkoutExecutionScreen(
            workoutRepository: repository,
            session: session,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Exercise 1 checkboxes should be visible (expanded)
      expect(find.byKey(const ValueKey('set_checkbox_0_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('set_checkbox_0_1')), findsOneWidget);

      // Exercise 2 and 3 set checkboxes should NOT be visible (collapsed)
      expect(find.byKey(const ValueKey('set_checkbox_1_0')), findsNothing);
      expect(find.byKey(const ValueKey('set_checkbox_2_0')), findsNothing);
    });

    testWidgets('Swipe Left on Exercise 1 navigates to Exercise 2 (auto-expands Ex 2, collapses Ex 1)', (tester) async {
      final session = createThreeExerciseSession();
      repository.startSession(session, clientId: 'client_alex');

      await tester.pumpWidget(
        MaterialApp(
          home: ClientWorkoutExecutionScreen(
            workoutRepository: repository,
            session: session,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Exercise 1 is expanded initially
      expect(find.byKey(const ValueKey('set_checkbox_0_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('set_checkbox_1_0')), findsNothing);

      // Perform swipe left (drag right-to-left) on Exercise 1
      final ex1Card = find.byKey(const ValueKey('exercise_card_gesture_0'));
      expect(ex1Card, findsOneWidget);
      await tester.fling(ex1Card, const Offset(-400, 0), 1000.0);
      await tester.pumpAndSettle();

      // Now Exercise 2 should be expanded and Exercise 1 collapsed
      expect(find.byKey(const ValueKey('set_checkbox_1_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('set_checkbox_0_0')), findsNothing);
    });

    testWidgets('Swipe Right on Exercise 2 navigates back to Exercise 1', (tester) async {
      final session = createThreeExerciseSession();
      repository.startSession(session, clientId: 'client_alex');

      await tester.pumpWidget(
        MaterialApp(
          home: ClientWorkoutExecutionScreen(
            workoutRepository: repository,
            session: session,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // First swipe left to get to Exercise 2
      final ex1Card = find.byKey(const ValueKey('exercise_card_gesture_0'));
      await tester.fling(ex1Card, const Offset(-400, 0), 1000.0);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('set_checkbox_1_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('set_checkbox_0_0')), findsNothing);

      // Now perform swipe right (drag left-to-right) on Exercise 2
      final ex2Card = find.byKey(const ValueKey('exercise_card_gesture_1'));
      expect(ex2Card, findsOneWidget);
      await tester.fling(ex2Card, const Offset(400, 0), 1000.0);
      await tester.pumpAndSettle();

      // Exercise 1 is expanded again and Exercise 2 is collapsed
      expect(find.byKey(const ValueKey('set_checkbox_0_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('set_checkbox_1_0')), findsNothing);
    });

    testWidgets('Boundary check: Swiping right on the first exercise (index 0) remains safely on Exercise 1', (tester) async {
      final session = createThreeExerciseSession();
      repository.startSession(session, clientId: 'client_alex');

      await tester.pumpWidget(
        MaterialApp(
          home: ClientWorkoutExecutionScreen(
            workoutRepository: repository,
            session: session,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Swipe right on Exercise 1 (boundary condition: index 0 cannot go to -1)
      final ex1Card = find.byKey(const ValueKey('exercise_card_gesture_0'));
      await tester.fling(ex1Card, const Offset(400, 0), 1000.0);
      await tester.pumpAndSettle();

      // Stays on Exercise 1 without crashing
      expect(find.byKey(const ValueKey('set_checkbox_0_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('set_checkbox_1_0')), findsNothing);
    });

    testWidgets('Boundary check: Swiping left on the last exercise remains safely on the last exercise', (tester) async {
      final session = createThreeExerciseSession();
      repository.startSession(session, clientId: 'client_alex');

      await tester.pumpWidget(
        MaterialApp(
          home: ClientWorkoutExecutionScreen(
            workoutRepository: repository,
            session: session,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Swipe left from Ex 1 -> Ex 2
      await tester.fling(find.byKey(const ValueKey('exercise_card_gesture_0')), const Offset(-400, 0), 1000.0);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('set_checkbox_1_0')), findsOneWidget);

      // Swipe left from Ex 2 -> Ex 3 (last exercise)
      await tester.fling(find.byKey(const ValueKey('exercise_card_gesture_1')), const Offset(-400, 0), 1000.0);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('set_checkbox_2_0')), findsOneWidget);

      // Now swipe left on Ex 3 (boundary: cannot exceed last index)
      await tester.fling(find.byKey(const ValueKey('exercise_card_gesture_2')), const Offset(-400, 0), 1000.0);
      await tester.pumpAndSettle();

      // Stays on Ex 3 without crashing
      expect(find.byKey(const ValueKey('set_checkbox_2_0')), findsOneWidget);
    });

    testWidgets('Gesture conflict check: Tapping checkbox completes set without triggering swipe', (tester) async {
      final session = createThreeExerciseSession();
      repository.startSession(session, clientId: 'client_alex');

      await tester.pumpWidget(
        MaterialApp(
          home: ClientWorkoutExecutionScreen(
            workoutRepository: repository,
            session: session,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final set1Checkbox = find.byKey(const ValueKey('set_checkbox_0_0'));
      expect(set1Checkbox, findsOneWidget);
      expect(repository.activeSession.exercises[0].sets[0].isCompleted, isFalse);

      // Tap Set 1 Checkbox
      await tester.tap(set1Checkbox);
      await tester.pumpAndSettle();

      // Must complete set and remain on Exercise 1 (not swiped to Exercise 2)
      expect(repository.activeSession.exercises[0].sets[0].isCompleted, isTrue);
      expect(find.byKey(const ValueKey('set_checkbox_0_0')), findsOneWidget);
    });

    testWidgets('Gesture conflict check: Vertical drag scrolls list without switching exercises', (tester) async {
      final session = createThreeExerciseSession();
      repository.startSession(session, clientId: 'client_alex');

      await tester.pumpWidget(
        MaterialApp(
          home: ClientWorkoutExecutionScreen(
            workoutRepository: repository,
            session: session,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Exercise 1 is expanded
      expect(find.byKey(const ValueKey('set_checkbox_0_0')), findsOneWidget);

      // Perform vertical drag (scroll down)
      final ex1Card = find.byKey(const ValueKey('exercise_card_gesture_0'));
      await tester.drag(ex1Card, const Offset(0, -200));
      await tester.pumpAndSettle();

      // Vertical drag must scroll the list and NOT trigger exercise switching
      expect(find.byKey(const ValueKey('set_checkbox_0_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('set_checkbox_1_0')), findsNothing);
    });

    testWidgets('Gesture conflict check: Tapping header manually expands/collapses card without swiping', (tester) async {
      final session = createThreeExerciseSession();
      repository.startSession(session, clientId: 'client_alex');

      await tester.pumpWidget(
        MaterialApp(
          home: ClientWorkoutExecutionScreen(
            workoutRepository: repository,
            session: session,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap chevron of Exercise 2 to expand it
      final ex2Chevron = find.byIcon(Icons.keyboard_arrow_down_rounded).first;
      await tester.tap(ex2Chevron);
      await tester.pumpAndSettle();

      // Both Exercise 1 and Exercise 2 can be expanded when manually opened via header
      expect(find.byKey(const ValueKey('set_checkbox_0_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('set_checkbox_1_0')), findsOneWidget);
    });

    testWidgets('List container swipe: Swiping on exercise list area navigates between exercises', (tester) async {
      final session = createThreeExerciseSession();
      repository.startSession(session, clientId: 'client_alex');

      await tester.pumpWidget(
        MaterialApp(
          home: ClientWorkoutExecutionScreen(
            workoutRepository: repository,
            session: session,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('set_checkbox_0_0')), findsOneWidget);

      // Swipe left on the list swipe detector
      final listDetector = find.byKey(const ValueKey('exercise_list_swipe_detector'));
      expect(listDetector, findsOneWidget);
      await tester.fling(listDetector, const Offset(-400, 0), 1000.0);
      await tester.pumpAndSettle();

      // Navigated to Exercise 2
      expect(find.byKey(const ValueKey('set_checkbox_1_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('set_checkbox_0_0')), findsNothing);
    });
  });
}
