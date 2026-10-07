/**
 * Alpha X AI — Nutrition Intelligence Tool Definitions Barrel
 * Phase 10 — Nutrition Intelligence Engine
 */

import { analyzeClientNutritionSummaryTool } from './analyze_client_nutrition_summary';
import { analyzeClientDailyNutritionTool } from './analyze_client_daily_nutrition';
import { getClientNutritionHistoryTool } from './get_client_nutrition_history';
import { analyzeClientMealBreakdownTool } from './analyze_client_meal_breakdown';
import { compareClientNutritionPeriodsTool } from './compare_client_nutrition_periods';

export * from './analyze_client_nutrition_summary';
export * from './analyze_client_daily_nutrition';
export * from './get_client_nutrition_history';
export * from './analyze_client_meal_breakdown';
export * from './compare_client_nutrition_periods';

export const NUTRITION_INTELLIGENCE_TOOLS = [
  analyzeClientNutritionSummaryTool,
  analyzeClientDailyNutritionTool,
  getClientNutritionHistoryTool,
  analyzeClientMealBreakdownTool,
  compareClientNutritionPeriodsTool,
];
