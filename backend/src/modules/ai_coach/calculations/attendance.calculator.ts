/**
 * Alpha X AI — Deterministic Attendance Calculator
 * Phase 8 — Deterministic Fitness Calculation Engine
 */

import { CalculationResult, AttendanceSummaryValue } from './calculation.types';
import { round2 } from './calculation.validation';

export interface RawAttendanceEntry {
  date: Date | string;
  present: boolean;
  method?: string;
  checkInTime?: Date | string;
}

export class AttendanceCalculator {
  /**
   * Deterministically calculates gym attendance metrics over recorded attendance entries.
   *
   * Formulas:
   * - totalRecords = count
   * - presentCount = count(where present === true)
   * - absentCount = count(where present === false)
   * - attendancePercentage = (presentCount / totalRecords) * 100
   *
   * Strict Rule: Missing calendar dates are NEVER fabricated as absences.
   * Calculations operate strictly over recorded attendance entries.
   */
  public calculateAttendanceSummary(
    records: RawAttendanceEntry[],
    startDateFilter?: string | null,
    endDateFilter?: string | null
  ): CalculationResult<AttendanceSummaryValue> {
    if (!records || records.length === 0) {
      return {
        metric: 'ATTENDANCE_SUMMARY',
        status: 'NO_RECORDS_FOUND',
        value: {
          totalRecords: 0,
          presentCount: 0,
          absentCount: 0,
          attendancePercentage: 0,
          unit: 'percentage',
          note: 'Evaluated strictly over recorded gym attendance logs. Unrecorded dates are never treated as absences.',
        },
        unit: 'percentage',
        source: 'ALPHA_X_DATABASE',
        calculationMethod: 'attendancePercentage = (presentCount / totalRecords) * 100',
        recordCount: 0,
        startDate: startDateFilter || null,
        endDate: endDateFilter || null,
        message: 'No gym attendance records recorded for this client in the specified period.',
      };
    }

    const totalRecords = records.length;
    let presentCount = 0;
    let absentCount = 0;

    for (const r of records) {
      if (r.present === true) {
        presentCount++;
      } else {
        absentCount++;
      }
    }

    const attendancePercentage = round2((presentCount / totalRecords) * 100);

    const dates = records
      .map((r) => (r.date instanceof Date ? r.date.toISOString().split('T')[0] : String(r.date).split('T')[0]))
      .sort();

    return {
      metric: 'ATTENDANCE_SUMMARY',
      status: 'SUCCESS',
      value: {
        totalRecords,
        presentCount,
        absentCount,
        attendancePercentage,
        unit: 'percentage',
        note: 'Evaluated strictly over recorded gym attendance logs. Unrecorded dates are never treated as absences.',
      },
      unit: 'percentage',
      source: 'ALPHA_X_DATABASE',
      calculationMethod: 'attendancePercentage = (presentCount / totalRecords) * 100',
      recordCount: totalRecords,
      startDate: dates[0] || startDateFilter || null,
      endDate: dates[dates.length - 1] || endDateFilter || null,
      startValue: presentCount,
      endValue: attendancePercentage,
    };
  }
}

export const attendanceCalculator = new AttendanceCalculator();
