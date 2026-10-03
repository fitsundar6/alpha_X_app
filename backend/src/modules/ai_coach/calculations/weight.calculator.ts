/**
 * Alpha X AI — Deterministic Weight Calculator
 * Phase 8 — Deterministic Fitness Calculation Engine
 */

import { CalculationResult, WeightSummaryValue } from './calculation.types';
import { round2, safeAverage, safeMin, safeMax } from './calculation.validation';
import { InvalidCalculationInputError } from './calculation.errors';

export interface RawWeightEntry {
  date: Date | string;
  weightKg: number;
  waistCm?: number | null;
}

export class WeightCalculator {
  /**
   * Deterministically calculates comprehensive weight progress metrics over a series of records.
   *
   * Formulas:
   * - changeKg = latestWeight - startingWeight
   * - weightLostKg = startingWeight - latestWeight (if latest < starting)
   * - percentageChange = ((latestWeight - startingWeight) / startingWeight) * 100
   * - averageWeight = sum(weights) / count
   * - minimumWeight = min(weights)
   * - maximumWeight = max(weights)
   */
  public calculateWeightSummary(
    rawRecords: RawWeightEntry[],
    startDateFilter?: string | null,
    endDateFilter?: string | null
  ): CalculationResult<WeightSummaryValue> {
    if (!rawRecords || rawRecords.length === 0) {
      return {
        metric: 'WEIGHT_SUMMARY',
        status: 'NO_RECORDS_FOUND',
        value: {
          startingWeightKg: null,
          latestWeightKg: null,
          changeKg: null,
          weightLostKg: null,
          percentageChange: null,
          averageWeightKg: null,
          minimumWeightKg: null,
          maximumWeightKg: null,
          recordCount: 0,
          startDate: startDateFilter || null,
          endDate: endDateFilter || null,
          unit: 'kg',
        },
        unit: 'kg',
        source: 'ALPHA_X_DATABASE',
        calculationMethod: 'latest - earliest; arithmetic mean; min/max',
        recordCount: 0,
        startDate: startDateFilter || null,
        endDate: endDateFilter || null,
        startValue: null,
        endValue: null,
        message: 'No recorded weight entries found for this client in the specified period.',
      };
    }

    // 1. Filter and validate valid positive body weights
    const validRecords = rawRecords
      .map((r) => {
        const d = r.date instanceof Date ? r.date : new Date(r.date);
        const w = Number(r.weightKg);
        return { date: d, weightKg: w };
      })
      .filter((r) => {
        if (isNaN(r.date.getTime())) return false;
        if (typeof r.weightKg !== 'number' || isNaN(r.weightKg) || !isFinite(r.weightKg)) return false;
        if (r.weightKg <= 0) {
          // Reject negative or zero body weights
          return false;
        }
        return true;
      });

    if (validRecords.length === 0) {
      throw new InvalidCalculationInputError(
        'WEIGHT_SUMMARY',
        'All provided weight records contain invalid, zero, or negative numeric values.'
      );
    }

    // 2. Sort chronologically ascending (earliest to latest)
    validRecords.sort((a, b) => a.date.getTime() - b.date.getTime());

    const weights = validRecords.map((r) => r.weightKg);
    const count = validRecords.length;
    const earliest = validRecords[0];
    const latest = validRecords[count - 1];

    const startingWeightKg = round2(earliest.weightKg);
    const latestWeightKg = round2(latest.weightKg);
    const averageWeightKg = safeAverage(weights);
    const minimumWeightKg = safeMin(weights);
    const maximumWeightKg = safeMax(weights);

    const startDate = earliest.date.toISOString().split('T')[0];
    const endDate = latest.date.toISOString().split('T')[0];

    // 3. Guard against insufficient data for change over time (< 2 records)
    if (count < 2) {
      return {
        metric: 'WEIGHT_SUMMARY',
        status: 'INSUFFICIENT_DATA',
        value: {
          startingWeightKg,
          latestWeightKg,
          changeKg: null,
          weightLostKg: null,
          percentageChange: null,
          averageWeightKg,
          minimumWeightKg,
          maximumWeightKg,
          recordCount: count,
          startDate,
          endDate,
          unit: 'kg',
        },
        unit: 'kg',
        source: 'ALPHA_X_DATABASE',
        calculationMethod: 'latest - earliest (requires at least 2 records for change)',
        recordCount: count,
        startDate,
        endDate,
        startValue: startingWeightKg,
        endValue: latestWeightKg,
        message: 'Insufficient data: only 1 weight record exists. At least 2 measurements are required to calculate change over time.',
      };
    }

    // 4. Calculate change and percentage change
    const changeKg = round2(latestWeightKg - startingWeightKg);

    let weightLostKg: number | null = null;
    if (changeKg < 0) {
      // Body weight decreased -> net weight lost
      weightLostKg = round2(startingWeightKg - latestWeightKg);
    } else {
      weightLostKg = null;
    }

    let percentageChange: number | null = null;
    if (startingWeightKg > 0) {
      percentageChange = round2(((latestWeightKg - startingWeightKg) / startingWeightKg) * 100);
    }

    return {
      metric: 'WEIGHT_SUMMARY',
      status: 'SUCCESS',
      value: {
        startingWeightKg,
        latestWeightKg,
        changeKg,
        weightLostKg,
        percentageChange,
        averageWeightKg,
        minimumWeightKg,
        maximumWeightKg,
        recordCount: count,
        startDate,
        endDate,
        unit: 'kg',
      },
      unit: 'kg',
      source: 'ALPHA_X_DATABASE',
      calculationMethod: 'change = latest - earliest; percentage = (change / earliest) * 100',
      recordCount: count,
      startDate,
      endDate,
      startValue: startingWeightKg,
      endValue: latestWeightKg,
    };
  }

