/**
 * Alpha X AI — Nutrition Intelligence Service
 * Phase 10 — Nutrition Intelligence Engine
 *
 * Coordinates database retrieval from Prisma (ClientFoodLog, DietPlan, MacroPlan),
 * prepares inputs, and executes deterministic nutrition calculations.
 */

import { prisma } from '../../../config/prisma';
import { clientDataService } from '../tools/definitions/client/client_data.service';
import {
  NutritionIntelligenceResult,
  RawFoodLogItem,
  NutritionTarget,
  DailyNutritionBreakdown,
  NutritionSummaryAnalysis,
  NutritionHistoryAnalysis,
  MealBreakdownAnalysis,
  NutritionPeriodComparison,
} from './nutrition_intelligence.types';
import {
  validateNutritionDateRange,
  computePresetComparisonNutritionDates,
  validateCustomNutritionComparison,
  formatDateToIso,
  isValidDateString,
} from './nutrition_intelligence.validation';
import { nutritionIntelligenceCalculator } from './nutrition_intelligence.calculator';
import { NutritionDateRangeError } from './nutrition_intelligence.errors';

export interface NutritionFilterOptions {
  startDate?: string;
  endDate?: string;
  limit?: number;
}

export interface PeriodComparisonFilterOptions {
  preset?: string;
  p1StartDate?: string;
  p1EndDate?: string;
  p2StartDate?: string;
  p2EndDate?: string;
}

export class NutritionIntelligenceService {
  /**
   * Fetches active assigned nutrition target (DietPlan or MacroPlan) for client.
   */
  private async fetchActiveTarget(clientProfileId: string): Promise<NutritionTarget | null> {
    // 1. Check active DietPlan
    const diet = await prisma.dietPlan.findFirst({
      where: { clientProfileId, isActive: true },
      select: {
        planName: true,
        dailyCalories: true,
        protein: true,
        carbohydrates: true,
        fat: true,
        fiber: true,
        waterTargetLiters: true,
      },
      orderBy: { updatedAt: 'desc' },
    });

    if (diet) {
      return {
        planName: diet.planName || 'Active Diet Plan',
        dailyCalories: diet.dailyCalories,
        protein: diet.protein,
        carbohydrates: diet.carbohydrates,
        fat: diet.fat,
        fiber: diet.fiber,
        waterTargetLiters: diet.waterTargetLiters,
        source: 'DIET_PLAN',
      };
    }

    // 2. Check active MacroPlan
    const macro = await prisma.macroPlan.findFirst({
      where: { clientProfileId, isActive: true },
      select: {
        calories: true,
        protein: true,
        carbs: true,
        fat: true,
        fiber: true,
        waterLiters: true,
      },
      orderBy: { updatedAt: 'desc' },
    });

    if (macro) {
      return {
        planName: 'Active Macro Plan',
        dailyCalories: macro.calories,
        protein: macro.protein,
        carbohydrates: macro.carbs,
        fat: macro.fat,
        fiber: macro.fiber,
        waterTargetLiters: macro.waterLiters,
        source: 'MACRO_PLAN',
      };
    }

    return null;
  }

