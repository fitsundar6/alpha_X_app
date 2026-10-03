/**
 * Alpha X AI — Deterministic Steps & Activity Calculator
 * Phase 8 — Deterministic Fitness Calculation Engine
 */

import { CalculationResult, ActivitySummaryValue } from './calculation.types';
import { round2, safeAverage, safeMin, safeMax, safeSum } from './calculation.validation';

export interface RawActivityRecordEntry {
  date: Date | string;
  steps: number;
  stepGoal?: number | null;
  cardioMinutes?: number | null;
  caloriesBurned?: number | null;
  distanceMeters?: number | null;
  isGoalAchieved?: boolean | null;
}

export class ActivityCalculator {
  /**
   * Deterministically calculates activity and step metrics over recorded activity entries.
   *
   * Formulas:
   * - totalSteps = sum(steps)
   * - averageDailySteps = totalSteps / count
   * - minimumDailySteps = min(steps)
   * - maximumDailySteps = max(steps)
   * - totalCardioMinutes = sum(cardioMinutes)
   * - averageCardioMinutes = totalCardioMinutes / count
   * - totalCaloriesBurned = sum(caloriesBurned)
   * - averageCaloriesBurned = totalCaloriesBurned / count
   * - stepDifference = averageDailySteps - stepGoal (if goal exists)
   * - goalAchievementPercentage = (averageDailySteps / stepGoal) * 100
   */
  public calculateActivitySummary(
    records: RawActivityRecordEntry[],
    fallbackStepGoal?: number | null,
    startDateFilter?: string | null,
    endDateFilter?: string | null
  ): CalculationResult<ActivitySummaryValue> {
    if (!records || records.length === 0) {
      return {
        metric: 'ACTIVITY_SUMMARY',
        status: 'NO_RECORDS_FOUND',
        value: {
          totalSteps: 0,
          averageDailySteps: 0,
          minimumDailySteps: 0,
          maximumDailySteps: 0,
          totalCardioMinutes: 0,
          averageCardioMinutes: 0,
          totalCaloriesBurned: 0,
          averageCaloriesBurned: 0,
          daysRecorded: 0,
          stepGoal: fallbackStepGoal || null,
          stepDifference: null,
          goalAchievementPercentage: null,
          units: {
            steps: 'steps',
            cardio: 'minutes',
            energy: 'kcal',
          },
        },
        unit: 'steps, minutes, kcal',
        source: 'ALPHA_X_DATABASE',
        calculationMethod: 'sum and arithmetic means over recorded activity records',
        recordCount: 0,
        startDate: startDateFilter || null,
        endDate: endDateFilter || null,
        message: 'No activity or step records found for this client in the specified period.',
      };
    }

    const count = records.length;
    const stepsList = records.map((r) => Math.max(Number(r.steps) || 0, 0));
    const cardioList = records.map((r) => Math.max(Number(r.cardioMinutes) || 0, 0));
    const caloriesList = records.map((r) => Math.max(Number(r.caloriesBurned) || 0, 0));

    const totalSteps = stepsList.reduce((acc, curr) => acc + curr, 0);
    const averageDailySteps = round2(totalSteps / count);
    const minimumDailySteps = Math.min(...stepsList);
    const maximumDailySteps = Math.max(...stepsList);

    const totalCardioMinutes = cardioList.reduce((acc, curr) => acc + curr, 0);
    const averageCardioMinutes = round2(totalCardioMinutes / count);

    const totalCaloriesBurned = round2(caloriesList.reduce((acc, curr) => acc + curr, 0));
    const averageCaloriesBurned = round2(totalCaloriesBurned / count);

    // Determine representative step goal
    const explicitGoals = records
      .map((r) => r.stepGoal)
      .filter((g): g is number => typeof g === 'number' && g > 0);
    const effectiveGoal = explicitGoals.length > 0 ? explicitGoals[0] : (fallbackStepGoal && fallbackStepGoal > 0 ? fallbackStepGoal : null);

    let stepDifference: number | null = null;
    let goalAchievementPercentage: number | null = null;

    if (effectiveGoal && effectiveGoal > 0) {
      stepDifference = round2(averageDailySteps - effectiveGoal);
      goalAchievementPercentage = round2((averageDailySteps / effectiveGoal) * 100);
    }

    const dates = records
      .map((r) => (r.date instanceof Date ? r.date.toISOString().split('T')[0] : String(r.date).split('T')[0]))
      .sort();

    return {
      metric: 'ACTIVITY_SUMMARY',
      status: 'SUCCESS',
      value: {
        totalSteps,
        averageDailySteps,
        minimumDailySteps,
        maximumDailySteps,
        totalCardioMinutes,
        averageCardioMinutes,
        totalCaloriesBurned,
        averageCaloriesBurned,
        daysRecorded: count,
        stepGoal: effectiveGoal,
        stepDifference,
        goalAchievementPercentage,
        units: {
          steps: 'steps',
          cardio: 'minutes',
          energy: 'kcal',
        },
      },
      unit: 'steps, minutes, kcal',
      source: 'ALPHA_X_DATABASE',
      calculationMethod: 'totalSteps = sum(steps); avg = total / daysRecorded; goal% = (avg / goal) * 100',
      recordCount: count,
      startDate: dates[0] || startDateFilter || null,
      endDate: dates[dates.length - 1] || endDateFilter || null,
      startValue: averageDailySteps,
      endValue: totalSteps,
    };
  }
}

export const activityCalculator = new ActivityCalculator();
