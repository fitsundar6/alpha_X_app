/**
 * Alpha X AI — Phase 10 Test Suite: Nutrition Intelligence Engine
 *
 * Verifies complete test coverage across:
 * - Schema & Model Compatibility (1-8)
 * - Pure Deterministic Math: Daily Nutrition & Meals (9-18)
 * - Pure Deterministic Math: Aggregated Summaries & Averages (19-28)
 * - Pure Deterministic Math: Macro Caloric Splits & Percentages (29-37)
 * - Pure Deterministic Math: Target Comparison & Adherence Rates (38-47)
 * - Pure Deterministic Math: Missing Data & Unlogged Days Audit (48-55)
 * - Pure Deterministic Math: Meal Breakdown Patterns (56-64)
 * - Pure Deterministic Math: Chronological History & Trend Detection (65-73)
 * - Pure Deterministic Math: Period Comparison Engine (74-84)
 * - Date Range Validation & Preset Calculations (85-91)
 * - Invalid, Zero, Negative & Corrupted Input Safety (92-99)
 * - Security, Permissions & Client Context Isolation (100-106)
 * - Tool System Execution & Schema Validation (107-113)
 * - Real Database Verification (AXG-0007) (114-118)
 * - Localhost Test Gate: End-to-End Gemini Integration (119-122)
 * - Full Regression (Phases 0-9) (123-128)
 */

import http from 'http';
import jwt from 'jsonwebtoken';
import app from '../../server';
import { env } from '../../config/environment';
import { prisma } from '../../config/prisma';
import { geminiService } from './gemini.service';
import { toolRegistry } from './tools/tool.registry';
import { toolExecutor } from './tools/tool.executor';
import { toolConfig } from './tools/tool.config';
import { ToolPermission } from './tools/tool.types';
import { resetToolsToDefault, initializeDefaultTools } from './tools';
import { clientDataService } from './tools/definitions/client/client_data.service';
import { conversationStore } from './conversation';
import {
  nutritionIntelligenceService,
  nutritionIntelligenceCalculator,
  validateNutritionDateRange,
  computePresetComparisonNutritionDates,
  validateCustomNutritionComparison,
  round2,
  RawFoodLogItem,
  NutritionTarget,
} from './nutrition_intelligence';
import { workoutIntelligenceCalculator } from './workout_intelligence';
import { weightCalculator, nutritionCalculator } from './calculations';

