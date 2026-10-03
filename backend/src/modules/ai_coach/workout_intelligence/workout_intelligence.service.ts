/**
 * Alpha X AI — Workout Intelligence Service
 * Phase 9 — Workout Intelligence Engine
 *
 * Coordinates database data retrieval from Prisma (WorkoutRecord, Exercise, WorkoutAssignment),
 * prepares inputs, and executes deterministic workout intelligence calculations.
 */

import { prisma } from '../../../config/prisma';
import { clientDataService } from '../tools/definitions/client/client_data.service';
import {
  WorkoutIntelligenceResult,
  WorkoutIntelligenceFilterOptions,
  WorkoutSessionAnalysis,
  WorkoutVolumeAnalysis,
  ExercisePerformanceAnalysis,
  PersonalBestRecord,
  WorkoutIntensityAnalysis,
  PeriodComparisonAnalysis,
  TrainingFrequencyAnalysis,
  RawWorkoutSessionEntry,
} from './workout_intelligence.types';
import {
  validateDateRange,
  computePresetComparisonDates,
  validateCustomComparisonIntervals,
  PeriodComparisonDateSpans,
} from './workout_intelligence.validation';
import { workoutIntelligenceCalculator } from './workout_intelligence.calculator';
import { WorkoutIntelligenceError, ExerciseNotFoundError } from './workout_intelligence.errors';

export class WorkoutIntelligenceService {
  /**
   * Fetches exercise-to-primary-muscles mapping from the authoritative Exercise table.
   */
  private async getExerciseMuscleMap(): Promise<Map<string, string[]>> {
    const exercises = await prisma.exercise.findMany({
      where: { isActive: true },
      select: {
        name: true,
        normalizedName: true,
        primaryMuscles: true,
        bodyPart: true,
      },
    });

    const map = new Map<string, string[]>();
    for (const ex of exercises) {
      const muscles = ex.primaryMuscles && ex.primaryMuscles.length > 0 ? ex.primaryMuscles : [ex.bodyPart];
      map.set(ex.name.toLowerCase().trim(), muscles);
      map.set(ex.normalizedName.toLowerCase().trim(), muscles);
    }
    return map;
  }

  /**
   * Queries raw workout records for a client within an optional validated date window.
   */
  private async fetchClientWorkouts(
    userId: string,
    startDate?: Date,
    endDate?: Date,
    limit: number = 100
  ): Promise<RawWorkoutSessionEntry[]> {
    const where: any = {
      clientId: userId,
      isCompleted: true,
    };

    if (startDate || endDate) {
      where.startedAt = {};
      if (startDate) where.startedAt.gte = startDate;
      if (endDate) where.startedAt.lte = endDate;
    }

    const records = await prisma.workoutRecord.findMany({
      where,
      select: {
        id: true,
        sessionTitle: true,
        workoutType: true,
        startedAt: true,
        completedAt: true,
        durationSeconds: true,
        totalVolume: true,
        completedSetsCount: true,
        averageRpe: true,
        averageRir: true,
        isCompleted: true,
        exerciseRecords: {
          select: {
            exerciseId: true,
            exerciseName: true,
            isSkipped: true,
            setRecords: {
              select: {
                setNumber: true,
                actualWeight: true,
                actualReps: true,
                actualRpe: true,
                actualRir: true,
                isCompleted: true,
              },
              orderBy: { setNumber: 'asc' },
            },
          },
          orderBy: { orderIndex: 'asc' },
        },
      },
      orderBy: { startedAt: 'asc' },
      take: Math.min(Math.max(limit, 1), 365),
    });

    return records.map((r) => ({
      id: r.id,
      sessionTitle: r.sessionTitle,
      workoutType: r.workoutType,
      startedAt: r.startedAt,
      completedAt: r.completedAt,
      durationSeconds: r.durationSeconds,
      totalVolume: r.totalVolume,
      completedSetsCount: r.completedSetsCount,
      averageRpe: r.averageRpe,
      averageRir: r.averageRir,
      isCompleted: r.isCompleted,
      exerciseRecords: r.exerciseRecords.map((e) => ({
        exerciseId: e.exerciseId,
        exerciseName: e.exerciseName,
        isSkipped: e.isSkipped,
        setRecords: e.setRecords.map((s) => ({
          setNumber: s.setNumber,
          actualWeight: s.actualWeight,
          actualReps: s.actualReps,
          actualRpe: s.actualRpe,
          actualRir: s.actualRir,
          isCompleted: s.isCompleted,
        })),
      })),
    }));
  }

