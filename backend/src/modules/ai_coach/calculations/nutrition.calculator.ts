/**
 * Alpha X AI — Deterministic Nutrition & Macro Calculator
 * Phase 8 — Deterministic Fitness Calculation Engine
 */

import {
  CalculationResult,
  NutritionSummaryValue,
  NutritionTargetComparisonValue,
} from './calculation.types';
import { round2, safeSum } from './calculation.validation';

export interface RawFoodLogEntry {
  dateString: string; // 'YYYY-MM-DD'
  calories: number;
  protein: number;
  carbohydrates: number;
  fat: number;
  fiber?: number | null;
}

export interface AssignedDietTarget {
  planName?: string;
  dailyCalories: number;
  protein: number;
  carbohydrates: number;
  fat: number;
  fiber: number;
}

export class NutritionCalculator {
  /**
   * Deterministically calculates aggregated nutrition and daily averages from actual client food logs.
   *
   * Formulas:
   * - totalLoggedCalories = sum(calories)
   * - distinctDaysCount = count of unique dateString days containing food logs
   * - averageDailyCalories = totalLoggedCalories / distinctDaysCount
   * - averageDailyProtein = totalLoggedProtein / distinctDaysCount
   * - averageDailyCarbs = totalLoggedCarbs / distinctDaysCount
   * - averageDailyFat = totalLoggedFat / distinctDaysCount
   * - averageDailyFiber = totalLoggedFiber / distinctDaysCount
   */
  public calculateNutritionSummary(
    foodLogs: RawFoodLogEntry[],
    startDateFilter?: string | null,
    endDateFilter?: string | null
  ): CalculationResult<NutritionSummaryValue> {
    if (!foodLogs || foodLogs.length === 0) {
      return {
        metric: 'NUTRITION_SUMMARY',
        status: 'NO_RECORDS_FOUND',
        value: {
          totalLoggedCalories: 0,
          totalLoggedProtein: 0,
          totalLoggedCarbs: 0,
          totalLoggedFat: 0,
          totalLoggedFiber: 0,
          distinctDaysCount: 0,
          totalLogsCount: 0,
          averageDailyCalories: 0,
          averageDailyProtein: 0,
          averageDailyCarbs: 0,
          averageDailyFat: 0,
          averageDailyFiber: 0,
          units: {
            calories: 'kcal',
            protein: 'g',
            carbs: 'g',
            fat: 'g',
            fiber: 'g',
          },
        },
        unit: 'kcal, grams',
        source: 'ALPHA_X_DATABASE',
        calculationMethod: 'sum of logged items; daily average = total / distinct logged days',
        recordCount: 0,
        startDate: startDateFilter || null,
        endDate: endDateFilter || null,
        message: 'No logged food items found for this client in the specified period.',
      };
    }

    // 1. Group records by unique dateString to identify logged days
    const uniqueDays = new Set<string>();
    let totalCalories = 0;
    let totalProtein = 0;
    let totalCarbs = 0;
    let totalFat = 0;
    let totalFiber = 0;

    for (const log of foodLogs) {
      if (log.dateString) {
        uniqueDays.add(log.dateString);
      }
      totalCalories += Math.max(Number(log.calories) || 0, 0);
      totalProtein += Math.max(Number(log.protein) || 0, 0);
      totalCarbs += Math.max(Number(log.carbohydrates) || 0, 0);
      totalFat += Math.max(Number(log.fat) || 0, 0);
      totalFiber += Math.max(Number(log.fiber) || 0, 0);
    }

    const distinctDaysCount = Math.max(uniqueDays.size, 1);
    const totalLogsCount = foodLogs.length;

    const roundedTotalCalories = round2(totalCalories);
    const roundedTotalProtein = round2(totalProtein);
    const roundedTotalCarbs = round2(totalCarbs);
    const roundedTotalFat = round2(totalFat);
    const roundedTotalFiber = round2(totalFiber);

    const averageDailyCalories = round2(roundedTotalCalories / distinctDaysCount);
    const averageDailyProtein = round2(roundedTotalProtein / distinctDaysCount);
    const averageDailyCarbs = round2(roundedTotalCarbs / distinctDaysCount);
    const averageDailyFat = round2(roundedTotalFat / distinctDaysCount);
    const averageDailyFiber = round2(roundedTotalFiber / distinctDaysCount);

    const sortedDays = Array.from(uniqueDays).sort();
    const startDate = sortedDays[0] || startDateFilter || null;
    const endDate = sortedDays[sortedDays.length - 1] || endDateFilter || null;

    return {
      metric: 'NUTRITION_SUMMARY',
      status: 'SUCCESS',
      value: {
        totalLoggedCalories: roundedTotalCalories,
        totalLoggedProtein: roundedTotalProtein,
        totalLoggedCarbs: roundedTotalCarbs,
        totalLoggedFat: roundedTotalFat,
        totalLoggedFiber: roundedTotalFiber,
        distinctDaysCount: uniqueDays.size,
        totalLogsCount,
        averageDailyCalories,
        averageDailyProtein,
        averageDailyCarbs,
        averageDailyFat,
        averageDailyFiber,
        units: {
          calories: 'kcal',
          protein: 'g',
          carbs: 'g',
          fat: 'g',
          fiber: 'g',
        },
      },
      unit: 'kcal, grams',
      source: 'ALPHA_X_DATABASE',
      calculationMethod: 'total / distinct logged days',
      recordCount: totalLogsCount,
      startDate,
      endDate,
      startValue: averageDailyCalories,
      endValue: averageDailyProtein,
    };
  }

