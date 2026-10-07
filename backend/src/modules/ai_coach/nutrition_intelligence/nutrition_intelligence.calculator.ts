/**
 * Alpha X AI — Deterministic Nutrition Intelligence Calculator
 * Phase 10 — Nutrition Intelligence Engine
 *
 * PURE MATHEMATICAL IMPLEMENTATION: ZERO DATABASE DEPENDENCIES.
 * Evaluates real client nutrition data using deterministic, audited arithmetic.
 */

import {
  RawFoodLogItem,
  NutritionTarget,
  DailyNutritionBreakdown,
  MealSummary,
  NutritionSummaryAnalysis,
  NutritionHistoryAnalysis,
  WeeklyNutritionRollup,
  MealBreakdownAnalysis,
  MealBreakdownTypeStats,
  NutritionPeriodComparison,
  MacroCaloriesAndPercentages,
  FoodItemSummary,
} from './nutrition_intelligence.types';
import { round2, safeNumber, calculateElapsedDays, isValidDateString } from './nutrition_intelligence.validation';

export class NutritionIntelligenceCalculator {
  /**
   * Computes macronutrient caloric contributions and percentage split.
   * Standard conversion: Protein = 4 kcal/g, Carbohydrates = 4 kcal/g, Fat = 9 kcal/g.
   */
  public calculateMacroCaloriesAndPercentages(
    proteinGrams: number,
    carbsGrams: number,
    fatGrams: number
  ): MacroCaloriesAndPercentages {
    const proteinKcal = round2(Math.max(0, proteinGrams) * 4);
    const carbsKcal = round2(Math.max(0, carbsGrams) * 4);
    const fatKcal = round2(Math.max(0, fatGrams) * 9);
    const totalMacroKcal = round2(proteinKcal + carbsKcal + fatKcal);

    let proteinPct = 0;
    let carbsPct = 0;
    let fatPct = 0;

    if (totalMacroKcal > 0) {
      proteinPct = round2((proteinKcal / totalMacroKcal) * 100);
      carbsPct = round2((carbsKcal / totalMacroKcal) * 100);
      fatPct = round2((fatKcal / totalMacroKcal) * 100);
    }

    return {
      proteinKcal,
      carbsKcal,
      fatKcal,
      totalMacroKcal,
      proteinPct,
      carbsPct,
      fatPct,
    };
  }

