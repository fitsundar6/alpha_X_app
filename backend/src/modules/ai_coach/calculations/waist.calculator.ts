/**
 * Alpha X AI — Deterministic Waist Measurement Calculator
 * Phase 8 — Deterministic Fitness Calculation Engine
 */

import { CalculationResult, WaistSummaryValue } from './calculation.types';
import { round2, safeAverage, safeMin, safeMax } from './calculation.validation';
import { InvalidCalculationInputError } from './calculation.errors';

export interface RawWaistEntry {
  date: Date | string;
  waistCm?: number | null;
}

export class WaistCalculator {
  /**
   * Deterministically calculates waist circumference progress metrics over a series of records.
   *
   * Formulas:
   * - changeCm = latestWaist - startingWaist
   * - percentageChange = ((latestWaist - startingWaist) / startingWaist) * 100
   * - averageWaist = sum(waists) / count
   * - minimumWaist = min(waists)
   * - maximumWaist = max(waists)
   *
   * Units: Strictly centimeters (cm).
   */
  public calculateWaistSummary(
    rawRecords: RawWaistEntry[],
    startDateFilter?: string | null,
    endDateFilter?: string | null
  ): CalculationResult<WaistSummaryValue> {
    if (!rawRecords || rawRecords.length === 0) {
      return {
        metric: 'WAIST_SUMMARY',
        status: 'NO_RECORDS_FOUND',
        value: {
          startingWaistCm: null,
          latestWaistCm: null,
          changeCm: null,
          percentageChange: null,
          averageWaistCm: null,
          minimumWaistCm: null,
          maximumWaistCm: null,
          recordCount: 0,
          startDate: startDateFilter || null,
          endDate: endDateFilter || null,
          unit: 'cm',
        },
        unit: 'cm',
        source: 'ALPHA_X_DATABASE',
        calculationMethod: 'latest - earliest; arithmetic mean; min/max',
        recordCount: 0,
        startDate: startDateFilter || null,
        endDate: endDateFilter || null,
        startValue: null,
        endValue: null,
        message: 'No recorded waist measurement entries found for this client in the specified period.',
      };
    }

    // 1. Filter records where waistCm is recorded and positive
    const validRecords = rawRecords
      .map((r) => {
        const d = r.date instanceof Date ? r.date : new Date(r.date);
        const w = r.waistCm !== null && r.waistCm !== undefined ? Number(r.waistCm) : null;
        return { date: d, waistCm: w };
      })
      .filter((r): r is { date: Date; waistCm: number } => {
        if (isNaN(r.date.getTime())) return false;
        if (r.waistCm === null || isNaN(r.waistCm) || !isFinite(r.waistCm)) return false;
        if (r.waistCm <= 0) return false;
        return true;
      });

    if (validRecords.length === 0) {
      return {
        metric: 'WAIST_SUMMARY',
        status: 'NO_RECORDS_FOUND',
        value: {
          startingWaistCm: null,
          latestWaistCm: null,
          changeCm: null,
          percentageChange: null,
          averageWaistCm: null,
          minimumWaistCm: null,
          maximumWaistCm: null,
          recordCount: 0,
          startDate: startDateFilter || null,
          endDate: endDateFilter || null,
          unit: 'cm',
        },
        unit: 'cm',
        source: 'ALPHA_X_DATABASE',
        calculationMethod: 'latest - earliest; arithmetic mean; min/max',
        recordCount: 0,
        startDate: startDateFilter || null,
        endDate: endDateFilter || null,
        startValue: null,
        endValue: null,
        message: 'No non-null waist circumference records found in the retrieved dataset.',
      };
    }

    // 2. Sort chronologically ascending
    validRecords.sort((a, b) => a.date.getTime() - b.date.getTime());

    const waists = validRecords.map((r) => r.waistCm);
    const count = validRecords.length;
    const earliest = validRecords[0];
    const latest = validRecords[count - 1];

    const startingWaistCm = round2(earliest.waistCm);
    const latestWaistCm = round2(latest.waistCm);
    const averageWaistCm = safeAverage(waists);
    const minimumWaistCm = safeMin(waists);
    const maximumWaistCm = safeMax(waists);

    const startDate = earliest.date.toISOString().split('T')[0];
    const endDate = latest.date.toISOString().split('T')[0];

    // 3. Insufficient data guard for change calculation
    if (count < 2) {
      return {
        metric: 'WAIST_SUMMARY',
        status: 'INSUFFICIENT_DATA',
        value: {
          startingWaistCm,
          latestWaistCm,
          changeCm: null,
          percentageChange: null,
          averageWaistCm,
          minimumWaistCm,
          maximumWaistCm,
          recordCount: count,
          startDate,
          endDate,
          unit: 'cm',
        },
        unit: 'cm',
        source: 'ALPHA_X_DATABASE',
        calculationMethod: 'latest - earliest (requires at least 2 records for change)',
        recordCount: count,
        startDate,
        endDate,
        startValue: startingWaistCm,
        endValue: latestWaistCm,
        message: 'Insufficient data: only 1 waist measurement exists. At least 2 measurements are required to calculate change over time.',
      };
    }

    // 4. Calculate change and percentage change
    const changeCm = round2(latestWaistCm - startingWaistCm);
    let percentageChange: number | null = null;
    if (startingWaistCm > 0) {
      percentageChange = round2(((latestWaistCm - startingWaistCm) / startingWaistCm) * 100);
    }

    return {
      metric: 'WAIST_SUMMARY',
      status: 'SUCCESS',
      value: {
        startingWaistCm,
        latestWaistCm,
        changeCm,
        percentageChange,
        averageWaistCm,
        minimumWaistCm,
        maximumWaistCm,
        recordCount: count,
        startDate,
        endDate,
        unit: 'cm',
      },
      unit: 'cm',
      source: 'ALPHA_X_DATABASE',
      calculationMethod: 'change = latest - earliest; percentage = (change / earliest) * 100',
      recordCount: count,
      startDate,
      endDate,
      startValue: startingWaistCm,
      endValue: latestWaistCm,
    };
  }
}

export const waistCalculator = new WaistCalculator();
