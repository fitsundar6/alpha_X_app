/**
 * Alpha X AI — Deterministic Weekly Check-In Calculator
 * Phase 8 — Deterministic Fitness Calculation Engine
 */

import { CalculationResult, CheckInSummaryValue } from './calculation.types';
import { round2, safeAverage } from './calculation.validation';

export interface RawWeeklyCheckInEntry {
  weekNumber: number;
  year: number;
  checkInDate: Date | string;
  sleepHours?: number | null;
  sleepQuality?: string | null;
  recoveryQuality?: string | null;
  dietAdherence?: string | null;
  workoutCompletion?: string | null;
  hasPain?: boolean | null;
  painLevel?: number | null;
  painLocation?: string | null;
  painDescription?: string | null;
}

export class CheckInCalculator {
  /**
   * Deterministically calculates aggregated metrics over recorded weekly check-in entries.
   *
   * Formulas:
   * - checkInCount = count
   * - averageSleepHours = sum(sleepHours) / count
   * - painRecordedCount = count(where hasPain === true)
   * - averagePainLevel = sum(painLevel) / count(where painLevel > 0)
   * - categorical distributions: counts per distinct label
   *
   * Strict Rule: Preserves original values and rating scales without inventing medical diagnoses.
   */
  public calculateCheckInSummary(
    records: RawWeeklyCheckInEntry[],
    startDateFilter?: string | null,
    endDateFilter?: string | null
  ): CalculationResult<CheckInSummaryValue> {
    if (!records || records.length === 0) {
      return {
        metric: 'CHECKIN_SUMMARY',
        status: 'NO_RECORDS_FOUND',
        value: {
          checkInCount: 0,
          averageSleepHours: null,
          painRecordedCount: 0,
          averagePainLevel: null,
          sleepQualityDistribution: {},
          recoveryQualityDistribution: {},
          dietAdherenceDistribution: {},
          workoutCompletionDistribution: {},
          units: {
            sleep: 'hours',
            painLevel: '1-10',
          },
          note: 'Mathematical summary of recorded weekly client reflections. Strictly descriptive; does not represent medical diagnosis.',
        },
        unit: 'hours, counts',
        source: 'ALPHA_X_DATABASE',
        calculationMethod: 'arithmetic means and frequency distributions over recorded check-ins',
        recordCount: 0,
        startDate: startDateFilter || null,
        endDate: endDateFilter || null,
        message: 'No weekly check-in records found for this client in the specified period.',
      };
    }

    const checkInCount = records.length;
    const sleepHoursList: number[] = [];
    let painRecordedCount = 0;
    const painLevels: number[] = [];

    const sleepQualityDist: Record<string, number> = {};
    const recoveryQualityDist: Record<string, number> = {};
    const dietAdherenceDist: Record<string, number> = {};
    const workoutCompletionDist: Record<string, number> = {};

    for (const r of records) {
      if (r.sleepHours !== null && r.sleepHours !== undefined) {
        const sh = Number(r.sleepHours);
        if (!isNaN(sh) && isFinite(sh) && sh > 0) {
          sleepHoursList.push(sh);
        }
      }

      if (r.hasPain === true) {
        painRecordedCount++;
        if (r.painLevel !== null && r.painLevel !== undefined) {
          const pl = Number(r.painLevel);
          if (!isNaN(pl) && isFinite(pl) && pl > 0) {
            painLevels.push(pl);
          }
        }
      }

      if (r.sleepQuality) {
        sleepQualityDist[r.sleepQuality] = (sleepQualityDist[r.sleepQuality] || 0) + 1;
      }
      if (r.recoveryQuality) {
        recoveryQualityDist[r.recoveryQuality] = (recoveryQualityDist[r.recoveryQuality] || 0) + 1;
      }
      if (r.dietAdherence) {
        dietAdherenceDist[r.dietAdherence] = (dietAdherenceDist[r.dietAdherence] || 0) + 1;
      }
      if (r.workoutCompletion) {
        workoutCompletionDist[r.workoutCompletion] = (workoutCompletionDist[r.workoutCompletion] || 0) + 1;
      }
    }

    const averageSleepHours = safeAverage(sleepHoursList);
    const averagePainLevel = safeAverage(painLevels);

    const dates = records
      .map((r) => (r.checkInDate instanceof Date ? r.checkInDate.toISOString().split('T')[0] : String(r.checkInDate).split('T')[0]))
      .sort();

    return {
      metric: 'CHECKIN_SUMMARY',
      status: 'SUCCESS',
      value: {
        checkInCount,
        averageSleepHours,
        painRecordedCount,
        averagePainLevel,
        sleepQualityDistribution: sleepQualityDist,
        recoveryQualityDistribution: recoveryQualityDist,
        dietAdherenceDistribution: dietAdherenceDist,
        workoutCompletionDistribution: workoutCompletionDist,
        units: {
          sleep: 'hours',
          painLevel: '1-10',
        },
        note: 'Mathematical summary of recorded weekly client reflections. Strictly descriptive; does not represent medical diagnosis.',
      },
      unit: 'hours, counts',
      source: 'ALPHA_X_DATABASE',
      calculationMethod: 'averageSleepHours = sum/count; painLevel = sum/count; distributions = counts',
      recordCount: checkInCount,
      startDate: dates[0] || startDateFilter || null,
      endDate: dates[dates.length - 1] || endDateFilter || null,
      startValue: averageSleepHours,
      endValue: painRecordedCount,
    };
  }
}

export const checkInCalculator = new CheckInCalculator();
