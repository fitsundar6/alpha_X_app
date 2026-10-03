/**
 * Alpha X AI — Workout Intelligence Engine Types
 * Phase 9 — Workout Intelligence Engine
 */

export type WorkoutIntelligenceStatus =
  | 'SUCCESS'
  | 'NO_RECORDS_FOUND'
  | 'INSUFFICIENT_DATA'
  | 'INVALID_INPUT'
  | 'RPE_DATA_UNAVAILABLE';

export interface WorkoutIntelligenceResult<T = any> {
  status: WorkoutIntelligenceStatus;
  clientId: string;
  metric: string;
  value: T;
  unit: string;
  exercise?: string;
  dateRange?: {
    startDate: string | null;
    endDate: string | null;
  };
  recordCount: number;
  source: 'ALPHA_X_DATABASE';
  calculationMethod: 'DETERMINISTIC_CALCULATION';
  dataQuality?: string;
  message?: string;
}

export interface RawSetEntry {
  setNumber: number;
  actualWeight?: number | null; // in kg
  actualReps?: number | null;
  actualRpe?: number | null;
  actualRir?: number | null;
  isCompleted?: boolean;
}

export interface RawExerciseRecordEntry {
  exerciseId?: string;
  exerciseName: string;
  isSkipped?: boolean;
  setRecords: RawSetEntry[];
}

export interface RawWorkoutSessionEntry {
  id: string;
  sessionTitle: string;
  workoutType?: string;
  startedAt: Date | string;
  completedAt?: Date | string | null;
  durationSeconds: number;
  totalVolume: number; // in kg
  completedSetsCount: number;
  averageRpe?: number | null;
  averageRir?: number | null;
  isCompleted?: boolean;
  exerciseRecords: RawExerciseRecordEntry[];
}

export interface WorkoutSessionAnalysis {
  completedSessionsCount: number;
  sessionsPerWeek: number;
  sessionsPerMonth: number;
  averageWeeklySessions: number;
  trainingDaysCount: number; // Unique calendar dates with completed workouts
  longestGapDays: number;    // Longest gap between recorded consecutive sessions
  averageGapDays: number;    // Average days between recorded consecutive sessions
  mostRecentSessionDate: string | null;
  oldestSessionDate: string | null;
  dateRange: {
    startDate: string | null;
    endDate: string | null;
  };
}

export interface ExerciseVolumeContribution {
  exerciseName: string;
  totalVolumeKg: number;
  percentageOfTotal: number;
  occurrences: number;
}

export interface WorkoutTypeVolumeContribution {
  workoutType: string;
  totalVolumeKg: number;
  sessionCount: number;
}

export interface MuscleGroupVolumeContribution {
  muscleGroup: string;
  totalVolumeKg: number;
  percentageOfTotal: number;
}

export interface WorkoutVolumeAnalysis {
  totalVolumeKg: number;
  averageSessionVolumeKg: number;
  minSessionVolumeKg: number;
  maxSessionVolumeKg: number;
  volumeByExercise: ExerciseVolumeContribution[];
  volumeByWorkoutType: WorkoutTypeVolumeContribution[];
  volumeByMuscleGroup: MuscleGroupVolumeContribution[];
  unit: 'kg';
}

export interface ExercisePerformanceDataPoint {
  date: string;
  sessionTitle: string;
  topWeightKg: number;
  totalReps: number;
  totalSets: number;
  volumeKg: number;
  averageRpe?: number | null;
  averageRir?: number | null;
}

export interface ExercisePerformanceDifference {
  weightDeltaKg: number;
  repsDelta: number;
  volumeDeltaKg: number;
  percentageVolumeChange: number | null;
  direction: 'INCREASED' | 'DECREASED' | 'UNCHANGED';
}

export interface ExercisePerformanceAnalysis {
  exerciseName: string;
  totalSessions: number;
  totalSets: number;
  totalReps: number;
  averageWeightKg: number;
  maxWeightKg: number;
  averageReps: number;
  maxReps: number;
  totalVolumeKg: number;
  averageVolumePerSessionKg: number;
  averageRpe: number | null;
  averageRir: number | null;
  latestPerformance: ExercisePerformanceDataPoint | null;
  previousPerformance: ExercisePerformanceDataPoint | null;
  performanceDifference: ExercisePerformanceDifference | null;
  unit: 'kg, reps, sets';
}

export type PersonalBestMetricType =
  | 'HIGHEST_WEIGHT'
  | 'HIGHEST_REPS_AT_WEIGHT'
  | 'HIGHEST_SESSION_VOLUME';

export interface PersonalBestRecord {
  exerciseName: string;
  metric: PersonalBestMetricType;
  metricLabel: string;
  value: number;
  unit: string;
  secondaryMetric?: string;
  date: string;
  sessionTitle: string;
  source: 'ALPHA_X_DATABASE';
}

export interface ExerciseIntensityDataPoint {
  exerciseName: string;
  averageRpe: number | null;
  averageRir: number | null;
  setsCount: number;
}

export interface WorkoutIntensityAnalysis {
  averageRpe: number | null;
  minRpe: number | null;
  maxRpe: number | null;
  averageRir: number | null;
  minRir: number | null;
  maxRir: number | null;
  rpeRecordCount: number;
  rirRecordCount: number;
  exerciseIntensities: ExerciseIntensityDataPoint[];
  units: {
    rpe: 'RPE (1-10)';
    rir: 'RIR';
  };
  note: string;
}

export interface PeriodComparisonData {
  startDate: string;
  endDate: string;
  daysCount: number;
  sessionCount: number;
  totalVolumeKg: number;
  averageSessionVolumeKg: number;
  averageRpe: number | null;
  averageRir: number | null;
}

export interface PeriodComparisonAnalysis {
  currentPeriod: PeriodComparisonData;
  previousPeriod: PeriodComparisonData;
  comparison: {
    volumeDeltaKg: number;
    volumePercentageChange: number | null;
    sessionCountDelta: number;
    rpeDelta: number | null;
    direction: 'INCREASED' | 'DECREASED' | 'UNCHANGED';
  };
}

export interface PlannedVsCompletedFrequency {
  plannedSessionsCount: number;
  completedSessionsCount: number;
  completionPercentage: number | null;
}

export interface TrainingFrequencyAnalysis {
  averageSessionsPerWeek: number;
  sessionsPerMonth: number;
  trainingDaysCount: number;
  activeWeeksCount: number;
  inactiveWeeksCount: number;
  averageDaysBetweenSessions: number;
  longestGapDays: number;
  exerciseFrequencies: Array<{
    exerciseName: string;
    frequencyCount: number;
    frequencyPercentage: number;
  }>;
  muscleGroupFrequencies: Array<{
    muscleGroup: string;
    sessionCount: number;
    percentage: number;
  }>;
  plannedVsCompleted?: PlannedVsCompletedFrequency;
}

export interface WorkoutIntelligenceFilterOptions {
  startDate?: string;
  endDate?: string;
  limit?: number;
  exerciseName?: string;
  presetRange?: 'last_7_days' | 'last_14_days' | 'last_28_days' | 'custom';
}