  /**
   * Calculates a detailed nutrition breakdown for a single calendar day across all meals and items.
   */
  public calculateDailyNutrition(
    foodLogs: RawFoodLogItem[],
    target?: NutritionTarget | null,
    targetDate?: string
  ): DailyNutritionBreakdown {
    const date = targetDate || (foodLogs.length > 0 ? foodLogs[0].dateString : 'UNKNOWN');

    if (!foodLogs || foodLogs.length === 0) {
      return {
        date,
        totalCalories: 0,
        totalProtein: 0,
        totalCarbs: 0,
        totalFat: 0,
        totalFiber: 0,
        macroCalories: { proteinKcal: 0, carbsKcal: 0, fatKcal: 0 },
        macroPercentages: { proteinPct: 0, carbsPct: 0, fatPct: 0 },
        loggedItemsCount: 0,
        mealCounts: {},
        meals: {},
        targetComparison: target
          ? {
              targetCalories: round2(target.dailyCalories),
              targetProtein: round2(target.protein),
              targetCarbs: round2(target.carbohydrates),
              targetFat: round2(target.fat),
              targetFiber: round2(target.fiber),
              calorieDiff: round2(0 - target.dailyCalories),
              proteinDiff: round2(0 - target.protein),
              carbsDiff: round2(0 - target.carbohydrates),
              fatDiff: round2(0 - target.fat),
              fiberDiff: round2(0 - target.fiber),
              calorieAdherencePct: 0,
              proteinAdherencePct: 0,
              isCalorieCompliant: false,
              isProteinCompliant: false,
            }
          : undefined,
      };
    }

    let totalCalories = 0;
    let totalProtein = 0;
    let totalCarbs = 0;
    let totalFat = 0;
    let totalFiber = 0;

    // Group logs by mealType
    const mealBuckets: { [mealType: string]: RawFoodLogItem[] } = {};

    for (const log of foodLogs) {
      const cal = Math.max(0, safeNumber(log.calories));
      const p = Math.max(0, safeNumber(log.protein));
      const c = Math.max(0, safeNumber(log.carbohydrates));
      const f = Math.max(0, safeNumber(log.fat));
      const fib = Math.max(0, safeNumber(log.fiber));

      totalCalories += cal;
      totalProtein += p;
      totalCarbs += c;
      totalFat += f;
      totalFiber += fib;

      const rawMealType = (log.mealType || 'General').trim();
      const mealKey = rawMealType.charAt(0).toUpperCase() + rawMealType.slice(1).toLowerCase();
      if (!mealBuckets[mealKey]) {
        mealBuckets[mealKey] = [];
      }
      mealBuckets[mealKey].push(log);
    }

    const roundedCalories = round2(totalCalories);
    const roundedProtein = round2(totalProtein);
    const roundedCarbs = round2(totalCarbs);
    const roundedFat = round2(totalFat);
    const roundedFiber = round2(totalFiber);

    const macroSplit = this.calculateMacroCaloriesAndPercentages(roundedProtein, roundedCarbs, roundedFat);

    // Build meal summaries
    const meals: { [mealType: string]: MealSummary } = {};
    const mealCounts: { [mealType: string]: number } = {};

    for (const [mealType, items] of Object.entries(mealBuckets)) {
      let mealCal = 0;
      let mealP = 0;
      let mealC = 0;
      let mealF = 0;
      let mealFib = 0;
      const itemSummaries: FoodItemSummary[] = [];

      for (const item of items) {
        const cal = Math.max(0, safeNumber(item.calories));
        const p = Math.max(0, safeNumber(item.protein));
        const c = Math.max(0, safeNumber(item.carbohydrates));
        const f = Math.max(0, safeNumber(item.fat));
        const fib = Math.max(0, safeNumber(item.fiber));

        mealCal += cal;
        mealP += p;
        mealC += c;
        mealF += f;
        mealFib += fib;

        itemSummaries.push({
          foodName: item.foodName || 'Food Item',
          category: item.category || 'General',
          quantity: safeNumber(item.quantity, 1),
          servingSize: safeNumber(item.servingSize, 100),
          servingUnit: item.servingUnit || 'g',
          calories: round2(cal),
          protein: round2(p),
          carbohydrates: round2(c),
          fat: round2(f),
          fiber: round2(fib),
        });
      }

      const rMealCal = round2(mealCal);
      const rMealP = round2(mealP);
      const rMealC = round2(mealC);
      const rMealF = round2(mealF);
      const rMealFib = round2(mealFib);

      mealCounts[mealType] = items.length;
      meals[mealType] = {
        mealType,
        itemsCount: items.length,
        calories: rMealCal,
        protein: rMealP,
        carbohydrates: rMealC,
        fat: rMealF,
        fiber: rMealFib,
        percentageOfDailyCalories: roundedCalories > 0 ? round2((rMealCal / roundedCalories) * 100) : 0,
        items: itemSummaries,
      };
    }

    // Target comparison for this day
    let targetComparison: DailyNutritionBreakdown['targetComparison'];
    if (target) {
      const targetCal = round2(target.dailyCalories);
      const targetP = round2(target.protein);
      const targetC = round2(target.carbohydrates);
      const targetF = round2(target.fat);
      const targetFib = round2(target.fiber);

      const calorieDiff = round2(roundedCalories - targetCal);
      const proteinDiff = round2(roundedProtein - targetP);
      const carbsDiff = round2(roundedCarbs - targetC);
      const fatDiff = round2(roundedFat - targetF);
      const fiberDiff = round2(roundedFiber - targetFib);

      const calorieAdherencePct = targetCal > 0 ? round2((roundedCalories / targetCal) * 100) : 0;
      const proteinAdherencePct = targetP > 0 ? round2((roundedProtein / targetP) * 100) : 0;

      // Within ±10% for calories, >= 90% for protein
      const isCalorieCompliant = targetCal > 0 && Math.abs(calorieDiff) <= targetCal * 0.1;
      const isProteinCompliant = targetP > 0 && roundedProtein >= targetP * 0.9;

      targetComparison = {
        targetCalories: targetCal,
        targetProtein: targetP,
        targetCarbs: targetC,
        targetFat: targetF,
        targetFiber: targetFib,
        calorieDiff,
        proteinDiff,
        carbsDiff,
        fatDiff,
        fiberDiff,
        calorieAdherencePct,
        proteinAdherencePct,
        isCalorieCompliant,
        isProteinCompliant,
      };
    }

    return {
      date,
      totalCalories: roundedCalories,
      totalProtein: roundedProtein,
      totalCarbs: roundedCarbs,
      totalFat: roundedFat,
      totalFiber: roundedFiber,
      macroCalories: {
        proteinKcal: macroSplit.proteinKcal,
        carbsKcal: macroSplit.carbsKcal,
        fatKcal: macroSplit.fatKcal,
      },
      macroPercentages: {
        proteinPct: macroSplit.proteinPct,
        carbsPct: macroSplit.carbsPct,
        fatPct: macroSplit.fatPct,
      },
      loggedItemsCount: foodLogs.length,
      mealCounts,
      meals,
      targetComparison,
    };
  }