  /**
   * Fetches raw food logs from database for client within date range.
   */
  private async fetchClientFoodLogs(
    clientProfileId: string,
    startDate?: Date | null,
    endDate?: Date | null,
    limit: number = 200
  ): Promise<RawFoodLogItem[]> {
    const where: any = { clientProfileId };

    if (startDate || endDate) {
      where.date = {};
      if (startDate) where.date.gte = startDate;
      if (endDate) where.date.lte = endDate;
    }

    const records = await prisma.clientFoodLog.findMany({
      where,
      select: {
        id: true,
        dateString: true,
        mealType: true,
        foodName: true,
        category: true,
        servingSize: true,
        servingUnit: true,
        quantity: true,
        calories: true,
        protein: true,
        carbohydrates: true,
        fat: true,
        fiber: true,
        source: true,
        weightSource: true,
        mealId: true,
        loggedAt: true,
      },
      orderBy: [
        { date: 'asc' },
        { loggedAt: 'asc' },
      ],
      take: Math.min(Math.max(1, limit), 500),
    });

    return records.map((r) => ({
      id: r.id,
      dateString: r.dateString,
      mealType: r.mealType,
      foodName: r.foodName,
      category: r.category,
      servingSize: r.servingSize,
      servingUnit: r.servingUnit,
      quantity: r.quantity,
      calories: r.calories,
      protein: r.protein,
      carbohydrates: r.carbohydrates,
      fat: r.fat,
      fiber: r.fiber,
      source: r.source,
      weightSource: r.weightSource,
      mealId: r.mealId,
      loggedAt: r.loggedAt,
    }));
  }

  /**
   * 1. ANALYZE NUTRITION SUMMARY:
   * Aggregated nutrition intake, daily averages, macro percentage split, target adherence, and completeness.
   */
  public async analyzeNutritionSummary(
    clientIdOrName: string,
    options: NutritionFilterOptions = {}
  ): Promise<NutritionIntelligenceResult<NutritionSummaryAnalysis> | any> {
    const resolution = await clientDataService.resolveClient(clientIdOrName);
    if (resolution.status !== 'FOUND' || !resolution.client) {
      return {
        status: resolution.status === 'AMBIGUOUS' ? 'AMBIGUOUS_CLIENT' : 'CLIENT_NOT_FOUND',
        clientId: clientIdOrName,
        metric: 'NUTRITION_SUMMARY',
        value: null,
        unit: 'kcal, grams',
        recordCount: 0,
        source: 'ALPHA_X_DATABASE',
        calculationMethod: 'DETERMINISTIC_CALCULATION',
        matches: resolution.matches,
        message: resolution.message,
      };
    }

    const { start, end, startDateStr, endDateStr } = validateNutritionDateRange(options.startDate, options.endDate);
    const limit = options.limit ? Math.min(Math.max(1, options.limit), 500) : 300;

    const [logs, target] = await Promise.all([
      this.fetchClientFoodLogs(resolution.client.profileId, start, end, limit),
      this.fetchActiveTarget(resolution.client.profileId),
    ]);

    const analysis = nutritionIntelligenceCalculator.calculateNutritionSummary(
      logs,
      target,
      startDateStr,
      endDateStr
    );

    if (logs.length === 0) {
      return {
        status: 'NO_RECORDS_FOUND',
        clientId: resolution.client.clientId || resolution.client.profileId,
        metric: 'NUTRITION_SUMMARY',
        value: analysis,
        unit: 'kcal, grams',
        dateRange: { startDate: startDateStr, endDate: endDateStr },
        recordCount: 0,
        source: 'ALPHA_X_DATABASE',
        calculationMethod: 'DETERMINISTIC_CALCULATION',
        dataQuality: 'INSUFFICIENT',
        message: `No food log records found for ${resolution.client.name} in the specified date range.`,
      };
    }

    return {
      status: 'SUCCESS',
      clientId: resolution.client.clientId || resolution.client.profileId,
      metric: 'NUTRITION_SUMMARY',
      value: analysis,
      unit: 'kcal, grams',
      dateRange: { startDate: analysis.dateRange.startDate, endDate: analysis.dateRange.endDate },
      recordCount: logs.length,
      source: 'ALPHA_X_DATABASE',
      calculationMethod: 'DETERMINISTIC_CALCULATION',
      dataQuality: analysis.missingData.dataCompletenessScore >= 80 ? 'HIGH' : analysis.missingData.dataCompletenessScore >= 50 ? 'MODERATE' : 'LOW',
    };
  }

