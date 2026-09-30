import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';

void main() {
  group('Workout Execution Engine Tests', () {
    late WorkoutRepository repository;

    setUp(() {
      repository = WorkoutRepository();
    });

    test('Initializes active workout session with exercises and sets', () {
      final session = repository.activeSession;
      expect(session.id, isNotEmpty);
      expect(session.exercises, isNotEmpty);
      expect(session.isCompleted, isFalse);

      final firstExercise = session.exercises.first;
      expect(firstExercise.sets, isNotEmpty);
      expect(firstExercise.sets.first.setType, SetType.working);
      expect(firstExercise.sets.first.targetWeight, greaterThan(0));
      expect(firstExercise.sets.first.targetRepsMin, greaterThan(0));
    });

    test('Completes set and detects Personal Records', () {
      // Set 1 initial weight: 70kg, update to 75kg (exceeds existing 70kg PR)
      repository.updateSetActual(
        exerciseIndex: 0,
        setIndex: 0,
        weight: 75.0,
        reps: 10,
        rpe: 9.0,
        rir: 1,
      );

      final pr = repository.completeSet(
        exerciseIndex: 0,
        setIndex: 0,
      );

      expect(pr, isNotNull);
      expect(pr!.type, PRType.weight);
      expect(pr.value, 75.0);

      final updatedExercise = repository.activeSession.exercises.first;
      expect(updatedExercise.sets.first.isCompleted, isTrue);
      expect(updatedExercise.sets.first.actualWeight, 75.0);
    });

    test('Plate calculator computes barbell plate configuration correctly', () {
      // 100 kg total with 20 kg bar = 40 kg per side (20kg + 20kg or 25kg + 15kg)
      final calc = repository.calculatePlates(targetWeightKg: 100.0, barWeightKg: 20.0);
      expect(calc.targetWeightKg, 100.0);
      expect(calc.barWeightKg, 20.0);
      expect(calc.weightPerSide, 40.0);
      expect(calc.isExact, isTrue);
      expect(calc.remainderKg, 0.0);

      // Verify plates add up to 40 kg per side
      double sideTotal = 0;
      calc.platesPerSide.forEach((plate, count) {
        sideTotal += plate * count;
      });
      expect(sideTotal, 40.0);
    });

    test('Add and delete workout sets', () {
      final initialCount = repository.activeSession.exercises.first.sets.length;
      repository.addSet(0, setType: SetType.failure);

      expect(repository.activeSession.exercises.first.sets.length, initialCount + 1);
      expect(repository.activeSession.exercises.first.sets.last.setType, SetType.failure);

      // Deleting uncompleted set succeeds
      final deleted = repository.deleteSet(0, initialCount);
      expect(deleted, isTrue);
      expect(repository.activeSession.exercises.first.sets.length, initialCount);
    });

    test('Swap exercise with approved alternative', () {
      final currentEx = repository.activeSession.exercises.first;
      expect(currentEx.approvedAlternativeIds, contains('ex_incline_db'));

      final swapped = repository.swapExercise(0, 'ex_incline_db');
      expect(swapped, isTrue);

      final newEx = repository.activeSession.exercises.first;
      expect(newEx.exerciseId, 'ex_incline_db');
      expect(newEx.exerciseName, 'Incline Dumbbell Press');
      // Previous exercise ID is preserved in alternatives for swapping back
      expect(newEx.approvedAlternativeIds, contains('ex_incline_smith'));
    });

    test('Completes entire workout session', () {
      expect(repository.activeSession.isCompleted, isFalse);
      repository.completeWorkout();
      expect(repository.activeSession.isCompleted, isTrue);
      expect(repository.activeSession.completedAt, isNotNull);
    });
  });
}