  /**
   * Calculates comprehensive multi-day aggregated nutrition summary,
   * daily averages over logged days and calendar days, macro caloric splits,
   * target compliance adherence, and missing data diagnostics.
   */
  public calculateNutritionSummary(
    foodLogs: RawFoodLogItem[],
    target?: NutritionTarget | null,
    startDateFilter?: string | null,
    endDateFilter?: string | null
  ): NutritionSummaryAnalysis {
    if (!foodLogs || foodLogs.length === 0) {
      const elapsedDays = startDateFilter && endDateFilter
        ? calculateElapsedDays(startDateFilter, endDateFilter)
        : 0;

      return {
        dateRange: {
          startDate: startDateFilter || null,
          endDate: endDateFilter || null,
          elapsedDays,
        },
        totalLoggedCalories: 0,
        totalLoggedProtein: 0,
        totalLoggedCarbs: 0,
        totalLoggedFat: 0,
        totalLoggedFiber: 0,
        distinctLoggedDays: 0,
        unloggedDaysCount: elapsedDays,
        loggingAdherencePct: 0,
        totalLogsCount: 0,
        averageDailyCalories: 0,
        averageDailyProtein: 0,
        averageDailyCarbs: 0,
        averageDailyFat: 0,
        averageDailyFiber: 0,
        calendarAverageDailyCalories: 0,
        macroCaloricSplit: {
          proteinKcal: 0,
          carbsKcal: 0,
          fatKcal: 0,
          totalMacroKcal: 0,
          proteinPct: 0,
          carbsPct: 0,
          fatPct: 0,
        },
        targetComparison: target
          ? {
              hasActiveTarget: true,
              target,
              difference: {
                calories: round2(0 - target.dailyCalories),
                protein: round2(0 - target.protein),
                carbs: round2(0 - target.carbohydrates),
                fat: round2(0 - target.fat),
                fiber: round2(0 - target.fiber),
              },
              adherencePercentage: { calories: 0, protein: 0, carbs: 0, fat: 0 },
              complianceDays: {
                calorieCompliantDays: 0,
                proteinCompliantDays: 0,
                totalLoggedDays: 0,
                calorieComplianceRate: 0,
                proteinComplianceRate: 0,
              },
            }
          : undefined,
        missingData: {
          unrecordedDays: [],
          zeroValueLogsCount: 0,
          missingFiberLogsCount: 0,
          dataCompletenessScore: 0,
        },
      };
    }

    // 1. Group records by unique calendar day
    const dayBuckets: { [date: string]: RawFoodLogItem[] } = {};
    let zeroValueLogsCount = 0;
    let missingFiberLogsCount = 0;

    for (const log of foodLogs) {
      const dateStr = log.dateString || 'UNKNOWN';
      if (!dayBuckets[dateStr]) {
        dayBuckets[dateStr] = [];
      }
      dayBuckets[dateStr].push(log);

      if (safeNumber(log.calories) <= 0) {
        zeroValueLogsCount++;
      }
      if (log.fiber === null || log.fiber === undefined || safeNumber(log.fiber) === 0) {
        missingFiberLogsCount++;
      }
    }

    const uniqueDates = Object.keys(dayBuckets).filter(isValidDateString).sort();
    const distinctLoggedDays = uniqueDates.length > 0 ? uniqueDates.length : Object.keys(dayBuckets).length;

    const earliestDate = uniqueDates[0] || startDateFilter || null;
    const latestDate = uniqueDates[uniqueDates.length - 1] || endDateFilter || null;

    const effectiveStart = startDateFilter || earliestDate;
    const effectiveEnd = endDateFilter || latestDate;

    const elapsedDays = effectiveStart && effectiveEnd
      ? calculateElapsedDays(effectiveStart, effectiveEnd)
      : Math.max(1, distinctLoggedDays);

    const unloggedDaysCount = Math.max(0, elapsedDays - distinctLoggedDays);
    const loggingAdherencePct = elapsedDays > 0 ? round2((distinctLoggedDays / elapsedDays) * 100) : 100;

    // 2. Identify unrecorded days if range is manageable (<= 31 days)
    const unrecordedDays: string[] = [];
    if (effectiveStart && effectiveEnd && elapsedDays <= 31 && isValidDateString(effectiveStart) && isValidDateString(effectiveEnd)) {
      const [sy, sm, sd] = effectiveStart.split('-').map(Number);
      const current = new Date(Date.UTC(sy, sm - 1, sd));
      const [ey, em, ed] = effectiveEnd.split('-').map(Number);
      const endTimestamp = Date.UTC(ey, em - 1, ed);

      while (current.getTime() <= endTimestamp) {
        const y = current.getUTCFullYear();
        const m = String(current.getUTCMonth() + 1).padStart(2, '0');
        const d = String(current.getUTCDate()).padStart(2, '0');
        const iso = `${y}-${m}-${d}`;
        if (!dayBuckets[iso]) {
          unrecordedDays.push(iso);
        }
        current.setUTCDate(current.getUTCDate() + 1);
      }
    }

    // 3. Accumulate totals across all logs
    let totalCalories = 0;
    let totalProtein = 0;
    let totalCarbs = 0;
    let totalFat = 0;
    let totalFiber = 0;

    for (const log of foodLogs) {
      totalCalories += Math.max(0, safeNumber(log.calories));
      totalProtein += Math.max(0, safeNumber(log.protein));
      totalCarbs += Math.max(0, safeNumber(log.carbohydrates));
      totalFat += Math.max(0, safeNumber(log.fat));
      totalFiber += Math.max(0, safeNumber(log.fiber));
    }

    const roundedTotalCalories = round2(totalCalories);
    const roundedTotalProtein = round2(totalProtein);
    const roundedTotalCarbs = round2(totalCarbs);
    const roundedTotalFat = round2(totalFat);
    const roundedTotalFiber = round2(totalFiber);

    // Averages over logged days (sole standard for intake averages)
    const averageDailyCalories = round2(roundedTotalCalories / Math.max(distinctLoggedDays, 1));
    const averageDailyProtein = round2(roundedTotalProtein / Math.max(distinctLoggedDays, 1));
    const averageDailyCarbs = round2(roundedTotalCarbs / Math.max(distinctLoggedDays, 1));
    const averageDailyFat = round2(roundedTotalFat / Math.max(distinctLoggedDays, 1));
    const averageDailyFiber = round2(roundedTotalFiber / Math.max(distinctLoggedDays, 1));

    // Calendar average across all elapsed days
    const calendarAverageDailyCalories = round2(roundedTotalCalories / Math.max(elapsedDays, 1));

    // Macro Split
    const macroCaloricSplit = this.calculateMacroCaloriesAndPercentages(
      averageDailyProtein,
      averageDailyCarbs,
      averageDailyFat
    );

    // 4. Target Comparison & Day-by-Day Compliance
    let targetComparison: NutritionSummaryAnalysis['targetComparison'];
    if (target) {
      const targetCal = round2(target.dailyCalories);
      const targetP = round2(target.protein);
      const targetC = round2(target.carbohydrates);
      const targetF = round2(target.fat);
      const targetFib = round2(target.fiber);

      const diffCalories = round2(averageDailyCalories - targetCal);
      const diffProtein = round2(averageDailyProtein - targetP);
      const diffCarbs = round2(averageDailyCarbs - targetC);
      const diffFat = round2(averageDailyFat - targetF);
      const diffFiber = round2(averageDailyFiber - targetFib);

      const calorieAdherencePct = targetCal > 0 ? round2((averageDailyCalories / targetCal) * 100) : 0;
      const proteinAdherencePct = targetP > 0 ? round2((averageDailyProtein / targetP) * 100) : 0;
      const carbsAdherencePct = targetC > 0 ? round2((averageDailyCarbs / targetC) * 100) : 0;
      const fatAdherencePct = targetF > 0 ? round2((averageDailyFat / targetF) * 100) : 0;

      // Evaluate compliance per logged day
      let calorieCompliantDays = 0;
      let proteinCompliantDays = 0;

      for (const [dateKey, dayLogs] of Object.entries(dayBuckets)) {
        let dayCal = 0;
        let dayP = 0;
        for (const item of dayLogs) {
          dayCal += Math.max(0, safeNumber(item.calories));
          dayP += Math.max(0, safeNumber(item.protein));
        }
        if (targetCal > 0 && Math.abs(dayCal - targetCal) <= targetCal * 0.1) {
          calorieCompliantDays++;
        }
        if (targetP > 0 && dayP >= targetP * 0.9) {
          proteinCompliantDays++;
        }
      }

      const calorieComplianceRate = distinctLoggedDays > 0
        ? round2((calorieCompliantDays / distinctLoggedDays) * 100)
        : 0;
      const proteinComplianceRate = distinctLoggedDays > 0
        ? round2((proteinCompliantDays / distinctLoggedDays) * 100)
        : 0;

      targetComparison = {
        hasActiveTarget: true,
        target,
        difference: {
          calories: diffCalories,
          protein: diffProtein,
          carbs: diffCarbs,
          fat: diffFat,
          fiber: diffFiber,
        },
        adherencePercentage: {
          calories: calorieAdherencePct,
          protein: proteinAdherencePct,
          carbs: carbsAdherencePct,
          fat: fatAdherencePct,
        },
        complianceDays: {
          calorieCompliantDays,
          proteinCompliantDays,
          totalLoggedDays: distinctLoggedDays,
          calorieComplianceRate,
          proteinComplianceRate,
        },
      };
    }

    // 5. Data Completeness Score (0 - 100%)
    // Weightings: Logging adherence (50%), non-zero items ratio (30%), recorded fiber ratio (20%)
    const nonZeroRatio = foodLogs.length > 0 ? (foodLogs.length - zeroValueLogsCount) / foodLogs.length : 1;
    const fiberRatio = foodLogs.length > 0 ? (foodLogs.length - missingFiberLogsCount) / foodLogs.length : 1;
    const completenessScore = round2(
      (loggingAdherencePct * 0.5) + (nonZeroRatio * 100 * 0.3) + (fiberRatio * 100 * 0.2)
    );

    return {
      dateRange: {
        startDate: effectiveStart,
        endDate: effectiveEnd,
        elapsedDays,
      },
      totalLoggedCalories: roundedTotalCalories,
      totalLoggedProtein: roundedTotalProtein,
      totalLoggedCarbs: roundedTotalCarbs,
      totalLoggedFat: roundedTotalFat,
      totalLoggedFiber: roundedTotalFiber,
      distinctLoggedDays,
      unloggedDaysCount,
      loggingAdherencePct,
      totalLogsCount: foodLogs.length,
      averageDailyCalories,
      averageDailyProtein,
      averageDailyCarbs,
      averageDailyFat,
      averageDailyFiber,
      calendarAverageDailyCalories,
      macroCaloricSplit,
      targetComparison,
      missingData: {
        unrecordedDays,
        zeroValueLogsCount,
        missingFiberLogsCount,
        dataCompletenessScore: Math.min(100, Math.max(0, completenessScore)),
      },
    };
  }