  /**
   * Deterministically analyzes overall workout session frequency, history, and training days.
   */
  public async analyzeWorkoutProgress(
    clientIdOrName: string,
    options: WorkoutIntelligenceFilterOptions = {}
  ): Promise<WorkoutIntelligenceResult<WorkoutSessionAnalysis> | any> {
    const resolution = await clientDataService.resolveClient(clientIdOrName);
    if (resolution.status !== 'FOUND' || !resolution.client) {
      return {
        source: 'ALPHA_X_DATABASE',
        status: resolution.status === 'AMBIGUOUS' ? 'MULTIPLE_CLIENTS_FOUND' : 'CLIENT_NOT_FOUND',
        matches: resolution.matches,
        message: resolution.message,
      };
    }

    const { start, end, startDateStr, endDateStr } = validateDateRange(options.startDate, options.endDate);
    const workouts = await this.fetchClientWorkouts(resolution.client.userId, start, end, options.limit || 100);

    if (workouts.length === 0) {
      return {
        status: 'NO_RECORDS_FOUND',
        clientId: resolution.client.clientId || resolution.client.userId,
        metric: 'WORKOUT_SESSION_PROGRESS',
        value: workoutIntelligenceCalculator.analyzeSessions([], startDateStr, endDateStr),
        unit: 'sessions, days',
        recordCount: 0,
        source: 'ALPHA_X_DATABASE',
        calculationMethod: 'DETERMINISTIC_CALCULATION',
        message: 'No completed workout session records found for this client in the specified period.',
      };
    }

    const analysis = workoutIntelligenceCalculator.analyzeSessions(workouts, startDateStr, endDateStr);

    return {
      status: 'SUCCESS',
      clientId: resolution.client.clientId || resolution.client.userId,
      metric: 'WORKOUT_SESSION_PROGRESS',
      value: analysis,
      unit: 'sessions, days',
      dateRange: analysis.dateRange,
      recordCount: analysis.completedSessionsCount,
      source: 'ALPHA_X_DATABASE',
      calculationMethod: 'DETERMINISTIC_CALCULATION',
    };
  }

  /**
   * Deterministically calculates volume load, volume by exercise, and volume by muscle groups.
   */
  public async analyzeTrainingVolume(
    clientIdOrName: string,
    options: WorkoutIntelligenceFilterOptions = {}
  ): Promise<WorkoutIntelligenceResult<WorkoutVolumeAnalysis> | any> {
    const resolution = await clientDataService.resolveClient(clientIdOrName);
    if (resolution.status !== 'FOUND' || !resolution.client) {
      return {
        source: 'ALPHA_X_DATABASE',
        status: resolution.status === 'AMBIGUOUS' ? 'MULTIPLE_CLIENTS_FOUND' : 'CLIENT_NOT_FOUND',
        matches: resolution.matches,
        message: resolution.message,
      };
    }

    const { start, end, startDateStr, endDateStr } = validateDateRange(options.startDate, options.endDate);
    const workouts = await this.fetchClientWorkouts(resolution.client.userId, start, end, options.limit || 100);

    if (workouts.length === 0) {
      return {
        status: 'NO_RECORDS_FOUND',
        clientId: resolution.client.clientId || resolution.client.userId,
        metric: 'TRAINING_VOLUME_BREAKDOWN',
        value: workoutIntelligenceCalculator.analyzeVolume([]),
        unit: 'kg',
        recordCount: 0,
        source: 'ALPHA_X_DATABASE',
        calculationMethod: 'DETERMINISTIC_CALCULATION',
        message: 'No completed workout session records found to compute training volume.',
      };
    }

    const muscleMap = await this.getExerciseMuscleMap();
    const volumeAnalysis = workoutIntelligenceCalculator.analyzeVolume(workouts, muscleMap);

    return {
      status: 'SUCCESS',
      clientId: resolution.client.clientId || resolution.client.userId,
      metric: 'TRAINING_VOLUME_BREAKDOWN',
      value: volumeAnalysis,
      unit: 'kg',
      dateRange: { startDate: startDateStr || null, endDate: endDateStr || null },
      recordCount: workouts.length,
      source: 'ALPHA_X_DATABASE',
      calculationMethod: 'DETERMINISTIC_CALCULATION',
    };
  }