  /**
   * Deterministically compares weight between two specific explicit dates/records.
   */
  public compareTwoDates(
    recordA: RawWeightEntry,
    recordB: RawWeightEntry
  ): CalculationResult<{
    earlierDate: string;
    laterDate: string;
    earlierWeightKg: number;
    laterWeightKg: number;
    changeKg: number;
    weightLostKg: number | null;
    percentageChange: number | null;
  }> {
    const dateA = recordA.date instanceof Date ? recordA.date : new Date(recordA.date);
    const dateB = recordB.date instanceof Date ? recordB.date : new Date(recordB.date);

    if (isNaN(dateA.getTime()) || isNaN(dateB.getTime())) {
      throw new InvalidCalculationInputError('DATE_WEIGHT_COMPARISON', 'Invalid comparison date provided');
    }

    if (recordA.weightKg <= 0 || recordB.weightKg <= 0) {
      throw new InvalidCalculationInputError('DATE_WEIGHT_COMPARISON', 'Comparison weight must be positive');
    }

    const [earlier, later] = dateA.getTime() <= dateB.getTime()
      ? [{ date: dateA, weight: recordA.weightKg }, { date: dateB, weight: recordB.weightKg }]
      : [{ date: dateB, weight: recordB.weightKg }, { date: dateA, weight: recordA.weightKg }];

    const earlierWeightKg = round2(earlier.weight);
    const laterWeightKg = round2(later.weight);
    const changeKg = round2(laterWeightKg - earlierWeightKg);
    const weightLostKg = changeKg < 0 ? round2(earlierWeightKg - laterWeightKg) : null;
    const percentageChange = earlierWeightKg > 0
      ? round2(((laterWeightKg - earlierWeightKg) / earlierWeightKg) * 100)
      : null;

    return {
      metric: 'DATE_WEIGHT_COMPARISON',
      status: 'SUCCESS',
      value: {
        earlierDate: earlier.date.toISOString().split('T')[0],
        laterDate: later.date.toISOString().split('T')[0],
        earlierWeightKg,
        laterWeightKg,
        changeKg,
        weightLostKg,
        percentageChange,
      },
      unit: 'kg',
      source: 'ALPHA_X_DATABASE',
      calculationMethod: 'laterWeight - earlierWeight',
      recordCount: 2,
      startDate: earlier.date.toISOString().split('T')[0],
      endDate: later.date.toISOString().split('T')[0],
      startValue: earlierWeightKg,
      endValue: laterWeightKg,
    };
  }
}

export const weightCalculator = new WeightCalculator();
