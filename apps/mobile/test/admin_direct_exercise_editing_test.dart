import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_x_gym/features/workout/presentation/admin/admin_create_edit_session_screen.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Alpha X Admin Direct Exercise Editing Tests', () {
    testWidgets('1. Compact row UI: displays exercise name on left, editable sets/reps/rest on right, and delete button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final initialSession = WorkoutSession(
        id: 'sess_direct_01',
        title: 'Push Day Hypertrophy',
        workoutType: 'Strength',
        targetMuscleGroup: 'Chest, Triceps',
        difficulty: 'Intermediate',
        estimatedDurationMinutes: 50,
        exercises: [
          WorkoutExercise(
            id: 'we_bench_1',
            exerciseId: 'ex_bench',
            exerciseName: 'Flat Barbell Bench Press',
            category: 'Chest',
            primaryMusclesDisplay: 'Chest',
            secondaryMusclesDisplay: 'Triceps',
            restSeconds: 90,
            trainerNote: 'Explosive concentric',
            sets: [
              const ExerciseSet(id: 's_1', setNumber: 1, targetRepsMin: 8, targetRepsMax: 12, targetWeight: 80.0),
              const ExerciseSet(id: 's_2', setNumber: 2, targetRepsMin: 8, targetRepsMax: 12, targetWeight: 80.0),
              const ExerciseSet(id: 's_3', setNumber: 3, targetRepsMin: 8, targetRepsMax: 12, targetWeight: 80.0),
            ],
          ),
        ],
      );

      final workoutRepo = WorkoutRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: AdminCreateEditSessionScreen(
            workoutRepository: workoutRepo,
            sessionToEdit: initialSession,
            onSaved: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify exercise name on left
      expect(find.text('Flat Barbell Bench Press'), findsOneWidget);

      // 2. Verify drag handle exists on left for reordering
      expect(find.byType(ReorderableDragStartListener), findsOneWidget);
      expect(find.byIcon(Icons.drag_indicator), findsOneWidget);

      // 3. Verify editable fields for Sets, Reps, and Rest
      expect(find.widgetWithText(TextFormField, '3'), findsWidgets);
      expect(find.widgetWithText(TextFormField, '8–12'), findsWidgets);
      expect(find.widgetWithText(TextFormField, '90'), findsWidgets);

      // 4. Verify Delete button exists
      expect(find.byTooltip('Delete Exercise'), findsOneWidget);

      // 5. Verify obsolete Up/Down and separate Edit buttons are NOT present in the row
      expect(find.byTooltip('Move Up'), findsNothing);
      expect(find.byTooltip('Move Down'), findsNothing);
      expect(find.byTooltip('Edit Exercise Details'), findsNothing);

      // 6. Verify duplicate and replace are preserved
      expect(find.byTooltip('Duplicate Exercise'), findsOneWidget);
      expect(find.byTooltip('Replace with Library Exercise'), findsOneWidget);
    });

    testWidgets('2. Direct editing of sets, reps, and rest time updates session state without opening separate edit dialog', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final initialSession = WorkoutSession(
        id: 'sess_direct_02',
        title: 'Pull Day Strength',
        workoutType: 'Strength',
        targetMuscleGroup: 'Back, Biceps',
        difficulty: 'Advanced',
        estimatedDurationMinutes: 60,
        exercises: [
          WorkoutExercise(
            id: 'we_pull_1',
            exerciseId: 'ex_pullup',
            exerciseName: 'Weighted Pull-Ups',
            category: 'Back',
            primaryMusclesDisplay: 'Lats',
            secondaryMusclesDisplay: 'Biceps',
            restSeconds: 120,
            trainerNote: 'Full dead-hang',
            sets: [
              const ExerciseSet(id: 's_1', setNumber: 1, targetRepsMin: 5, targetRepsMax: 5, targetWeight: 15.0),
              const ExerciseSet(id: 's_2', setNumber: 2, targetRepsMin: 5, targetRepsMax: 5, targetWeight: 15.0),
              const ExerciseSet(id: 's_3', setNumber: 3, targetRepsMin: 5, targetRepsMax: 5, targetWeight: 15.0),
            ],
          ),
        ],
      );

      final workoutRepo = WorkoutRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: AdminCreateEditSessionScreen(
            workoutRepository: workoutRepo,
            sessionToEdit: initialSession,
            onSaved: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the Sets text field and change from 3 to 4 directly
      final setsFinder = find.widgetWithText(TextFormField, '3');
      expect(setsFinder, findsOneWidget);
      await tester.enterText(setsFinder, '4');
      await tester.pumpAndSettle();

      // Find the Reps text field and change from 5 to 6-8 directly
      final repsFinder = find.widgetWithText(TextFormField, '5');
      expect(repsFinder, findsOneWidget);
      await tester.enterText(repsFinder, '6-8');
      await tester.pumpAndSettle();

      // Find the Rest text field and change from 120 to 90 directly
      final restFinder = find.widgetWithText(TextFormField, '120');
      expect(restFinder, findsOneWidget);
      await tester.enterText(restFinder, '90');
      await tester.pumpAndSettle();

      // Verify no modal bottom sheet or separate edit dialog was popped up
      expect(find.byType(BottomSheet), findsNothing);

      // Now tap Save in AppBar to persist
      final saveButton = find.widgetWithText(TextButton, 'SAVE');
      expect(saveButton, findsOneWidget);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Verify the session in the repository was updated with the new sets, reps, and rest
      final saved = await workoutRepo.getSessionById('sess_direct_02');
      expect(saved, isNotNull);
      expect(saved!.exercises.length, equals(1));
      final savedExercise = saved.exercises.first;
      expect(savedExercise.sets.length, equals(4));
      expect(savedExercise.sets.first.targetRepsMin, equals(6));
      expect(savedExercise.sets.first.targetRepsMax, equals(8));
      expect(savedExercise.restSeconds, equals(90));
    });

    testWidgets('3. Direct deletion: tapping delete button removes exercise immediately from session', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final initialSession = WorkoutSession(
        id: 'sess_direct_03',
        title: 'Full Body Circuit',
        workoutType: 'Conditioning',
        targetMuscleGroup: 'Full Body',
        difficulty: 'Intermediate',
        estimatedDurationMinutes: 45,
        exercises: [
          WorkoutExercise(
            id: 'we_del_1',
            exerciseId: 'ex_squat',
            exerciseName: 'Barbell Back Squat',
            category: 'Legs',
            primaryMusclesDisplay: 'Quads',
            secondaryMusclesDisplay: 'Glutes',
            sets: [const ExerciseSet(id: 's_1', setNumber: 1, targetRepsMin: 10, targetRepsMax: 10, targetWeight: 100.0)],
            trainerNote: '',
          ),
          WorkoutExercise(
            id: 'we_del_2',
            exerciseId: 'ex_pushup',
            exerciseName: 'Diamond Push-Ups',
            category: 'Chest',
            primaryMusclesDisplay: 'Triceps',
            secondaryMusclesDisplay: 'Chest',
            sets: [const ExerciseSet(id: 's_2', setNumber: 1, targetRepsMin: 15, targetRepsMax: 20, targetWeight: 0.0)],
            trainerNote: '',
          ),
        ],
      );

      final workoutRepo = WorkoutRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: AdminCreateEditSessionScreen(
            workoutRepository: workoutRepo,
            sessionToEdit: initialSession,
            onSaved: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Barbell Back Squat'), findsOneWidget);
      expect(find.text('Diamond Push-Ups'), findsOneWidget);

      // Tap delete on the first exercise
      final deleteButtons = find.byTooltip('Delete Exercise');
      expect(deleteButtons, findsNWidgets(2));
      await tester.tap(deleteButtons.first);
      await tester.pumpAndSettle();

      // Verify Squat is removed, Diamond Push-Ups remains
      expect(find.text('Barbell Back Squat'), findsNothing);
      expect(find.text('Diamond Push-Ups'), findsOneWidget);
      expect(find.byTooltip('Delete Exercise'), findsOneWidget);
    });

    testWidgets('4. Reopening session confirms directly edited sets, reps, and rest time persist across save round-trip', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final initialSession = WorkoutSession(
        id: 'sess_direct_04',
        title: 'Leg Day Volume',
        workoutType: 'Hypertrophy',
        targetMuscleGroup: 'Quads, Calves',
        difficulty: 'Advanced',
        estimatedDurationMinutes: 60,
        exercises: [
          WorkoutExercise(
            id: 'we_leg_press',
            exerciseId: 'ex_leg_press',
            exerciseName: 'Seated Leg Press',
            category: 'Legs',
            primaryMusclesDisplay: 'Quads',
            secondaryMusclesDisplay: 'Hamstrings',
            restSeconds: 75,
            trainerNote: 'Slow negative',
            sets: [
              const ExerciseSet(id: 's_1', setNumber: 1, targetRepsMin: 12, targetRepsMax: 15, targetWeight: 140.0),
              const ExerciseSet(id: 's_2', setNumber: 2, targetRepsMin: 12, targetRepsMax: 15, targetWeight: 140.0),
            ],
          ),
        ],
      );

      final workoutRepo = WorkoutRepository();
      final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

      // Launch root host with navKey
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  navKey.currentState!.push(
                    MaterialPageRoute(
                      builder: (_) => AdminCreateEditSessionScreen(
                        workoutRepository: workoutRepo,
                        sessionToEdit: initialSession,
                        onSaved: () {},
                      ),
                    ),
                  );
                },
                child: const Text('Open Initial'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Initial'));
      await tester.pumpAndSettle();

      // Edit sets: 2 -> 5
      final setsFinder = find.widgetWithText(TextFormField, '2');
      await tester.enterText(setsFinder, '5');
      await tester.pumpAndSettle();

      // Edit reps: 12-15 -> 15-20
      final repsFinder = find.widgetWithText(TextFormField, '12–15');
      await tester.enterText(repsFinder, '15-20');
      await tester.pumpAndSettle();

      // Edit rest: 75 -> 45
      final restFinder = find.widgetWithText(TextFormField, '75');
      await tester.enterText(restFinder, '45');
      await tester.pumpAndSettle();

      // Save via AppBar SAVE button
      final saveButton = find.widgetWithText(TextButton, 'SAVE');
      expect(saveButton, findsOneWidget);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      final savedSession = await workoutRepo.getSessionById('sess_direct_04');
      expect(savedSession, isNotNull);

      // Reopen session in AdminCreateEditSessionScreen
      navKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => AdminCreateEditSessionScreen(
            workoutRepository: workoutRepo,
            sessionToEdit: savedSession,
            onSaved: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Confirm reloaded UI has the modified values directly in the compact row
      expect(find.text('Seated Leg Press'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '5'), findsWidgets);
      expect(find.widgetWithText(TextFormField, '15–20'), findsWidgets);
      expect(find.widgetWithText(TextFormField, '45'), findsWidgets);
    });
  });
}