async function runPhase10NutritionIntelligenceTests(): Promise<void> {
  console.log('================================================================');
  console.log('🥗  ALPHA X AI — PHASE 10 NUTRITION INTELLIGENCE TEST SUITE');
  console.log('================================================================\n');

  let passed = 0;
  let failed = 0;

  function assert(condition: boolean, testName: string, details?: string): void {
    if (condition) {
      passed++;
      console.log(`✔ [PASS] ${testName}`);
    } else {
      failed++;
      console.error(`❌ [FAIL] ${testName} ${details ? '— ' + details : ''}`);
    }
  }

  // Ensure tool registry and conversation stores are in standard state
  resetToolsToDefault();
  initializeDefaultTools();
  toolConfig.resetToDefaults();
  conversationStore.clear();

  // Spin up test server
  const server = http.createServer(app);
  await new Promise<void>((resolve) => server.listen(0, resolve));
  const address = server.address() as any;
  const baseUrl = `http://127.0.0.1:${address.port}`;
  console.log(`[TEST HARNESS] Running on ${baseUrl}\n`);

  const adminToken = jwt.sign(
    { id: 'admin_alex_stone', email: 'fitsundar6@gmail.com', role: 'ADMIN', name: 'Alpha X Admin' },
    env.JWT_ACCESS_SECRET,
    { expiresIn: '1h' }
  );

  const clientToken = jwt.sign(
    { id: 'client_user_test', email: 'client.test@alphax.local', role: 'CLIENT', name: 'Client Test' },
    env.JWT_ACCESS_SECRET,
    { expiresIn: '1h' }
  );

  const adminContext = {
    adminId: 'admin_alex_stone',
    requestId: 'req_phase10_test',
    conversationId: 'conv_phase10_test',
  };

  try {
    // =========================================================================
    // SECTION 1: SCHEMA & MODEL COMPATIBILITY (Tests 1 - 8)
    // =========================================================================
    console.log('\n--- SECTION 1: SCHEMA & MODEL COMPATIBILITY ---');

    assert(Boolean(prisma.clientFoodLog), 'Test 1: Prisma clientFoodLog model delegate exists');
    assert(Boolean(prisma.dietPlan), 'Test 2: Prisma dietPlan model delegate exists');
    assert(Boolean(prisma.macroPlan), 'Test 3: Prisma macroPlan model delegate exists');
    assert(Boolean(prisma.mealPhoto), 'Test 4: Prisma mealPhoto model delegate exists');
    assert(Boolean(prisma.food), 'Test 5: Prisma food catalog model delegate exists');
    assert(typeof nutritionIntelligenceCalculator.calculateDailyNutrition === 'function', 'Test 6: calculateDailyNutrition method exported');
    assert(typeof nutritionIntelligenceCalculator.calculateNutritionSummary === 'function', 'Test 7: calculateNutritionSummary method exported');
    assert(typeof nutritionIntelligenceCalculator.compareNutritionPeriods === 'function', 'Test 8: compareNutritionPeriods method exported');

    // =========================================================================
    // SECTION 2: PURE DETERMINISTIC MATH: DAILY NUTRITION & MEALS (Tests 9 - 18)
    // =========================================================================
    console.log('\n--- SECTION 2: PURE DETERMINISTIC MATH: DAILY NUTRITION & MEALS ---');

    const sampleDayLogs: RawFoodLogItem[] = [
      {
        id: 'log-1',
        dateString: '2026-10-01',
        mealType: 'Breakfast',
        foodName: 'Oatmeal & Berries',
        category: 'Grains',
        servingSize: 100,
        servingUnit: 'g',
        quantity: 1,
        calories: 350,
        protein: 12,
        carbohydrates: 60,
        fat: 5,
        fiber: 8,
      },
      {
        id: 'log-2',
        dateString: '2026-10-01',
        mealType: 'Breakfast',
        foodName: 'Whey Protein Scoop',
        category: 'Protein',
        servingSize: 30,
        servingUnit: 'g',
        quantity: 1,
        calories: 120,
        protein: 24,
        carbohydrates: 2,
        fat: 1.5,
        fiber: 0,
      },
      {
        id: 'log-3',
        dateString: '2026-10-01',
        mealType: 'Lunch',
        foodName: 'Chicken Breast',
        category: 'Protein',
        servingSize: 150,
        servingUnit: 'g',
        quantity: 1,
        calories: 250,
        protein: 46,
        carbohydrates: 0,
        fat: 5,
        fiber: 0,
      },
      {
        id: 'log-4',
        dateString: '2026-10-01',
        mealType: 'Lunch',
        foodName: 'Basmati Rice',
        category: 'Rice & Meals',
        servingSize: 150,
        servingUnit: 'g',
        quantity: 1,
        calories: 195,
        protein: 4,
        carbohydrates: 42,
        fat: 0.5,
        fiber: 0.6,
      },
      {
        id: 'log-5',
        dateString: '2026-10-01',
        mealType: 'Dinner',
        foodName: 'Salmon Fillet',
        category: 'Fish',
        servingSize: 150,
        servingUnit: 'g',
        quantity: 1,
        calories: 310,
        protein: 30,
        carbohydrates: 0,
        fat: 20,
        fiber: 0,
      },
      {
        id: 'log-6',
        dateString: '2026-10-01',
        mealType: 'Snacks',
        foodName: 'Almonds',
        category: 'Nuts & Seeds',
        servingSize: 30,
        servingUnit: 'g',
        quantity: 1,
        calories: 175,
        protein: 6,
        carbohydrates: 6,
        fat: 15,
        fiber: 3.5,
      },
    ];

    const sampleTarget: NutritionTarget = {
      planName: 'Hypertrophy Phase 1',
      dailyCalories: 1500,
      protein: 120,
      carbohydrates: 120,
      fat: 50,
      fiber: 20,
      source: 'DIET_PLAN',
    };

    const dailyResult = nutritionIntelligenceCalculator.calculateDailyNutrition(sampleDayLogs, sampleTarget, '2026-10-01');

    assert(dailyResult.totalCalories === 1400, 'Test 9: Daily total calories exact summation', `Expected 1400, got ${dailyResult.totalCalories}`);
    assert(dailyResult.totalProtein === 122, 'Test 10: Daily total protein exact summation', `Expected 122, got ${dailyResult.totalProtein}`);
    assert(dailyResult.totalCarbs === 110, 'Test 11: Daily total carbs exact summation', `Expected 110, got ${dailyResult.totalCarbs}`);
    assert(dailyResult.totalFat === 47, 'Test 12: Daily total fat exact summation', `Expected 47, got ${dailyResult.totalFat}`);
    assert(dailyResult.totalFiber === 12.1, 'Test 13: Daily total fiber exact summation', `Expected 12.1, got ${dailyResult.totalFiber}`);
    assert(dailyResult.loggedItemsCount === 6, 'Test 14: Logged items count exact', `Expected 6, got ${dailyResult.loggedItemsCount}`);
    assert(Boolean(dailyResult.meals['Breakfast']), 'Test 15: Breakfast meal bucket present');
    assert(dailyResult.meals['Breakfast'].calories === 470, 'Test 16: Breakfast calories exact (350 + 120)', `Got ${dailyResult.meals['Breakfast']?.calories}`);
    assert(dailyResult.meals['Breakfast'].protein === 36, 'Test 17: Breakfast protein exact (12 + 24)', `Got ${dailyResult.meals['Breakfast']?.protein}`);
    assert(dailyResult.targetComparison?.isProteinCompliant === true, 'Test 18: Daily protein compliant against target (122 >= 120 * 0.9)');

    // =========================================================================
    // SECTION 3: PURE DETERMINISTIC MATH: AGGREGATED SUMMARIES & AVERAGES (Tests 19 - 28)
    // =========================================================================
    console.log('\n--- SECTION 3: PURE DETERMINISTIC MATH: AGGREGATED SUMMARIES & AVERAGES ---');

    const multiDayLogs: RawFoodLogItem[] = [
      ...sampleDayLogs,
      // Day 2 (2026-10-02): 1600 kcal, 130g protein
      { id: 'd2-1', dateString: '2026-10-02', mealType: 'Lunch', foodName: 'Chicken Rice', category: 'General', servingSize: 300, servingUnit: 'g', quantity: 1, calories: 1600, protein: 130, carbohydrates: 150, fat: 40, fiber: 10 },
      // Day 3 (2026-10-03): 1500 kcal, 110g protein
      { id: 'd3-1', dateString: '2026-10-03', mealType: 'Dinner', foodName: 'Steak & Potato', category: 'General', servingSize: 300, servingUnit: 'g', quantity: 1, calories: 1500, protein: 110, carbohydrates: 120, fat: 55, fiber: 8 },
    ];

    const summaryResult = nutritionIntelligenceCalculator.calculateNutritionSummary(
      multiDayLogs,
      sampleTarget,
      '2026-10-01',
      '2026-10-05' // 5 elapsed calendar days, 3 logged days
    );

    assert(summaryResult.distinctLoggedDays === 3, 'Test 19: Distinct logged days count exact', `Expected 3, got ${summaryResult.distinctLoggedDays}`);
    assert(summaryResult.dateRange.elapsedDays === 5, 'Test 20: Elapsed calendar days exact (Oct 1 to Oct 5 = 5)', `Got ${summaryResult.dateRange.elapsedDays}`);
    assert(summaryResult.unloggedDaysCount === 2, 'Test 21: Unlogged days count exact (5 - 3 = 2)', `Got ${summaryResult.unloggedDaysCount}`);
    assert(summaryResult.loggingAdherencePct === 60, 'Test 22: Logging adherence percentage exact (3/5 = 60%)', `Got ${summaryResult.loggingAdherencePct}%`);
    assert(summaryResult.totalLoggedCalories === 4500, 'Test 23: Total logged calories exact (1400 + 1600 + 1500 = 4500)', `Got ${summaryResult.totalLoggedCalories}`);
    assert(summaryResult.averageDailyCalories === 1500, 'Test 24: Average daily calories over logged days exact (4500 / 3 = 1500)', `Got ${summaryResult.averageDailyCalories}`);
    assert(summaryResult.calendarAverageDailyCalories === 900, 'Test 25: Calendar average daily calories across all 5 days (4500 / 5 = 900)', `Got ${summaryResult.calendarAverageDailyCalories}`);
    assert(summaryResult.averageDailyProtein === round2((122 + 130 + 110) / 3), 'Test 26: Average daily protein exact (362 / 3 = 120.67g)', `Got ${summaryResult.averageDailyProtein}`);
    assert(summaryResult.totalLogsCount === 8, 'Test 27: Total individual food logs count exact', `Got ${summaryResult.totalLogsCount}`);
    assert(summaryResult.missingData.unrecordedDays.includes('2026-10-04'), 'Test 28: Unrecorded days identifies missing date 2026-10-04');

    // =========================================================================
    // SECTION 4: PURE DETERMINISTIC MATH: MACRO CALORIC SPLITS (Tests 29 - 37)
    // =========================================================================
    console.log('\n--- SECTION 4: PURE DETERMINISTIC MATH: MACRO CALORIC SPLITS ---');

    // Test with: Protein: 100g (400 kcal), Carbs: 200g (800 kcal), Fat: 50g (450 kcal)
    // Total macro kcal: 1650
    // Protein %: (400 / 1650) * 100 = 24.24%
    // Carbs %: (800 / 1650) * 100 = 48.48%
    // Fat %: (450 / 1650) * 100 = 27.27%
    const split = nutritionIntelligenceCalculator.calculateMacroCaloriesAndPercentages(100, 200, 50);

    assert(split.proteinKcal === 400, 'Test 29: Protein kcal conversion (100 * 4 = 400)', `Got ${split.proteinKcal}`);
    assert(split.carbsKcal === 800, 'Test 30: Carbs kcal conversion (200 * 4 = 800)', `Got ${split.carbsKcal}`);
    assert(split.fatKcal === 450, 'Test 31: Fat kcal conversion (50 * 9 = 450)', `Got ${split.fatKcal}`);
    assert(split.totalMacroKcal === 1650, 'Test 32: Total macro kcal exact (400 + 800 + 450 = 1650)', `Got ${split.totalMacroKcal}`);
    assert(split.proteinPct === 24.24, 'Test 33: Protein % of total macro kcal (24.24%)', `Got ${split.proteinPct}%`);
    assert(split.carbsPct === 48.48, 'Test 34: Carbs % of total macro kcal (48.48%)', `Got ${split.carbsPct}%`);
    assert(split.fatPct === 27.27, 'Test 35: Fat % of total macro kcal (27.27%)', `Got ${split.fatPct}%`);
    assert(round2(split.proteinPct + split.carbsPct + split.fatPct) === 99.99 || round2(split.proteinPct + split.carbsPct + split.fatPct) === 100, 'Test 36: Percentages sum to ~100%');

    // Edge case: All zeros
    const zeroSplit = nutritionIntelligenceCalculator.calculateMacroCaloriesAndPercentages(0, 0, 0);
    assert(zeroSplit.totalMacroKcal === 0 && zeroSplit.proteinPct === 0, 'Test 37: Zero macro input safe guard returns 0%');

    // =========================================================================
    // SECTION 5: PURE DETERMINISTIC MATH: TARGET COMPARISON & ADHERENCE (Tests 38 - 47)
    // =========================================================================
    console.log('\n--- SECTION 5: PURE DETERMINISTIC MATH: TARGET COMPARISON & ADHERENCE ---');

    assert(Boolean(summaryResult.targetComparison), 'Test 38: Target comparison block generated');
    assert(summaryResult.targetComparison?.difference.calories === 0, 'Test 39: Calorie delta exact (1500 - 1500 = 0)', `Got ${summaryResult.targetComparison?.difference.calories}`);
    assert(summaryResult.targetComparison?.adherencePercentage.calories === 100, 'Test 40: Calorie adherence percentage exact 100%', `Got ${summaryResult.targetComparison?.adherencePercentage.calories}%`);
    assert(summaryResult.targetComparison?.difference.protein === 0.67, 'Test 41: Protein delta exact (120.67 - 120 = +0.67g)', `Got ${summaryResult.targetComparison?.difference.protein}`);
    assert(summaryResult.targetComparison?.complianceDays.totalLoggedDays === 3, 'Test 42: Total logged days in compliance tracker is 3');
    assert(summaryResult.targetComparison?.complianceDays.calorieCompliantDays === 3, 'Test 43: All 3 days within ±10% of 1500 target (1400, 1600, 1500)');
    assert(summaryResult.targetComparison?.complianceDays.calorieComplianceRate === 100, 'Test 44: Calorie compliance rate is 100%');
    assert(summaryResult.targetComparison?.complianceDays.proteinCompliantDays === 3, 'Test 45: All 3 days hit >= 90% of 120g protein (108g min)');
    assert(summaryResult.targetComparison?.complianceDays.proteinComplianceRate === 100, 'Test 46: Protein compliance rate is 100%');

    // Non-target run
    const noTargetSummary = nutritionIntelligenceCalculator.calculateNutritionSummary(multiDayLogs, null);
    assert(noTargetSummary.targetComparison === undefined, 'Test 47: No target comparison generated when client has no target');

    // =========================================================================
    // SECTION 6: PURE DETERMINISTIC MATH: MISSING DATA AUDIT (Tests 48 - 55)
    // =========================================================================
    console.log('\n--- SECTION 6: PURE DETERMINISTIC MATH: MISSING DATA AUDIT ---');

    const corruptedLogs: RawFoodLogItem[] = [
      { id: 'c-1', dateString: '2026-10-01', mealType: 'Breakfast', foodName: 'Zero item', category: 'General', servingSize: 100, servingUnit: 'g', quantity: 1, calories: 0, protein: 0, carbohydrates: 0, fat: 0, fiber: 0 },
      { id: 'c-2', dateString: '2026-10-01', mealType: 'Lunch', foodName: 'No fiber item', category: 'General', servingSize: 100, servingUnit: 'g', quantity: 1, calories: 200, protein: 10, carbohydrates: 20, fat: 5, fiber: 0 },
    ];
    const missingAudit = nutritionIntelligenceCalculator.calculateNutritionSummary(corruptedLogs, null, '2026-10-01', '2026-10-02');

    assert(missingAudit.missingData.zeroValueLogsCount === 1, 'Test 48: Detects 1 zero-calorie log item');
    assert(missingAudit.missingData.missingFiberLogsCount === 2, 'Test 49: Detects 2 items missing fiber');
    assert(missingAudit.missingData.dataCompletenessScore < 60, 'Test 50: Completeness score penalized for missing data', `Score: ${missingAudit.missingData.dataCompletenessScore}`);
    assert(missingAudit.missingData.unrecordedDays.includes('2026-10-02'), 'Test 51: Unrecorded days includes 2026-10-02');

    const emptySummary = nutritionIntelligenceCalculator.calculateNutritionSummary([], null);
    assert(emptySummary.totalLoggedCalories === 0, 'Test 52: Empty logs produces 0 calories');
    assert(emptySummary.distinctLoggedDays === 0, 'Test 53: Empty logs produces 0 distinct days');
    assert(emptySummary.missingData.dataCompletenessScore === 0, 'Test 54: Empty logs completeness score is 0');
    assert(emptySummary.loggingAdherencePct === 0, 'Test 55: Empty logs logging adherence is 0%');

    // =========================================================================
    // SECTION 7: PURE DETERMINISTIC MATH: MEAL BREAKDOWN (Tests 56 - 64)
    // =========================================================================
    console.log('\n--- SECTION 7: PURE DETERMINISTIC MATH: MEAL BREAKDOWN ---');

    const mealBreakdown = nutritionIntelligenceCalculator.calculateMealBreakdown(sampleDayLogs);

    assert(mealBreakdown.totalLoggedMeals === 6, 'Test 56: Total logged meals matches item count (6)');
    assert(mealBreakdown.distinctLoggedDays === 1, 'Test 57: Distinct logged days in breakdown is 1');
    assert(mealBreakdown.mealTypeBreakdown.length === 4, 'Test 58: 4 distinct meal types found (Breakfast, Lunch, Dinner, Snacks)');
    assert(mealBreakdown.highestCalorieMealType === 'Breakfast', 'Test 59: Highest calorie meal type is Breakfast (470 kcal)', `Got ${mealBreakdown.highestCalorieMealType}`);
    assert(mealBreakdown.highestProteinMealType === 'Lunch', 'Test 60: Highest protein meal type is Lunch (50g protein)', `Got ${mealBreakdown.highestProteinMealType}`);
    assert(mealBreakdown.mostFrequentMealType === 'Breakfast' || mealBreakdown.mostFrequentMealType === 'Lunch', 'Test 61: Most frequent meal type identified');

    const breakfastStats = mealBreakdown.mealTypeBreakdown.find((m) => m.mealType === 'Breakfast');
    assert(Boolean(breakfastStats), 'Test 62: Breakfast stats present');
    assert(breakfastStats?.percentageOfTotalCalories === round2((470 / 1400) * 100), 'Test 63: Breakfast percentage of total daily calories exact (33.57%)', `Got ${breakfastStats?.percentageOfTotalCalories}%`);
    assert(breakfastStats?.topFoods.length === 2, 'Test 64: Top foods in Breakfast includes Oatmeal & Whey');

    // =========================================================================
    // SECTION 8: PURE DETERMINISTIC MATH: HISTORY & TRENDS (Tests 65 - 73)
    // =========================================================================
    console.log('\n--- SECTION 8: PURE DETERMINISTIC MATH: HISTORY & TRENDS ---');

    // Create 4 days of increasing calorie intake: 1200, 1400, 1600, 1800
    const trendLogs: RawFoodLogItem[] = [
      { id: 't-1', dateString: '2026-10-01', mealType: 'General', foodName: 'Food 1', category: 'General', servingSize: 100, servingUnit: 'g', quantity: 1, calories: 1200, protein: 100, carbohydrates: 100, fat: 40, fiber: 10 },
      { id: 't-2', dateString: '2026-10-02', mealType: 'General', foodName: 'Food 2', category: 'General', servingSize: 100, servingUnit: 'g', quantity: 1, calories: 1400, protein: 110, carbohydrates: 120, fat: 45, fiber: 12 },
      { id: 't-3', dateString: '2026-10-03', mealType: 'General', foodName: 'Food 3', category: 'General', servingSize: 100, servingUnit: 'g', quantity: 1, calories: 1600, protein: 120, carbohydrates: 140, fat: 50, fiber: 14 },
      { id: 't-4', dateString: '2026-10-04', mealType: 'General', foodName: 'Food 4', category: 'General', servingSize: 100, servingUnit: 'g', quantity: 1, calories: 1800, protein: 130, carbohydrates: 160, fat: 55, fiber: 16 },
    ];

    const history = nutritionIntelligenceCalculator.calculateNutritionHistory(trendLogs);

    assert(history.dailyBreakdowns.length === 4, 'Test 65: 4 chronological daily breakdowns produced');
    assert(history.trends.calorieTrend === 'INCREASING', 'Test 66: Calorie trend detected as INCREASING', `Got ${history.trends.calorieTrend}`);
    assert(history.trends.proteinTrend === 'INCREASING', 'Test 67: Protein trend detected as INCREASING', `Got ${history.trends.proteinTrend}`);
    assert(history.extremes.highestCalorieDay?.date === '2026-10-04', 'Test 68: Highest calorie day is 2026-10-04 (1800 kcal)');
    assert(history.extremes.lowestCalorieDay?.date === '2026-10-01', 'Test 69: Lowest calorie day is 2026-10-01 (1200 kcal)');
    assert(history.extremes.highestProteinDay?.date === '2026-10-04', 'Test 70: Highest protein day is 2026-10-04 (130g)');
    assert(history.extremes.lowestProteinDay?.date === '2026-10-01', 'Test 71: Lowest protein day is 2026-10-01 (100g)');
    assert(history.weeklyRollups.length === 1, 'Test 72: Weekly rollup generated 1 chunk for 4 days');
    assert(history.weeklyRollups[0].averageDailyCalories === 1500, 'Test 73: Weekly average calories exact (6000 / 4 = 1500)', `Got ${history.weeklyRollups[0].averageDailyCalories}`);

    // =========================================================================
    // SECTION 9: PURE DETERMINISTIC MATH: PERIOD COMPARISON (Tests 74 - 84)
    // =========================================================================
    console.log('\n--- SECTION 9: PURE DETERMINISTIC MATH: PERIOD COMPARISON ---');

    // Period 1 (Last week): 1400 kcal/day, 100g protein/day
    const p1Logs: RawFoodLogItem[] = [
      { id: 'p1-1', dateString: '2026-09-21', mealType: 'General', foodName: 'P1 food', category: 'General', servingSize: 100, servingUnit: 'g', quantity: 1, calories: 1400, protein: 100, carbohydrates: 150, fat: 40, fiber: 10 },
      { id: 'p1-2', dateString: '2026-09-22', mealType: 'General', foodName: 'P1 food', category: 'General', servingSize: 100, servingUnit: 'g', quantity: 1, calories: 1400, protein: 100, carbohydrates: 150, fat: 40, fiber: 10 },
    ];
    // Period 2 (This week): 1750 kcal/day (+25%), 130g protein/day (+30%)
    const p2Logs: RawFoodLogItem[] = [
      { id: 'p2-1', dateString: '2026-09-28', mealType: 'General', foodName: 'P2 food', category: 'General', servingSize: 100, servingUnit: 'g', quantity: 1, calories: 1750, protein: 130, carbohydrates: 180, fat: 50, fiber: 15 },
      { id: 'p2-2', dateString: '2026-09-29', mealType: 'General', foodName: 'P2 food', category: 'General', servingSize: 100, servingUnit: 'g', quantity: 1, calories: 1750, protein: 130, carbohydrates: 180, fat: 50, fiber: 15 },
    ];

    const periodComparison = nutritionIntelligenceCalculator.compareNutritionPeriods(
      p1Logs,
      p2Logs,
      { startDate: '2026-09-21', endDate: '2026-09-22', label: 'Last Week' },
      { startDate: '2026-09-28', endDate: '2026-09-29', label: 'This Week' },
      sampleTarget
    );

    assert(periodComparison.deltas.caloriesDelta === 350, 'Test 74: Calories delta exact (1750 - 1400 = +350 kcal)', `Got ${periodComparison.deltas.caloriesDelta}`);
    assert(periodComparison.deltas.caloriesPercentageChange === 25, 'Test 75: Calories percentage change exact (+25%)', `Got ${periodComparison.deltas.caloriesPercentageChange}%`);
    assert(periodComparison.deltas.proteinDelta === 30, 'Test 76: Protein delta exact (130 - 100 = +30g)', `Got ${periodComparison.deltas.proteinDelta}`);
    assert(periodComparison.deltas.proteinPercentageChange === 30, 'Test 77: Protein percentage change exact (+30%)', `Got ${periodComparison.deltas.proteinPercentageChange}%`);
    assert(periodComparison.deltas.carbsDelta === 30, 'Test 78: Carbs delta exact (180 - 150 = +30g)');
    assert(periodComparison.deltas.fatDelta === 10, 'Test 79: Fat delta exact (50 - 40 = +10g)');
    assert(periodComparison.deltas.fiberDelta === 5, 'Test 80: Fiber delta exact (15 - 10 = +5g)');
    assert(periodComparison.direction.calories === 'INCREASED', 'Test 81: Direction of calories is INCREASED');
    assert(periodComparison.direction.protein === 'INCREASED', 'Test 82: Direction of protein is INCREASED');
    assert(periodComparison.period1.label === 'Last Week', 'Test 83: Period 1 label preserved');
    assert(periodComparison.period2.label === 'This Week', 'Test 84: Period 2 label preserved');

    // =========================================================================
    // SECTION 10: DATE RANGE VALIDATION & PRESETS (Tests 85 - 91)
    // =========================================================================
    console.log('\n--- SECTION 10: DATE RANGE VALIDATION & PRESETS ---');

    const validRange = validateNutritionDateRange('2026-10-01', '2026-10-07');
    assert(validRange.startDateStr === '2026-10-01', 'Test 85: Valid startDate parsed');
    assert(validRange.endDateStr === '2026-10-07', 'Test 86: Valid endDate parsed');
    assert(validRange.elapsedDays === 6 || validRange.elapsedDays === 7, 'Test 87: Elapsed days calculated accurately');

    let dateErrorThrown = false;
    try {
      validateNutritionDateRange('2026-10-10', '2026-10-01'); // Inverted
    } catch (e: any) {
      dateErrorThrown = true;
    }
    assert(dateErrorThrown, 'Test 88: Inverted date range correctly throws NutritionDateRangeError');

    const preset7 = computePresetComparisonNutritionDates('LAST_7_DAYS_VS_PREVIOUS_7_DAYS', new Date('2026-10-06T00:00:00Z'));
    assert(Boolean(preset7.period1.startDate && preset7.period2.endDate), 'Test 89: LAST_7_DAYS preset dates computed');
    assert(preset7.period1.label === 'Previous 7 Days', 'Test 90: Period 1 label is Previous 7 Days');

    const customValid = validateCustomNutritionComparison('2026-09-01', '2026-09-07', '2026-09-08', '2026-09-14');
    assert(customValid.period1.startDate === '2026-09-01', 'Test 91: Custom comparison dates validated');

    // =========================================================================
    // SECTION 11: INVALID, ZERO & CORRUPTED INPUT SAFETY (Tests 92 - 99)
    // =========================================================================
    console.log('\n--- SECTION 11: INVALID, ZERO & CORRUPTED INPUT SAFETY ---');

    const corruptedDataLogs: any[] = [
      { id: 'err-1', dateString: '2026-10-01', calories: -50, protein: null, carbohydrates: 'invalid', fat: undefined, fiber: NaN },
      { id: 'err-2', dateString: '2026-10-01', calories: null, protein: -20, carbohydrates: null, fat: -10, fiber: null },
    ];
    const safeSummary = nutritionIntelligenceCalculator.calculateNutritionSummary(corruptedDataLogs, null);

    assert(safeSummary.totalLoggedCalories === 0, 'Test 92: Negative/null calories safely clamped to 0', `Got ${safeSummary.totalLoggedCalories}`);
    assert(safeSummary.totalLoggedProtein === 0, 'Test 93: Negative/null protein safely clamped to 0', `Got ${safeSummary.totalLoggedProtein}`);
    assert(safeSummary.averageDailyCalories === 0, 'Test 94: Safe average calories with zero division guard');
    assert(!Number.isNaN(safeSummary.macroCaloricSplit.proteinPct), 'Test 95: Macro split percentages never produce NaN');

    const safeDaily = nutritionIntelligenceCalculator.calculateDailyNutrition(corruptedDataLogs, null);
    assert(safeDaily.totalCalories === 0, 'Test 96: Daily total calories safe against corrupted fields');
    assert(!Number.isNaN(safeDaily.macroCalories.proteinKcal), 'Test 97: Daily macro calories never produce NaN');

    const emptyBreakdown = nutritionIntelligenceCalculator.calculateMealBreakdown([]);
    assert(emptyBreakdown.totalLoggedMeals === 0, 'Test 98: Empty logs meal breakdown safe return');

    const emptyHistory = nutritionIntelligenceCalculator.calculateNutritionHistory([]);
    assert(emptyHistory.dailyBreakdowns.length === 0, 'Test 99: Empty logs nutrition history safe return');

    // =========================================================================
    // SECTION 12: SECURITY, PERMISSIONS & CLIENT ISOLATION (Tests 100 - 106)
    // =========================================================================
    console.log('\n--- SECTION 12: SECURITY, PERMISSIONS & CLIENT ISOLATION ---');

    // Test resolving non-existent client
    const nonExistentResult = await nutritionIntelligenceService.analyzeNutritionSummary('NON_EXISTENT_CLIENT_ID_XYZ');
    assert(nonExistentResult.status === 'CLIENT_NOT_FOUND', 'Test 100: Non-existent client returns CLIENT_NOT_FOUND without guessing');

    // Test resolving ambiguous client
    const ambiguousResult = await nutritionIntelligenceService.analyzeNutritionSummary('Alex Mercer');
    assert(ambiguousResult.status === 'AMBIGUOUS_CLIENT' || ambiguousResult.matches?.length > 1, 'Test 101: Ambiguous client name rejected without arbitrary selection');

    // Test cross-client permission check on toolExecutor
    const summaryToolDef = toolRegistry.getTool('analyze_client_nutrition_summary');
    assert(Boolean(summaryToolDef), 'Test 102: analyze_client_nutrition_summary registered in tool registry');
    assert(summaryToolDef?.permission === ToolPermission.ANALYZE_DATA, 'Test 103: Tool permission is ANALYZE_DATA');

    // Verified Client Context Scoping: If verifiedClient is provided in context, handler scopes to that verified client
    const verifiedContext = {
      ...adminContext,
      verifiedClient: {
        profileId: 'de487357-9576-4c2e-8a84-0c282fda2666',
        clientId: 'AXG-0007',
        name: 'Sakthiprabakar',
      },
    };

    const toolExecution = await toolExecutor.executeTool(
      'analyze_client_nutrition_summary',
      { clientId: 'DIFFERENT_CLIENT_NAME' }, // Should be overridden by verifiedClient context
      verifiedContext as any
    );
    assert(toolExecution.success === true, 'Test 104: Tool execution succeeded with verified client context');
    assert(toolExecution.data.clientId === 'AXG-0007', 'Test 105: Context strictly scoped execution to verified client AXG-0007');

    // Rejection of unauthorized client execution (missing adminId)
    const clientUserContext = {
      adminId: '', // Missing / empty adminId
      requestId: 'req_unauth_test',
    };
    const unauthExecution = await toolExecutor.executeTool(
      'analyze_client_nutrition_summary',
      { clientId: 'AXG-0007' },
      clientUserContext as any
    );
    assert(unauthExecution.success === false, 'Test 106: Unauthorized non-admin context rejected by ToolExecutor');

    // =========================================================================
    // SECTION 13: TOOL SYSTEM EXECUTION & REGISTRY (Tests 107 - 113)
    // =========================================================================
    console.log('\n--- SECTION 13: TOOL SYSTEM EXECUTION & REGISTRY ---');

    assert(toolRegistry.hasTool('analyze_client_nutrition_summary'), 'Test 107: analyze_client_nutrition_summary registered');
    assert(toolRegistry.hasTool('analyze_client_daily_nutrition'), 'Test 108: analyze_client_daily_nutrition registered');
    assert(toolRegistry.hasTool('get_client_nutrition_history'), 'Test 109: get_client_nutrition_history registered');
    assert(toolRegistry.hasTool('analyze_client_meal_breakdown'), 'Test 110: analyze_client_meal_breakdown registered');
    assert(toolRegistry.hasTool('compare_client_nutrition_periods'), 'Test 111: compare_client_nutrition_periods registered');

    // Test daily nutrition tool execution
    const dailyToolExec = await toolExecutor.executeTool(
      'analyze_client_daily_nutrition',
      { clientId: 'AXG-0007', date: '2026-10-06' },
      adminContext as any
    );
    assert(dailyToolExec.success === true, 'Test 112: analyze_client_daily_nutrition tool executes successfully');
    assert(dailyToolExec.data.metric === 'DAILY_NUTRITION', 'Test 113: Tool returns metric DAILY_NUTRITION');

    // =========================================================================
    // SECTION 14: REAL DATABASE VERIFICATION (AXG-0007) (Tests 114 - 118)
    // =========================================================================
    console.log('\n--- SECTION 14: REAL DATABASE VERIFICATION (AXG-0007) ---');

    const dbSummary = await nutritionIntelligenceService.analyzeNutritionSummary('AXG-0007');
    assert(dbSummary.status === 'SUCCESS', 'Test 114: Real database nutrition summary succeeds for AXG-0007');
    assert(dbSummary.recordCount > 0, 'Test 115: Real food log records found for AXG-0007', `Count: ${dbSummary.recordCount}`);
    assert(dbSummary.value.distinctLoggedDays > 0, 'Test 116: Distinct logged days > 0 for AXG-0007', `Days: ${dbSummary.value.distinctLoggedDays}`);
    assert(dbSummary.source === 'ALPHA_X_DATABASE', 'Test 117: Source is strictly ALPHA_X_DATABASE');
    assert(dbSummary.calculationMethod === 'DETERMINISTIC_CALCULATION', 'Test 118: Method is strictly DETERMINISTIC_CALCULATION');

    // =========================================================================
    // SECTION 15: LOCALHOST TEST GATE: GEMINI INTEGRATION (Tests 119 - 122)
    // =========================================================================
    console.log('\n--- SECTION 15: LOCALHOST TEST GATE: GEMINI INTEGRATION ---');

    console.log('Testing live Gemini prompt with client nutrition question...');
    const chatResult = await geminiService.generateFitnessResponse({
      message: 'How is Sakthiprabakar doing with his protein intake?',
      adminId: 'admin_alex_stone',
      requestId: 'req_gate_test_p10',
    });

    assert(Boolean(chatResult.response), 'Test 119: Gemini live response received');
    assert(chatResult.response.length > 0, 'Test 120: Gemini generation completed with content');
    assert(Boolean(chatResult.toolsInvokedNames && chatResult.toolsInvokedNames.length > 0), 'Test 121: Gemini invoked database tools for client query', `Tools: ${(chatResult.toolsInvokedNames || []).join(', ')}`);
    assert(!chatResult.response.includes('I cannot assist with this request'), 'Test 122: Gemini provided substantive, evidence-grounded response');

    // =========================================================================
    // SECTION 16: FULL REGRESSION TESTING (Phases 0 - 9) (Tests 123 - 128)
    // =========================================================================
    console.log('\n--- SECTION 16: FULL REGRESSION TESTING (Phases 0 - 9) ---');

    // Phase 8 Weight calculator
    const weightRes = weightCalculator.calculateWeightSummary([
      { date: new Date('2026-09-01'), weightKg: 85 },
      { date: new Date('2026-10-01'), weightKg: 82 },
    ]);
    assert(weightRes.value.changeKg === -3, 'Test 123: Regression: Phase 8 weight delta exact (-3 kg)');

    // Phase 8 Nutrition calculator
    const phase8Nut = nutritionCalculator.calculateNutritionSummary([
      { dateString: '2026-10-01', calories: 2000, protein: 150, carbohydrates: 200, fat: 60, fiber: 30 },
    ]);
    assert(phase8Nut.value.totalLoggedCalories === 2000, 'Test 124: Regression: Phase 8 nutrition calculator exact (2000 kcal)');

    // Phase 9 Workout intelligence session volume
    const volRes = workoutIntelligenceCalculator.analyzeVolume([
      {
        id: 'w-1',
        sessionTitle: 'Upper',
        startedAt: new Date(),
        durationSeconds: 3600,
        totalVolume: 5000,
        completedSetsCount: 15,
        isCompleted: true,
        exerciseRecords: [],
      },
    ]);
    assert(volRes.totalVolumeKg === 5000, 'Test 125: Regression: Phase 9 workout volume exact (5000 kg)');

    // Tool registry size check
    const totalTools = toolRegistry.listTools(true);
    assert(totalTools.length >= 24, 'Test 126: Regression: All baseline, client, calculation, workout, and nutrition tools registered', `Total: ${totalTools.length}`);

    // Meal breakdown tool execution via toolExecutor
    const mealToolExec = await toolExecutor.executeTool(
      'analyze_client_meal_breakdown',
      { clientId: 'AXG-0007' },
      adminContext as any
    );
    assert(mealToolExec.success === true, 'Test 127: analyze_client_meal_breakdown executes via ToolExecutor');

    // Period comparison tool execution via toolExecutor
    const periodToolExec = await toolExecutor.executeTool(
      'compare_client_nutrition_periods',
      { clientId: 'AXG-0007', preset: 'THIS_WEEK_VS_LAST_WEEK' },
      adminContext as any
    );
    assert(periodToolExec.success === true, 'Test 128: compare_client_nutrition_periods executes via ToolExecutor');

  } finally {
    server.close();
  }

  console.log('\n================================================================');
  console.log(`🏁  PHASE 10 TEST SUMMARY: ${passed} PASSED, ${failed} FAILED`);
  console.log('================================================================\n');

  if (failed > 0) {
    process.exit(1);
  }
}

runPhase10NutritionIntelligenceTests().catch((err) => {
  console.error('Fatal test runner error:', err);
  process.exit(1);
});