  /**
   * Deterministically calculates exercise-specific progression, weight/reps deltas, and lifetime volume.
   */
  public async analyzeExerciseProgress(
    clientIdOrName: string,
    exerciseName: string,
    options: WorkoutIntelligenceFilterOptions = {}
  ): Promise<WorkoutIntelligenceResult<ExercisePerformanceAnalysis> | any> {
    if (!exerciseName || typeof exerciseName !== 'string' || exerciseName.trim().length === 0) {
      return {
        status: 'INVALID_INPUT',
        source: 'ALPHA_X_DATABASE',
        metric: 'EXERCISE_PROGRESSION',
        message: 'Exercise name parameter is required for exercise progression analysis',
      };
    }

    const resolution = await clientDataService.resolveClient(clientIdOrName);
    if (resolution.status !== 'FOUND' || !resolution.client) {
      return {
        source: 'ALPHA_X_DATABASE',
        status: resolution.status === 'AMBIGUOUS' ? 'MULTIPLE_CLIENTS_FOUND' : 'CLIENT_NOT_FOUND',
        matches: resolution.matches,
        message: resolution.message,
      };
    }

    const { start, end } = validateDateRange(options.startDate, options.endDate);
    const workouts = await this.fetchClientWorkouts(resolution.client.userId, start, end, options.limit || 100);

    const exerciseAnalysis = workoutIntelligenceCalculator.analyzeExercise(exerciseName, workouts);

    if (exerciseAnalysis.totalSessions === 0) {
      return {
        status: 'NO_RECORDS_FOUND',
        clientId: resolution.client.clientId || resolution.client.userId,
        exercise: exerciseName.trim(),
        metric: 'EXERCISE_PROGRESSION',
        value: exerciseAnalysis,
        unit: 'kg, reps, sets',
        recordCount: 0,
        source: 'ALPHA_X_DATABASE',
        calculationMethod: 'DETERMINISTIC_CALCULATION',
        message: `No recorded workout sessions found containing exercise '${exerciseName}' for this client.`,
      };
    }

    const status = exerciseAnalysis.totalSessions < 2 ? 'INSUFFICIENT_DATA' : 'SUCCESS';

    return {
      status,
      clientId: resolution.client.clientId || resolution.client.userId,
      exercise: exerciseAnalysis.exerciseName,
      metric: 'EXERCISE_PROGRESSION',
      value: exerciseAnalysis,
      unit: 'kg, reps, sets',
      recordCount: exerciseAnalysis.totalSessions,
      source: 'ALPHA_X_DATABASE',
      calculationMethod: 'DETERMINISTIC_CALCULATION',
      message: exerciseAnalysis.totalSessions < 2
        ? 'Only 1 recorded occurrence of this exercise found. At least 2 sessions are required to compute progression delta.'
        : undefined,
    };
  }

