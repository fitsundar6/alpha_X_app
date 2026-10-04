/**
 * Alpha X — Weekly Telemetry System Entities & Interfaces
 * "Spotify-Wrapped for Lifting"
 */

export interface MuscleGroupTelemetry {
  muscleGroup: 'CHEST' | 'BACK' | 'LEGS' | 'SHOULDERS' | 'ARMS' | 'CORE';
  displayName: string;
  totalSets: number;
  totalVolumeKg: number;
  status: 'UNDERSTIMULATED' | 'OPTIMAL' | 'HIGH_VOLUME' | 'DELOAD_RECOMMENDED';
  statusColor: string; // Hex color for UI
  topExercises: string[];
}

export interface PRHighlight {
  exerciseName: string;
  type: string; // WEIGHT, VOLUME, REPS
  value: number;
  weight?: number;
  reps?: number;
  achievedAt: string;
}

export interface PhysicalComparison {
  tonnageKg: number;
  equivalentLabel: string;
  itemCount: number;
  itemIcon: string;
  description: string;
}

export interface WeeklyTelemetryReport {
  id: string;
  clientId: string;
  clientName: string;
  weekNumber: number;
  year: number;
  startDate: string; // ISO date 'YYYY-MM-DD'
  endDate: string; // ISO date 'YYYY-MM-DD'
  totalWorkoutsCompleted: number;
  targetWorkouts: number;
  adherencePercentage: number;
  totalDurationMinutes: number;
  totalVolumeKg: number;
  completedSetsCount: number;
  averageRpe: number | null;
  physicalComparison: PhysicalComparison;
  muscleHeatmap: MuscleGroupTelemetry[];
  personalRecords: PRHighlight[];
  aiCoachCommentary: string;
  streakWeeks: number;
  generatedAt: string;
}

export interface AdminTelemetryClientSummary {
  clientId: string;
  clientName: string;
  email: string;
  photoUrl?: string | null;
  totalVolumeKg: number;
  workoutsCompleted: number;
  adherencePercentage: number;
  topMuscleGroup: string;
  prCount: number;
  rank: number;
  needsEncouragement: boolean;
  physicalComparisonLabel: string;
}

export interface AdminTelemetryOverview {
  weekNumber: number;
  year: number;
  startDate: string;
  endDate: string;
  totalTonnageMovedKg: number;
  totalSessionsCompleted: number;
  averageGymAdherencePct: number;
  leaderboard: AdminTelemetryClientSummary[];
  topPrPerformers: { clientName: string; exerciseName: string; value: number }[];
}