  /**
   * Generates chronological daily breakdowns, weekly rollups, and detects intake trends.
   */
  public calculateNutritionHistory(
    foodLogs: RawFoodLogItem[],
    target?: NutritionTarget | null,
    startDateFilter?: string | null,
    endDateFilter?: string | null
  ): NutritionHistoryAnalysis {
    if (!foodLogs || foodLogs.length === 0) {
      return {
        dateRange: {
          startDate: startDateFilter || null,
          endDate: endDateFilter || null,
          elapsedDays: 0,
        },
        distinctLoggedDays: 0,
        dailyBreakdowns: [],
        weeklyRollups: [],
        trends: {
          calorieTrend: 'INSUFFICIENT_DATA',
          proteinTrend: 'INSUFFICIENT_DATA',
          calorieChangeAvg: 0,
          proteinChangeAvg: 0,
        },
        extremes: {
          highestCalorieDay: null,
          lowestCalorieDay: null,
          highestProteinDay: null,
          lowestProteinDay: null,
        },
      };
    }

    // Group logs by dateString
    const dayBuckets: { [date: string]: RawFoodLogItem[] } = {};
    for (const log of foodLogs) {
      const d = log.dateString || 'UNKNOWN';
      if (!dayBuckets[d]) {
        dayBuckets[d] = [];
      }
      dayBuckets[d].push(log);
    }

    const sortedDates = Object.keys(dayBuckets).sort();
    const dailyBreakdowns: DailyNutritionBreakdown[] = [];

    let highestCalDay: { date: string; calories: number } | null = null;
    let lowestCalDay: { date: string; calories: number } | null = null;
    let highestProtDay: { date: string; protein: number } | null = null;
    let lowestProtDay: { date: string; protein: number } | null = null;

    for (const date of sortedDates) {
      const daily = this.calculateDailyNutrition(dayBuckets[date], target, date);
      dailyBreakdowns.push(daily);

      // Track extremes
      if (!highestCalDay || daily.totalCalories > highestCalDay.calories) {
        highestCalDay = { date, calories: daily.totalCalories };
      }
      if (!lowestCalDay || daily.totalCalories < lowestCalDay.calories) {
        lowestCalDay = { date, calories: daily.totalCalories };
      }
      if (!highestProtDay || daily.totalProtein > highestProtDay.protein) {
        highestProtDay = { date, protein: daily.totalProtein };
      }
      if (!lowestProtDay || daily.totalProtein < lowestProtDay.protein) {
        lowestProtDay = { date, protein: daily.totalProtein };
      }
    }

    // Weekly Rollups
    const weeklyRollups: WeeklyNutritionRollup[] = [];
    const chunkSize = 7;
    for (let i = 0; i < dailyBreakdowns.length; i += chunkSize) {
      const slice = dailyBreakdowns.slice(i, i + chunkSize);
      const weekIndex = Math.floor(i / chunkSize) + 1;
      const startD = slice[0].date;
      const endD = slice[slice.length - 1].date;

      let sumCal = 0;
      let sumP = 0;
      let sumC = 0;
      let sumF = 0;
      let sumFib = 0;

      for (const d of slice) {
        sumCal += d.totalCalories;
        sumP += d.totalProtein;
        sumC += d.totalProtein;
        sumF += d.totalFat;
        sumFib += d.totalFiber;
      }

      const count = slice.length;
      weeklyRollups.push({
        weekLabel: `Week ${weekIndex} (${startD} to ${endD})`,
        startDate: startD,
        endDate: endD,
        loggedDaysCount: count,
        averageDailyCalories: round2(sumCal / count),
        averageDailyProtein: round2(sumP / count),
        averageDailyCarbs: round2(sumC / count),
        averageDailyFat: round2(sumF / count),
        averageDailyFiber: round2(sumFib / count),
      });
    }

    // Detect Trends across chronological daily breakdowns
    let calorieTrend: NutritionHistoryAnalysis['trends']['calorieTrend'] = 'INSUFFICIENT_DATA';
    let proteinTrend: NutritionHistoryAnalysis['trends']['proteinTrend'] = 'INSUFFICIENT_DATA';
    let calorieChangeAvg = 0;
    let proteinChangeAvg = 0;

    if (dailyBreakdowns.length >= 3) {
      const mid = Math.floor(dailyBreakdowns.length / 2);
      const firstHalf = dailyBreakdowns.slice(0, mid);
      const secondHalf = dailyBreakdowns.slice(mid);

      const firstAvgCal = firstHalf.reduce((acc, d) => acc + d.totalCalories, 0) / firstHalf.length;
      const secondAvgCal = secondHalf.reduce((acc, d) => acc + d.totalCalories, 0) / secondHalf.length;

      const firstAvgProt = firstHalf.reduce((acc, d) => acc + d.totalProtein, 0) / firstHalf.length;
      const secondAvgProt = secondHalf.reduce((acc, d) => acc + d.totalProtein, 0) / secondHalf.length;

      calorieChangeAvg = round2(secondAvgCal - firstAvgCal);
      proteinChangeAvg = round2(secondAvgProt - firstAvgProt);

      // Stable threshold: ±5%
      const calStableThreshold = firstAvgCal * 0.05;
      if (Math.abs(calorieChangeAvg) <= calStableThreshold) {
        calorieTrend = 'STABLE';
      } else if (calorieChangeAvg > 0) {
        calorieTrend = 'INCREASING';
      } else {
        calorieTrend = 'DECREASING';
      }

      const protStableThreshold = firstAvgProt * 0.05;
      if (Math.abs(proteinChangeAvg) <= protStableThreshold) {
        proteinTrend = 'STABLE';
      } else if (proteinChangeAvg > 0) {
        proteinTrend = 'INCREASING';
      } else {
        proteinTrend = 'DECREASING';
      }
    }

    const earliest = sortedDates[0] || startDateFilter || null;
    const latest = sortedDates[sortedDates.length - 1] || endDateFilter || null;
    const elapsedDays = earliest && latest ? calculateElapsedDays(earliest, latest) : sortedDates.length;

    return {
      dateRange: {
        startDate: earliest,
        endDate: latest,
        elapsedDays,
      },
      distinctLoggedDays: sortedDates.length,
      dailyBreakdowns,
      weeklyRollups,
      trends: {
        calorieTrend,
        proteinTrend,
        calorieChangeAvg,
        proteinChangeAvg,
      },
      extremes: {
        highestCalorieDay: highestCalDay,
        lowestCalorieDay: lowestCalDay,
        highestProteinDay: highestProtDay,
        lowestProteinDay: lowestProtDay,
      },
    };
  }