  /**
   * Deterministically calculates personal-best records (top weight, highest reps, peak session volume).
   */
  public async getPersonalBests(
    clientIdOrName: string,
    exerciseName?: string
  ): Promise<WorkoutIntelligenceResult<PersonalBestRecord[]> | any> {
    const resolution = await clientDataService.resolveClient(clientIdOrName);
    if (resolution.status !== 'FOUND' || !resolution.client) {
      return {
        source: 'ALPHA_X_DATABASE',
        status: resolution.status === 'AMBIGUOUS' ? 'MULTIPLE_CLIENTS_FOUND' : 'CLIENT_NOT_FOUND',
        matches: resolution.matches,
        message: resolution.message,
      };
    }

    const workouts = await this.fetchClientWorkouts(resolution.client.userId, undefined, undefined, 200);
    const pbs = workoutIntelligenceCalculator.calculatePersonalBests(workouts, exerciseName);

    if (pbs.length === 0) {
      return {
        status: 'NO_RECORDS_FOUND',
        clientId: resolution.client.clientId || resolution.client.userId,
        exercise: exerciseName || undefined,
        metric: 'PERSONAL_BESTS',
        value: [],
        unit: 'kg, reps',
        recordCount: 0,
        source: 'ALPHA_X_DATABASE',
        calculationMethod: 'DETERMINISTIC_CALCULATION',
        message: 'No personal-best records identified from stored client workout data.',
      };
    }

    return {
      status: 'SUCCESS',
      clientId: resolution.client.clientId || resolution.client.userId,
      exercise: exerciseName || undefined,
      metric: 'PERSONAL_BESTS',
      value: pbs,
      unit: 'kg, reps',
      recordCount: pbs.length,
      source: 'ALPHA_X_DATABASE',
      calculationMethod: 'DETERMINISTIC_CALCULATION',
    };
  }

  /**
   * Deterministically calculates perceived exertion metrics (average/min/max RPE and RIR).
   */
  public async analyzeWorkoutIntensity(
    clientIdOrName: string,
    options: WorkoutIntelligenceFilterOptions = {}
  ): Promise<WorkoutIntelligenceResult<WorkoutIntensityAnalysis> | any> {
    const resolution = await clientDataService.resolveClient(clientIdOrName);
    if (resolution.status !== 'FOUND' || !resolution.client) {
      return {
        source: 'ALPHA_X_DATABASE',
        status: resolution.status === 'AMBIGUOUS' ? 'MULTIPLE_CLIENTS_FOUND' : 'CLIENT_NOT_FOUND',
        matches: resolution.matches,
        message: resolution.message,
      };
    }

    const { start, end } = validateDateRange(options.startDate, options.endDate);
    const workouts = await this.fetchClientWorkouts(resolution.client.userId, start, end, options.limit || 100);

    const intensity = workoutIntelligenceCalculator.analyzeIntensity(workouts);

    if (intensity.rpeRecordCount === 0 && intensity.rirRecordCount === 0) {
      return {
        status: 'RPE_DATA_UNAVAILABLE',
        clientId: resolution.client.clientId || resolution.client.userId,
        metric: 'WORKOUT_INTENSITY_RPE_RIR',
        value: intensity,
        unit: 'RPE (1-10), RIR',
        recordCount: 0,
        source: 'ALPHA_X_DATABASE',
        calculationMethod: 'DETERMINISTIC_CALCULATION',
        message: 'No RPE or RIR intensity metrics have been recorded in completed workouts for this client.',
      };
    }

    return {
      status: 'SUCCESS',
      clientId: resolution.client.clientId || resolution.client.userId,
      metric: 'WORKOUT_INTENSITY_RPE_RIR',
      value: intensity,
      unit: 'RPE (1-10), RIR',
      recordCount: intensity.rpeRecordCount,
      source: 'ALPHA_X_DATABASE',
      calculationMethod: 'DETERMINISTIC_CALCULATION',
    };
  }

