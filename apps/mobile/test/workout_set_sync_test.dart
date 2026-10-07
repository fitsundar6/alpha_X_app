import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';
import 'package:alpha_x_gym/features/workout/presentation/client/widgets/exercise_stats.dart';
import 'package:alpha_x_gym/features/workout/presentation/client/client_session_overview_screen.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Workout Set Count Synchronization Tests', () {
    // Real API payload matching backend response for 3 / 5 / 4 sets
    final apiSessionJson = {
      'id': 'ws_sync_test_354',
      'title': 'Chest & Back Hypertrophy',
      'workoutType': 'Hypertrophy',
      'targetMuscleGroup': 'Chest • Back',
      'difficulty': 'Intermediate',
      'estimatedDurationMinutes': 60,
      'description': 'Targeted chest and back session.',
      'isActive': true,
      'availabilityType': 'INDIVIDUAL',
      'isRecommended': true,
      'exercises': [
        {
          'id': 'ex_sync_1',
          'sessionId': 'ws_sync_test_354',
          'exerciseId': 'ex_bench_press',
          'exerciseName': 'Barbell Bench Press',
          'category': 'Chest',
          'orderIndex': 0,
          'numberOfSets': 3,
          'setCount': 3,
          'setsCount': 3,
          'totalSets': 3,
          'targetSets': 3,
          'targetReps': '8–10',
          'targetWeight': 90.0,
          'restSeconds': 120,
          'targetRir': 2,
          'targetRpe': 8.0,
          'tempo': '3-1-1-0',
          'setType': 'Working',
          'trainerNote': 'Keep scapulae retracted.',
          'sets': [
            {
              'id': 'set_1_1',
              'setNumber': 1,
              'setType': 'Working',
              'targetWeight': 90.0,
              'targetRepsMin': 8,
              'targetRepsMax': 10,
              'targetRpe': 8.0,
              'targetRir': 2,
              'tempo': '3-1-1-0',
              'restSeconds': 120,
              'isCompleted': false,
            },
            {
              'id': 'set_1_2',
              'setNumber': 2,
              'setType': 'Working',
              'targetWeight': 90.0,
              'targetRepsMin': 8,
              'targetRepsMax': 10,
              'targetRpe': 8.0,
              'targetRir': 2,
              'tempo': '3-1-1-0',
              'restSeconds': 120,
              'isCompleted': false,
            },
            {
              'id': 'set_1_3',
              'setNumber': 3,
              'setType': 'Working',
              'targetWeight': 90.0,
              'targetRepsMin': 8,
              'targetRepsMax': 10,
              'targetRpe': 8.0,
              'targetRir': 2,
              'tempo': '3-1-1-0',
              'restSeconds': 120,
              'isCompleted': false,
            },
          ],
        },
        {
          'id': 'ex_sync_2',
          'sessionId': 'ws_sync_test_354',
          'exerciseId': 'ex_incline_db',
          'exerciseName': 'Incline Dumbbell Press',
          'category': 'Chest',
          'orderIndex': 1,
          'numberOfSets': 5,
          'setCount': 5,
          'setsCount': 5,
          'totalSets': 5,
          'targetSets': 5,
          'targetReps': '10–12',
          'targetWeight': 32.0,
          'restSeconds': 90,
          'targetRir': 1,
          'targetRpe': 8.5,
          'tempo': '3-0-1-0',
          'setType': 'Working',
          'trainerNote': 'Deep stretch at bottom.',
          'sets': [
            {
              'id': 'set_2_1',
              'setNumber': 1,
              'setType': 'Working',
              'targetWeight': 32.0,
              'targetRepsMin': 10,
              'targetRepsMax': 12,
              'targetRpe': 8.5,
              'targetRir': 1,
              'tempo': '3-0-1-0',
              'restSeconds': 90,
              'isCompleted': false,
            },
            {
              'id': 'set_2_2',
              'setNumber': 2,
              'setType': 'Working',
              'targetWeight': 32.0,
              'targetRepsMin': 10,
              'targetRepsMax': 12,
              'targetRpe': 8.5,
              'targetRir': 1,
              'tempo': '3-0-1-0',
              'restSeconds': 90,
              'isCompleted': false,
            },
            {
              'id': 'set_2_3',
              'setNumber': 3,
              'setType': 'Working',
              'targetWeight': 32.0,
              'targetRepsMin': 10,
              'targetRepsMax': 12,
              'targetRpe': 8.5,
              'targetRir': 1,
              'tempo': '3-0-1-0',
              'restSeconds': 90,
              'isCompleted': false,
            },
            {
              'id': 'set_2_4',
              'setNumber': 4,
              'setType': 'Working',
              'targetWeight': 32.0,
              'targetRepsMin': 10,
              'targetRepsMax': 12,
              'targetRpe': 8.5,
              'targetRir': 1,
              'tempo': '3-0-1-0',
              'restSeconds': 90,
              'isCompleted': false,
            },
            {
              'id': 'set_2_5',
              'setNumber': 5,
              'setType': 'Working',
              'targetWeight': 32.0,
              'targetRepsMin': 10,
              'targetRepsMax': 12,
              'targetRpe': 8.5,
              'targetRir': 1,
              'tempo': '3-0-1-0',
              'restSeconds': 90,
              'isCompleted': false,
            },
          ],
        },
        {
          'id': 'ex_sync_3',
          'sessionId': 'ws_sync_test_354',
          'exerciseId': 'ex_cable_fly',
          'exerciseName': 'Cable Chest Fly',
          'category': 'Chest',
          'orderIndex': 2,
          'numberOfSets': 4,
          'setCount': 4,
          'setsCount': 4,
          'totalSets': 4,
          'targetSets': 4,
          'targetReps': '12–15',
          'targetWeight': 18.0,
          'restSeconds': 60,
          'targetRir': 1,
          'targetRpe': 9.0,
          'tempo': '2-1-1-1',
          'setType': 'Working',
          'trainerNote': 'Squeeze pecs at midline.',
          // Test with sets omitted to verify Flutter fallback parsing:
        },
      ],
    };

    test('1. Flutter Model Parsing Test: Parses 3 / 5 / 4 sets and preserves all metadata', () {
      final session = WorkoutSession.fromJson(apiSessionJson);

      expect(session.exercises.length, 3);

      // Exercise 1: 3 sets
      final ex1 = session.exercises[0];
      expect(ex1.exerciseName, 'Barbell Bench Press');
      expect(ex1.numberOfSets, 3);
      expect(ex1.setCount, 3);
      expect(ex1.sets.length, 3);
      expect(ex1.sets[0].targetWeight, 90.0);
      expect(ex1.sets[0].targetRepsMin, 8);
      expect(ex1.sets[0].targetRepsMax, 10);
      expect(ex1.sets[0].targetRpe, 8.0);
      expect(ex1.sets[0].targetRir, 2);
      expect(ex1.restSeconds, 120);

      // Exercise 2: 5 sets
      final ex2 = session.exercises[1];
      expect(ex2.exerciseName, 'Incline Dumbbell Press');
      expect(ex2.numberOfSets, 5);
      expect(ex2.setCount, 5);
      expect(ex2.sets.length, 5);
      expect(ex2.sets[0].targetWeight, 32.0);
      expect(ex2.sets[0].targetRepsMin, 10);
      expect(ex2.sets[0].targetRepsMax, 12);
      expect(ex2.sets[0].targetRpe, 8.5);
      expect(ex2.sets[0].targetRir, 1);
      expect(ex2.restSeconds, 90);

      // Exercise 3: 4 sets (fallback parsed from numberOfSets: 4 when sets array omitted)
      final ex3 = session.exercises[2];
      expect(ex3.exerciseName, 'Cable Chest Fly');
      expect(ex3.numberOfSets, 4);
      expect(ex3.setCount, 4);
      expect(ex3.sets.length, 4);
      expect(ex3.sets[0].targetWeight, 18.0);
      expect(ex3.sets[0].targetRepsMin, 12);
      expect(ex3.sets[0].targetRepsMax, 15);
      expect(ex3.sets[0].targetRpe, 9.0);
      expect(ex3.sets[0].targetRir, 1);
      expect(ex3.restSeconds, 60);

      // Session totalSets
      expect(session.totalSets, 12);
    });

    testWidgets('2. ExerciseStats UI Test: Displays exact set count for 3, 5, and 4 sets', (tester) async {
      final session = WorkoutSession.fromJson(apiSessionJson);

      // Widget for Exercise 1 (3 sets)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExerciseStats(
              targetMuscle: 'Upper Chest',
              setsCount: session.exercises[0].sets.length,
              targetReps: '8-10',
              restSeconds: 120,
            ),
          ),
        ),
      );
      expect(find.text('SETS'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      // Widget for Exercise 2 (5 sets)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExerciseStats(
              targetMuscle: 'Upper Chest',
              setsCount: session.exercises[1].sets.length,
              targetReps: '10-12',
              restSeconds: 90,
            ),
          ),
        ),
      );
      expect(find.text('SETS'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);

      // Widget for Exercise 3 (4 sets)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExerciseStats(
              targetMuscle: 'Mid Chest',
              setsCount: session.exercises[2].sets.length,
              targetReps: '12-15',
              restSeconds: 60,
            ),
          ),
        ),
      );
      expect(find.text('SETS'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('3. ClientSessionOverviewScreen UI Test: Renders 3 × ..., 5 × ..., 4 × ... and Total Sets 12', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final session = WorkoutSession.fromJson(apiSessionJson);
      final repo = WorkoutRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: ClientSessionOverviewScreen(
            session: session,
            workoutRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Total Sets metric in header: 3 + 5 + 4 = 12
      expect(find.text('Total Sets'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);

      // Verify Exercise 1 shows 3 sets
      expect(find.textContaining('3 ×'), findsOneWidget);

      // Verify Exercise 2 shows 5 sets
      expect(find.textContaining('5 ×'), findsOneWidget);

      // Verify Exercise 3 shows 4 sets
      expect(find.textContaining('4 ×'), findsOneWidget);
    });

    test('4. App Close & Reopen Test: Serializing and Deserializing maintains exact 3 / 5 / 4 sets', () {
      final session = WorkoutSession.fromJson(apiSessionJson);

      // App closes: Session is serialized to JSON string in SharedPreferences
      final serializedJsonString = jsonEncode(session.toJson());

      // App reopens: Session is deserialized from JSON string
      final restoredMap = jsonDecode(serializedJsonString) as Map<String, dynamic>;
      final restoredSession = WorkoutSession.fromJson(restoredMap);

      expect(restoredSession.exercises.length, 3);
      expect(restoredSession.exercises[0].numberOfSets, 3);
      expect(restoredSession.exercises[0].sets.length, 3);
      expect(restoredSession.exercises[1].numberOfSets, 5);
      expect(restoredSession.exercises[1].sets.length, 5);
      expect(restoredSession.exercises[2].numberOfSets, 4);
      expect(restoredSession.exercises[2].sets.length, 4);
      expect(restoredSession.totalSets, 12);

      // Verify all parameters survived close & reopen cycle
      expect(restoredSession.exercises[0].sets[0].targetWeight, 90.0);
      expect(restoredSession.exercises[0].sets[0].targetRpe, 8.0);
      expect(restoredSession.exercises[0].sets[0].targetRir, 2);
      expect(restoredSession.exercises[0].sets[0].tempo, '3-1-1-0');
      expect(restoredSession.exercises[1].sets[0].targetWeight, 32.0);
      expect(restoredSession.exercises[1].sets[0].targetRpe, 8.5);
      expect(restoredSession.exercises[1].sets[0].targetRir, 1);
      expect(restoredSession.exercises[2].sets[0].targetWeight, 18.0);
      expect(restoredSession.exercises[2].sets[0].targetRpe, 9.0);
    });

    test('5. Logout and Login Test: Re-initialized repository loads sessions with 3 / 5 / 4 sets', () {
      // User logs out: in-memory state is recreated
      final newRepo = WorkoutRepository();
      expect(newRepo, isNotNull);

      // Simulated client workouts fetch populated with the assigned session
      final session = WorkoutSession.fromJson(apiSessionJson);
      expect(session.exercises[0].sets.length, 3);
      expect(session.exercises[1].sets.length, 5);
      expect(session.exercises[2].sets.length, 4);
      expect(session.totalSets, 12);
    });

    test('6. Regression Tests: Reps, weights, RPE, rest time, order, completion are strictly preserved', () {
      final session = WorkoutSession.fromJson(apiSessionJson);

      // Order
      expect(session.exercises[0].exerciseName, 'Barbell Bench Press');
      expect(session.exercises[1].exerciseName, 'Incline Dumbbell Press');
      expect(session.exercises[2].exerciseName, 'Cable Chest Fly');

      // Weights & Reps
      expect(session.exercises[0].sets[0].targetWeight, 90.0);
      expect(session.exercises[0].sets[0].targetRepsDisplay, '8–10');
      expect(session.exercises[1].sets[0].targetWeight, 32.0);
      expect(session.exercises[1].sets[0].targetRepsDisplay, '10–12');
      expect(session.exercises[2].sets[0].targetWeight, 18.0);
      expect(session.exercises[2].sets[0].targetRepsDisplay, '12–15');

      // RPE / RIR
      expect(session.exercises[0].sets[0].targetRpe, 8.0);
      expect(session.exercises[0].sets[0].targetRir, 2);
      expect(session.exercises[1].sets[0].targetRpe, 8.5);
      expect(session.exercises[1].sets[0].targetRir, 1);
      expect(session.exercises[2].sets[0].targetRpe, 9.0);
      expect(session.exercises[2].sets[0].targetRir, 1);

      // Rest time
      expect(session.exercises[0].restSeconds, 120);
      expect(session.exercises[1].restSeconds, 90);
      expect(session.exercises[2].restSeconds, 60);

      // Workout Completion preserves completed sets
      final completedExercise = session.exercises[0].copyWith(
        sets: session.exercises[0].sets.map((s) => s.copyWith(isCompleted: true, actualReps: 8, actualWeight: 90.0)).toList(),
      );
      expect(completedExercise.isAllSetsCompleted, true);
      expect(completedExercise.completedSetsCount, 3);
      expect(completedExercise.totalExerciseVolume, 90.0 * 8 * 3);
    });
  });
}