  /**
   * Analyzes meal composition across Breakfast, Lunch, Dinner, Snacks, and other categories.
   */
  public calculateMealBreakdown(foodLogs: RawFoodLogItem[]): MealBreakdownAnalysis {
    if (!foodLogs || foodLogs.length === 0) {
      return {
        dateRange: { startDate: null, endDate: null },
        totalLoggedMeals: 0,
        distinctLoggedDays: 0,
        mealTypeBreakdown: [],
        mostFrequentMealType: null,
        highestCalorieMealType: null,
        highestProteinMealType: null,
      };
    }

    const uniqueDates = new Set<string>();
    let overallCalories = 0;

    // Group logs by mealType
    const mealBuckets: {
      [mealType: string]: {
        logs: RawFoodLogItem[];
        dates: Set<string>;
        foodCounts: { [name: string]: { occurrences: number; calories: number } };
      };
    } = {};

    for (const log of foodLogs) {
      if (log.dateString) uniqueDates.add(log.dateString);
      overallCalories += Math.max(0, safeNumber(log.calories));

      const rawMealType = (log.mealType || 'General').trim();
      const mealType = rawMealType.charAt(0).toUpperCase() + rawMealType.slice(1).toLowerCase();

      if (!mealBuckets[mealType]) {
        mealBuckets[mealType] = { logs: [], dates: new Set(), foodCounts: {} };
      }
      mealBuckets[mealType].logs.push(log);
      if (log.dateString) mealBuckets[mealType].dates.add(log.dateString);

      const fName = log.foodName || 'Item';
      if (!mealBuckets[mealType].foodCounts[fName]) {
        mealBuckets[mealType].foodCounts[fName] = { occurrences: 0, calories: 0 };
      }
      mealBuckets[mealType].foodCounts[fName].occurrences++;
      mealBuckets[mealType].foodCounts[fName].calories += Math.max(0, safeNumber(log.calories));
    }

    const mealTypeStatsList: MealBreakdownTypeStats[] = [];

    for (const [mealType, data] of Object.entries(mealBuckets)) {
      let cal = 0;
      let p = 0;
      let c = 0;
      let f = 0;
      let fib = 0;

      for (const log of data.logs) {
        cal += Math.max(0, safeNumber(log.calories));
        p += Math.max(0, safeNumber(log.protein));
        c += Math.max(0, safeNumber(log.carbohydrates));
        f += Math.max(0, safeNumber(log.fat));
        fib += Math.max(0, safeNumber(log.fiber));
      }

      const daysCount = Math.max(1, data.dates.size);
      const rCal = round2(cal);
      const rP = round2(p);
      const rC = round2(c);
      const rF = round2(f);
      const rFib = round2(fib);

      const topFoods = Object.entries(data.foodCounts)
        .map(([name, info]) => ({
          foodName: name,
          occurrences: info.occurrences,
          totalCalories: round2(info.calories),
        }))
        .sort((a, b) => b.occurrences - a.occurrences || b.totalCalories - a.totalCalories)
        .slice(0, 5);

      mealTypeStatsList.push({
        mealType,
        totalLogsCount: data.logs.length,
        daysLoggedCount: data.dates.size,
        totalCalories: rCal,
        averageCalories: round2(rCal / daysCount),
        totalProtein: rP,
        averageProtein: round2(rP / daysCount),
        totalCarbs: rC,
        averageCarbs: round2(rC / daysCount),
        totalFat: rF,
        averageFat: round2(rF / daysCount),
        totalFiber: rFib,
        averageFiber: round2(rFib / daysCount),
        percentageOfTotalCalories: overallCalories > 0 ? round2((rCal / overallCalories) * 100) : 0,
        topFoods,
      });
    }

    // Sort by total calories descending
    mealTypeStatsList.sort((a, b) => b.totalCalories - a.totalCalories);

    // Identify descriptors
    let mostFrequent: MealBreakdownTypeStats | null = null;
    let highestCal: MealBreakdownTypeStats | null = null;
    let highestProt: MealBreakdownTypeStats | null = null;

    for (const stat of mealTypeStatsList) {
      if (!mostFrequent || stat.totalLogsCount > mostFrequent.totalLogsCount) {
        mostFrequent = stat;
      }
      if (!highestCal || stat.averageCalories > highestCal.averageCalories) {
        highestCal = stat;
      }
      if (!highestProt || stat.averageProtein > highestProt.averageProtein) {
        highestProt = stat;
      }
    }

    const sortedDates = Array.from(uniqueDates).sort();

    return {
      dateRange: {
        startDate: sortedDates[0] || null,
        endDate: sortedDates[sortedDates.length - 1] || null,
      },
      totalLoggedMeals: foodLogs.length,
      distinctLoggedDays: uniqueDates.size,
      mealTypeBreakdown: mealTypeStatsList,
      mostFrequentMealType: mostFrequent?.mealType || null,
      highestCalorieMealType: highestCal?.mealType || null,
      highestProteinMealType: highestProt?.mealType || null,
    };
  }