  /**
   * Deterministically compares workout volume, frequency, and intensity across two distinct time periods.
   */
  public async compareWorkoutPeriods(
    clientIdOrName: string,
    options: {
      preset?: 'last_7_days' | 'last_14_days' | 'last_28_days';
      currentStart?: string;
      currentEnd?: string;
      prevStart?: string;
      prevEnd?: string;
    } = {}
  ): Promise<WorkoutIntelligenceResult<PeriodComparisonAnalysis> | any> {
    const resolution = await clientDataService.resolveClient(clientIdOrName);
    if (resolution.status !== 'FOUND' || !resolution.client) {
      return {
        source: 'ALPHA_X_DATABASE',
        status: resolution.status === 'AMBIGUOUS' ? 'MULTIPLE_CLIENTS_FOUND' : 'CLIENT_NOT_FOUND',
        matches: resolution.matches,
        message: resolution.message,
      };
    }

    let dateSpans: PeriodComparisonDateSpans;
    if (options.currentStart && options.currentEnd && options.prevStart && options.prevEnd) {
      dateSpans = validateCustomComparisonIntervals(
        options.currentStart,
        options.currentEnd,
        options.prevStart,
        options.prevEnd
      );
    } else {
      dateSpans = computePresetComparisonDates(options.preset || 'last_14_days');
    }

    // Fetch workouts for both spans
    const currentWorkouts = await this.fetchClientWorkouts(
      resolution.client.userId,
      dateSpans.current.startDate,
      dateSpans.current.endDate,
      100
    );

    const previousWorkouts = await this.fetchClientWorkouts(
      resolution.client.userId,
      dateSpans.previous.startDate,
      dateSpans.previous.endDate,
      100
    );

    const comparison = workoutIntelligenceCalculator.comparePeriods(currentWorkouts, previousWorkouts, dateSpans);

    return {
      status: 'SUCCESS',
      clientId: resolution.client.clientId || resolution.client.userId,
      metric: 'PERIOD_WORKOUT_COMPARISON',
      value: comparison,
      unit: 'kg, sessions, RPE',
      recordCount: currentWorkouts.length + previousWorkouts.length,
      source: 'ALPHA_X_DATABASE',
      calculationMethod: 'DETERMINISTIC_CALCULATION',
    };
  }

  /**
   * Deterministically analyzes training frequency, consistency, active weeks, and planned vs completed workouts.
   */
  public async analyzeTrainingFrequency(
    clientIdOrName: string,
    options: WorkoutIntelligenceFilterOptions = {}
  ): Promise<WorkoutIntelligenceResult<TrainingFrequencyAnalysis> | any> {
    const resolution = await clientDataService.resolveClient(clientIdOrName);
    if (resolution.status !== 'FOUND' || !resolution.client) {
      return {
        source: 'ALPHA_X_DATABASE',
        status: resolution.status === 'AMBIGUOUS' ? 'MULTIPLE_CLIENTS_FOUND' : 'CLIENT_NOT_FOUND',
        matches: resolution.matches,
        message: resolution.message,
      };
    }

    const { start, end, startDateStr, endDateStr } = validateDateRange(options.startDate, options.endDate);
    const workouts = await this.fetchClientWorkouts(resolution.client.userId, start, end, options.limit || 100);

    // Fetch planned active assignments for client
    const plannedAssignments = await prisma.workoutAssignment.findMany({
      where: {
        active: true,
        OR: [{ clientId: resolution.client.userId }, { clientId: null }],
      },
    });

    const muscleMap = await this.getExerciseMuscleMap();
    const freq = workoutIntelligenceCalculator.analyzeFrequency(
      workouts,
      muscleMap,
      plannedAssignments.length > 0 ? plannedAssignments.length : undefined
    );

    if (workouts.length === 0) {
      return {
        status: 'NO_RECORDS_FOUND',
        clientId: resolution.client.clientId || resolution.client.userId,
        metric: 'TRAINING_FREQUENCY_ANALYSIS',
        value: freq,
        unit: 'sessions/week, occurrences',
        dateRange: { startDate: startDateStr || null, endDate: endDateStr || null },
        recordCount: 0,
        source: 'ALPHA_X_DATABASE',
        calculationMethod: 'DETERMINISTIC_CALCULATION',
        message: 'No completed workout records found to analyze training frequency.',
      };
    }

    return {
      status: 'SUCCESS',
      clientId: resolution.client.clientId || resolution.client.userId,
      metric: 'TRAINING_FREQUENCY_ANALYSIS',
      value: freq,
      unit: 'sessions/week, occurrences',
      dateRange: { startDate: startDateStr || null, endDate: endDateStr || null },
      recordCount: workouts.length,
      source: 'ALPHA_X_DATABASE',
      calculationMethod: 'DETERMINISTIC_CALCULATION',
    };
  }
}

export const workoutIntelligenceService = new WorkoutIntelligenceService();
