import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';
import 'package:alpha_x_gym/features/exercise/domain/models/exercise_model.dart';
import 'package:alpha_x_gym/features/exercise/data/repositories/exercise_repository.dart';
import 'package:alpha_x_gym/features/workout/presentation/client/widgets/client_exercise_detail_sheet.dart';
import 'package:alpha_x_gym/features/workout/presentation/client/widgets/exercise_media.dart';
import 'package:alpha_x_gym/features/workout/presentation/client/widgets/trainer_note_card.dart';
import 'package:alpha_x_gym/features/workout/presentation/client/widgets/previous_performance_card.dart';
import 'package:alpha_x_gym/features/workout/presentation/client/widgets/exercise_instructions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/features/workout/presentation/client/widgets/set_performance_row.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('Client Exercise Experience - Data Query & History Logic Tests', () {
    late WorkoutRepository repository;

    setUp(() {
      repository = WorkoutRepository();
    });

    test('Retrieves previous performance using clientId + exerciseId ordered newest first', () {
      final history = repository.getClientExerciseHistory(
        clientId: 'client_john_doe',
        exerciseId: 'ex_incline_smith',
      );

      expect(history.isNotEmpty, isTrue);
      expect(history.length, greaterThanOrEqualTo(2));
      // Verify descending date order (most recent first)
      for (int i = 0; i < history.length - 1; i++) {
        expect(
          history[i].date.isAfter(history[i + 1].date) ||
              history[i].date.isAtSameMomentAs(history[i + 1].date),
          isTrue,
        );
      }

      // Check latest session performance
      final latest = repository.getClientPreviousPerformance(
        clientId: 'client_john_doe',
        exerciseId: 'ex_incline_smith',
      );
      expect(latest, isNotNull);
      expect(latest!.isNotEmpty, isTrue);
      expect(latest.first.actualWeight, isNotNull);
      expect(latest.first.actualReps, isNotNull);
    });

    test('Does NOT return performance of another client or another exercise', () {
      // Query for an unknown or different client
      final nonExistentClientHistory = repository.getClientExerciseHistory(
        clientId: 'client_unknown_999',
        exerciseId: 'ex_incline_smith',
      );
      expect(nonExistentClientHistory, isEmpty);

      // Query for an exercise the client has never performed
      final nonExistentExerciseHistory = repository.getClientExerciseHistory(
        clientId: 'client_john_doe',
        exerciseId: 'non_existent_exercise_123',
      );
      expect(nonExistentExerciseHistory, isEmpty);

      final latestEmpty = repository.getClientPreviousPerformance(
        clientId: 'client_john_doe',
        exerciseId: 'non_existent_exercise_123',
      );
      expect(latestEmpty, isNull);
    });

    test('Excludes skipped exercises and incomplete workouts from history', () {
      final history = repository.getClientExerciseHistory(
        clientId: 'client_john_doe',
        exerciseId: 'ex_incline_smith',
      );

      for (final item in history) {
        expect(item.sets.isNotEmpty, isTrue);
      }
    });
  });

  group('Client Exercise Experience - Widget Tests', () {
    late WorkoutRepository repository;

    setUp(() {
      repository = WorkoutRepository();
    });

    const testExercise = WorkoutExercise(
      id: 'we_test_bench',
      exerciseId: 'ex_incline_smith',
      exerciseName: 'Incline Smith Machine Press',
      category: 'Chest',
      primaryMusclesDisplay: 'Chest',
      secondaryMusclesDisplay: 'Triceps',
      trainerNote: 'Keep shoulder blades retracted and elbows at 45 degrees.',
      restSeconds: 90,
      sets: [
        ExerciseSet(
          id: 'set_1',
          setNumber: 1,
          targetWeight: 80,
          targetRepsMin: 8,
          targetRepsMax: 10,
        ),
        ExerciseSet(
          id: 'set_2',
          setNumber: 2,
          targetWeight: 80,
          targetRepsMin: 8,
          targetRepsMax: 10,
        ),
        ExerciseSet(
          id: 'set_3',
          setNumber: 3,
          targetWeight: 80,
          targetRepsMin: 8,
          targetRepsMax: 10,
        ),
      ],
    );

    final testDbExercise = Exercise(
      id: 'ex_incline_smith',
      name: 'Incline Smith Machine Press',
      category: 'Chest',
      primaryMuscles: const [MuscleGroup.midChest],
      equipment: 'Smith Machine',
      difficulty: 'Intermediate',
      description: 'The incline smith machine press develops clavicular pectoral fibers.',
      setupInstructions: const [
        'Lie flat on the bench with your eyes directly under the bar.',
        'Grip the bar slightly wider than shoulder-width with wrists straight.',
        'Unrack the bar and stabilize it directly over your chest with arms locked.',
      ],
      executionSteps: const [
        'Lower the bar with control to your mid-chest while tucking elbows at 45 degrees.',
        'Press the bar back up explosively until your elbows are extended.',
      ],
      coachingCues: const [
        'Retract scapulae throughout movement',
        'Drive through the floor with your legs',
      ],
      videoUrl: '',
    );

    testWidgets('ClientExerciseDetailSheet renders all required sections', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClientExerciseDetailSheet(
              workoutExercise: testExercise,
              catalogExercise: testDbExercise,
              workoutRepository: repository,
              clientId: 'client_john_doe',
              actionButtonLabel: 'START SET',
              onPrimaryAction: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Exercise Name
      expect(find.text('Incline Smith Machine Press'), findsWidgets);

      // 2. Stats (Target Muscle, Sets, Target Reps, Rest)
      expect(find.text('Chest'), findsWidgets);
      expect(find.text('3'), findsWidgets);
      expect(find.text('8–10'), findsWidgets);
      expect(find.text('90 sec'), findsWidgets);

      // 3. Previous Performance section (now immediately below Stats)
      await tester.scrollUntilVisible(find.text('Previous Performance'), 150);
      await tester.pumpAndSettle();
      expect(find.text('Previous Performance'), findsOneWidget);

      // 4. Trainer Note
      await tester.scrollUntilVisible(find.text('Trainer Note'), 150);
      await tester.pumpAndSettle();
      expect(find.text('Trainer Note'), findsOneWidget);
      expect(
        find.textContaining('Keep shoulder blades retracted'),
        findsOneWidget,
      );

      // 5. How to perform (Instructions at the bottom)
      await tester.scrollUntilVisible(find.text('How to Perform'), 150);
      await tester.pumpAndSettle();
      expect(find.text('How to Perform'), findsOneWidget);

      // 6. Action button
      expect(find.text('START SET'), findsOneWidget);
    });

    testWidgets('TrainerNoteCard does not render when note is empty or whitespace', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TrainerNoteCard(note: ''),
                TrainerNoteCard(note: '   '),
              ],
            ),
          ),
        ),
      );

      expect(find.text('TRAINER NOTE'), findsNothing);
    });

    testWidgets('PreviousPerformanceCard displays "No previous performance" when history is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PreviousPerformanceCard(
              exerciseName: 'Incline Smith Machine Press',
              history: [],
            ),
          ),
        ),
      );

      expect(find.text('No previous performance'), findsOneWidget);
      expect(find.text('View Previous Performance'), findsNothing);
    });

    testWidgets('PreviousPerformanceCard displays set breakdown and date when available', (tester) async {
      final sampleHistory = [
        ExercisePerformanceHistoryItem(
          recordId: 'rec_test_1',
          sessionTitle: 'Chest Hypertrophy A',
          date: DateTime(2026, 9, 24),
          sets: const [
            ExerciseSet(
              id: 'set_1',
              setNumber: 1,
              targetWeight: 80,
              targetRepsMin: 8,
              targetRepsMax: 10,
              actualWeight: 80,
              actualReps: 10,
              isCompleted: true,
            ),
            ExerciseSet(
              id: 'set_2',
              setNumber: 2,
              targetWeight: 80,
              targetRepsMin: 8,
              targetRepsMax: 10,
              actualWeight: 80,
              actualReps: 9,
              isCompleted: true,
            ),
            ExerciseSet(
              id: 'set_3',
              setNumber: 3,
              targetWeight: 75,
              targetRepsMin: 8,
              targetRepsMax: 10,
              actualWeight: 75,
              actualReps: 10,
              isCompleted: true,
            ),
          ],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviousPerformanceCard(
              exerciseName: 'Incline Smith Machine Press',
              history: sampleHistory,
            ),
          ),
        ),
      );

      expect(find.text('Last Workout'), findsOneWidget);
      expect(find.text('24 Sep 2026'), findsOneWidget);
      expect(find.text('Set 1'), findsOneWidget);
      expect(find.text('80 kg × 10'), findsOneWidget);
      expect(find.text('Set 2'), findsOneWidget);
      expect(find.text('80 kg × 9'), findsOneWidget);
      expect(find.text('Set 3'), findsOneWidget);
      expect(find.text('75 kg × 10'), findsOneWidget);
      expect(find.text('View Previous Performance'), findsOneWidget);
    });

    testWidgets('ExerciseInstructions expands and shows Setup and Execution steps', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExerciseInstructions(
                setupInstructions: [
                  'Lie flat on the bench with your eyes directly under the bar.',
                  'Grip the bar slightly wider than shoulder-width with wrists straight.',
                ],
                executionSteps: [
                  'Lower the bar with control to your mid-chest while tucking elbows at 45 degrees.',
                  'Press the bar back up explosively until your elbows are extended.',
                ],
                coachingCues: [
                  'Retract scapulae throughout movement',
                  'Drive through the floor with your legs',
                ],
                initialExpanded: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap to expand
      await tester.tap(find.text('How to Perform'));
      await tester.pumpAndSettle();

      // Check Setup and Execution headers
      expect(find.text('Setup'), findsOneWidget);
      expect(find.text('Execution'), findsOneWidget);
      expect(find.text('Key Form Cues'), findsOneWidget);
      expect(find.textContaining('Lie flat on the bench'), findsOneWidget);
      expect(find.textContaining('Lower the bar with control'), findsOneWidget);
      expect(find.textContaining('Retract scapulae throughout movement'), findsOneWidget);
    });

    testWidgets('SetPerformanceRow shows reference previous performance and actual achieved display', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SetPerformanceRow(
              setNumber: 1,
              previousDisplay: '80 kg × 10',
              targetDisplay: '80 kg × 8–10',
              actualDisplay: '82.5 kg × 10',
              isCompleted: true,
            ),
          ),
        ),
      );

      // Verify reference previous performance display
      expect(find.text('80 kg × 10'), findsOneWidget);
      expect(find.text('PREVIOUS'), findsOneWidget);
      expect(find.text('82.5 kg × 10'), findsOneWidget);
    });
  });

  group('Client Exercise Experience - Real Media & Error Handling Tests', () {
    testWidgets('Case 1: Exercise with valid animated GIF displays animated GIF with ANIMATED FORM badge', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExerciseMedia(
              gifUrl: 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0757-5v7KYld.gif',
              exerciseName: 'Incline Smith Machine Press',
            ),
          ),
        ),
      );

      // Verify Image is rendered
      expect(find.byType(Image), findsOneWidget);
      // Verify badge does NOT say 'DEMO'
      expect(find.text('DEMO'), findsNothing);
      expect(find.text('ANIMATED FORM'), findsOneWidget);
      expect(find.text('Demonstration unavailable'), findsNothing);
    });

    testWidgets('Case 2: Exercise with no media displays "Demonstration unavailable"', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExerciseMedia(
              videoUrl: '',
              imageUrl: '',
              animationUrl: '',
              thumbnailUrl: '',
              gifUrl: '',
              exerciseName: 'Custom Unknown Exercise',
            ),
          ),
        ),
      );

      expect(find.text('Demonstration unavailable'), findsOneWidget);
      expect(find.text('Refer to the detailed form instructions below'), findsOneWidget);
      expect(find.text('DEMO'), findsNothing);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('Case 2b: Exercise with only static hero image strictly displays "Demonstration unavailable" (NEVER hero image)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExerciseMedia(
              imageUrl: 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=600',
              exerciseName: 'Custom Unknown Exercise Without GIF',
            ),
          ),
        ),
      );

      // Must NEVER display hero image as demonstration
      expect(find.text('Demonstration unavailable'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('Case 3: Failed media load displays "Unable to load demonstration" with Retry action', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExerciseMedia(
              gifUrl: 'assets/non_existent_demonstration.gif',
              exerciseName: 'Test Movement',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Unable to load demonstration'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('DEMO'), findsNothing);
    });

    test('Case 4: Two different exercises have different GIF media matching their respective exercise IDs', () {
      final repo = ExerciseRepository();
      final benchExercise = repo.getExerciseById('ex_incline_smith');
      final latPulldownExercise = repo.getExerciseById('ex_lat_pulldown');

      expect(benchExercise, isNotNull);
      expect(latPulldownExercise, isNotNull);

      expect(benchExercise!.gifDemonstrationUrl, isNotEmpty);
      expect(latPulldownExercise!.gifDemonstrationUrl, isNotEmpty);

      // Verify each exercise has its OWN GIF, not hero images and not identical media
      expect(benchExercise.gifDemonstrationUrl, isNot(equals(latPulldownExercise.gifDemonstrationUrl)));
      expect(benchExercise.gifDemonstrationUrl, contains('0757-5v7KYld.gif'));
      expect(latPulldownExercise.gifDemonstrationUrl, contains('2330-LEprlgG.gif'));
      expect(benchExercise.gifDemonstrationUrl.endsWith('.gif'), isTrue);
      expect(latPulldownExercise.gifDemonstrationUrl.endsWith('.gif'), isTrue);
      expect(benchExercise.gifDemonstrationUrl, isNot(contains('unsplash')));
      expect(latPulldownExercise.gifDemonstrationUrl, isNot(contains('unsplash')));
    });

    test('Case 5: Client opens same exercise from different workouts and resolves same animated GIF via exercise ID', () {
      final repo = ExerciseRepository();
      const exerciseId = 'ex_incline_smith';

      // Exercise from Workout 1
      const workout1Exercise = WorkoutExercise(
        id: 'we_workout1_smith',
        exerciseId: exerciseId,
        exerciseName: 'Incline Smith Press',
        category: 'Chest',
        primaryMusclesDisplay: 'Upper Chest',
        secondaryMusclesDisplay: 'Triceps',
        trainerNote: '',
        sets: [],
      );

      // Exercise from Workout 2
      const workout2Exercise = WorkoutExercise(
        id: 'we_workout2_smith',
        exerciseId: exerciseId,
        exerciseName: 'Incline Smith Press (Top Set)',
        category: 'Chest',
        primaryMusclesDisplay: 'Upper Chest',
        secondaryMusclesDisplay: 'Triceps',
        trainerNote: '',
        sets: [],
      );

      final catalog1 = repo.getExerciseById(workout1Exercise.exerciseId);
      final catalog2 = repo.getExerciseById(workout2Exercise.exerciseId);

      expect(catalog1, isNotNull);
      expect(catalog2, isNotNull);
      expect(catalog1!.id, equals(catalog2!.id));
      expect(catalog1.gifDemonstrationUrl, equals(catalog2.gifDemonstrationUrl));
      expect(catalog1.gifDemonstrationUrl, isNotEmpty);
      expect(catalog1.gifDemonstrationUrl.endsWith('.gif'), isTrue);
      expect(catalog1.gifDemonstrationUrl, isNot(contains('unsplash')));
    });
  });

  group('Client Exercise Experience - 5 Distinct Exercise Demonstrations & Verification', () {
    final repo = ExerciseRepository();

    test('Exercise 1: Dumbbell Romanian Deadlift (ex_db_rdl) displays correct continuous animated GIF', () {
      final exercise = repo.getExerciseById('ex_db_rdl');
      expect(exercise, isNotNull);
      expect(exercise!.name, equals('Dumbbell Romanian Deadlift'));

      final gif = exercise.gifDemonstrationUrl;
      expect(gif, isNotEmpty);
      expect(gif, equals('https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1459-rR0LJzx.gif'));
      expect(gif.endsWith('.gif'), isTrue);
      expect(gif, isNot(contains('unsplash')));
    });

    test('Exercise 2: Incline Smith Machine Press (ex_incline_smith) displays correct continuous animated GIF', () {
      final exercise = repo.getExerciseById('ex_incline_smith');
      expect(exercise, isNotNull);
      expect(exercise!.name, equals('Incline Smith Machine Press'));

      final gif = exercise.gifDemonstrationUrl;
      expect(gif, isNotEmpty);
      expect(gif, equals('https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0757-5v7KYld.gif'));
      expect(gif.endsWith('.gif'), isTrue);
      expect(gif, isNot(contains('unsplash')));
    });

    test('Exercise 3: Barbell Romanian Deadlift (ex_romanian_deadlift) displays correct continuous animated GIF', () {
      final exercise = repo.getExerciseById('ex_romanian_deadlift');
      expect(exercise, isNotNull);
      expect(exercise!.name, contains('Romanian Deadlift'));

      final gif = exercise.gifDemonstrationUrl;
      expect(gif, isNotEmpty);
      expect(gif, equals('https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0085-wQ2c4XD.gif'));
      expect(gif.endsWith('.gif'), isTrue);
      expect(gif, isNot(contains('unsplash')));
    });

    test('Exercise 4: Wide Grip Lat Pulldown (ex_lat_pulldown) displays correct continuous animated GIF', () {
      final exercise = repo.getExerciseById('ex_lat_pulldown');
      expect(exercise, isNotNull);
      expect(exercise!.name, equals('Wide Grip Lat Pulldown'));

      final gif = exercise.gifDemonstrationUrl;
      expect(gif, isNotEmpty);
      expect(gif, equals('https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/2330-LEprlgG.gif'));
      expect(gif.endsWith('.gif'), isTrue);
      expect(gif, isNot(contains('unsplash')));
    });

    test('Exercise 5: Dumbbell Lateral Raise (ex_db_lateral_raise) displays correct continuous animated GIF', () {
      final exercise = repo.getExerciseById('ex_db_lateral_raise');
      expect(exercise, isNotNull);
      expect(exercise!.name, equals('Dumbbell Lateral Raise'));

      final gif = exercise.gifDemonstrationUrl;
      expect(gif, isNotEmpty);
      expect(gif, equals('https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0334-DsgkuIt.gif'));
      expect(gif.endsWith('.gif'), isTrue);
      expect(gif, isNot(contains('unsplash')));
    });

    test('Confirm all 5 distinct exercises have unique GIFs (no identical or generic demo GIF)', () {
      final ids = [
        'ex_db_rdl',
        'ex_incline_smith',
        'ex_romanian_deadlift',
        'ex_lat_pulldown',
        'ex_db_lateral_raise',
      ];

      final gifUrls = ids.map((id) => repo.getExerciseById(id)!.gifDemonstrationUrl).toSet();
      expect(gifUrls.length, equals(5), reason: 'Each of the 5 exercises must have its own unique GIF demonstration');
      for (final url in gifUrls) {
        expect(url.endsWith('.gif'), isTrue);
        expect(url, isNot(contains('unsplash')));
      }
    });

    testWidgets('Widget rendering verification: Dumbbell Romanian Deadlift renders GIF with ANIMATED FORM badge', (tester) async {
      final exercise = repo.getExerciseById('ex_db_rdl')!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExerciseMedia(
              exerciseId: exercise.id,
              exerciseName: exercise.name,
              gifUrl: exercise.gifDemonstrationUrl,
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('ANIMATED FORM'), findsOneWidget);
      expect(find.byIcon(Icons.loop), findsOneWidget);
      expect(find.text('DEMO'), findsNothing);
      expect(find.text('Demonstration unavailable'), findsNothing);
    });

    testWidgets('Widget rendering verification: Incline Smith Machine Press renders GIF with ANIMATED FORM badge', (tester) async {
      final exercise = repo.getExerciseById('ex_incline_smith')!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExerciseMedia(
              exerciseId: exercise.id,
              exerciseName: exercise.name,
              gifUrl: exercise.gifDemonstrationUrl,
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('ANIMATED FORM'), findsOneWidget);
      expect(find.byIcon(Icons.loop), findsOneWidget);
      expect(find.text('Demonstration unavailable'), findsNothing);
    });

    testWidgets('Widget fallback rule: Unknown exercise without GIF renders "Demonstration unavailable" and NEVER hero image', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExerciseMedia(
              exerciseId: 'non_existent_exercise_id_9999',
              exerciseName: 'Non Existent Exercise',
              imageUrl: 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=600',
            ),
          ),
        ),
      );

      expect(find.text('Demonstration unavailable'), findsOneWidget);
      expect(find.text('Refer to the detailed form instructions below'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(find.text('ANIMATED FORM'), findsNothing);
    });
  });
}
