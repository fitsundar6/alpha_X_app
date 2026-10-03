/**
 * Alpha X AI — Calculation Engine Validation & Formatting Helpers
 * Phase 8 — Deterministic Fitness Calculation Engine
 */

import { InvalidCalculationInputError } from './calculation.errors';

/**
 * Rounds a number to exactly two decimal places using standard arithmetic rounding.
 * Guarded against IEEE 754 precision artifacts.
 */
export function round2(value: number): number {
  if (value === null || value === undefined || isNaN(value) || !isFinite(value)) {
    return 0;
  }
  const result = Math.round((value + Number.EPSILON) * 100) / 100;
  return Object.is(result, -0) ? 0 : result;
}

/**
 * Validates whether a value is a valid finite positive number.
 */
export function isFinitePositiveNumber(value: any): boolean {
  return typeof value === 'number' && isFinite(value) && !isNaN(value) && value > 0;
}

/**
 * Validates whether a value is a valid finite non-negative number (>= 0).
 */
export function isFiniteNonNegativeNumber(value: any): boolean {
  return typeof value === 'number' && isFinite(value) && !isNaN(value) && value >= 0;
}

export interface ValidatedDateRange {
  start?: Date;
  end?: Date;
  startDateStr?: string;
  endDateStr?: string;
}

/**
 * Validates ISO date strings (YYYY-MM-DD), ensures chronological ordering (start <= end),
 * and enforces maximum query span limit of 365 days.
 */
export function validateDateRange(
  startDateStr?: string,
  endDateStr?: string
): ValidatedDateRange {
  if (!startDateStr && !endDateStr) {
    return {};
  }

  const dateRegex = /^\d{4}-\d{2}-\d{2}$/;

  let start: Date | undefined;
  let end: Date | undefined;

  if (startDateStr) {
    if (!dateRegex.test(startDateStr) || isNaN(Date.parse(startDateStr))) {
      throw new InvalidCalculationInputError(
        'DATE_RANGE',
        `Invalid startDate '${startDateStr}'. Format must be YYYY-MM-DD`
      );
    }
    start = new Date(`${startDateStr}T00:00:00.000Z`);
  }

  if (endDateStr) {
    if (!dateRegex.test(endDateStr) || isNaN(Date.parse(endDateStr))) {
      throw new InvalidCalculationInputError(
        'DATE_RANGE',
        `Invalid endDate '${endDateStr}'. Format must be YYYY-MM-DD`
      );
    }
    end = new Date(`${endDateStr}T23:59:59.999Z`);
  }

  if (start && end) {
    if (start > end) {
      throw new InvalidCalculationInputError(
        'DATE_RANGE',
        `startDate (${startDateStr}) cannot be after endDate (${endDateStr})`
      );
    }

    const diffDays = Math.ceil((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24));
    if (diffDays > 365) {
      throw new InvalidCalculationInputError(
        'DATE_RANGE',
        `Requested date range (${diffDays} days) exceeds maximum allowable span of 365 days`
      );
    }
  }

  return {
    start,
    end,
    startDateStr,
    endDateStr,
  };
}

/**
 * Safely computes arithmetic sum of numeric elements, skipping null/undefined/NaN.
 */
export function safeSum(values: Array<number | null | undefined>): number {
  let sum = 0;
  for (const v of values) {
    if (typeof v === 'number' && !isNaN(v) && isFinite(v)) {
      sum += v;
    }
  }
  return round2(sum);
}

/**
 * Safely computes arithmetic mean of numeric elements, skipping null/undefined/NaN.
 */
export function safeAverage(values: Array<number | null | undefined>): number | null {
  const valid = values.filter((v): v is number => typeof v === 'number' && !isNaN(v) && isFinite(v));
  if (valid.length === 0) return null;
  const sum = valid.reduce((acc, curr) => acc + curr, 0);
  return round2(sum / valid.length);
}

/**
 * Safely determines minimum value from numeric elements.
 */
export function safeMin(values: Array<number | null | undefined>): number | null {
  const valid = values.filter((v): v is number => typeof v === 'number' && !isNaN(v) && isFinite(v));
  if (valid.length === 0) return null;
  return round2(Math.min(...valid));
}

/**
 * Safely determines maximum value from numeric elements.
 */
export function safeMax(values: Array<number | null | undefined>): number | null {
  const valid = values.filter((v): v is number => typeof v === 'number' && !isNaN(v) && isFinite(v));
  if (valid.length === 0) return null;
  return round2(Math.max(...valid));
}
