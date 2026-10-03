/**
 * Alpha X AI — Deterministic Workout & Training Volume Calculator
 * Phase 8 — Deterministic Fitness Calculation Engine
 */

import { CalculationResult, WorkoutSummaryValue } from './calculation.types';
import { round2, safeAverage, safeMin, safeMax } from './calculation.validation';

export interface RawWorkoutRecordEntry {
  startedAt: Date | string;
  completedAt?: Date | string | null;
  durationSeconds: number;
  totalVolume: number;
  completedSetsCount: number;
  averageRpe?: number | null;
  averageRir?: number | null;
  isCompleted?: boolean;
}

export class WorkoutCalculator {
  /**
   * Deterministically calculates workout volume, duration, and intensity metrics over recorded sessions.
   *
   * Formulas:
   * - completedSessionsCount = count(workouts)
   * - totalVolumeKg = sum(totalVolume) [using authoritative stored value]
   * - averageSessionVolumeKg = totalVolumeKg / completedSessionsCount
   * - maxSessionVolumeKg = max(totalVolume)
   * - totalDurationMinutes = sum(durationSeconds) / 60
   * - averageDurationMinutes = totalDurationMinutes / completedSessionsCount
   * - totalCompletedSets = sum(completedSetsCount)
   * - averageCompletedSets = totalCompletedSets / completedSessionsCount
   * - averageRpe = sum(rpe) / count(rpe) [ignoring nulls]
   * - averageRir = sum(rir) / count(rir) [ignoring nulls]
   */
  public calculateWorkoutSummary(
    workouts: RawWorkoutRecordEntry[],
    startDateFilter?: string | null,
    endDateFilter?: string | null
  ): CalculationResult<WorkoutSummaryValue> {
    if (!workouts || workouts.length === 0) {
      return {
        metric: 'WORKOUT_SUMMARY',
        status: 'NO_RECORDS_FOUND',
        value: {
          completedSessionsCount: 0,
          totalVolumeKg: 0,
          averageSessionVolumeKg: 0,
          maxSessionVolumeKg: 0,
          totalDurationMinutes: 0,
          averageDurationMinutes: 0,
          totalCompletedSets: 0,
          averageCompletedSets: 0,
          averageRpe: null,
          minRpe: null,
          maxRpe: null,
          averageRir: null,
          minRir: null,
          maxRir: null,
          rpeRecordCount: 0,
          rirRecordCount: 0,
          units: {
            volume: 'kg',
            duration: 'minutes',
            sets: 'sets',
            rpe: 'RPE',
            rir: 'RIR',
          },
        },
        unit: 'kg, minutes, sets',
        source: 'ALPHA_X_DATABASE',
        calculationMethod: 'sum and arithmetic means over recorded completed workouts',
        recordCount: 0,
        startDate: startDateFilter || null,
        endDate: endDateFilter || null,
        message: 'No completed workout session records found for this client.',
      };
    }

    const count = workouts.length;

    let totalVolume = 0;
    let maxVolume = 0;
    let totalSeconds = 0;
    let totalSets = 0;

    const validRpes: number[] = [];
    const validRirs: number[] = [];

    for (const w of workouts) {
      const vol = Math.max(Number(w.totalVolume) || 0, 0);
      totalVolume += vol;
      if (vol > maxVolume) {
        maxVolume = vol;
      }

      totalSeconds += Math.max(Number(w.durationSeconds) || 0, 0);
      totalSets += Math.max(Number(w.completedSetsCount) || 0, 0);

      if (w.averageRpe !== null && w.averageRpe !== undefined) {
        const rpeNum = Number(w.averageRpe);
        if (!isNaN(rpeNum) && isFinite(rpeNum) && rpeNum > 0) {
          validRpes.push(rpeNum);
        }
      }

      if (w.averageRir !== null && w.averageRir !== undefined) {
        const rirNum = Number(w.averageRir);
        if (!isNaN(rirNum) && isFinite(rirNum) && rirNum >= 0) {
          validRirs.push(rirNum);
        }
      }
    }

    const totalVolumeKg = round2(totalVolume);
    const averageSessionVolumeKg = round2(totalVolumeKg / count);
    const maxSessionVolumeKg = round2(maxVolume);

    const totalDurationMinutes = round2(totalSeconds / 60);
    const averageDurationMinutes = round2(totalDurationMinutes / count);

    const totalCompletedSets = totalSets;
    const averageCompletedSets = round2(totalCompletedSets / count);

    const averageRpe = safeAverage(validRpes);
    const minRpe = safeMin(validRpes);
    const maxRpe = safeMax(validRpes);

    const averageRir = safeAverage(validRirs);
    const minRir = safeMin(validRirs);
    const maxRir = safeMax(validRirs);

    const dates = workouts
      .map((w) => (w.startedAt instanceof Date ? w.startedAt.toISOString().split('T')[0] : String(w.startedAt).split('T')[0]))
      .sort();

    return {
      metric: 'WORKOUT_SUMMARY',
      status: 'SUCCESS',
      value: {
        completedSessionsCount: count,
        totalVolumeKg,
        averageSessionVolumeKg,
        maxSessionVolumeKg,
        totalDurationMinutes,
        averageDurationMinutes,
        totalCompletedSets,
        averageCompletedSets,
        averageRpe,
        minRpe,
        maxRpe,
        averageRir,
        minRir,
        maxRir,
        rpeRecordCount: validRpes.length,
        rirRecordCount: validRirs.length,
        units: {
          volume: 'kg',
          duration: 'minutes',
          sets: 'sets',
          rpe: 'RPE',
          rir: 'RIR',
        },
      },
      unit: 'kg, minutes, sets',
      source: 'ALPHA_X_DATABASE',
      calculationMethod: 'totalVolume = sum(volume); avg = total / sessions; duration = sum(sec)/60',
      recordCount: count,
      startDate: dates[0] || startDateFilter || null,
      endDate: dates[dates.length - 1] || endDateFilter || null,
      startValue: totalVolumeKg,
      endValue: averageSessionVolumeKg,
    };
  }
}

export const workoutCalculator = new WorkoutCalculator();
