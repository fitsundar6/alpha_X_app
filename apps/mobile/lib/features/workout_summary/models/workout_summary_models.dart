import 'package:flutter/material.dart';

/// Complete workout summary model containing all performance metrics,
/// exercise details, athlete metadata, and timestamps.
class WorkoutSummary {
  String planName;
  int week;
  int day;
  DateTime date;
  int workoutNumber;
  Duration duration;
  double totalVolume;
  List<ExerciseLog> exercises;
  String username;
  int? streakDays;
  int? prsCount;

  WorkoutSummary({
    required this.planName,
    required this.week,
    required this.day,
    required this.date,
    required this.workoutNumber,
    required this.duration,
    required this.totalVolume,
    required this.exercises,
    required this.username,
    this.streakDays,
    this.prsCount,
  });

  /// Factory producing the default mock dataset specified in the specification:
  /// Quadriceps 1 set, Glutes 1 set, Hamstrings 1 set so the UI visually matches
  /// the reference anatomy diagram identically.
  factory WorkoutSummary.mock() {
    return WorkoutSummary(
      planName: 'Ani workout plan',
      week: 1,
      day: 3,
      date: DateTime(2026, 10, 9),
      workoutNumber: 81,
      duration: const Duration(minutes: 58, seconds: 24),
      totalVolume: 8450.0,
      username: '@username',
      streakDays: 14,
      prsCount: 3,
      exercises: [
        ExerciseLog(
          name: 'Barbell Back Squat',
          primaryMuscles: ['quadriceps', 'glutes'],
          secondaryMuscles: ['hamstrings', 'lower_back', 'calves'],
          sets: 1,
          reps: 8,
          weight: 120.0,
        ),
        ExerciseLog(
          name: 'Romanian Deadlift',
          primaryMuscles: ['hamstrings', 'glutes'],
          secondaryMuscles: ['lower_back', 'forearms'],
          sets: 1,
          reps: 10,
          weight: 100.0,
        ),
        ExerciseLog(
          name: 'Leg Press',
          primaryMuscles: ['quadriceps'],
          secondaryMuscles: ['glutes'],
          sets: 1,
          reps: 12,
          weight: 180.0,
        ),
      ],
    );
  }
}

/// Individual exercise execution log within a workout session.
class ExerciseLog {
  String name;
  List<String> primaryMuscles;
  List<String> secondaryMuscles;
  int sets;
  int reps;
  double weight;

  ExerciseLog({
    required this.name,
    required this.primaryMuscles,
    required this.secondaryMuscles,
    required this.sets,
    required this.reps,
    required this.weight,
  });
}

/// Computed muscle activation record with aggregate sets and visual color intensity.
class MuscleActivation {
  String muscleId;
  String displayName;
  int sets;
  Color color;

  MuscleActivation({
    required this.muscleId,
    required this.displayName,
    required this.sets,
    required this.color,
  });
}