  /**
   * 2. ANALYZE DAILY NUTRITION:
   * Single-day detailed breakdown by meal (Breakfast, Lunch, Dinner, Snacks), items, and comparison to daily target.
   */
  public async analyzeDailyNutrition(
    clientIdOrName: string,
    targetDate?: string,
    options: { limit?: number } = {}
  ): Promise<NutritionIntelligenceResult<DailyNutritionBreakdown> | any> {
    const resolution = await clientDataService.resolveClient(clientIdOrName);
    if (resolution.status !== 'FOUND' || !resolution.client) {
      return {
        status: resolution.status === 'AMBIGUOUS' ? 'AMBIGUOUS_CLIENT' : 'CLIENT_NOT_FOUND',
        clientId: clientIdOrName,
        metric: 'DAILY_NUTRITION',
        value: null,
        unit: 'kcal, grams',
        recordCount: 0,
        source: 'ALPHA_X_DATABASE',
        calculationMethod: 'DETERMINISTIC_CALCULATION',
        matches: resolution.matches,
        message: resolution.message,
      };
    }

    // Default to today or latest logged date if not provided
    let dateStr = targetDate;
    if (dateStr && !isValidDateString(dateStr)) {
      throw new NutritionDateRangeError(`Date '${dateStr}' must be a valid YYYY-MM-DD format.`);
    }

    const targetPromise = this.fetchActiveTarget(resolution.client.profileId);

    // If no date specified, find most recent logged date for this client
    if (!dateStr) {
      const latestLog = await prisma.clientFoodLog.findFirst({
        where: { clientProfileId: resolution.client.profileId },
        orderBy: { date: 'desc' },
        select: { dateString: true },
      });
      dateStr = latestLog?.dateString || formatDateToIso(new Date());
    }

    const { start, end } = validateNutritionDateRange(dateStr, dateStr);

    const [logs, target] = await Promise.all([
      this.fetchClientFoodLogs(resolution.client.profileId, start, end, options.limit || 100),
      targetPromise,
    ]);

    const daily = nutritionIntelligenceCalculator.calculateDailyNutrition(logs, target, dateStr);

    if (logs.length === 0) {
      return {
        status: 'NO_RECORDS_FOUND',
        clientId: resolution.client.clientId || resolution.client.profileId,
        metric: 'DAILY_NUTRITION',
        value: daily,
        unit: 'kcal, grams',
        dateRange: { startDate: dateStr, endDate: dateStr },
        recordCount: 0,
        source: 'ALPHA_X_DATABASE',
        calculationMethod: 'DETERMINISTIC_CALCULATION',
        dataQuality: 'INSUFFICIENT',
        message: `No food log entries recorded for ${resolution.client.name} on ${dateStr}.`,
      };
    }

    return {
      status: 'SUCCESS',
      clientId: resolution.client.clientId || resolution.client.profileId,
      metric: 'DAILY_NUTRITION',
      value: daily,
      unit: 'kcal, grams',
      dateRange: { startDate: dateStr, endDate: dateStr },
      recordCount: logs.length,
      source: 'ALPHA_X_DATABASE',
      calculationMethod: 'DETERMINISTIC_CALCULATION',
      dataQuality: 'HIGH',
    };
  }

