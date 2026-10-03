/**
 * Alpha X AI — Workout Intelligence Validation & Date Engine
 * Phase 9 — Workout Intelligence Engine
 */

import { validateDateRange, round2, safeAverage, safeMin, safeMax } from '../calculations/calculation.validation';
import { WorkoutIntelligenceError } from './workout_intelligence.errors';

export { validateDateRange, round2, safeAverage, safeMin, safeMax };

export interface PeriodDateSpan {
  startDateStr: string;
  endDateStr: string;
  startDate: Date;
  endDate: Date;
  days: number;
}

export interface PeriodComparisonDateSpans {
  current: PeriodDateSpan;
  previous: PeriodDateSpan;
}

/**
 * Computes contiguous current and previous comparison date intervals
 * based on presets (7, 14, 28 days) or custom day spans.
 */
export function computePresetComparisonDates(
  preset: 'last_7_days' | 'last_14_days' | 'last_28_days' | number,
  referenceDate: Date = new Date()
): PeriodComparisonDateSpans {
  let spanDays = 7;
  if (preset === 'last_14_days' || preset === 14) spanDays = 14;
  else if (preset === 'last_28_days' || preset === 28) spanDays = 28;
  else if (typeof preset === 'number' && preset > 0 && preset <= 180) spanDays = preset;

  // Truncate reference date to UTC midnight
  const refYear = referenceDate.getUTCFullYear();
  const refMonth = referenceDate.getUTCMonth();
  const refDay = referenceDate.getUTCDate();
  const endCurrent = new Date(Date.UTC(refYear, refMonth, refDay, 23, 59, 59, 999));

  // Current start = endCurrent - (spanDays - 1) days
  const startCurrent = new Date(endCurrent.getTime() - (spanDays - 1) * 24 * 60 * 60 * 1000);
  startCurrent.setUTCHours(0, 0, 0, 0);

  // Previous end = startCurrent - 1 ms
  const endPrevious = new Date(startCurrent.getTime() - 1);
  endPrevious.setUTCHours(23, 59, 59, 999);

  // Previous start = endPrevious - (spanDays - 1) days
  const startPrevious = new Date(endPrevious.getTime() - (spanDays - 1) * 24 * 60 * 60 * 1000);
  startPrevious.setUTCHours(0, 0, 0, 0);

  return {
    current: {
      startDateStr: startCurrent.toISOString().split('T')[0],
      endDateStr: endCurrent.toISOString().split('T')[0],
      startDate: startCurrent,
      endDate: endCurrent,
      days: spanDays,
    },
    previous: {
      startDateStr: startPrevious.toISOString().split('T')[0],
      endDateStr: endPrevious.toISOString().split('T')[0],
      startDate: startPrevious,
      endDate: endPrevious,
      days: spanDays,
    },
  };
}

/**
 * Validates custom comparison intervals, ensuring both periods are non-overlapping and chronologically valid.
 */
export function validateCustomComparisonIntervals(
  currentStartStr: string,
  currentEndStr: string,
  previousStartStr: string,
  previousEndStr: string
): PeriodComparisonDateSpans {
  const current = validateDateRange(currentStartStr, currentEndStr);
  const previous = validateDateRange(previousStartStr, previousEndStr);

  if (!current.start || !current.end || !previous.start || !previous.end) {
    throw new WorkoutIntelligenceError(
      'PERIOD_COMPARISON',
      'Both current and previous comparison periods require valid startDate and endDate'
    );
  }

  if (previous.start >= current.start) {
    throw new WorkoutIntelligenceError(
      'PERIOD_COMPARISON',
      'Previous period start date must precede current period start date'
    );
  }

  if (previous.end >= current.start) {
    throw new WorkoutIntelligenceError(
      'PERIOD_COMPARISON',
      'Comparison periods must be non-overlapping (previous period must end before current period begins)'
    );
  }

  const currentDays = Math.ceil((current.end.getTime() - current.start.getTime()) / (1000 * 60 * 60 * 24));
  const previousDays = Math.ceil((previous.end.getTime() - previous.start.getTime()) / (1000 * 60 * 60 * 24));

  return {
    current: {
      startDateStr: currentStartStr,
      endDateStr: currentEndStr,
      startDate: current.start,
      endDate: current.end,
      days: currentDays,
    },
    previous: {
      startDateStr: previousStartStr,
      endDateStr: previousEndStr,
      startDate: previous.start,
      endDate: previous.end,
      days: previousDays,
    },
  };
}