  /**
   * Deterministically compares two nutrition periods (e.g. this week vs last week),
   * calculating exact deltas, percentage changes, and directional shifts.
   */
  public compareNutritionPeriods(
    p1Logs: RawFoodLogItem[],
    p2Logs: RawFoodLogItem[],
    p1Range: { startDate: string; endDate: string; label?: string },
    p2Range: { startDate: string; endDate: string; label?: string },
    target?: NutritionTarget | null
  ): NutritionPeriodComparison {
    const s1 = this.calculateNutritionSummary(p1Logs, target, p1Range.startDate, p1Range.endDate);
    const s2 = this.calculateNutritionSummary(p2Logs, target, p2Range.startDate, p2Range.endDate);

    const caloriesDelta = round2(s2.averageDailyCalories - s1.averageDailyCalories);
    const caloriesPercentageChange = s1.averageDailyCalories > 0
      ? round2((caloriesDelta / s1.averageDailyCalories) * 100)
      : null;

    const proteinDelta = round2(s2.averageDailyProtein - s1.averageDailyProtein);
    const proteinPercentageChange = s1.averageDailyProtein > 0
      ? round2((proteinDelta / s1.averageDailyProtein) * 100)
      : null;

    const carbsDelta = round2(s2.averageDailyCarbs - s1.averageDailyCarbs);
    const carbsPercentageChange = s1.averageDailyCarbs > 0
      ? round2((carbsDelta / s1.averageDailyCarbs) * 100)
      : null;

    const fatDelta = round2(s2.averageDailyFat - s1.averageDailyFat);
    const fatPercentageChange = s1.averageDailyFat > 0
      ? round2((fatDelta / s1.averageDailyFat) * 100)
      : null;

    const fiberDelta = round2(s2.averageDailyFiber - s1.averageDailyFiber);
    const fiberPercentageChange = s1.averageDailyFiber > 0
      ? round2((fiberDelta / s1.averageDailyFiber) * 100)
      : null;

    const loggedDaysDelta = s2.distinctLoggedDays - s1.distinctLoggedDays;
    const loggingAdherenceDeltaPct = round2(s2.loggingAdherencePct - s1.loggingAdherencePct);

    let calorieAdherenceDeltaPct: number | null = null;
    let proteinAdherenceDeltaPct: number | null = null;
    if (s1.targetComparison && s2.targetComparison) {
      calorieAdherenceDeltaPct = round2(
        s2.targetComparison.adherencePercentage.calories - s1.targetComparison.adherencePercentage.calories
      );
      proteinAdherenceDeltaPct = round2(
        s2.targetComparison.adherencePercentage.protein - s1.targetComparison.adherencePercentage.protein
      );
    }

    // Directions
    const calDir = Math.abs(caloriesDelta) <= 15 ? 'UNCHANGED' : caloriesDelta > 0 ? 'INCREASED' : 'DECREASED';
    const protDir = Math.abs(proteinDelta) <= 3 ? 'UNCHANGED' : proteinDelta > 0 ? 'INCREASED' : 'DECREASED';
    const carbsDir = Math.abs(carbsDelta) <= 5 ? 'UNCHANGED' : carbsDelta > 0 ? 'INCREASED' : 'DECREASED';
    const fatDir = Math.abs(fatDelta) <= 2 ? 'UNCHANGED' : fatDelta > 0 ? 'INCREASED' : 'DECREASED';

    let adhDir: 'IMPROVED' | 'DECLINED' | 'UNCHANGED' = 'UNCHANGED';
    if (loggingAdherenceDeltaPct > 2) adhDir = 'IMPROVED';
    else if (loggingAdherenceDeltaPct < -2) adhDir = 'DECLINED';

    return {
      period1: {
        label: p1Range.label || `Period 1 (${p1Range.startDate} to ${p1Range.endDate})`,
        dateRange: { startDate: p1Range.startDate, endDate: p1Range.endDate },
        summary: s1,
      },
      period2: {
        label: p2Range.label || `Period 2 (${p2Range.startDate} to ${p2Range.endDate})`,
        dateRange: { startDate: p2Range.startDate, endDate: p2Range.endDate },
        summary: s2,
      },
      deltas: {
        caloriesDelta,
        caloriesPercentageChange,
        proteinDelta,
        proteinPercentageChange,
        carbsDelta,
        carbsPercentageChange,
        fatDelta,
        fatPercentageChange,
        fiberDelta,
        fiberPercentageChange,
        loggedDaysDelta,
        loggingAdherenceDeltaPct,
        calorieAdherenceDeltaPct,
        proteinAdherenceDeltaPct,
      },
      direction: {
        calories: calDir,
        protein: protDir,
        carbs: carbsDir,
        fat: fatDir,
        adherence: adhDir,
      },
    };
  }
}

export const nutritionIntelligenceCalculator = new NutritionIntelligenceCalculator();