  /**
   * 3. GET NUTRITION HISTORY & TRENDS:
   * Multi-day/weekly chronological nutrition trajectory with detected calorie and protein trends.
   */
  public async getNutritionHistory(
    clientIdOrName: string,
    options: NutritionFilterOptions = {}
  ): Promise<NutritionIntelligenceResult<NutritionHistoryAnalysis> | any> {
    const resolution = await clientDataService.resolveClient(clientIdOrName);
    if (resolution.status !== 'FOUND' || !resolution.client) {
      return {
        status: resolution.status === 'AMBIGUOUS' ? 'AMBIGUOUS_CLIENT' : 'CLIENT_NOT_FOUND',
        clientId: clientIdOrName,
        metric: 'NUTRITION_HISTORY',
        value: null,
        unit: 'kcal, grams',
        recordCount: 0,
        source: 'ALPHA_X_DATABASE',
        calculationMethod: 'DETERMINISTIC_CALCULATION',
        matches: resolution.matches,
        message: resolution.message,
      };
    }

    const { start, end, startDateStr, endDateStr } = validateNutritionDateRange(options.startDate, options.endDate);
    const limit = options.limit ? Math.min(Math.max(1, options.limit), 500) : 300;

    const [logs, target] = await Promise.all([
      this.fetchClientFoodLogs(resolution.client.profileId, start, end, limit),
      this.fetchActiveTarget(resolution.client.profileId),
    ]);

    const history = nutritionIntelligenceCalculator.calculateNutritionHistory(
      logs,
      target,
      startDateStr,
      endDateStr
    );

    if (logs.length === 0) {
      return {
        status: 'NO_RECORDS_FOUND',
        clientId: resolution.client.clientId || resolution.client.profileId,
        metric: 'NUTRITION_HISTORY',
        value: history,
        unit: 'kcal, grams',
        dateRange: { startDate: startDateStr, endDate: endDateStr },
        recordCount: 0,
        source: 'ALPHA_X_DATABASE',
        calculationMethod: 'DETERMINISTIC_CALCULATION',
        dataQuality: 'INSUFFICIENT',
        message: `No food history records found for ${resolution.client.name} in the specified period.`,
      };
    }

    return {
      status: 'SUCCESS',
      clientId: resolution.client.clientId || resolution.client.profileId,
      metric: 'NUTRITION_HISTORY',
      value: history,
      unit: 'kcal, grams',
      dateRange: { startDate: history.dateRange.startDate, endDate: history.dateRange.endDate },
      recordCount: logs.length,
      source: 'ALPHA_X_DATABASE',
      calculationMethod: 'DETERMINISTIC_CALCULATION',
      dataQuality: history.distinctLoggedDays >= 7 ? 'HIGH' : 'MODERATE',
    };
  }

  /**
   * 4. ANALYZE MEAL BREAKDOWN:
   * Distribution of calories and macros across meal types (Breakfast, Lunch, Dinner, Snacks).
   */
  public async analyzeMealBreakdown(
    clientIdOrName: string,
    options: NutritionFilterOptions = {}
  ): Promise<NutritionIntelligenceResult<MealBreakdownAnalysis> | any> {
    const resolution = await clientDataService.resolveClient(clientIdOrName);
    if (resolution.status !== 'FOUND' || !resolution.client) {
      return {
        status: resolution.status === 'AMBIGUOUS' ? 'AMBIGUOUS_CLIENT' : 'CLIENT_NOT_FOUND',
        clientId: clientIdOrName,
        metric: 'MEAL_BREAKDOWN',
        value: null,
        unit: 'percentage, kcal, grams',
        recordCount: 0,
        source: 'ALPHA_X_DATABASE',
        calculationMethod: 'DETERMINISTIC_CALCULATION',
        matches: resolution.matches,
        message: resolution.message,
      };
    }

    const { start, end, startDateStr, endDateStr } = validateNutritionDateRange(options.startDate, options.endDate);
    const limit = options.limit ? Math.min(Math.max(1, options.limit), 500) : 300;

    const logs = await this.fetchClientFoodLogs(resolution.client.profileId, start, end, limit);
    const breakdown = nutritionIntelligenceCalculator.calculateMealBreakdown(logs);

    if (logs.length === 0) {
      return {
        status: 'NO_RECORDS_FOUND',
        clientId: resolution.client.clientId || resolution.client.profileId,
        metric: 'MEAL_BREAKDOWN',
        value: breakdown,
        unit: 'percentage, kcal, grams',
        dateRange: { startDate: startDateStr, endDate: endDateStr },
        recordCount: 0,
        source: 'ALPHA_X_DATABASE',
        calculationMethod: 'DETERMINISTIC_CALCULATION',
        dataQuality: 'INSUFFICIENT',
        message: `No meal records found for ${resolution.client.name} to generate a meal breakdown.`,
      };
    }

    return {
      status: 'SUCCESS',
      clientId: resolution.client.clientId || resolution.client.profileId,
      metric: 'MEAL_BREAKDOWN',
      value: breakdown,
      unit: 'percentage, kcal, grams',
      dateRange: { startDate: breakdown.dateRange.startDate, endDate: breakdown.dateRange.endDate },
      recordCount: logs.length,
      source: 'ALPHA_X_DATABASE',
      calculationMethod: 'DETERMINISTIC_CALCULATION',
      dataQuality: 'HIGH',
    };
  }

