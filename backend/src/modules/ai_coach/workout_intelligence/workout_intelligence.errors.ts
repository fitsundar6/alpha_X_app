/**
 * Alpha X AI — Workout Intelligence Errors
 * Phase 9 — Workout Intelligence Engine
 */

export class WorkoutIntelligenceError extends Error {
  public readonly code: string;
  public readonly analysis: string;

  constructor(analysis: string, message: string, code: string = 'WORKOUT_INTELLIGENCE_ERROR') {
    super(`[Workout Intelligence: ${analysis}] ${message}`);
    this.name = 'WorkoutIntelligenceError';
    this.code = code;
    this.analysis = analysis;
  }
}

export class InsufficientWorkoutDataError extends WorkoutIntelligenceError {
  constructor(analysis: string, message: string) {
    super(analysis, message, 'INSUFFICIENT_WORKOUT_DATA');
    this.name = 'InsufficientWorkoutDataError';
  }
}

export class ExerciseNotFoundError extends WorkoutIntelligenceError {
  constructor(exerciseName: string) {
    super('EXERCISE_ANALYSIS', `Exercise '${exerciseName}' not found in client workout history`, 'EXERCISE_NOT_FOUND');
    this.name = 'ExerciseNotFoundError';
  }
}
