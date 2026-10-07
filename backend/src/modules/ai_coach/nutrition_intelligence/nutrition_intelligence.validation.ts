/**
 * Alpha X AI — Nutrition Intelligence Validation & Date Helpers
 * Phase 10 — Nutrition Intelligence Engine
 */

import { NutritionDateRangeError } from './nutrition_intelligence.errors';

const ISO_DATE_REGEX = /^\d{4}-\d{2}-\d{2}$/;

/**
 * Validates that a string is a valid YYYY-MM-DD calendar date
 */
export function isValidDateString(dateStr: string): boolean {
  if (!dateStr || !ISO_DATE_REGEX.test(dateStr)) return false;
  const [year, month, day] = dateStr.split('-').map(Number);
  if (month < 1 || month > 12) return false;
  if (day < 1 || day > 31) return false;
  const d = new Date(Date.UTC(year, month - 1, day));
  return (
    d.getUTCFullYear() === year &&
    d.getUTCMonth() === month - 1 &&
    d.getUTCDate() === day
  );
}

/**
 * Formats a Date object to YYYY-MM-DD (UTC)
 */
export function formatDateToIso(date: Date): string {
  const y = date.getUTCFullYear();
  const m = String(date.getUTCMonth() + 1).padStart(2, '0');
  const d = String(date.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

/**
 * Validates and normalizes optional startDate and endDate filters
 */
export function validateNutritionDateRange(
  startDate?: string,
  endDate?: string
): {
  start: Date | null;
  end: Date | null;
  startDateStr: string | null;
  endDateStr: string | null;
  elapsedDays: number | null;
} {
  let start: Date | null = null;
  let end: Date | null = null;
  let startDateStr: string | null = null;
  let endDateStr: string | null = null;

  if (startDate) {
    if (!isValidDateString(startDate)) {
      throw new NutritionDateRangeError(`startDate '${startDate}' must be a valid YYYY-MM-DD format.`);
    }
    const [y, m, d] = startDate.split('-').map(Number);
    start = new Date(Date.UTC(y, m - 1, d, 0, 0, 0, 0));
    startDateStr = startDate;
  }

  if (endDate) {
    if (!isValidDateString(endDate)) {
      throw new NutritionDateRangeError(`endDate '${endDate}' must be a valid YYYY-MM-DD format.`);
    }
    const [y, m, d] = endDate.split('-').map(Number);
    end = new Date(Date.UTC(y, m - 1, d, 23, 59, 59, 999));
    endDateStr = endDate;
  }

  if (start && end && start.getTime() > end.getTime()) {
    throw new NutritionDateRangeError(`startDate (${startDateStr}) cannot be after endDate (${endDateStr}).`);
  }

  let elapsedDays: number | null = null;
  if (start && end) {
    const diffMs = end.getTime() - start.getTime();
    elapsedDays = Math.max(1, Math.round(diffMs / (1000 * 60 * 60 * 24)));
  }

  return { start, end, startDateStr, endDateStr, elapsedDays };
}

/**
 * Calculates number of elapsed calendar days between two dates inclusive
 */
export function calculateElapsedDays(startDateStr: string, endDateStr: string): number {
  if (!isValidDateString(startDateStr) || !isValidDateString(endDateStr)) {
    return 1;
  }
  const [y1, m1, d1] = startDateStr.split('-').map(Number);
  const [y2, m2, d2] = endDateStr.split('-').map(Number);
  const t1 = Date.UTC(y1, m1 - 1, d1);
  const t2 = Date.UTC(y2, m2 - 1, d2);
  const diff = Math.abs(t2 - t1);
  return Math.max(1, Math.round(diff / (1000 * 60 * 60 * 24)) + 1);
}

/**
 * IEEE 754 safe precision rounding to 2 decimal places
 */
export function round2(num: number): number {
  if (!Number.isFinite(num)) return 0;
  return Math.round((num + Number.EPSILON) * 100) / 100;
}

/**
 * Safe number parsing with zero fallback
 */
export function safeNumber(val: any, defaultVal = 0): number {
  const n = Number(val);
  return Number.isFinite(n) ? n : defaultVal;
}

/**
 * Computes preset comparison dates for period comparisons
 */
export function computePresetComparisonNutritionDates(
  preset: string,
  referenceDate: Date = new Date()
): {
  period1: { startDate: string; endDate: string; label: string };
  period2: { startDate: string; endDate: string; label: string };
} {
  const today = new Date(Date.UTC(referenceDate.getUTCFullYear(), referenceDate.getUTCMonth(), referenceDate.getUTCDate()));

  switch (preset.toUpperCase()) {
    case 'LAST_7_DAYS_VS_PREVIOUS_7_DAYS': {
      // Period 2: Days -6 to 0 (last 7 days including today)
      const p2End = new Date(today);
      const p2Start = new Date(today);
      p2Start.setUTCDate(p2Start.getUTCDate() - 6);

      // Period 1: Days -13 to -7
      const p1End = new Date(today);
      p1End.setUTCDate(p1End.getUTCDate() - 7);
      const p1Start = new Date(today);
      p1Start.setUTCDate(p1Start.getUTCDate() - 13);

      return {
        period1: {
          startDate: formatDateToIso(p1Start),
          endDate: formatDateToIso(p1End),
          label: 'Previous 7 Days',
        },
        period2: {
          startDate: formatDateToIso(p2Start),
          endDate: formatDateToIso(p2End),
          label: 'Last 7 Days',
        },
      };
    }

    case 'LAST_14_DAYS_VS_PREVIOUS_14_DAYS': {
      const p2End = new Date(today);
      const p2Start = new Date(today);
      p2Start.setUTCDate(p2Start.getUTCDate() - 13);

      const p1End = new Date(today);
      p1End.setUTCDate(p1End.getUTCDate() - 14);
      const p1Start = new Date(today);
      p1Start.setUTCDate(p1Start.getUTCDate() - 27);

      return {
        period1: {
          startDate: formatDateToIso(p1Start),
          endDate: formatDateToIso(p1End),
          label: 'Previous 14 Days',
        },
        period2: {
          startDate: formatDateToIso(p2Start),
          endDate: formatDateToIso(p2End),
          label: 'Last 14 Days',
        },
      };
    }

    case 'THIS_WEEK_VS_LAST_WEEK':
    default: {
      // Find Monday of current week (assuming Mon=1 ... Sun=7)
      const dayOfWeek = today.getUTCDay(); // 0 is Sunday
      const diffToMonday = dayOfWeek === 0 ? -6 : 1 - dayOfWeek;
      const thisMonday = new Date(today);
      thisMonday.setUTCDate(thisMonday.getUTCDate() + diffToMonday);

      const lastMonday = new Date(thisMonday);
      lastMonday.setUTCDate(lastMonday.getUTCDate() - 7);
      const lastSunday = new Date(thisMonday);
      lastSunday.setUTCDate(lastSunday.getUTCDate() - 1);

      return {
        period1: {
          startDate: formatDateToIso(lastMonday),
          endDate: formatDateToIso(lastSunday),
          label: 'Last Week',
        },
        period2: {
          startDate: formatDateToIso(thisMonday),
          endDate: formatDateToIso(today),
          label: 'This Week',
        },
      };
    }
  }
}

/**
 * Validates custom comparison intervals
 */
export function validateCustomNutritionComparison(
  p1Start?: string,
  p1End?: string,
  p2Start?: string,
  p2End?: string
): {
  period1: { startDate: string; endDate: string; label: string };
  period2: { startDate: string; endDate: string; label: string };
} {
  if (!p1Start || !p1End || !p2Start || !p2End) {
    throw new NutritionDateRangeError('All four dates (p1StartDate, p1EndDate, p2StartDate, p2EndDate) are required for custom comparison.');
  }

  const range1 = validateNutritionDateRange(p1Start, p1End);
  const range2 = validateNutritionDateRange(p2Start, p2End);

  if (!range1.startDateStr || !range1.endDateStr || !range2.startDateStr || !range2.endDateStr) {
    throw new NutritionDateRangeError('Invalid date bounds provided for period comparison.');
  }

  return {
    period1: {
      startDate: range1.startDateStr,
      endDate: range1.endDateStr,
      label: `Period 1 (${range1.startDateStr} to ${range1.endDateStr})`,
    },
    period2: {
      startDate: range2.startDateStr,
      endDate: range2.endDateStr,
      label: `Period 2 (${range2.startDateStr} to ${range2.endDateStr})`,
    },
  };
}
