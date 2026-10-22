import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_x_gym/features/ai_coach/domain/models/ai_coach_models.dart';
import 'package:alpha_x_gym/features/ai_coach/data/repositories/ai_coach_repository.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/workout/presentation/admin/admin_workout_proposals_screen.dart';
import 'package:alpha_x_gym/features/workout/presentation/admin/admin_create_edit_session_screen.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';
import 'package:alpha_x_gym/features/exercise/presentation/widgets/exercise_picker_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Alpha X Admin Exercise Replacement & Drag-and-Drop Reordering UI Tests', () {
    testWidgets('1. Proposal Editor renders ReorderableListView with ReorderableDragStartListener for each exercise', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final proposal = AiProposal(
        id: 'prop_test_dnd_01',
        clientId: 'AXG-1029',
        clientName: 'Alex Mercer',
        type: AiProposalType.workout,
        title: 'Push Day Hypertrophy',
        summary: 'Targeted chest, delts, and arms session',
        reason: 'Optimal progressive overload',
        status: AiProposalStatus.pending,
        payload: {
          'title': 'Push Day Hypertrophy',
          'workoutType': 'Strength',
          'targetMuscleGroup': 'Chest & Shoulders',
          'isMultiDaySplit': true,
          'weeklySchedule': [
            {
              'dayId': 'day_1',
              'day': 'Monday',
              'dayName': 'Monday',
              'sessionTitle': 'Monday Push',
              'splitCategory': 'Push',
              'targetMuscleGroup': 'Chest',
              'exercises': [
                {'exerciseId': 'ex_1', 'exerciseName': 'Barbell Flat Bench Press', 'name': 'Barbell Flat Bench Press', 'sets': 4, 'targetReps': '6-8', 'weight': 80.0},
                {'exerciseId': 'ex_2', 'exerciseName': 'Incline Dumbbell Press', 'name': 'Incline Dumbbell Press', 'sets': 3, 'targetReps': '8-10', 'weight': 30.0},
                {'exerciseId': 'ex_3', 'exerciseName': 'Cable Chest Fly', 'name': 'Cable Chest Fly', 'sets': 3, 'targetReps': '12-15', 'weight': 15.0},
              ],
            },
          ],
        },
      );

      final workoutRepo = WorkoutRepository();
      final aiRepo = AiCoachRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkoutProposalDetailSheet(
              proposal: proposal,
              workoutRepository: workoutRepo,
              aiCoachRepository: aiRepo,
              onProposalUpdated: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Proposal Title
      expect(find.text('Push Day Hypertrophy'), findsWidgets);

      // Verify ReorderableListView exists for the day
      expect(find.byType(ReorderableListView), findsWidgets);

      // Verify drag handles with ReorderableDragStartListener exist
      expect(find.byType(ReorderableDragStartListener), findsNWidgets(3));

      // Verify drag indicator icons exist
      expect(find.byIcon(Icons.drag_indicator), findsNWidgets(3));

      // Verify Replace action buttons exist for each exercise
      expect(find.byTooltip('Replace Exercise from Library'), findsNWidgets(3));
    });

    testWidgets('2. ExercisePickerDialog excludes current exercise ID from selectable list', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Show dialog with excluded exercise 'ex_bb_bench'
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    ExercisePickerDialog.show(
                      context,
                      initialCategory: 'Chest',
                      excludedExerciseId: 'ex_bb_bench',
                    );
                  },
                  child: const Text('Open Picker'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Verify Dialog header
      expect(find.text('SELECT EXERCISE'), findsOneWidget);

      // Verify search field exists
      expect(find.byType(TextField), findsOneWidget);

      // Verify that 'ex_bb_bench' is NOT present in the selectable tiles
      final excludedFinder = find.byKey(const ValueKey('ex_item_ex_bb_bench'));
      expect(excludedFinder, findsNothing);
    });

    testWidgets('3. AdminCreateEditSessionScreen initializes with ReorderableDragStartListener on drag indicators', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final initialSession = WorkoutSession(
        id: 'sess_test_101',
        title: 'Chest & Arms Hypertrophy',
        workoutType: 'Strength',
        targetMuscleGroup: 'Chest, Arms',
        difficulty: 'Intermediate',
        estimatedDurationMinutes: 60,
        exercises: [
          WorkoutExercise(
            id: 'we_1',
            exerciseId: 'ex_1',
            exerciseName: 'Barbell Flat Bench Press',
            category: 'Chest',
            primaryMusclesDisplay: 'Chest',
            secondaryMusclesDisplay: 'Triceps',
            trainerNote: 'Drive with chest',
            sets: [
              ExerciseSet(id: 's_1', setNumber: 1, targetRepsMin: 6, targetRepsMax: 8, targetWeight: 80.0),
              ExerciseSet(id: 's_2', setNumber: 2, targetRepsMin: 6, targetRepsMax: 8, targetWeight: 80.0),
            ],
          ),
          WorkoutExercise(
            id: 'we_2',
            exerciseId: 'ex_2',
            exerciseName: 'Dumbbell Incline Press',
            category: 'Chest',
            primaryMusclesDisplay: 'Chest',
            secondaryMusclesDisplay: 'Shoulders',
            trainerNote: 'Control eccentric',
            sets: [
              ExerciseSet(id: 's_3', setNumber: 1, targetRepsMin: 8, targetRepsMax: 10, targetWeight: 28.0),
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

      // Verify Screen title
      expect(find.text('EDIT WORKOUT PLAN'), findsOneWidget);

      // Verify ReorderableListView is present
      expect(find.byType(ReorderableListView), findsOneWidget);

      // Verify drag start listeners are attached to the drag indicators
      expect(find.byType(ReorderableDragStartListener), findsNWidgets(2));

      // Verify the two exercises are displayed
      expect(find.text('Barbell Flat Bench Press'), findsOneWidget);
      expect(find.text('Dumbbell Incline Press'), findsOneWidget);

      // Verify replace action button exists
      expect(find.byTooltip('Replace with Library Exercise'), findsNWidgets(2));
    });
  });
}