  /**
   * 5. COMPARE NUTRITION PERIODS:
   * Compares nutrition intake between two periods (preset e.g. THIS_WEEK_VS_LAST_WEEK, or custom dates).
   */
  public async compareNutritionPeriods(
    clientIdOrName: string,
    options: PeriodComparisonFilterOptions = {}
  ): Promise<NutritionIntelligenceResult<NutritionPeriodComparison> | any> {
    const resolution = await clientDataService.resolveClient(clientIdOrName);
    if (resolution.status !== 'FOUND' || !resolution.client) {
      return {
        status: resolution.status === 'AMBIGUOUS' ? 'AMBIGUOUS_CLIENT' : 'CLIENT_NOT_FOUND',
        clientId: clientIdOrName,
        metric: 'PERIOD_COMPARISON',
        value: null,
        unit: 'deltas, percentage',
        recordCount: 0,
        source: 'ALPHA_X_DATABASE',
        calculationMethod: 'DETERMINISTIC_CALCULATION',
        matches: resolution.matches,
        message: resolution.message,
      };
    }

    // Determine period date spans
    let periodDates: {
      period1: { startDate: string; endDate: string; label: string };
      period2: { startDate: string; endDate: string; label: string };
    };

    if (options.p1StartDate && options.p1EndDate && options.p2StartDate && options.p2EndDate) {
      periodDates = validateCustomNutritionComparison(
        options.p1StartDate,
        options.p1EndDate,
        options.p2StartDate,
        options.p2EndDate
      );
    } else {
      periodDates = computePresetComparisonNutritionDates(options.preset || 'THIS_WEEK_VS_LAST_WEEK');
    }

    const p1Range = validateNutritionDateRange(periodDates.period1.startDate, periodDates.period1.endDate);
    const p2Range = validateNutritionDateRange(periodDates.period2.startDate, periodDates.period2.endDate);

    const [p1Logs, p2Logs, target] = await Promise.all([
      this.fetchClientFoodLogs(resolution.client.profileId, p1Range.start, p1Range.end, 300),
      this.fetchClientFoodLogs(resolution.client.profileId, p2Range.start, p2Range.end, 300),
      this.fetchActiveTarget(resolution.client.profileId),
    ]);

    const comparison = nutritionIntelligenceCalculator.compareNutritionPeriods(
      p1Logs,
      p2Logs,
      periodDates.period1,
      periodDates.period2,
      target
    );

    const totalRecords = p1Logs.length + p2Logs.length;

    return {
      status: 'SUCCESS',
      clientId: resolution.client.clientId || resolution.client.profileId,
      metric: 'PERIOD_COMPARISON',
      value: comparison,
      unit: 'deltas, percentage',
      dateRange: {
        startDate: periodDates.period1.startDate,
        endDate: periodDates.period2.endDate,
      },
      recordCount: totalRecords,
      source: 'ALPHA_X_DATABASE',
      calculationMethod: 'DETERMINISTIC_CALCULATION',
      dataQuality: totalRecords > 0 ? 'HIGH' : 'INSUFFICIENT',
    };
  }
}

export const nutritionIntelligenceService = new NutritionIntelligenceService();
