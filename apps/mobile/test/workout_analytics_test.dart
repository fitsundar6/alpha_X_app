import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_x_gym/features/analytics/domain/models/workout_analytics_models.dart';
import 'package:alpha_x_gym/features/analytics/domain/services/workout_analytics_calculator.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';

void main() {
  group('Brzycki 1RM Formula & Safety Boundary Tests', () {
    test('1. Valid Brzycki 1RM calculation: 1 rep returns exact weight', () {
      final rm = WorkoutAnalyticsCalculator.calculateBrzycki1RM(100.0, 1);
      expect(rm, equals(100.0));
    });

    test('2. Valid Brzycki 1RM calculation: 5 reps at 100 kg = 112.5 kg', () {
      // 100 * 36 / (37 - 5) = 3600 / 32 = 112.5
      final rm = WorkoutAnalyticsCalculator.calculateBrzycki1RM(100.0, 5);
      expect(rm, equals(112.5));
    });

    test('3. Valid Brzycki 1RM calculation: 10 reps at 80 kg = 106.7 kg', () {
      // 80 * 36 / (37 - 10) = 2880 / 27 = 106.666... -> 106.7
      final rm = WorkoutAnalyticsCalculator.calculateBrzycki1RM(80.0, 10);
      expect(rm, equals(106.7));
    });

    test('4. Boundary & safety: 0 reps or negative reps rejected with null', () {
      expect(WorkoutAnalyticsCalculator.calculateBrzycki1RM(100.0, 0), isNull);
      expect(WorkoutAnalyticsCalculator.calculateBrzycki1RM(100.0, -5), isNull);
    });

    test('5. Boundary & safety: 0 weight or negative weight rejected with null', () {
      expect(WorkoutAnalyticsCalculator.calculateBrzycki1RM(0.0, 5), isNull);
      expect(WorkoutAnalyticsCalculator.calculateBrzycki1RM(-50.0, 5), isNull);
    });

    test('6. Division by zero protection: reps == 37 rejected with null', () {
      // Denominator (37 - 37) = 0 -> must NOT crash or return Infinity
      final rm = WorkoutAnalyticsCalculator.calculateBrzycki1RM(100.0, 37);
      expect(rm, isNull);
    });

    test('7. Negative denominator protection: reps > 37 rejected with null', () {
      // Denominator (37 - 40) = -3 -> must NOT return negative 1RM
      final rm = WorkoutAnalyticsCalculator.calculateBrzycki1RM(100.0, 40);
      expect(rm, isNull);
    });

    test('8. Extreme input overflow protection: 1,000,000,000 safely rejected', () {
      // Guard against freeze bug that occurred in Step Count feature
      expect(WorkoutAnalyticsCalculator.calculateBrzycki1RM(1000000000.0, 5), isNull);
      expect(WorkoutAnalyticsCalculator.calculateBrzycki1RM(100.0, 1000000000), isNull);
      expect(WorkoutAnalyticsCalculator.calculateBrzycki1RM(double.nan, 5), isNull);
      expect(WorkoutAnalyticsCalculator.calculateBrzycki1RM(double.infinity, 5), isNull);
    });
  });

  group('Volume Calculation & Completion Integrity Tests', () {
    test('9. Unfinished sets strictly contribute 0 volume', () {
      const incompleteSet = ExerciseSet(
        id: 's1',
        setNumber: 1,
        targetWeight: 80,
        targetRepsMin: 8,
        targetRepsMax: 10,
        actualWeight: 80,
        actualReps: 10,
        isCompleted: false, // NOT completed
      );
      expect(WorkoutAnalyticsCalculator.calculateSetVolume(incompleteSet), equals(0.0));
    });

    test('10. Completed sets compute accurate volume: weight * reps', () {
      const completeSet = ExerciseSet(
        id: 's2',
        setNumber: 2,
        targetWeight: 80,
        targetRepsMin: 8,
        targetRepsMax: 10,
        actualWeight: 80,
        actualReps: 10,
        isCompleted: true,
      );
      expect(WorkoutAnalyticsCalculator.calculateSetVolume(completeSet), equals(800.0));
    });

    test('11. Skipped exercises contribute 0 volume', () {
      const skippedEx = WorkoutExercise(
        id: 'we1',
        exerciseId: 'ex1',
        exerciseName: 'Bench Press',
        category: 'Chest',
        primaryMusclesDisplay: 'Chest',
        secondaryMusclesDisplay: 'Triceps',
        trainerNote: '',
        isSkipped: true,
        sets: [
          ExerciseSet(
            id: 's1',
            setNumber: 1,
            targetWeight: 100,
            targetRepsMin: 5,
            targetRepsMax: 5,
            actualWeight: 100,
            actualReps: 5,
            isCompleted: true,
          ),
        ],
      );
      expect(WorkoutAnalyticsCalculator.calculateExercisesVolume([skippedEx]), equals(0.0));
    });
  });

  group('A. Weekly Overview Analytics Tests', () {
    final now = DateTime(2026, 10, 15, 12, 0);

    final mockRecords = [
      // Current Week: Session 1 (2 days ago)
      WorkoutRecord(
        id: 'rec_curr_1',
        clientId: 'client_1',
        sessionTitle: 'Chest & Triceps Power',
        workoutType: 'Strength',
        targetMuscleGroup: 'Chest',
        startedAt: now.subtract(const Duration(days: 2, hours: 1)),
        completedAt: now.subtract(const Duration(days: 2)),
        isCompleted: true,
        personalRecords: [
          PersonalRecord(
            id: 'pr_1',
            exerciseId: 'ex_incline_smith',
            exerciseName: 'Incline Smith Press',
            type: PRType.weight,
            value: 90.0,
            weight: 90.0,
            reps: 6,
            achievedAt: now.subtract(const Duration(days: 2)),
          ),
        ],
        exercises: [
          WorkoutExercise(
            id: 'we_1',
            exerciseId: 'ex_incline_smith',
            exerciseName: 'Incline Smith Press',
            category: 'Chest',
            primaryMusclesDisplay: 'Chest',
            secondaryMusclesDisplay: 'Triceps',
            trainerNote: '',
            sets: [
              ExerciseSet(
                id: 's1',
                setNumber: 1,
                targetWeight: 90,
                targetRepsMin: 6,
                targetRepsMax: 8,
                actualWeight: 90,
                actualReps: 6,
                isCompleted: true,
              ), // 540 kg
              ExerciseSet(
                id: 's2',
                setNumber: 2,
                targetWeight: 90,
                targetRepsMin: 6,
                targetRepsMax: 8,
                actualWeight: 90,
                actualReps: 6,
                isCompleted: true,
              ), // 540 kg
            ],
          ),
        ],
      ),
      // Current Week: Session 2 (4 days ago)
      WorkoutRecord(
        id: 'rec_curr_2',
        clientId: 'client_1',
        sessionTitle: 'Back & Biceps Volume',
        workoutType: 'Hypertrophy',
        targetMuscleGroup: 'Back',
        startedAt: now.subtract(const Duration(days: 4, hours: 1)),
        completedAt: now.subtract(const Duration(days: 4)),
        isCompleted: true,
        exercises: [
          WorkoutExercise(
            id: 'we_2',
            exerciseId: 'ex_lat_pulldown',
            exerciseName: 'Lat Pulldown',
            category: 'Back',
            primaryMusclesDisplay: 'Back',
            secondaryMusclesDisplay: 'Biceps',
            trainerNote: '',
            sets: [
              ExerciseSet(
                id: 's3',
                setNumber: 1,
                targetWeight: 70,
                targetRepsMin: 10,
                targetRepsMax: 12,
                actualWeight: 70,
                actualReps: 10,
                isCompleted: true,
              ), // 700 kg
            ],
          ),
        ],
      ),
      // Previous Week: Session 3 (9 days ago)
      WorkoutRecord(
        id: 'rec_prev_1',
        clientId: 'client_1',
        sessionTitle: 'Leg Day',
        workoutType: 'Strength',
        targetMuscleGroup: 'Legs',
        startedAt: now.subtract(const Duration(days: 9, hours: 1)),
        completedAt: now.subtract(const Duration(days: 9)),
        isCompleted: true,
        exercises: [
          WorkoutExercise(
            id: 'we_3',
            exerciseId: 'ex_squat',
            exerciseName: 'Barbell Squat',
            category: 'Legs',
            primaryMusclesDisplay: 'Legs',
            secondaryMusclesDisplay: 'Glutes',
            trainerNote: '',
            sets: [
              ExerciseSet(
                id: 's4',
                setNumber: 1,
                targetWeight: 100,
                targetRepsMin: 5,
                targetRepsMax: 5,
                actualWeight: 100,
                actualReps: 5,
                isCompleted: true,
              ), // 500 kg
            ],
          ),
        ],
      ),
    ];

    test('12. Weekly Overview: accurate sessions, volume, PRs and week-over-week diffs', () {
      final overview = WorkoutAnalyticsCalculator.calculateWeeklyOverview(
        mockRecords,
        now: now,
        targetDays: 4,
      );

      // Current week: 2 sessions (rec_curr_1: 1080 kg, rec_curr_2: 700 kg) = 1780 kg
      expect(overview.completedSessions, equals(2));
      expect(overview.totalVolumeKg, equals(1780.0));
      expect(overview.prsAchieved, equals(1));
      expect(overview.daysTrained, equals(2));
      expect(overview.consistencyRate, equals(0.5)); // 2 of 4 days = 50%

      // Prev week: 1 session = 500 kg, 0 PRs
      expect(overview.prevWeekSessions, equals(1));
      expect(overview.prevWeekVolumeKg, equals(500.0));
      expect(overview.prevWeekPRs, equals(0));

      // Comparison diffs
      expect(overview.sessionsDiff, equals(1)); // +1 session
      expect(overview.prsDiff, equals(1)); // +1 PR
      // Volume change: ((1780 - 500) / 500) * 100 = 256.0%
      expect(overview.volumeChangePercent, equals(256.0));
      expect(overview.formattedVolume, equals('1.8k kg'));
    });
  });

  group('B. Weekly Report Analytics Tests', () {
    final now = DateTime(2026, 10, 15, 12, 0);

    test('13. Weekly Report: completed vs planned, reps, sets, narrative', () {
      final record = WorkoutRecord(
        id: 'r1',
        clientId: 'c1',
        sessionTitle: 'Upper Body Blast',
        workoutType: 'Strength',
        targetMuscleGroup: 'Chest',
        startedAt: now.subtract(const Duration(days: 1)),
        completedAt: now.subtract(const Duration(days: 1)),
        isCompleted: true,
        personalRecords: [
          PersonalRecord(
            id: 'pr_1',
            exerciseId: 'ex_db_press',
            exerciseName: 'Dumbbell Press',
            type: PRType.weight,
            value: 40.0,
            weight: 40.0,
            reps: 8,
            achievedAt: now.subtract(const Duration(days: 1)),
          ),
        ],
        exercises: [
          WorkoutExercise(
            id: 'we1',
            exerciseId: 'ex_db_press',
            exerciseName: 'Dumbbell Press',
            category: 'Chest',
            primaryMusclesDisplay: 'Chest',
            secondaryMusclesDisplay: 'Triceps',
            trainerNote: '',
            sets: [
              ExerciseSet(
                id: 's1',
                setNumber: 1,
                targetWeight: 40,
                targetRepsMin: 8,
                targetRepsMax: 8,
                actualWeight: 40,
                actualReps: 8,
                isCompleted: true,
              ),
              ExerciseSet(
                id: 's2',
                setNumber: 2,
                targetWeight: 40,
                targetRepsMin: 8,
                targetRepsMax: 8,
                actualWeight: 40,
                actualReps: 8,
                isCompleted: true,
              ),
            ],
          ),
        ],
      );

      final report = WorkoutAnalyticsCalculator.calculateWeeklyReport(
        [record],
        now: now,
        plannedWorkouts: 4,
      );

      expect(report.completedWorkouts, equals(1));
      expect(report.plannedWorkouts, equals(4));
      expect(report.completionPercentage, equals(25.0));
      expect(report.totalCompletedSets, equals(2));
      expect(report.totalReps, equals(16));
      expect(report.totalVolumeKg, equals(640.0));
      expect(report.prsAchieved, equals(1));
      expect(report.muscleGroupsTrained, contains('Chest'));
      expect(report.summaryNarrative, contains('Outstanding work!'));
      expect(report.summaryNarrative, contains('1 of 4 planned sessions'));
    });

    test('14. Weekly Report: empty history generates supportive encouragement', () {
      final report = WorkoutAnalyticsCalculator.calculateWeeklyReport(
        [],
        now: now,
        plannedWorkouts: 4,
      );

      expect(report.completedWorkouts, equals(0));
      expect(report.totalVolumeKg, equals(0.0));
      expect(report.summaryNarrative, contains('No completed workout sessions recorded'));
    });
  });

  group('C. Muscle Tracker Period & Distribution Tests', () {
    final now = DateTime(2026, 10, 15, 12, 0);

    final testRecords = [
      // 5 days ago: Chest (800 kg) & Shoulders (300 kg)
      WorkoutRecord(
        id: 'r_7d',
        clientId: 'c1',
        sessionTitle: 'Push Day',
        workoutType: 'Strength',
        targetMuscleGroup: 'Chest',
        startedAt: now.subtract(const Duration(days: 5)),
        completedAt: now.subtract(const Duration(days: 5)),
        isCompleted: true,
        exercises: [
          WorkoutExercise(
            id: 'we_chest',
            exerciseId: 'ex_bench',
            exerciseName: 'Bench Press',
            category: 'Chest',
            primaryMusclesDisplay: 'Chest',
            secondaryMusclesDisplay: 'Triceps',
            trainerNote: '',
            sets: [
              ExerciseSet(
                id: 's1',
                setNumber: 1,
                targetWeight: 80,
                targetRepsMin: 10,
                targetRepsMax: 10,
                actualWeight: 80,
                actualReps: 10,
                isCompleted: true,
              ),
            ],
          ),
          WorkoutExercise(
            id: 'we_shoulders',
            exerciseId: 'ex_ohp',
            exerciseName: 'Overhead Press',
            category: 'Shoulders',
            primaryMusclesDisplay: 'Shoulders',
            secondaryMusclesDisplay: 'Triceps',
            trainerNote: '',
            sets: [
              ExerciseSet(
                id: 's2',
                setNumber: 1,
                targetWeight: 50,
                targetRepsMin: 6,
                targetRepsMax: 6,
                actualWeight: 50,
                actualReps: 6,
                isCompleted: true,
              ),
            ],
          ),
        ],
      ),
      // 20 days ago: Back (1200 kg) (in 30D and 90D, but NOT in 7D)
      WorkoutRecord(
        id: 'r_30d',
        clientId: 'c1',
        sessionTitle: 'Pull Day',
        workoutType: 'Strength',
        targetMuscleGroup: 'Back',
        startedAt: now.subtract(const Duration(days: 20)),
        completedAt: now.subtract(const Duration(days: 20)),
        isCompleted: true,
        exercises: [
          WorkoutExercise(
            id: 'we_back',
            exerciseId: 'ex_deadlift',
            exerciseName: 'Deadlift',
            category: 'Back',
            primaryMusclesDisplay: 'Back',
            secondaryMusclesDisplay: 'Hamstrings',
            trainerNote: '',
            sets: [
              ExerciseSet(
                id: 's3',
                setNumber: 1,
                targetWeight: 120,
                targetRepsMin: 10,
                targetRepsMax: 10,
                actualWeight: 120,
                actualReps: 10,
                isCompleted: true,
              ),
            ],
          ),
        ],
      ),
    ];

    test('15. Muscle Tracker: 7D period includes only records within 7 days', () {
      final tracker7D = WorkoutAnalyticsCalculator.calculateMuscleTracker(
        testRecords,
        period: AnalyticsPeriod.sevenDays,
        now: now,
      );

      final chest = tracker7D.stats.firstWhere((s) => s.muscleGroup == 'Chest');
      final shoulders = tracker7D.stats.firstWhere((s) => s.muscleGroup == 'Shoulders');
      final back = tracker7D.stats.firstWhere((s) => s.muscleGroup == 'Back');

      expect(chest.totalSets, equals(1));
      expect(chest.totalVolumeKg, equals(800.0));
      expect(shoulders.totalSets, equals(1));
      expect(shoulders.totalVolumeKg, equals(300.0));
      // Back is 20 days old -> 0 sets in 7D
      expect(back.totalSets, equals(0));
      expect(back.totalVolumeKg, equals(0.0));
      expect(tracker7D.totalSets, equals(2));
      expect(tracker7D.totalVolumeKg, equals(1100.0));
    });

    test('16. Muscle Tracker: 30D period includes older 20-day records', () {
      final tracker30D = WorkoutAnalyticsCalculator.calculateMuscleTracker(
        testRecords,
        period: AnalyticsPeriod.thirtyDays,
        now: now,
      );

      final back = tracker30D.stats.firstWhere((s) => s.muscleGroup == 'Back');
      expect(back.totalSets, equals(1));
      expect(back.totalVolumeKg, equals(1200.0));
      expect(tracker30D.totalSets, equals(3));
      expect(tracker30D.totalVolumeKg, equals(2300.0));
    });
  });

  group('D. Exercise Analytics & 1RM Progression Tests', () {
    final now = DateTime(2026, 10, 15, 12, 0);

    final exerciseRecords = [
      // Day 1 (10 days ago): 80 kg x 5 reps -> 1RM = 80 * 36 / 32 = 90.0 kg
      WorkoutRecord(
        id: 'ex_rec_1',
        clientId: 'c1',
        sessionTitle: 'Chest Day A',
        workoutType: 'Strength',
        targetMuscleGroup: 'Chest',
        startedAt: now.subtract(const Duration(days: 10)),
        completedAt: now.subtract(const Duration(days: 10)),
        isCompleted: true,
        exercises: [
          WorkoutExercise(
            id: 'we_bench_1',
            exerciseId: 'ex_bench',
            exerciseName: 'Bench Press',
            category: 'Chest',
            primaryMusclesDisplay: 'Chest',
            secondaryMusclesDisplay: 'Triceps',
            trainerNote: '',
            sets: [
              ExerciseSet(
                id: 's1',
                setNumber: 1,
                targetWeight: 80,
                targetRepsMin: 5,
                targetRepsMax: 5,
                actualWeight: 80,
                actualReps: 5,
                isCompleted: true,
              ),
            ],
          ),
        ],
      ),
      // Day 2 (3 days ago): 90 kg x 5 reps -> 1RM = 90 * 36 / 32 = 101.3 kg
      WorkoutRecord(
        id: 'ex_rec_2',
        clientId: 'c1',
        sessionTitle: 'Chest Day B',
        workoutType: 'Strength',
        targetMuscleGroup: 'Chest',
        startedAt: now.subtract(const Duration(days: 3)),
        completedAt: now.subtract(const Duration(days: 3)),
        isCompleted: true,
        exercises: [
          WorkoutExercise(
            id: 'we_bench_2',
            exerciseId: 'ex_bench',
            exerciseName: 'Bench Press',
            category: 'Chest',
            primaryMusclesDisplay: 'Chest',
            secondaryMusclesDisplay: 'Triceps',
            trainerNote: '',
            sets: [
              ExerciseSet(
                id: 's2',
                setNumber: 1,
                targetWeight: 90,
                targetRepsMin: 5,
                targetRepsMax: 5,
                actualWeight: 90,
                actualReps: 5,
                isCompleted: true,
              ),
            ],
          ),
        ],
      ),
    ];

    test('17. Exercise Analytics: computes best weight, peak 1RM, trend points, progress %', () {
      final analytics = WorkoutAnalyticsCalculator.calculateExerciseAnalytics(
        exerciseRecords,
        exerciseId: 'ex_bench',
        exerciseName: 'Bench Press',
        period: AnalyticsPeriod.thirtyDays,
        now: now,
      );

      expect(analytics.hasData, isTrue);
      expect(analytics.bestRecordedWeight, equals(90.0));
      expect(analytics.bestWeightReps, equals(5));
      expect(analytics.peakEstimated1RM, equals(101.3));
      expect(analytics.trendPoints.length, equals(2));
      expect(analytics.trendPoints[0].estimated1RM, equals(90.0));
      expect(analytics.trendPoints[1].estimated1RM, equals(101.3));

      // Progress: ((101.25 - 90.0) / 90.0) * 100 = 12.5% or 12.6%
      expect(analytics.progressPercent, isNotNull);
      expect(analytics.progressPercent!, closeTo(12.5, 0.2));
      expect(analytics.formattedBestWeight, equals('90 kg × 5'));
      expect(analytics.formattedPeak1RM, equals('101.3 kg'));
    });

    test('18. Exercise Analytics: empty state when exercise has no recorded sets', () {
      final emptyAnalytics = WorkoutAnalyticsCalculator.calculateExerciseAnalytics(
        exerciseRecords,
        exerciseId: 'ex_squat', // Not in records
        exerciseName: 'Barbell Squat',
        period: AnalyticsPeriod.thirtyDays,
        now: now,
      );

      expect(emptyAnalytics.hasData, isFalse);
      expect(emptyAnalytics.bestRecordedWeight, equals(0.0));
      expect(emptyAnalytics.peakEstimated1RM, equals(0.0));
      expect(emptyAnalytics.trendPoints, isEmpty);
      expect(emptyAnalytics.formattedBestWeight, equals('—'));
      expect(emptyAnalytics.formattedPeak1RM, equals('—'));
    });

    test('19. extractRecordedExercises extracts all exercises client logged sets for', () {
      final recordedList = WorkoutAnalyticsCalculator.extractRecordedExercises(exerciseRecords);
      expect(recordedList.length, equals(1));
      expect(recordedList.first['id'], equals('ex_bench'));
      expect(recordedList.first['name'], equals('Bench Press'));
    });
  });
}
