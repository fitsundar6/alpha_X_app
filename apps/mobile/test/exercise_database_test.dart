import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_x_gym/features/exercise/domain/models/exercise_model.dart';
import 'package:alpha_x_gym/features/exercise/data/repositories/exercise_repository.dart';
import 'package:alpha_x_gym/features/exercise/data/default_exercise_catalog.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Exercise Database & CRUD Tests', () {
    late ExerciseRepository exerciseRepo;
    late WorkoutRepository workoutRepo;

    setUp(() {
      exerciseRepo = ExerciseRepository();
      workoutRepo = WorkoutRepository();
    });

    test('Exercise repository loads library with 100+ unique exercises and comprehensive categories', () {
      expect(exerciseRepo.allExercises.length, greaterThanOrEqualTo(100));
      expect(exerciseRepo.allExercises.length, equals(defaultAlphaXExercises.length));
      expect(exerciseRepo.activeExercises.isNotEmpty, isTrue);

      // Verify no duplicate IDs
      final ids = exerciseRepo.allExercises.map((e) => e.id).toList();
      final uniqueIds = ids.toSet();
      expect(uniqueIds.length, equals(ids.length), reason: 'All exercise IDs must be unique');

      // Verify no duplicate names
      final names = exerciseRepo.allExercises.map((e) => e.name.toLowerCase().trim()).toList();
      final uniqueNames = names.toSet();
      expect(uniqueNames.length, equals(names.length), reason: 'All exercise names must be unique');

      // Verify categories covered
      final categories = exerciseRepo.allExercises.map((e) => e.category).toSet();
      expect(categories, containsAll(['Chest', 'Back', 'Shoulders', 'Biceps', 'Triceps', 'Quadriceps', 'Hamstrings', 'Glutes', 'Core', 'Full Body']));

      // Verify standard equipment list includes barbell, dumbbell, cable, machine
      final equipment = exerciseRepo.availableEquipment;
      expect(equipment, containsAll(['Barbell', 'Dumbbell', 'Cable', 'Machine', 'Smith Machine', 'Bodyweight']));
    });

    test('Admin creates new custom exercise with coaching cues and biomechanics', () {
      final initialCount = exerciseRepo.allExercises.length;

      final newEx = Exercise(
        id: 'ex_test_custom_press',
        name: 'Alpha X Landmine Chest Press',
        displayName: 'Alpha X Landmine Chest Press',
        description: 'Unilateral angled pressing movement targeting upper clavicular pectoral fibres with minimal anterior shoulder impingement.',
        category: 'Chest',
        primaryMuscles: [MuscleGroup.upperChest],
        secondaryMuscles: [MuscleGroup.frontDelts, MuscleGroup.triceps],
        equipment: 'Barbell',
        movementPattern: 'Angled Push',
        difficulty: 'Intermediate',
        executionSteps: ['Anchor barbell into landmine pivot.', 'Press diagonally upward and inward.'],
        coachingCues: ['Squeeze pecs at lockout.', 'Keep scapula depressed.'],
        commonMistakes: ['Flaring elbow excessively.', 'Leaning backward.'],
        videoUrl: 'https://alphaxgym.com/exercises/landmine-press',
        approvedAlternativeIds: ['ex_incline_smith'],
      );

      exerciseRepo.addExercise(newEx);

      expect(exerciseRepo.allExercises.length, initialCount + 1);
      final retrieved = exerciseRepo.getExerciseById('ex_test_custom_press');
      expect(retrieved, isNotNull);
      expect(retrieved!.name, 'Alpha X Landmine Chest Press');
      expect(retrieved.primaryMuscles.first, MuscleGroup.upperChest);
      expect(retrieved.approvedAlternativeIds, contains('ex_incline_smith'));
      expect(retrieved.coachingCues.length, 2);
    });

    test('Admin adds custom equipment dynamically', () {
      final initialEquipmentCount = exerciseRepo.availableEquipment.length;

      exerciseRepo.addCustomEquipment('BFR Cuffs');
      expect(exerciseRepo.availableEquipment, contains('BFR Cuffs'));
      expect(exerciseRepo.availableEquipment.length, initialEquipmentCount + 1);

      // Prevent duplicate equipment additions
      exerciseRepo.addCustomEquipment('BFR Cuffs');
      expect(exerciseRepo.availableEquipment.length, initialEquipmentCount + 1);
    });

    test('Exercise search matches by name, category, muscle, equipment, and movement pattern', () {
      final chestResults = exerciseRepo.searchExercises(query: 'chest');
      expect(chestResults.isNotEmpty, isTrue);
      expect(chestResults.any((e) => e.category.toLowerCase() == 'chest'), isTrue);

      final smithResults = exerciseRepo.searchExercises(equipment: 'Smith Machine');
      expect(smithResults.isNotEmpty, isTrue);
      expect(smithResults.every((e) => e.equipment == 'Smith Machine'), isTrue);

      final quadResults = exerciseRepo.searchExercises(muscle: 'Quadriceps');
      expect(quadResults.isNotEmpty, isTrue);
      expect(quadResults.any((e) => e.primaryMuscles.any((m) => m.displayName.toLowerCase().contains('quad'))), isTrue);
    });

    test('Exercise search handles partial keywords: bench, lat, shoulder, curl, squat, cable', () {
      // "bench" should return bench press exercises
      final benchResults = exerciseRepo.searchExercises(query: 'bench');
      expect(benchResults.length, greaterThanOrEqualTo(5));
      expect(benchResults.any((e) => e.name.contains('Bench Press')), isTrue);

      // "lat" should return lat pulldowns and lateral raises
      final latResults = exerciseRepo.searchExercises(query: 'lat');
      expect(latResults.length, greaterThanOrEqualTo(4));
      expect(latResults.any((e) => e.name.contains('Lat Pulldown')), isTrue);
      expect(latResults.any((e) => e.name.contains('Lateral Raise')), isTrue);

      // "shoulder" should return shoulder/overhead presses and lateral raises
      final shoulderResults = exerciseRepo.searchExercises(query: 'shoulder');
      expect(shoulderResults.length, greaterThanOrEqualTo(3));

      // "curl" should return biceps curls and leg curls
      final curlResults = exerciseRepo.searchExercises(query: 'curl');
      expect(curlResults.length, greaterThanOrEqualTo(8));
      expect(curlResults.any((e) => e.name.contains('Barbell Curl')), isTrue);
      expect(curlResults.any((e) => e.name.contains('Leg Curl')), isTrue);

      // "squat" should return squat variations
      final squatResults = exerciseRepo.searchExercises(query: 'squat');
      expect(squatResults.length, greaterThanOrEqualTo(5));
      expect(squatResults.any((e) => e.name.contains('Barbell Back Squat')), isTrue);

      // "cable" should return cable exercises across body parts
      final cableResults = exerciseRepo.searchExercises(query: 'cable');
      expect(cableResults.length, greaterThanOrEqualTo(10));
      expect(cableResults.any((e) => e.equipment == 'Cable'), isTrue);
    });

    test('Category filtering groups related categories like Legs and Arms cleanly', () {
      final legResults = exerciseRepo.searchExercises(category: 'Legs');
      expect(legResults.length, greaterThanOrEqualTo(15));
      expect(legResults.any((e) => e.name.contains('Squat')), isTrue);

      final armResults = exerciseRepo.searchExercises(category: 'Arms');
      expect(armResults.length, greaterThanOrEqualTo(15));
      expect(armResults.any((e) => e.category == 'Biceps' || e.category == 'Triceps'), isTrue);
    });

    test('Exercise duplication creates an exact editable copy with distinct ID', () {
      final original = exerciseRepo.allExercises.first;
      final initialCount = exerciseRepo.allExercises.length;

      exerciseRepo.duplicateExercise(original.id);

      expect(exerciseRepo.allExercises.length, initialCount + 1);
      final duplicated = exerciseRepo.allExercises.firstWhere((e) => e.name == '${original.name} (Copy)');
      expect(duplicated.id, isNot(original.id));
      expect(duplicated.name, '${original.name} (Copy)');
      expect(duplicated.category, original.category);
      expect(duplicated.equipment, original.equipment);
    });

    test('Exercise archive and restore updates active status without permanent deletion', () {
      final testExercise = exerciseRepo.allExercises.first;
      final id = testExercise.id;

      expect(testExercise.isActive, isTrue);

      exerciseRepo.archiveExercise(id);
      expect(exerciseRepo.getExerciseById(id)!.isActive, isFalse);
      expect(exerciseRepo.activeExercises.any((e) => e.id == id), isFalse);
      expect(exerciseRepo.archivedExercises.any((e) => e.id == id), isTrue);

      exerciseRepo.restoreExercise(id);
      expect(exerciseRepo.getExerciseById(id)!.isActive, isTrue);
      expect(exerciseRepo.activeExercises.any((e) => e.id == id), isTrue);
    });

    test('Historical workout usage safety check prevents deleting exercises in past logs', () {
      // Complete a workout using an exercise
      workoutRepo.startSession(workoutRepo.adminSessions.first);
      final exerciseUsed = workoutRepo.activeSession.exercises.first;
      workoutRepo.completeSet(exerciseIndex: 0, setIndex: 0);
      workoutRepo.completeWorkout(durationSeconds: 1800);

      // Verify safety check detects exercise is used in history
      final isUsed = workoutRepo.isExerciseUsedInHistory(exerciseUsed.exerciseId);
      expect(isUsed, isTrue);

      // Verify that unused exercise returns false
      final isUnused = workoutRepo.isExerciseUsedInHistory('ex_never_used_999');
      expect(isUnused, isFalse);
    });

    test('Alternatives lookup returns approved alternatives or intelligent biomechanical fallbacks', () {
      final alternatives = exerciseRepo.getAlternatives('ex_incline_smith');
      expect(alternatives.isNotEmpty, isTrue);
      expect(alternatives.every((alt) => alt.id != 'ex_incline_smith'), isTrue);
    });
  });
}
