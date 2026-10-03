/**
 * Alpha X AI — Deterministic Fitness Calculation Engine
 * Phase 8 — Types & Interfaces
 */

export type CalculationStatus =
  | 'SUCCESS'
  | 'NO_RECORDS_FOUND'
  | 'DATA_NOT_AVAILABLE'
  | 'INSUFFICIENT_DATA'
  | 'INVALID_INPUT';

export type CalculationMetricType =
  | 'WEIGHT_SUMMARY'
  | 'WEIGHT_CHANGE'
  | 'DATE_WEIGHT_COMPARISON'
  | 'WAIST_SUMMARY'
  | 'WAIST_CHANGE'
  | 'NUTRITION_SUMMARY'
  | 'NUTRITION_TARGET_COMPARISON'
  | 'ACTIVITY_SUMMARY'
  | 'WORKOUT_SUMMARY'
  | 'ATTENDANCE_SUMMARY'
  | 'CHECKIN_SUMMARY';

export interface CalculationResult<T = any> {
  metric: CalculationMetricType | string;
  status: CalculationStatus;
  value: T;
  unit: string;
  source: 'ALPHA_X_DATABASE';
  calculationMethod: string;
  recordCount: number;
  startDate?: string | null;
  endDate?: string | null;
  startValue?: number | null;
  endValue?: number | null;
  message?: string;
}

export interface WeightRecordInput {
  date: Date | string;
  weightKg: number;
  waistCm?: number | null;
}

export interface WeightSummaryValue {
  startingWeightKg: number | null;
  latestWeightKg: number | null;
  changeKg: number | null;
  weightLostKg: number | null;
  percentageChange: number | null;
  averageWeightKg: number | null;
  minimumWeightKg: number | null;
  maximumWeightKg: number | null;
  recordCount: number;
  startDate: string | null;
  endDate: string | null;
  unit: 'kg';
}

export interface WaistSummaryValue {
  startingWaistCm: number | null;
  latestWaistCm: number | null;
  changeCm: number | null;
  percentageChange: number | null;
  averageWaistCm: number | null;
  minimumWaistCm: number | null;
  maximumWaistCm: number | null;
  recordCount: number;
  startDate: string | null;
  endDate: string | null;
  unit: 'cm';
}

export interface NutritionSummaryValue {
  totalLoggedCalories: number;
  totalLoggedProtein: number;
  totalLoggedCarbs: number;
  totalLoggedFat: number;
  totalLoggedFiber: number;
  distinctDaysCount: number;
  totalLogsCount: number;
  averageDailyCalories: number;
  averageDailyProtein: number;
  averageDailyCarbs: number;
  averageDailyFat: number;
  averageDailyFiber: number;
  units: {
    calories: 'kcal';
    protein: 'g';
    carbs: 'g';
    fat: 'g';
    fiber: 'g';
  };
}

export interface NutritionTargetComparisonValue {
  target: {
    calories: number;
    protein: number;
    carbs: number;
    fat: number;
    fiber: number;
    planName?: string;
  };
  actualAverage: {
    calories: number;
    protein: number;
    carbs: number;
    fat: number;
    fiber: number;
    daysCount: number;
  };
  difference: {
    calories: number;
    protein: number;
    carbs: number;
    fat: number;
    fiber: number;
  };
  units: {
    calories: 'kcal';
    protein: 'g';
    carbs: 'g';
    fat: 'g';
    fiber: 'g';
  };
  note: string;
}

export interface ActivitySummaryValue {
  totalSteps: number;
  averageDailySteps: number;
  minimumDailySteps: number;
  maximumDailySteps: number;
  totalCardioMinutes: number;
  averageCardioMinutes: number;
  totalCaloriesBurned: number;
  averageCaloriesBurned: number;
  daysRecorded: number;
  stepGoal?: number | null;
  stepDifference?: number | null;
  goalAchievementPercentage?: number | null;
  units: {
    steps: 'steps';
    cardio: 'minutes';
    energy: 'kcal';
  };
}

export interface WorkoutSummaryValue {
  completedSessionsCount: number;
  totalVolumeKg: number;
  averageSessionVolumeKg: number;
  maxSessionVolumeKg: number;
  totalDurationMinutes: number;
  averageDurationMinutes: number;
  totalCompletedSets: number;
  averageCompletedSets: number;
  averageRpe: number | null;
  minRpe: number | null;
  maxRpe: number | null;
  averageRir: number | null;
  minRir: number | null;
  maxRir: number | null;
  rpeRecordCount: number;
  rirRecordCount: number;
  units: {
    volume: 'kg';
    duration: 'minutes';
    sets: 'sets';
    rpe: 'RPE';
    rir: 'RIR';
  };
}

export interface AttendanceSummaryValue {
  totalRecords: number;
  presentCount: number;
  absentCount: number;
  attendancePercentage: number;
  unit: 'percentage';
  note: string;
}

export interface CheckInSummaryValue {
  checkInCount: number;
  averageSleepHours: number | null;
  painRecordedCount: number;
  averagePainLevel: number | null;
  sleepQualityDistribution: Record<string, number>;
  recoveryQualityDistribution: Record<string, number>;
  dietAdherenceDistribution: Record<string, number>;
  workoutCompletionDistribution: Record<string, number>;
  units: {
    sleep: 'hours';
    painLevel: '1-10';
  };
  note: string;
}

export interface CalculationDateRangeOptions {
  startDate?: string;
  endDate?: string;
  limit?: number;
}