  /**
   * Deterministically calculates the mathematical comparison between assigned target and actual daily intake.
   *
   * Formulas:
   * - difference = actualAverage - assignedTarget
   *
   * Strict Rule: Keeps Assigned Target and Actual Logged Intake strictly separate.
   */
  public compareTargetVsActual(
    target: AssignedDietTarget,
    actualSummary: NutritionSummaryValue
  ): CalculationResult<NutritionTargetComparisonValue> {
    const calorieDiff = round2(actualSummary.averageDailyCalories - target.dailyCalories);
    const proteinDiff = round2(actualSummary.averageDailyProtein - target.protein);
    const carbsDiff = round2(actualSummary.averageDailyCarbs - target.carbohydrates);
    const fatDiff = round2(actualSummary.averageDailyFat - target.fat);
    const fiberDiff = round2(actualSummary.averageDailyFiber - target.fiber);

    return {
      metric: 'NUTRITION_TARGET_COMPARISON',
      status: 'SUCCESS',
      value: {
        target: {
          planName: target.planName || 'Active Diet Plan',
          calories: round2(target.dailyCalories),
          protein: round2(target.protein),
          carbs: round2(target.carbohydrates),
          fat: round2(target.fat),
          fiber: round2(target.fiber),
        },
        actualAverage: {
          calories: actualSummary.averageDailyCalories,
          protein: actualSummary.averageDailyProtein,
          carbs: actualSummary.averageDailyCarbs,
          fat: actualSummary.averageDailyFat,
          fiber: actualSummary.averageDailyFiber,
          daysCount: actualSummary.distinctDaysCount,
        },
        difference: {
          calories: calorieDiff,
          protein: proteinDiff,
          carbs: carbsDiff,
          fat: fatDiff,
          fiber: fiberDiff,
        },
        units: {
          calories: 'kcal',
          protein: 'g',
          carbs: 'g',
          fat: 'g',
          fiber: 'g',
        },
        note: 'Mathematical difference is defined as (actualAverage - target). Negative value denotes intake below target; positive denotes intake above target.',
      },
      unit: 'kcal, grams',
      source: 'ALPHA_X_DATABASE',
      calculationMethod: 'difference = actualAverage - target',
      recordCount: actualSummary.totalLogsCount,
      startDate: null,
      endDate: null,
    };
  }
}

export const nutritionCalculator = new NutritionCalculator();
